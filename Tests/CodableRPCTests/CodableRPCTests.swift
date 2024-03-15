import Foundation
import CodableRPC
import XCTest

final class CodableRPCTests: XCTestCase {
  private var server: RPCServer<TestMethod>!
  private var client: RPCClient<TestMethod>!
  private let host = "127.0.0.1"
  private var port = 0

  override func setUpWithError() throws {
    try super.setUpWithError()
    // Random port to avoid collisions when tests are run in parallel.
    port = Int.random(in: 1_024...9_999)
    server = RPCServer<TestMethod>(dependencyProvider: DependencyProvider())
    client = RPCClient<TestMethod>()
    try connect()
  }

  override func tearDownWithError() throws {
    try disconnect()
    server = nil
    client = nil
    try super.tearDownWithError()
  }

  func testSuccessMethod() throws {
    let parameters = ThingParameters(message: "abc123")
    let result = try client.call(.getThing(parameters))

    switch result {
    case .thing(let result):
      XCTAssertEqual(parameters.message, result.message)
    case .none:
      XCTFail("Unexpected result.")
    }
  }

  func testFailureMethod() throws {
    XCTAssertThrowsError(try client.call(.doThingWithFailure)) { error in
      XCTAssertEqual(
        error.localizedDescription,
        "RPCServer: Failure performing method doThingWithFailure: this is fine"
      )
    }
  }

  func testMultipleCalls() throws {
    for i in 0..<10 {
      let parameters = ThingParameters(message: "\(i)")
      let result = try client.call(.getThing(parameters))

      switch result {
      case .thing(let result):
        XCTAssertEqual(parameters.message, result.message)
      case .none:
        XCTFail("Unexpected result.")
      }
    }
  }

  func testAsyncMethod() throws {
    for i in 0..<10 {
      let parameters = ThingParameters(message: "\(i)")
      let result = try client.call(.getThingAsync(parameters))

      switch result {
      case .thing(let result):
        XCTAssertEqual(parameters.message, result.message)
      case .none:
        XCTFail("Unexpected result.")
      }
    }
  }

  func testCallTimeout() throws {
    XCTAssertThrowsError(try client.call(.sleep(0.5), timeout: .milliseconds(100))) { error in
      if let clientError = error as? RPCClientError, case .callTimeout = clientError {
        // Success.
      } else {
        XCTFail("Unexpected error: \(error)")
      }
    }
  }

  // MARK: - Private

  private func connect() throws {
    try server.start(host: host, port: port)
    try client.connect(host: host, port: port)
  }

  private func disconnect() throws {
    try client.disconnect()
    try server.stop()
  }
}

enum TestMethod: RPCMethod {
  typealias Result = TestMethodResult

  case getThing(ThingParameters)
  case getThingAsync(ThingParameters)
  case doThingWithFailure
  case sleep(TimeInterval)
}

extension TestMethod: RPCMethodPerformable {
  func perform(dependencyProvider: DependencyProvider) async throws -> TestMethodResult {
    switch self {
    case .getThing(let parameters):
      return .thing(ThingResult(message: parameters.message))

    case .doThingWithFailure:
      throw CodableError(description: "this is fine")

    case .getThingAsync(let parameters):
      return await withCheckedContinuation { continuation in
        let dither = Double.random(in: 0..<0.1)
        DispatchQueue.global().asyncAfter(deadline: .now() + dither) {
          let result = ThingResult(message: parameters.message)
          continuation.resume(with: .success(.thing(result)))
        }
      }

    case .sleep(let interval):
      return await withCheckedContinuation { continuation in
        DispatchQueue.global().asyncAfter(deadline: .now() + interval) {
          continuation.resume(with: .success(.none))
        }
      }
    }
  }
}

struct DependencyProvider {}

enum TestMethodResult: Codable {
  case thing(ThingResult)
  case none
}

struct ThingParameters: Codable {
  let message: String
}

struct ThingResult: Codable {
  let message: String
}
