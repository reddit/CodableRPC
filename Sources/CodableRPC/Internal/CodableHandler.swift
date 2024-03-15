import Foundation
import NIOCore
import NIOFoundationCompat

/// A Codable channel handler.
final class CodableHandler<In: Decodable, Out: Encodable>: ChannelInboundHandler, ChannelOutboundHandler {
  typealias InboundIn = ByteBuffer
  typealias InboundOut = In
  typealias OutboundIn = Out
  typealias OutboundOut = ByteBuffer

  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()

  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    var buffer = unwrapInboundIn(data)

    do {
      guard let decodable = try buffer.readJSONDecodable(In.self, decoder: decoder, length: buffer.readableBytes) else {
        context.fireErrorCaught(CodableHandlerError.insufficientBytes)
        return
      }
      context.fireChannelRead(wrapInboundOut(decodable))
    } catch let error as DecodingError {
      context.fireErrorCaught(CodableHandlerError.invalidJSON(error))
    } catch {
      context.fireErrorCaught(error)
    }
  }

  func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
    do {
      let encodable = unwrapOutboundIn(data)
      let data = try encoder.encode(encodable)
      var buffer = context.channel.allocator.buffer(capacity: data.count)
      buffer.writeBytes(data)
      context.write(wrapOutboundOut(buffer), promise: promise)
    } catch let error as EncodingError {
      promise?.fail(CodableHandlerError.invalidJSON(error))
    } catch {
      promise?.fail(error)
    }
  }
}

enum CodableHandlerError: Swift.Error {
  case invalidJSON(Error)
  case insufficientBytes
}
