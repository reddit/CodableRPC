import Foundation
import NIOCore
import NIOPosix
import os.log

/// An RPC server that receives communications from a client using the generic `Method` type.
/// The connecting client must be specialized with the same type as the server.
public final class RPCServer<Method: RPCMethodPerformable> {
  private let config: RPCServerConfig
  private let dependencyProvider: Method.DependencyProvider

  private var group: MultiThreadedEventLoopGroup?
  private var channel: Channel?

  /// - Parameters:
  ///   - config: The configuration of the server instance.
  ///   - dependencyProvider: An object providing external dependencies for use by `RPCMethodPerformable`.
  public init(config: RPCServerConfig = .init(), dependencyProvider: Method.DependencyProvider) {
    self.config = config
    self.dependencyProvider = dependencyProvider
  }

  deinit {
    assert(state == .initialized || state == .stopped)
  }

  /// Starts the server and binds to the given address.
  public func start(host: String, port: Int) throws {
    guard state == .initialized || state == .stopped else {
      throw RPCServerError.invalidState(expected: [.initialized, .stopped], actual: state)
    }

    state = .starting(host: host, port: port)
    let group = MultiThreadedEventLoopGroup(numberOfThreads: config.numberOfThreads)
    self.group = group

    // The channel options used below may not have detailed documentation when viewing Quick Help,
    // but they're actually pretty well documented if you navigate to `ChannelOptions` and search
    // for the option struct.

    let bootstrap = ServerBootstrap(group: group)
      .serverChannelOption(ChannelOptions.backlog, value: 256)
      .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
      .childChannelInitializer { [log = config.log, dependencyProvider] channel in
        let frameHandler = NullDelimitedFrameHandler()
        return channel.pipeline.addHandlers(
          [
            ByteToMessageHandler(frameHandler),
            MessageToByteHandler(frameHandler),
            CodableHandler<Method, Result<Method.Result, CodableError>>(),
            MethodHandler<Method>(log: log, dependencyProvider: dependencyProvider),
          ]
        )
      }
      .childChannelOption(ChannelOptions.tcpOption(.tcp_nodelay), value: 1)
      .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

    channel = try bootstrap.bind(host: host, port: port).wait()
    state = .started
  }

  /// Stops the server and disconnects any clients.
  public func stop() throws {
    guard state == .started else { return }

    state = .stopping

    // Wait for the channel to close, but ignore errors as it may already be closed.
    try? channel?.close().wait()
    channel = nil

    // Wait for the group to shutdown, but ignore errors as we've no way to recover.
    try? group?.syncShutdownGracefully()
    group = nil

    state = .stopped
  }

  private var _state = RPCServerState.initialized
  private let lock = NSLock()
  private var state: RPCServerState {
    get {
      let localState: RPCServerState
      lock.lock()
      localState = _state
      lock.unlock()
      return localState
    }
    set {
      lock.lock()
      _state = newValue
      os_log("RPCServer: %{public}s", log: config.log, "\(newValue)")
      lock.unlock()
    }
  }
}

private class MethodHandler<Method: RPCMethodPerformable>: ChannelInboundHandler {
  typealias InboundIn = Method
  typealias OutboundOut = Result<Method.Result, CodableError>

  private let log: OSLog
  private let dependencyProvider: Method.DependencyProvider

  init(log: OSLog, dependencyProvider: Method.DependencyProvider) {
    self.log = log
    self.dependencyProvider = dependencyProvider
  }

  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    let promise: EventLoopPromise<OutboundOut> = context.eventLoop.makePromise()
    promise.futureResult.whenComplete { result in
      switch result {
      case .success(let callResult):
        context.channel.writeAndFlush(self.wrapOutboundOut(callResult), promise: nil)
      case .failure(let error):
        self.errorCaught(context: context, error: error)
      }
    }
    let method = unwrapInboundIn(data)

    Task {
      do {
        let result = try await method.perform(dependencyProvider: dependencyProvider)
        promise.succeed(.success(result))
      } catch {
        let msg = "RPCServer: Failure performing method \(String(describing: method)): \(error.localizedDescription)"
        promise.succeed(.failure(CodableError(description: msg)))
      }
    }
  }

  func errorCaught(context: ChannelHandlerContext, error: Error) {
    os_log("RPCServer: client error %{public}s", log: log, "\(error)")

    let codableError = CodableError(description: error.localizedDescription)
    let result = wrapOutboundOut(.failure(codableError))
    context.channel.writeAndFlush(result, promise: nil)

    // Close the client connection.
    context.close(promise: nil)
  }

  func channelActive(context: ChannelHandlerContext) {
    if let ip = context.remoteAddress?.ipAddress,
       let port = context.remoteAddress?.port {
      os_log("RPCServer: client %{public}s connected", log: log, "\(ip):\(port)")
    }
  }

  func channelInactive(context: ChannelHandlerContext) {
    if let ip = context.remoteAddress?.ipAddress,
       let port = context.remoteAddress?.port {
      os_log("RPCServer: client %{public}s disconnected", log: log, "\(ip):\(port)")
    }
  }

  func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
    context.fireUserInboundEventTriggered(event)
  }
}

private enum RPCServerState: Equatable, CustomStringConvertible {
  case initialized
  case starting(host: String, port: Int)
  case started
  case stopping
  case stopped

  var description: String {
    switch self {
    case .initialized:
      return "initialized"
    case .starting(let host, let port):
      return "starting on \(host):\(port)"
    case .started:
      return "started"
    case .stopping:
      return "stopping"
    case .stopped:
      return "stopped"
    }
  }
}

private enum RPCServerError: Error, LocalizedError {
  case invalidState(expected: [RPCServerState], actual: RPCServerState)

  var errorDescription: String? {
    "\(String(describing: Self.self)).\(caseDescription)"
  }

  private var caseDescription: String {
    switch self {
    case .invalidState(let expected, let actual):
      return "invalidState(expected: \(expected), actual: \(actual))"
    }
  }
}
