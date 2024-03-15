import Foundation
import CodableRPC
import RPCMethod

// Construct external dependencies needed by the RPC methods. These objects would likely be
// provided by your dependency injection system.
public struct MethodDependencies {
  public let timeProvider: TimeProvider

  public init(timeProvider: TimeProvider = TimeProvider()) {
    self.timeProvider = timeProvider
  }

  public struct TimeProvider {
    public init () {}

    public var currentTime: TimeInterval {
      Date().timeIntervalSinceReferenceDate
    }
  }
}

// Extend the 'RPCMethod' method type in your server target with 'RPCMethodPerformable' to
// implement the method that performs the methods.
extension ExampleRPCMethod: RPCMethodPerformable {
  public func perform(dependencyProvider: MethodDependencies) async throws -> ExampleMethodResult {
    switch self {
    case .ping:
      return .pong(dependencyProvider.timeProvider.currentTime)
    }
  }
}
