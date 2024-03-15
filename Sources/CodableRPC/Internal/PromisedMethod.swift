import Foundation
import NIOCore

struct PromisedMethod<Method: RPCMethod, MethodResult> {
  let method: Method
  let promise: EventLoopPromise<MethodResult>
}
