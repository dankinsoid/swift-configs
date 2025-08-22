import Foundation

@available(*, deprecated, renamed: "ConfigsCancellation")
public typealias RemoteConfigsCancellation = ConfigsCancellation

/// Represents a cancellable configuration listener subscription
public struct ConfigsCancellation {
    private let _cancel: () -> Void

    /// Creates a cancellation token with a cancel closure
    public init(_ cancel: @escaping () -> Void) {
        _cancel = cancel
    }

    /// Cancels the associated subscription
    public func cancel() {
        _cancel()
    }
}
