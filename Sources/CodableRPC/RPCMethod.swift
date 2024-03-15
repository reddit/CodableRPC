import Foundation

/// An RPC method used to communicate between the client and server.
public protocol RPCMethod: Codable {
  associatedtype Result: Codable
}

/// A protocol that declares the method used to perform the RPC method on the server.
///
/// You may implement this protocol as an extension in order to avoid linking server dependencies
/// with the client.
public protocol RPCMethodPerformable: RPCMethod {
  associatedtype DependencyProvider

  func perform(dependencyProvider: DependencyProvider) async throws -> Result
}

/// A simple Error type that conforms to Codable.
public struct CodableError: Error, Codable, LocalizedError {
  public let description: String

  public init(description: String) {
    self.description = description
  }

  public var errorDescription: String? {
    description
  }
}

extension Result: Codable where Success: Codable, Failure == CodableError {
  enum CodingKeys: String, CodingKey {
    case success
    case failure
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if let value = try container.decodeIfPresent(Success.self, forKey: .success) {
      self = .success(value)
    } else if let value = try container.decodeIfPresent(Failure.self, forKey: .failure) {
      self = .failure(value)
    } else {
      self = .failure(.init(description: "RPCMethod: Unexpected branch decoding CodableError"))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case .success(let value):
      try container.encode(value, forKey: .success)

    case .failure(let error):
      try container.encode(error, forKey: .failure)
    }
  }
}
