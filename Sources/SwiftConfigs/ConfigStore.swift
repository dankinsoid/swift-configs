import Foundation

/// Protocol for implementing configuration storage backends
///
/// Implement this protocol to create custom configuration stores. Most users should use
/// the built-in stores (`UserDefaults`, `Keychain`, etc.) rather than implementing this directly.
///
/// ## Key Implementation Points
///
/// - **Thread Safety**: All methods may be called from any thread and should be thread-safe
/// - **Error Handling**: Use throws for recoverable errors; unrecoverable errors should call `ConfigSystem.fail()`
/// - **Performance**: Frequent `get()` calls should be optimized for speed
/// - **Change Notifications**: Implement `onChange()` to support reactive configuration updates
///
/// ## Example: Firebase Remote Config
///
/// ```swift
/// struct FirebaseRemoteStore: ConfigStore {
///     var isWritable: Bool { false } // Remote configs are read-only
///     
///     func fetch(completion: @escaping (Error?) -> Void) {
///         RemoteConfig.remoteConfig().fetch { status, error in
///             if status == .success {
///                 RemoteConfig.remoteConfig().activate()
///             }
///             completion(error)
///         }
///     }
///     
///     func get(_ key: String) throws -> String? {
///         return RemoteConfig.remoteConfig().configValue(forKey: key).stringValue
///     }
///     
///     func set(_ value: String?, for key: String) throws {
///         throw ConfigError.readOnlyStore
///     }
///     
///     // Other required methods...
/// }
/// ```
public protocol ConfigStore: _SwiftConfigsSendableAnalyticsStore {

    /// Fetches the latest configuration values from the backend
    /// 
    /// - Parameter completion: Called when fetch completes, with error if failed
    /// - Note: For local stores, this typically does nothing and completes immediately
    func fetch(completion: @escaping (Error?) -> Void)
    
    /// Registers a listener for any configuration changes in the store
    ///
    /// - Parameter listener: Called whenever any configuration value changes
    /// - Returns: Cancellation token to stop listening, or `nil` if not supported
    func onChange(_ listener: @escaping () -> Void) -> Cancellation?
    
    /// Registers a listener for changes to a specific configuration key
    ///
    /// - Parameters:
    ///   - key: The configuration key to monitor
    ///   - listener: Called with the new value when the key changes
    /// - Returns: Cancellation token to stop listening, or `nil` if not supported
    func onChangeOfKey(_ key: String, _ listener: @escaping (String?) -> Void) -> Cancellation?
    
    /// Retrieves the string value for a configuration key
    ///
    /// - Parameter key: The configuration key to retrieve
    /// - Returns: The string value, or `nil` if not found
    /// - Throws: Storage-related errors (network, permission, corruption, etc.)
    func get(_ key: String) throws -> String?
    
    /// Stores a string value for a configuration key
    ///
    /// - Parameters:
    ///   - value: The string value to store, or `nil` to remove
    ///   - key: The configuration key
    /// - Throws: Storage-related errors or if store is read-only
    func set(_ value: String?, for key: String) throws
    
    /// Checks whether a value exists for a configuration key
    ///
    /// - Parameter key: The configuration key to check
    /// - Returns: `true` if a value exists, `false` otherwise
    /// - Throws: Storage-related errors
    func exists(_ key: String) throws -> Bool
    
    /// Removes all configuration values from the store
    ///
    /// - Throws: Storage-related errors or if store is read-only
    /// - Warning: This operation cannot be undone
    func removeAll() throws
    
    /// Returns all configuration keys currently stored
    ///
    /// - Returns: Set of all keys, or `nil` if enumeration is not supported
    /// - Note: Some stores may not support key enumeration for security/performance reasons
    func keys() -> Set<String>?
    
    /// Whether the store supports writing operations
    ///
    /// Read-only stores should return `false` and throw errors on write attempts.
    var isWritable: Bool { get }
}

extension ConfigStore {

	/// Retrieves a value and transforms it to the target type
	///
	/// - Parameters:
	///   - key: The configuration key to retrieve
	///   - transformer: The transformer to convert string to target type
	/// - Returns: The transformed value, or `nil` if not found or conversion failed
	/// - Throws: Storage-related errors from the underlying store
	public func get<T>(_ key: String, as transformer: ConfigTransformer<T>) throws -> T? {
		try get(key).flatMap(transformer.decode)
	}

	/// Transforms a value and stores it as a string
	///
	/// - Parameters:
	///   - value: The value to transform and store, or `nil` to remove
	///   - key: The configuration key
	///   - transformer: The transformer to convert value to string
	/// - Throws: Storage-related errors or transformation failures
	public func set<T>(_ value: T?, for key: String, as transformer: ConfigTransformer<T>) throws {
		try set(value.flatMap(transformer.encode), for: key)
	}

    /// Default implementation that checks existence by attempting to get the value
    ///
    /// - Parameter key: The configuration key to check
    /// - Returns: `true` if `get()` returns a non-nil value, `false` otherwise
    /// - Throws: Storage-related errors from the underlying store
    /// - Note: Override this method if your store has a more efficient existence check
    public func exists(_ key: String) throws -> Bool {
        try get(key) != nil
    }
}

extension ConfigStore where Self: AnyObject {

    /// Default implementation of key-specific change listener for reference types
    ///
    /// Monitors the entire store for changes and filters for the specific key.
    /// Override this method if your store supports more efficient key-specific monitoring.
    ///
    /// - Parameters:
    ///   - key: The configuration key to monitor  
    ///   - listener: Called with the new value when the key changes
    /// - Returns: Cancellation token to stop listening, or `nil` if not supported
    /// - Warning: Uses weak references to avoid retain cycles. Ensure the store instance remains alive.
    public func onChangeOfKey(_ key: String, _ listener: @escaping (String?) -> Void) -> Cancellation? {
        var lastValue: String? = try? get(key)
        return onChange { [weak self] in
            guard let self else { return }
            let newValue = try? self.get(key)
            if lastValue != newValue {
                lastValue = newValue
                listener(newValue)
            }
        }
    }
}

struct Unsupported: Error {}

// MARK: - Sendable support helpers

#if compiler(>=5.6)
    @preconcurrency public protocol _SwiftConfigsSendableAnalyticsStore: Sendable {}
#else
    public protocol _SwiftConfigsSendableAnalyticsStore {}
#endif
