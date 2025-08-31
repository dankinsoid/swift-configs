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
public struct Configs: ConfigsType {

    /// The store registry coordinating access across multiple configuration stores
    public let registry: StoreRegistry
    
    /// In-memory value overrides for testing and temporary modifications
    var values: [String: Any]
    
    public var configs: Configs {
        get { self }
        set { self = newValue }
    }

    /// Creates a configuration instance with a custom store registry
    ///
    /// - Parameter registry: The store registry to use for configuration operations
    /// - Note: Most applications should use the default initializer instead
    public init(registry: StoreRegistry) {
        self.registry = registry
        self.values = [:]
    }
    
    init(registry: StoreRegistry, values: [String: Any]) {
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
}

public extension Configs {

    /// Indicates whether at least one fetch operation has been completed
    ///
    /// This can be used to determine if remote configuration values have been loaded
    /// at least once since the application started.
    var hasFetched: Bool { registry.hasFetched }
    
    /// Gets a configuration value using a config key
    func get<Value, P: KeyAccess>(_ key: ConfigKey<Value, P>) -> Value {
        if let overwrittenValue = values[key.name], let result = overwrittenValue as? Value {
            return result
        }
        return key.get(registry: registry)
    }
    
    /// Sets a configuration value using a config key
    @inlinable func set<Value>(_ key: ConfigKey<Value, ReadWrite>, _ newValue: Value) {
        key.set(registry: registry, newValue)
    }
    
    /// Removes a configuration value using a config key
    @inlinable func remove<Value>(_ key: ConfigKey<Value, ReadWrite>) {
        key.remove(registry: registry)
    }
    
    /// Checks if a configuration value exists using a config key
    func exists<Value, P: KeyAccess>(_ key: ConfigKey<Value, P>) -> Bool {
        if let overwrittenValue = values[key.name] {
            return overwrittenValue is Value
        }
        return key.exists(registry: configs.registry)
    }

    /// Creates a new instance with an overridden configuration value
    ///
    /// This method returns a new instance with the specified key-value override.
    /// The override takes precedence over stored values and is useful for testing
    /// or temporary configuration changes.
    ///
    /// ```swift
    /// let testConfigs = configs.with(\.apiToken, "test-token")
    /// let debugConfigs = configs.with(\.debugMode, true)
    /// ```
    ///
    /// - Parameters:
    ///   - key: The configuration key to override
    ///   - value: The override value, or `nil` to remove the override
    /// - Returns: A new instance with the value override applied
    /// - Note: This is a value type operation; the original instance remains unchanged
    func with<Value, P: KeyAccess>(_ key: ConfigKey<Value, P>, _ value: Value?) -> Self {
        var result = self
        result.values[key.name] = value
        return result
    }

    /// Fetches if needed and returns the value for a specific key
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    @inlinable func fetchIfNeeded<Value, P: KeyAccess>(_ key: ConfigKey<Value, P>) async throws -> Value {
        try await fetchIfNeeded()
        return get(key)
    }
    
    /// Fetches configuration values and returns the value for a specific key
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    @inlinable func fetch<Value, P: KeyAccess>(_ key: ConfigKey<Value, P>) async throws -> Value {
        try await fetch()
        return get(key)
    }
    
    /// Registers a listener for changes to a specific configuration key
    func onChange<Value, P: KeyAccess>(of key: ConfigKey<Value, P>, _ observer: @escaping (Value) -> Void) -> Cancellation {
        let overriden = values[key.name]
        return key.onChange(registry: registry) { [overriden] value in
            if let overriden, let result = overriden as? Value {
                observer(result)
                return
            }
            observer(value)
        }
        
    }
    /// Returns an async sequence for changes to a specific configuration key
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func changes<Value, P: KeyAccess>(of key: ConfigKey<Value, P>) -> ConfigChangesSequence<Value> {
        ConfigChangesSequence { observer in
            self.onChange(of: key) { value in
                observer(value)
            }
        }
    }

    /// Fetches the latest configuration values from all stores
    ///
    /// This method coordinates fetching across all configured stores concurrently.
    /// For local stores (UserDefaults, Keychain), this typically completes immediately.
    /// For remote stores, this triggers network requests to update cached values.
    ///
    /// - Throws: Aggregated errors from any stores that fail to fetch
    /// - Note: Individual store failures don't prevent other stores from succeeding
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func fetch() async throws {
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
    func onChange(_ listener: @escaping (Configs) -> Void) -> Cancellation {
        registry.onChange {
            listener(self)
        }
    }

    /// Fetches configuration values only if not already fetched
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func fetchIfNeeded() async throws {
        guard !hasFetched else { return }
        try await fetch()
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
}

#if compiler(>=5.6)
    extension Configs: @unchecked Sendable {}
#endif
