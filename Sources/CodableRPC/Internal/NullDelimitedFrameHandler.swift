import Foundation
import NIOCore

/// A NULL byte delimited frame encoder & decoder.
final class NullDelimitedFrameHandler: ByteToMessageDecoder, MessageToByteEncoder {
  typealias InboundOut = ByteBuffer
  typealias OutboundIn = ByteBuffer

  private let delimiter = UInt8(ascii: "\0")
  private var lastIndex = 0

  func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
    guard buffer.readableBytes >= 2 else { return .needMoreData }

    let readableBytesView = buffer.readableBytesView.dropFirst(lastIndex)

    guard let index = readableBytesView.firstIndex(of: delimiter) else {
      lastIndex = buffer.readableBytes
      return .needMoreData
    }

    let length = index - buffer.readerIndex

    guard let slice = buffer.readSlice(length: length) else { throw FrameHandlerError.badFrame }

    buffer.moveReaderIndex(forwardBy: 1)
    lastIndex = 0

    context.fireChannelRead(wrapInboundOut(slice))
    return .continue
  }

  func decodeLast(context: ChannelHandlerContext, buffer: inout ByteBuffer, seenEOF: Bool) throws -> DecodingState {
    while try decode(context: context, buffer: &buffer) == .continue {}
    return .needMoreData
  }

  func encode(data: OutboundIn, out: inout ByteBuffer) throws {
    var payload = data
    out.writeBuffer(&payload)
    out.writeBytes([delimiter])
  }
}

private enum FrameHandlerError: Error {
  case badFrame
}
