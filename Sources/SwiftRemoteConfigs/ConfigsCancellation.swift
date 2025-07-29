import Foundation

@available(*, deprecated, renamed: "ConfigsCancellation")
public typealias RemoteConfigsCancellation = ConfigsCancellation

public struct ConfigsCancellation {
    private let _cancel: () -> Void

    public init(_ cancel: @escaping () -> Void) {
        _cancel = cancel
    }

    public func cancel() {
        _cancel()
    }
}
