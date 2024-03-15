import os.log

/// Configuration options for the server.
public struct RPCServerConfig {
  /// An OSLog instance used for logging sever activity.
  public let log: OSLog

  /// The number of threads used for processing RPC calls from clients.
  public let numberOfThreads: Int

  /// - Parameters:
  ///   - log: An OSLog instance used for logging sever activity. A reasonable default is provided.
  ///   - numberOfThreads: The number of threads used for processing RPC calls from clients.
  public init(
    log: OSLog = OSLog(subsystem: "codable_rpc", category: "server"),
    numberOfThreads: Int = 1
  ) {
    self.log = log
    self.numberOfThreads = numberOfThreads
  }
}
