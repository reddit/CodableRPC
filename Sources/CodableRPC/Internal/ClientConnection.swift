import Foundation
import NIOCore
import NIOPosix
import os.log

/// An RPC client connection.
final class ClientConnection<Method: RPCMethod> {
  private typealias MethodResult = Result<Method.Result, CodableError>

  private let log: OSLog
  private var channel: Channel?
  private var group: MultiThreadedEventLoopGroup?

  init(log: OSLog, channel: Channel, group: MultiThreadedEventLoopGroup) {
    self.log = log
    self.channel = channel
    self.group = group
  }

  /// Performs the given method on the server.
  @discardableResult
  func call(_ method: Method, timeout: TimeAmount) throws -> Method.Result {
    guard let channel else {
      throw RPCClientError.connectionClosed
    }

    let promise: EventLoopPromise<MethodResult> = channel.eventLoop.makePromise()
    let promisedMethod = PromisedMethod(method: method, promise: promise)
    let future = channel.writeAndFlush(promisedMethod)
    future.cascadeFailure(to: promise)

    let task = channel.eventLoop.scheduleTask(in: timeout) {
      promise.fail(RPCClientError.callTimeout)
    }

    let result = try promise.futureResult.wait()
    task.cancel()
    switch result {
    case .success(let success):
      return success

    case .failure(let error):
      throw error
    }
  }

  /// Closes the client connection.
  func close() {
    do {
      // Wait for the channel to close, but ignore errors as it may already be closed.
      try channel?.close().wait()
      channel = nil
    } catch {
      os_log("RPCClient: channel close error: %{public}s", log: log, "\(error)")
    }

    do {
      // Wait for the group to shutdown, but ignore any errors as we've no way to recover.
      try group?.syncShutdownGracefully()
      group = nil
    } catch {
      os_log("RPCClient: group shutdown error: %{public}s", log: log, "\(error)")
    }
  }
}
