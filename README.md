# CodableRPC

CodableRPC is a general purpose RPC client & server implemented in Swift based on [SwiftNIO](https://github.com/apple/swift-nio). It uses Swift's [Codable](https://developer.apple.com/documentation/swift/encoding-decoding-and-serialization) for serialization, enabling you to write idiomatic and type-safe method calls.

While a general purpose RPC implementation, Reddit uses CodableRPC to support ad hoc communication between XCTest UI tests and the iOS app.

## Usage

```swift
// An RPCMethod enum defines the methods that can be performed by the server.
enum ExampleRPCMethod: RPCMethod {
  typealias Result = ExampleMethodResult

  case ping
}

// The method result enum defines the responses returned by the server.
enum ExampleMethodResult: Codable {
  case pong(TimeInterval)
}

// Construct external dependencies needed by the RPC methods. These objects would likely be
// provided by your dependency injection system.
struct MethodDependencies {
  let timeProvider = TimeProvider()

  struct TimeProvider {
    var currentTime: TimeInterval {
      Date().timeIntervalSinceReferenceDate
    }
  }
}

// Extend the 'RPCMethod' method type in your server target with 'RPCMethodPerformable' to
// implement the method that performs the methods.
extension ExampleRPCMethod: RPCMethodPerformable {
  func perform(dependencyProvider: MethodDependencies) async throws -> ExampleMethodResult {
    switch self {
    case .ping:
      return .pong(dependencyProvider.timeProvider.currentTime)
    }
  }
}

// Start the server.
let server = RPCServer<ExampleRPCMethod>(dependencyProvider: MethodDependencies())
try server.start(host: "127.0.0.1", port: 1234)

// Connect the client.
let client = RPCClient<ExampleRPCMethod>()
try client.connect(host: "127.0.0.1", port: 1234)

// Perform the 'ping' method.
let result = try client.call(.ping)

switch result {
case .pong(let currentTime):
  print(currentTime)
}
```

The included [example project](https://github.com/reddit/CodableRPC/tree/main/Example) demonstrates using CodableRPC to communicate between a UI test and the iOS app under test.

## Configuration

Both `RPCServer` and `RPCClient` can be initialized with custom configurations, though the defaults should be reasonable for simple workloads. See the documentation on `RPCServerConfig` and `RPCClientConfig` for details.
