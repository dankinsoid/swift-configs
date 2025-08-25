import Foundation

/// No-operation configuration store that provides no functionality
public struct NOOPConfigStore: ConfigStore {
	
    /// Shared instance of the no-op configuration store
    public static let instance = NOOPConfigStore()
	
	/// NOOP store claims to support writing (but does nothing)
	public var isWritable: Bool { true }

    /// Creates a no-op configuration store
    public init() {}

    /// Always returns nil
    public func get(_: String) -> String? {
        nil
    }

    /// Does nothing
    public func set(_: String?, for _: String) throws {}

    /// Does nothing
    public func removeAll() throws {}

    /// Immediately completes with no error
    public func fetch(completion: @escaping (Error?) -> Void) {
        completion(nil)
    }

    /// Returns no cancellation (no listening occurs)
    public func onChange(_: @escaping () -> Void) -> Cancellation? {
        nil
    }
	
	/// Returns no keys
	public func keys() -> Set<String>? {
		nil
	}
    
    public func exists(_ key: String) throws -> Bool {
        false
    }
}

extension ConfigStore where Self == NOOPConfigStore {

	/// Returns a shared instance of the no-op configuration store
	public static var noop: NOOPConfigStore {
		NOOPConfigStore.instance
	}
}
