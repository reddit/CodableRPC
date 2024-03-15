import SwiftUI
import CodableRPC
import RPCMethod
import RPCMethodPerformable

@main
struct ExampleApp: App {
  var server: RPCServer<ExampleRPCMethod>?

  init() {
    let server = RPCServer<ExampleRPCMethod>(dependencyProvider: MethodDependencies())
    self.server = server
    try! server.start(host: "127.0.0.1", port: 1234)
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
