import Foundation

/// Protocol for implementing configuration storage backends
///
/// This type is an implementation detail and should not normally be used, unless implementing your own configs backend.
/// To use the SwiftConfigs API, please refer to the documentation of ``Configs``.
///
/// ## Example Implementation
///
/// Here's how to implement a Firebase Remote Config store:
///
/// ```swift
/// public struct FirebaseRemoteStore: ConfigStore {
///     public var isWritable: Bool { false } // Remote configs are typically read-only
///     
///     public func fetch(completion: @escaping (Error?) -> Void) {
///         // Fetch latest configs from Firebase
///         RemoteConfig.remoteConfig().fetch { status, error in
///             if status == .success {
///                 RemoteConfig.remoteConfig().activate()
///             }
///             completion(error)
///         }
///     }
///     
///     public func get(_ key: String) -> String? {
///         // Get value from Firebase Remote Config
///         return RemoteConfig.remoteConfig().configValue(forKey: key).stringValue
///     }
///     
///     public func set(_ value: String?, for key: String) throws {
///         // Remote configs don't support writing
///         throw ConfigError.unsupportedOperation
///     }
///     
///     public func onChange(_ listener: @escaping () -> Void) -> Cancellation? {
///         // Set up real-time config updates listener
///         // Implementation depends on Firebase SDK capabilities
///         return nil
///     }
///     
///     public func removeAll() throws {
///         throw ConfigError.unsupportedOperation
///     }
///     
///     public func keys() -> Set<String>? {
///         // Return all available Firebase Remote Config keys
///         return Set(RemoteConfig.remoteConfig().keys(from: .remote))
///     }
///     
///     private enum ConfigError: Error {
///         case unsupportedOperation
///     }
/// }
///
/// // Bootstrap with Firebase Remote Config
/// ConfigSystem.bootstrap([
///     .default: .userDefaults,
///     .remote: FirebaseRemoteStore()
/// ])
/// ```
public protocol ConfigStore: _SwiftConfigsSendableAnalyticsStore {

    /// Fetches the latest configuration values from the backend
    func fetch(completion: @escaping (Error?) -> Void)
    /// Registers a listener for configuration changes
    func onChange(_ listener: @escaping () -> Void) -> Cancellation?
    /// Registers a listener for configuration changes
    func onChangeOfKey(_ key: String, _ listener: @escaping (String?) -> Void) -> Cancellation?
    /// Retrieves the value for a given key
    func get(_ key: String) throws -> String?
    /// Writes a value for a given key
    func set(_ value: String?, for key: String) throws
    /// Determines whether a value exists for a given key
    func exists(_ key: String) throws -> Bool
    /// Clears all stored configuration values
    func removeAll() throws
    /// Returns all available configuration keys
    func keys() -> Set<String>?
	/// Whether the store supports writing operations
	var isWritable: Bool { get }
}

extension ConfigStore {

	/// Retrieves and transforms a value for a given key
	public func get<T>(_ key: String, as transformer: ConfigTransformer<T>) throws -> T? {
		try get(key).flatMap(transformer.decode)
	}

	/// Transforms and writes a value for a given key
	public func set<T>(_ value: T?, for key: String, as transformer: ConfigTransformer<T>) throws {
		try set(value.flatMap(transformer.encode), for: key)
	}

    /// Determines whether a value exists for a given key
    public func exists(_ key: String) throws -> Bool {
        try get(key) != nil
    }
}

extension ConfigStore where Self: AnyObject {

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
