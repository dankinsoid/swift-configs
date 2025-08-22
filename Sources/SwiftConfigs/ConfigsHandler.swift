import Foundation

@available(*, deprecated, renamed: "ConfigsHandler")
public typealias RemoteConfigsHandler = ConfigsHandler

/// Protocol for implementing configuration storage backends
///
/// This type is an implementation detail and should not normally be used, unless implementing your own configs backend.
/// To use the SwiftConfigs API, please refer to the documentation of ``Configs``.
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
