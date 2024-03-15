import XCTest
import CodableRPC
import RPCMethod

final class ExampleUITests: XCTestCase {
  func testExample() throws {
    // Launch the app containing the RPC server.
    let app = XCUIApplication()
    app.launch()

    // Connect the client.
    let client = RPCClient<ExampleRPCMethod>()
    try client.connect(host: "127.0.0.1", port: 1234)

    for _ in 0..<100 {
      // Perform the 'ping' method.
      let result = try client.call(.ping)

      switch result {
      case .pong(let time):
        print("Server time:", Int(time))
      }

      wait(forDuration: 1)
    }

    try client.disconnect()
  }

  private func wait(forDuration duration: TimeInterval) {
    CFRunLoopRunInMode(.defaultMode, duration, false)
  }
}
