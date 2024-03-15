import Foundation
import CodableRPC

// An RPCMethod enum defines the methods that can be performed by the server.
public enum ExampleRPCMethod: RPCMethod {
  public typealias Result = ExampleMethodResult

  case ping
}

// The method result enum defines the responses returned by the server.
public enum ExampleMethodResult: Codable {
  case pong(TimeInterval)
}
