import Foundation

/// Primary interface for configuration management
///
/// This structure provides the main API for reading, writing, and observing configuration
/// values across multiple storage backends. It supports dynamic member lookup, async operations,
/// and change observation for reactive configuration management.
///
/// ## Key Features
///
/// - **Multi-Store Support**: Coordinates access across different configuration stores
/// - **Type Safety**: Compile-time enforcement of read-only vs read-write access
/// - **Dynamic Lookup**: Access configuration values using dot notation
/// - **Async Support**: Modern async/await API for configuration fetching
/// - **Change Observation**: Real-time notifications when configuration values change
/// - **Value Overrides**: Temporary in-memory overrides for testing and debugging
///
/// ## Usage Examples
///
/// ```swift
/// // Initialize with default system
/// let configs = Configs()
///
/// // Access values using dynamic member lookup
/// let apiUrl: String = configs.apiBaseURL
/// configs.debugMode = true
///
/// // Observe configuration changes
/// let cancellation = configs.onChange { updatedConfigs in
///     print("Configuration changed")
/// }
///
/// // Fetch latest values from remote sources
/// try await configs.fetch()
/// ```
@dynamicMemberLookup
public struct Configs {

    /// The store registry coordinating access across multiple configuration stores
    public let registry: StoreRegistry
    
    /// In-memory value overrides for testing and temporary modifications
    private let values: [String: Any]

    /// Creates a configuration instance with a custom store registry
    ///
    /// - Parameter registry: The store registry to use for configuration operations
    /// - Note: Most applications should use the default initializer instead
    public init(registry: StoreRegistry) {
        self.registry = registry
        self.values = [:]
    }
    
    private init(registry: StoreRegistry, values: [String: Any]) {
        self.registry = registry
        self.values = values
    }
    
    /// Creates a configuration instance using the system default registry
    ///
    /// This is the standard way to create a Configs instance. The system registry
    /// is configured through `ConfigSystem.bootstrap()`.
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
    public func remove<Value>(_ keyPath: KeyPath<Configs.Keys, Configs.Keys.Key<Value, Configs.Keys.ReadWrite>>) {
        let key = Keys()[keyPath: keyPath]
        remove(key)
    }

    /// Removes a configuration value using a config key
    public func remove<Value>(_ key: Configs.Keys.Key<Value, Configs.Keys.ReadWrite>) {
        key.remove(registry: registry)
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

    /// Indicates whether at least one fetch operation has been completed
    ///
    /// This can be used to determine if remote configuration values have been loaded
    /// at least once since the application started.
    public var hasFetched: Bool { registry.hasFetched }

    /// Fetches the latest configuration values from all stores
    ///
    /// This method coordinates fetching across all configured stores concurrently.
    /// For local stores (UserDefaults, Keychain), this typically completes immediately.
    /// For remote stores, this triggers network requests to update cached values.
    ///
    /// - Throws: Aggregated errors from any stores that fail to fetch
    /// - Note: Individual store failures don't prevent other stores from succeeding
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

    /// Registers a listener for configuration changes across all stores
    ///
    /// The listener is called whenever any configuration value changes in any store.
    /// This provides a centralized way to react to configuration updates from remote
    /// sources, user preferences changes, or programmatic updates.
    ///
    /// - Parameter listener: Called with an updated Configs instance when changes occur
    /// - Returns: Cancellation token to stop listening for changes
    /// - Note: The listener is called on the main thread
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
        var values = values
        values[Keys()[keyPath: key].name] = value
        return Configs(registry: registry, values: values)
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
    func onChange<Value, P: KeyAccess>(of key: Configs.Keys.Key<Value, P>, _ observer: @escaping (Value) -> Void) -> Cancellation {
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
    func onChange<Value, P: KeyAccess>(of keyPath: KeyPath<Configs.Keys, Configs.Keys.Key<Value, P>>, _ observer: @escaping (Value) -> Void) -> Cancellation {
        let key = Keys()[keyPath: keyPath]
        return onChange(of: key, observer)
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
    func changes<Value, P: KeyAccess>(of key: Configs.Keys.Key<Value, P>) -> ConfigChangesSequence<Value> {
        ConfigChangesSequence { observer in
            self.onChange(of: key) { value in
                observer(value)
            }
        }
    }

    /// Returns an async sequence for changes to a specific configuration key path
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func changes<Value, P: KeyAccess>(of keyPath: KeyPath<Configs.Keys, Configs.Keys.Key<Value, P>>) -> ConfigChangesSequence<Value> {
        let key = Keys()[keyPath: keyPath]
        return changes(of: key)
    }
}

#if compiler(>=5.6)
    extension Configs: @unchecked Sendable {}
#endif
