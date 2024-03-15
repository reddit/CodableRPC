import Foundation
import NIOCore
import os.log

/// An RPC client that communicates with a server using the generic `Method` type.
/// The remote server must be specialized with the same type as the client.
///
/// All connections perform exponential backoff. See `RPCClientConfig` for relevant configuration
/// options.
public final class RPCClient<Method: RPCMethod> {
  private let config: RPCClientConfig

  private var connection: ClientConnection<Method>?

  public init(config: RPCClientConfig = .init()) {
    self.config = config
  }

  deinit {
    assert(state == .initialized || state == .disconnected)
  }

  /// Initiates a connection to a server at the given address.
  public func connect(host: String, port: Int) throws {
    guard state == .initialized || state == .disconnected else {
      throw RPCClientError.invalidState(expected: [.initialized, .disconnected], actual: state)
    }

    state = .connecting(host: host, port: port)
    let connectionManager = ClientConnectionManager<Method>(config: config, log: config.log)
    connection = try connectionManager.connect(host: host, port: port)
    state = .connected
  }

  /// Disconnects from the server.
  public func disconnect() throws {
    guard state == .connected else { return }

    state = .disconnecting
    connection?.close()
    connection = nil
    state = .disconnected
  }

  /// Performs the given method on the server.
  @discardableResult
  public func call(_ method: Method, timeout: TimeAmount = .seconds(10)) throws -> Method.Result {
    guard state == .connected, let connection else {
      throw RPCClientError.invalidState(expected: [.connected], actual: state)
    }

    return try connection.call(method, timeout: timeout)
  }

  // MARK: - Private

  private var _state = RPCClientState.initialized
  private let lock = NSLock()
  private var state: RPCClientState {
    get {
      let localState: RPCClientState
      lock.lock()
      localState = _state
      lock.unlock()
      return localState
    }
    set {
      lock.lock()
      _state = newValue
      os_log("RPCClient: %{public}s", log: config.log, "\(newValue)")
      lock.unlock()
    }
  }
}

public enum RPCClientState: Equatable, CustomStringConvertible {
  case initialized
  case connecting(host: String, port: Int)
  case connected
  case disconnecting
  case disconnected

  public var description: String {
    switch self {
    case .initialized:
      return "initialized"
    case .connecting(let host, let port):
      return "connecting to \(host):\(port)"
    case .connected:
      return "connected"
    case .disconnecting:
      return "disconnecting"
    case .disconnected:
      return "disconnected"
    }
  }
}

public enum RPCClientError: Error, LocalizedError {
  case callTimeout
  case connectionResetByPeer
  case invalidState(expected: [RPCClientState], actual: RPCClientState)
  case connectionClosed

  public var errorDescription: String? {
    "\(String(describing: Self.self)).\(caseDescription)"
  }

  private var caseDescription: String {
    switch self {
    case .callTimeout:
      return "callTimeout"
    case .connectionResetByPeer:
      return "connectionResetByPeer"
    case .invalidState(let expected, let actual):
      return "invalidState(expected: \(expected), actual: \(actual))"
    case .connectionClosed:
      return "connectionClosed"
    }
  }
}
