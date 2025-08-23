import Foundation

/// Async sequence for configuration changes
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public struct ConfigChangesSequence<Element>: AsyncSequence {

    private let listen: @Sendable (@escaping (Element) -> Void) -> ConfigsCancellation

    init(
        listen: @escaping @Sendable (@escaping (Element) -> Void) -> ConfigsCancellation
    ) {
        self.listen = listen
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(listen: listen)
    }

    public final class AsyncIterator: AsyncIteratorProtocol {
        private var cancellation: ConfigsCancellation?
        private var continuation: AsyncStream<Element>.Continuation?
        private var stream: AsyncStream<Element>.AsyncIterator?
        private let listen: (@escaping (Element) -> Void) -> ConfigsCancellation

        init(listen: @escaping @Sendable (@escaping (Element) -> Void) -> ConfigsCancellation) {
            self.listen = listen
        }

        public func next() async -> Element? {
            if stream == nil {
                let (stream, continuation) = AsyncStream<Element>.makeStream()
                self.stream = stream.makeAsyncIterator()
                self.continuation = continuation

                cancellation = listen { element in
                    continuation.yield(element)
                }
            }
            return await stream?.next()
        }

        deinit {
            cancellation?.cancel()
            continuation?.finish()
        }
    }
}

#if compiler(>=5.6)
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    extension ConfigChangesSequence: Sendable {}
#endif
