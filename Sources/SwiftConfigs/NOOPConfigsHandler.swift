import Foundation

@available(*, deprecated, renamed: "NOOPConfigsHandler")
public typealias NOOPRemoteConfigsHandler = NOOPConfigsHandler

/// No-operation configuration handler that provides no functionality
public struct NOOPConfigsHandler: ConfigsHandler {
	
    /// Shared instance of the no-op configuration handler
    public static let instance = NOOPConfigsHandler()
	
	/// NOOP handler claims to support writing (but does nothing)
	public var supportWriting: Bool { true }

    /// Creates a no-op configuration handler
    public init() {}

    /// Always returns nil
    public func value(for _: String) -> String? {
        return nil
    }

    /// Does nothing
    public func writeValue(_: String?, for _: String) throws {}

    /// Does nothing
    public func clear() throws {}

    /// Immediately completes with no error
    public func fetch(completion: @escaping (Error?) -> Void) {
        completion(nil)
    }

    /// Returns no cancellation (no listening occurs)
    public func listen(_: @escaping () -> Void) -> ConfigsCancellation? {
        return nil
    }
	
	/// Returns no keys
	public func allKeys() -> Set<String>? {
		nil
	}
}

extension ConfigsHandler where Self == NOOPConfigsHandler {

	/// Returns a shared instance of the no-op configuration handler
	public static var noop: NOOPConfigsHandler {
		NOOPConfigsHandler.instance
	}
}
