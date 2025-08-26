import Foundation

/// A structure for handling configs and reading them from a configs provider.
@dynamicMemberLookup
public struct Configs {

    /// The configs store responsible for querying and storing values.
    public let registry: StoreRegistry
    private var values: [String: Any] = [:]

    /// Initializes the `Configs` instance with the custom store registry.
    public init(registry: StoreRegistry) {
        self.registry = registry
    }
    
    /// Initializes the `Configs` instance with the default store registry.
    public init() {
        self.init(registry: ConfigSystem.registry)
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
    public func get<Value, P: KeyAccess>(_ keyPath: KeyPath<Configs.Keys, Configs.Keys.Key<Value, P>>) -> Value {
        get(Keys()[keyPath: keyPath])
    }

    /// Gets a configuration value using a config key
    public func get<Value, P: KeyAccess>(_ key: Configs.Keys.Key<Value, P>) -> Value {
        if let overwrittenValue = values[key.name], let result = overwrittenValue as? Value {
            return result
        }
        return key.get(registry: registry)
    }

    /// Sets a configuration value using a config key
    public func set<Value>(_ key: Configs.Keys.Key<Value, Configs.Keys.ReadWrite>, _ newValue: Value) {
        key.set(registry: registry, newValue)
    }

    /// Sets a configuration value using a key path
    public func set<Value>(_ keyPath: KeyPath<Configs.Keys, Configs.Keys.Key<Value, Configs.Keys.ReadWrite>>, _ newValue: Value) {
        let key = Keys()[keyPath: keyPath]
        set(key, newValue)
    }

    /// Removes a configuration value using a key path
    public func delete<Value>(_ keyPath: KeyPath<Configs.Keys, Configs.Keys.Key<Value, Configs.Keys.ReadWrite>>) {
        let key = Keys()[keyPath: keyPath]
        delete(key)
    }

    /// Removes a configuration value using a config key
    public func delete<Value>(_ key: Configs.Keys.Key<Value, Configs.Keys.ReadWrite>) {
        key.delete(registry: registry)
    }

    /// Checks if a configuration value exists using a key path
    public func exists<Value, P: KeyAccess>(_ keyPath: KeyPath<Configs.Keys, Configs.Keys.Key<Value, P>>) -> Bool {
        let key = Keys()[keyPath: keyPath]
        return exists(key)
    }

    /// Checks if a configuration value exists using a config key
    public func exists<Value, P: KeyAccess>(_ key: Configs.Keys.Key<Value, P>) -> Bool {
        if let overwrittenValue = values[key.name] {
            return overwrittenValue is Value
        }
        return key.exists(registry: registry)
    }

    /// Whether the store has completed at least one fetch operation
    public var hasFetched: Bool { registry.hasFetched }

    /// Fetches the latest configuration values from the backend
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public func fetch() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            registry.fetch { error in
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
    public func onChange(_ listener: @escaping (Configs) -> Void) -> Cancellation {
        registry.onChange {
            listener(self)
        }
    }
}

public extension Configs {
    /// Overwrites the value of a key.
    /// - Parameters:
    ///   - key: The key to overwrite.
    ///   - value: The value to set.
    func with<Value, P: KeyAccess>(_ key: KeyPath<Configs.Keys, Configs.Keys.Key<Value, P>>, _ value: Value?) -> Self {
        var copy = self
        copy.values[Keys()[keyPath: key].name] = value
        return copy
    }

    /// Fetches configuration values only if not already fetched
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func fetchIfNeeded() async throws {
        guard !hasFetched else { return }
        try await fetch()
    }

    /// Fetches if needed and returns the value for a specific key
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func fetchIfNeeded<Value, P: KeyAccess>(_ key: Configs.Keys.Key<Value, P>) async throws -> Value {
        try await fetchIfNeeded()
        return get(key)
    }

    /// Fetches configuration values and returns the value for a specific key
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func fetch<Value, P: KeyAccess>(_ key: Configs.Keys.Key<Value, P>) async throws -> Value {
        try await fetch()
        return get(key)
    }

    /// Fetches if needed and returns the value for a specific key path
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func fetchIfNeeded<Value, P: KeyAccess>(_ keyPath: KeyPath<Configs.Keys, Configs.Keys.Key<Value, P>>) async throws -> Value {
        try await fetchIfNeeded(Keys()[keyPath: keyPath])
    }

    /// Fetches configuration values and returns the value for a specific key path
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func fetch<Value, P: KeyAccess>(_ keyPath: KeyPath<Configs.Keys, Configs.Keys.Key<Value, P>>) async throws -> Value {
        try await fetch(Keys()[keyPath: keyPath])
    }

    /// Registers a listener for changes to a specific configuration key
    @discardableResult
    func onChange<Value, P: KeyAccess>(_ key: Configs.Keys.Key<Value, P>, _ observer: @escaping (Value) -> Void) -> Cancellation {
        let overriden = values[key.name]
        return key.onChange(registry: registry) { [overriden] value in
            if let overriden, let result = overriden as? Value {
                observer(result)
                return
            }
            observer(value)
        }
    }

    /// Registers a listener for changes to a specific configuration key path
    @discardableResult
    func onChange<Value, P: KeyAccess>(_ keyPath: KeyPath<Configs.Keys, Configs.Keys.Key<Value, P>>, _ observer: @escaping (Value) -> Void) -> Cancellation {
        let key = Keys()[keyPath: keyPath]
        return onChange(key, observer)
    }

    /// Returns an async sequence for configuration changes
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func changes() -> ConfigChangesSequence<Configs> {
        ConfigChangesSequence { observer in
            self.onChange { configs in
                observer(configs)
            }
        }
    }

    /// Returns an async sequence for changes to a specific configuration key
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func changes<Value, P: KeyAccess>(for key: Configs.Keys.Key<Value, P>) -> ConfigChangesSequence<Value> {
        ConfigChangesSequence { observer in
            self.onChange(key) { value in
                observer(value)
            }
        }
    }

    /// Returns an async sequence for changes to a specific configuration key path
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func changes<Value, P: KeyAccess>(for keyPath: KeyPath<Configs.Keys, Configs.Keys.Key<Value, P>>) -> ConfigChangesSequence<Value> {
        let key = Keys()[keyPath: keyPath]
        return changes(for: key)
    }
}

#if compiler(>=5.6)
    extension Configs: @unchecked Sendable {}
#endif
