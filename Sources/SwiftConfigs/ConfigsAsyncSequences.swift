import Foundation

/// Async sequence for configuration changes
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public struct ConfigChangesSequence<Element> {

    fileprivate let onChange: @Sendable (@escaping (Element) -> Void) -> Cancellation

    @usableFromInline init(
        onChange: @escaping @Sendable (@escaping (Element) -> Void) -> Cancellation
    ) {
        self.onChange = onChange
    } 
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension ConfigChangesSequence: AsyncSequence {

       public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(onChange: onChange)
    }

    public final class AsyncIterator: AsyncIteratorProtocol {
        private var cancellation: Cancellation?
        private var continuation: AsyncStream<Element>.Continuation?
        private var stream: AsyncStream<Element>.AsyncIterator?
        private let onChange: (@escaping (Element) -> Void) -> Cancellation

        init(onChange: @escaping @Sendable (@escaping (Element) -> Void) -> Cancellation) {
            self.onChange = onChange
        }

        public func next() async -> Element? {
            if stream == nil {
                let (stream, continuation) = AsyncStream<Element>.makeStream()
                self.stream = stream.makeAsyncIterator()
                self.continuation = continuation

                cancellation = onChange { element in
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

#if canImport(Combine)
import Combine

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension ConfigChangesSequence: Publisher {

    public typealias Output = Element
    public typealias Failure = Never
    
    public func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Element == S.Input {
        let subscription = ConfigChangesSubscription<S>(sequence: self, subscriber: subscriber)
        subscriber.receive(subscription: subscription)
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
private final class ConfigChangesSubscription<S: Subscriber>: Subscription where S.Failure == Never {

    @Locked private var subscriber: S?
    @Locked private var cancellation: Cancellation?
    private let sequence: ConfigChangesSequence<S.Input>
    
    init(sequence: ConfigChangesSequence<S.Input>, subscriber: S) {
        self.sequence = sequence
        self.subscriber = subscriber
    }

    func request(_ demand: Subscribers.Demand) {
        guard cancellation == nil else { return }

        cancellation = sequence.onChange { [weak self] element in
            guard let self = self, let subscriber = self.subscriber else { return }
            _ = subscriber.receive(element)
        }
    }

    func cancel() {
        _cancellation.withWriterLock { cancellation in
            let result = cancellation
            cancellation = nil
            return result
        }?.cancel()

        _subscriber.withWriterLock { subscriber in
            let result = subscriber
            subscriber = nil
            return result
        }?.receive(completion: .finished)
    }
}
#endif
