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
    public subscript<Value>(dynamicMember keyPath: KeyPath<Configs.Keys, Configs.Keys.Key<Value, Configs.Keys.ReadOnly>>) -> Value {
        self.get(keyPath)
    }

    /// Dynamic member lookup for read-write config keys
    public subscript<Value>(dynamicMember keyPath: KeyPath<Configs.Keys, Configs.Keys.Key<Value, Configs.Keys.ReadWrite>>) -> Value {
        get {
            get(keyPath)
        }
        nonmutating set {
            set(keyPath, newValue)
        }
    }

    /// Gets a configuration value using a key path
    public func get<Value, P: ConfigKeyPermission>(_ keyPath: KeyPath<Configs.Keys, Configs.Keys.Key<Value, P>>) -> Value {
        get(Keys()[keyPath: keyPath])
    }

    /// Gets a configuration value using a config key
    public func get<Value, P: ConfigKeyPermission>(_ key: Configs.Keys.Key<Value, P>) -> Value {
        if let overwrittenValue = values[key.name], let result = overwrittenValue as? Value {
            return result
        }
        return key.get(handler: handler)
    }

    /// Sets a configuration value using a config key
    public func set<Value>(_ key: Configs.Keys.Key<Value, Configs.Keys.ReadWrite>, _ newValue: Value) {
        key.set(handler: handler, newValue)
    }

    /// Sets a configuration value using a key path
    public func set<Value>(_ keyPath: KeyPath<Configs.Keys, Configs.Keys.Key<Value, Configs.Keys.ReadWrite>>, _ newValue: Value) {
        let key = Keys()[keyPath: keyPath]
        set(key, newValue)
    }

    /// Removes a configuration value using a key path
    public func remove<Value>(_ keyPath: KeyPath<Configs.Keys, Configs.Keys.Key<Value, Configs.Keys.ReadWrite>>) throws {
        let key = Keys()[keyPath: keyPath]
        try remove(key)
    }

    /// Removes a configuration value using a config key
    public func remove<Value>(_ key: Configs.Keys.Key<Value, Configs.Keys.ReadWrite>) throws {
        try key.remove(handler: handler)
    }

    /// Checks if a configuration value exists using a key path
    public func exists<Value, P: ConfigKeyPermission>(_ keyPath: KeyPath<Configs.Keys, Configs.Keys.Key<Value, P>>) -> Bool {
        let key = Keys()[keyPath: keyPath]
        return exists(key)
    }

    /// Checks if a configuration value exists using a config key
    public func exists<Value, P: ConfigKeyPermission>(_ key: Configs.Keys.Key<Value, P>) -> Bool {
        if let overwrittenValue = values[key.name] {
            return overwrittenValue is Value
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
    func with<Value, P: ConfigKeyPermission>(_ key: KeyPath<Configs.Keys, Configs.Keys.Key<Value, P>>, _ value: Value?) -> Self {
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
    func fetchIfNeeded<Value, P: ConfigKeyPermission>(_ key: Configs.Keys.Key<Value, P>) async throws -> Value {
        try await fetchIfNeeded()
        return get(key)
    }

    /// Fetches configuration values and returns the value for a specific key
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func fetch<Value, P: ConfigKeyPermission>(_ key: Configs.Keys.Key<Value, P>) async throws -> Value {
        try await fetch()
        return get(key)
    }

    /// Fetches if needed and returns the value for a specific key path
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func fetchIfNeeded<Value, P: ConfigKeyPermission>(_ keyPath: KeyPath<Configs.Keys, Configs.Keys.Key<Value, P>>) async throws -> Value {
        try await fetchIfNeeded(Keys()[keyPath: keyPath])
    }

    /// Fetches configuration values and returns the value for a specific key path
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func fetch<Value, P: ConfigKeyPermission>(_ keyPath: KeyPath<Configs.Keys, Configs.Keys.Key<Value, P>>) async throws -> Value {
        try await fetch(Keys()[keyPath: keyPath])
    }

    /// Registers a listener for changes to a specific configuration key
    @discardableResult
    func listen<Value, P: ConfigKeyPermission>(_ key: Configs.Keys.Key<Value, P>, _ observer: @escaping (Value) -> Void) -> ConfigsCancellation {
        let overriden = values[key.name]
        return key.listen(handler: handler) { [overriden] value in
            if let overriden, let result = overriden as? Value {
                observer(result)
                return
            }
            observer(value)
        }
    }

    /// Registers a listener for changes to a specific configuration key path
    @discardableResult
    func listen<Value, P: ConfigKeyPermission>(_ keyPath: KeyPath<Configs.Keys, Configs.Keys.Key<Value, P>>, _ observer: @escaping (Value) -> Void) -> ConfigsCancellation {
        let key = Keys()[keyPath: keyPath]
        return listen(key, observer)
    }

    /// Returns an async sequence for configuration changes
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func changes() -> ConfigChangesSequence<Configs> {
        ConfigChangesSequence { observer in
            self.listen { configs in
                observer(configs)
            }
        }
    }

    /// Returns an async sequence for changes to a specific configuration key
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func changes<Value, P: ConfigKeyPermission>(for key: Configs.Keys.Key<Value, P>) -> ConfigChangesSequence<Value> {
        ConfigChangesSequence { observer in
            self.listen(key) { value in
                observer(value)
            }
        }
    }

    /// Returns an async sequence for changes to a specific configuration key path
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func changes<Value, P: ConfigKeyPermission>(for keyPath: KeyPath<Configs.Keys, Configs.Keys.Key<Value, P>>) -> ConfigChangesSequence<Value> {
        let key = Keys()[keyPath: keyPath]
        return changes(for: key)
    }
}

#if compiler(>=5.6)
    extension Configs: @unchecked Sendable {}
#endif
