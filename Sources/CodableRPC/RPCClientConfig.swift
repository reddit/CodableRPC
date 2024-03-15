import os.log

/// Configuration options for the client.
public struct RPCClientConfig {
  /// An OSLog instance used for logging client activity.
  public let log: OSLog

  /// The number of threads used for dispatching RPC calls.
  public let numberOfThreads: UInt

  /// The maximum number of connection attempts to perform before failing.
  public let maxConnectionAttempts: UInt

  /// The base retry interval in seconds. This value grows exponentially with each retry up to `maxRetryInterval`.
  public let connectionRetryBase: Double

  /// The maximum interval between retries in seconds.
  public let maxRetryInterval: Double

  /// - Parameters:
  ///   - log: An OSLog instance used for logging client activity. A reasonable default is provided.
  ///   - numberOfThreads: The number of threads used for dispatching RPC calls. 1 is a reasonable default for most workloads. Default: 1.
  ///   - maxConnectionAttempts: The maximum number of connection attempts to perform before failing. Default: 10.
  ///   - connectionRetryBase: The base retry interval in seconds. This value grows exponentially with each retry up to `maxRetryInterval`. Default: 0.1 seconds.
  ///   - maxRetryInterval: The maximum interval between retries in seconds. Default: 10 seconds.
  public init(
    log: OSLog = OSLog(subsystem: "codable_rpc", category: "client"),
    numberOfThreads: UInt = 1,
    maxConnectionAttempts: UInt = 10,
    connectionRetryBase: Double = 0.1,
    maxRetryInterval: Double = 10
  ) {
    self.log = log
    self.numberOfThreads = numberOfThreads
    self.maxConnectionAttempts = maxConnectionAttempts
    self.connectionRetryBase = connectionRetryBase
    self.maxRetryInterval = maxRetryInterval
  }
}
