import Foundation

@available(*, deprecated, renamed: "ConfigsHandler")
public typealias RemoteConfigsHandler = ConfigsHandler

/// Protocol for implementing configuration storage backends
///
/// This type is an implementation detail and should not normally be used, unless implementing your own configs backend.
/// To use the SwiftConfigs API, please refer to the documentation of ``Configs``.
///
/// ## Example Implementation
///
/// Here's how to implement a Firebase Remote Config handler:
///
/// ```swift
/// public struct FirebaseRemoteConfigHandler: ConfigsHandler {
///     public var supportWriting: Bool { false } // Remote configs are typically read-only
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
///     public func value(for key: String) -> String? {
///         // Get value from Firebase Remote Config
///         return RemoteConfig.remoteConfig().configValue(forKey: key).stringValue
///     }
///     
///     public func writeValue(_ value: String?, for key: String) throws {
///         // Remote configs don't support writing
///         throw ConfigError.unsupportedOperation
///     }
///     
///     public func listen(_ listener: @escaping () -> Void) -> ConfigsCancellation? {
///         // Set up real-time config updates listener
///         // Implementation depends on Firebase SDK capabilities
///         return nil
///     }
///     
///     public func clear() throws {
///         throw ConfigError.unsupportedOperation
///     }
///     
///     public func allKeys() -> Set<String>? {
///         // Return all available Firebase Remote Config keys
///         return Set(RemoteConfig.remoteConfig().allKeys(from: .remote))
///     }
///     
///     private enum ConfigError: Error {
///         case unsupportedOperation
///     }
/// }
///
/// // Bootstrap with Firebase Remote Config
/// ConfigsSystem.bootstrap([
///     .default: .userDefaults,
///     .remote: FirebaseRemoteConfigHandler()
/// ])
/// ```
public protocol ConfigsHandler: _SwiftConfigsSendableAnalyticsHandler {
    /// Fetches the latest configuration values from the backend
    func fetch(completion: @escaping (Error?) -> Void)
    /// Registers a listener for configuration changes
    func listen(_ listener: @escaping () -> Void) -> ConfigsCancellation?
    /// Retrieves the value for a given key
    func value(for key: String) -> String?
    /// Writes a value for a given key
    func writeValue(_ value: String?, for key: String) throws
    /// Clears all stored configuration values
    func clear() throws
    /// Returns all available configuration keys
    func allKeys() -> Set<String>?
	/// Whether the handler supports writing operations
	var supportWriting: Bool { get }
}

extension ConfigsHandler {

	/// Retrieves and transforms a value for a given key
	public func value<T>(for key: String, as transformer: ConfigTransformer<T>) -> T? {
		value(for: key).flatMap(transformer.decode)
	}

	/// Transforms and writes a value for a given key
	public func  writeValue<T>(_ value: T?, for key: String, as transformer: ConfigTransformer<T>) throws {
		try writeValue(value.flatMap(transformer.encode), for: key)
	}
}

struct Unsupported: Error {}

// MARK: - Sendable support helpers

#if compiler(>=5.6)
    @preconcurrency public protocol _SwiftConfigsSendableAnalyticsHandler: Sendable {}
#else
    public protocol _SwiftConfigsSendableAnalyticsHandler {}
#endif
