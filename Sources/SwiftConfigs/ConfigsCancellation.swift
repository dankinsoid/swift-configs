import Foundation

/// Represents a cancellable configuration listener subscription
public final class Cancellation {

    private var _cancel: () -> Void

    /// Creates a cancellation token with a cancel closure
    public init(_ cancel: @escaping () -> Void) {
        _cancel = cancel
    }

    /// Cancels the associated subscription
    public func cancel() {
        _cancel()
        _cancel = {}
    }

    deinit {
        cancel()
    }
}
