import Foundation

@available(*, deprecated, renamed: "Configs")
public typealias RemoteConfigs = Configs

/// A structure for handling configs and reading them from a configs provider.
@dynamicMemberLookup
public struct Configs {

	/// The configs handler responsible for querying and storing values.
	public let handler: ConfigsSystem.Handler
	private var values: [String: Any] = [:]

	/// Initializes the `Configs` instance with the default configs handler.
	public init() {
		self.handler = ConfigsSystem.handler
	}

    /// Dynamic member lookup for read-only config keys
    public subscript<Key: ConfigKey>(dynamicMember keyPath: KeyPath<Configs.Keys, Key>) -> Key.Value where Key.Permission == Configs.Keys.ReadOnly {
		self.get(keyPath)
	}

    /// Dynamic member lookup for read-write config keys
    public subscript<Key: ConfigKey>(dynamicMember keyPath: KeyPath<Configs.Keys, Key>) -> Key.Value where Key.Permission == Configs.Keys.ReadWrite {
		get {
			get(keyPath)
		}
		nonmutating set {
			set(keyPath, newValue)
		}
	}

	/// Gets a configuration value using a key path
	public func get<Key: ConfigKey>(_ keyPath: KeyPath<Configs.Keys, Key>) -> Key.Value {
		get(Keys()[keyPath: keyPath])
	}

	/// Gets a configuration value using a config key
	public func get<Key: ConfigKey>(_ key: Key) -> Key.Value {
		if let overwrittenValue = values[key.name], let result = overwrittenValue as? Key.Value {
			return result
		}
        return key.get(handler: handler)
	}

	/// Sets a configuration value using a config key
	public func set<Key: ConfigKey>(_ key: Key, _ newValue: Key.Value) where Key.Permission == Configs.Keys.ReadWrite {
        key.set(handler: handler, newValue)
	}

	/// Sets a configuration value using a key path
	public func set<Key: ConfigKey>(_ keyPath: KeyPath<Configs.Keys, Key>, _ newValue: Key.Value) where Key.Permission == Configs.Keys.ReadWrite {
		let key = Keys()[keyPath: keyPath]
		set(key, newValue)
	}

	/// Removes a configuration value using a key path
	public func remove<Key: ConfigKey>(_ keyPath: KeyPath<Configs.Keys, Key>) throws where Key.Permission == Configs.Keys.ReadWrite {
		let key = Keys()[keyPath: keyPath]
		try remove(key)
	}

	/// Removes a configuration value using a config key
	public func remove<Key: ConfigKey>(_ key: Key) throws where Key.Permission == Configs.Keys.ReadWrite {
        try key.remove(handler: handler)
	}

	/// Checks if a configuration value exists using a key path
	public func exists<Key: ConfigKey>(_ keyPath: KeyPath<Configs.Keys, Key>) -> Bool {
		let key = Keys()[keyPath: keyPath]
		return exists(key)
	}

	/// Checks if a configuration value exists using a config key
	public func exists<Key: ConfigKey>(_ key: Key) -> Bool {
		if let overwrittenValue = values[key.name] {
			return overwrittenValue is Key.Value
		}
        return key.exists(handler: handler)
	}

	/// Whether the handler has completed at least one fetch operation
	public var didFetch: Bool { handler.didFetch }

	/// Fetches the latest configuration values from the backend
	@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
	public func fetch() async throws {
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			handler.fetch { error in
				if let error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume(returning: ())
				}
			}
		}
	}

	/// Registers a listener for configuration changes
	@discardableResult
	public func listen(_ listener: @escaping (Configs) -> Void) -> ConfigsCancellation {
		handler.listen {
			listener(self)
		}
	}
}

public extension Configs {

	/// Overwrites the value of a key.
	/// - Parameters:
	///   - key: The key to overwrite.
	///   - value: The value to set.
	func with<T: ConfigKey>(_ key: KeyPath<Configs.Keys, T>, _ value: T.Value?) -> Self {
		var copy = self
		copy.values[Keys()[keyPath: key].name] = value
		return copy
	}

	/// Fetches configuration values only if not already fetched
	@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
	func fetchIfNeeded() async throws {
		guard !didFetch else { return }
		try await fetch()
	}

	/// Fetches if needed and returns the value for a specific key
	@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
	func fetchIfNeeded<T: ConfigKey>(_ key: T) async throws -> T.Value {
		try await fetchIfNeeded()
        return get(key)
	}

	/// Fetches configuration values and returns the value for a specific key
	@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func fetch<T: ConfigKey>(_ key: T) async throws -> T.Value {
		try await fetch()
        return get(key)
	}

    /// Fetches if needed and returns the value for a specific key path
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func fetchIfNeeded<T: ConfigKey>(_ keyPath: KeyPath<Configs.Keys, T>) async throws -> T.Value {
        try await fetchIfNeeded(Keys()[keyPath: keyPath])
    }

    /// Fetches configuration values and returns the value for a specific key path
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func fetch<T: ConfigKey>(_ keyPath: KeyPath<Configs.Keys, T>) async throws -> T.Value {
        try await fetch(Keys()[keyPath: keyPath])
    }

	/// Registers a listener for changes to a specific configuration key
	@discardableResult
	func listen<T: ConfigKey>(_ key: T, _ observer: @escaping (T.Value) -> Void) -> ConfigsCancellation {
		let overriden = values[key.name]
        return key.listen(handler: handler) { [overriden] value in
            if let overriden, let result = overriden as? T.Value {
                observer(result)
                return
            }
            observer(value)
        }
	}

	/// Registers a listener for changes to a specific configuration key path
	@discardableResult
	func listen<T: ConfigKey>(_ keyPath: KeyPath<Configs.Keys, T>, _ observer: @escaping (T.Value) -> Void) -> ConfigsCancellation {
		let key = Keys()[keyPath: keyPath]
		return listen(key, observer)
	}
}

#if compiler(>=5.6)
    extension Configs: @unchecked Sendable {}
#endif
