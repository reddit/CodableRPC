import Foundation
import NIOCore
import NIOPosix
import os.log

/// A connection manager with exponential backoff.
final class ClientConnectionManager<Method: RPCMethod> {
  private typealias MethodResult = Result<Method.Result, CodableError>

  private let config: RPCClientConfig
  private let log: OSLog

  init(config: RPCClientConfig, log: OSLog) {
    self.config = config
    self.log = log
  }

  /// Opens a connection to the given host and port.
  func connect(host: String, port: Int) throws -> ClientConnection<Method> {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: Int(config.numberOfThreads))
    let eventLoop = group.any()
    let promise = eventLoop.makePromise(of: ClientConnection<Method>.self)
    connect(
      eventLoop: eventLoop,
      promise: promise,
      group: group,
      attempt: 1,
      host: host,
      port: port
    )
    return try promise.futureResult.wait()
  }

  // MARK: - Private

  private func connect(
    eventLoop: EventLoop,
    promise: EventLoopPromise<ClientConnection<Method>>,
    group: MultiThreadedEventLoopGroup,
    attempt: Int,
    host: String,
    port: Int
  ) {
    let bootstrap = ClientBootstrap(group: group)
      .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
      .channelInitializer { [log] channel in
        let frameHandler = NullDelimitedFrameHandler()
        return channel.pipeline.addHandlers(
          [
            ByteToMessageHandler(frameHandler),
            MessageToByteHandler(frameHandler),
            CodableHandler<MethodResult, Method>(),
            MethodHandler<Method>(log: log),
          ]
        )
      }
    bootstrap.connect(host: host, port: port).whenComplete { [config, log] result in
      switch result {
      case .success(let channel):
        let connection = ClientConnection<Method>(
          log: log,
          channel: channel,
          group: group
        )
        promise.succeed(connection)
      case .failure(let error):
        guard attempt < config.maxConnectionAttempts else {
          promise.fail(error)
          return
        }

        let interval = min(config.maxRetryInterval, config.connectionRetryBase * pow(Double(2), Double(attempt - 1)))

        eventLoop.scheduleTask(in: .milliseconds(Int64(interval * 1_000))) {
          self.connect(
            eventLoop: eventLoop,
            promise: promise,
            group: group,
            attempt: attempt + 1,
            host: host,
            port: port
          )
        }
      }
    }
  }
}

private class MethodHandler<Method: RPCMethod>: ChannelInboundHandler, ChannelOutboundHandler {
  typealias InboundIn = Result<Method.Result, CodableError>
  typealias OutboundIn = PromisedMethod<Method, InboundIn>
  typealias OutboundOut = Method

  private let log: OSLog
  private var queue = CircularBuffer<EventLoopPromise<InboundIn>>()

  init(log: OSLog) {
    self.log = log
  }

  func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
    let promisedMethod = unwrapOutboundIn(data)
    queue.append(promisedMethod.promise)
    context.write(wrapOutboundOut(promisedMethod.method), promise: promise)
  }

  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    if queue.isEmpty {
      // Method has already been handled, forward read to next handler.
      return context.fireChannelRead(data)
    }

    let promise = queue.removeFirst()
    let result = unwrapInboundIn(data)
    promise.succeed(result)
  }

  func errorCaught(context: ChannelHandlerContext, error: Error) {
    os_log("RPCClient: server error %{public}s", log: log, "\(error)")

    if queue.isEmpty {
      // Method has already been handled, forward error to next handler.
      return context.fireErrorCaught(error)
    }

    let promise = queue.removeFirst()
    switch error {
    case is CodableHandlerError:
      promise.succeed(.failure(.init(description: error.localizedDescription)))

    default:
      // Unhandled error, close the connection.
      promise.fail(error)
      context.close(promise: nil)
    }
  }

  func channelInactive(context: ChannelHandlerContext) {
    if !queue.isEmpty {
      errorCaught(context: context, error: RPCClientError.connectionResetByPeer)
    }
  }

  func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
    context.fireUserInboundEventTriggered(event)
  }
}
