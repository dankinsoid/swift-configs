import Foundation

/// Defines a configuration interface with namespace-based key organization
///
/// Types conforming to `ConfigsType` provide access to configuration keys organized
/// into logical namespaces. The primary benefit is compile-time organization and
/// type safety for related configuration keys.
///
/// ## Namespace Organization
///
/// Define related keys in namespace extensions:
///
/// ```swift
/// extension Configs.Keys {
///     var security: Security { Security() }
///     
///     struct Security: ConfigNamespaceKeys {
///         var apiToken: RWConfigKey<String?> {
///             key("api-token", in: .secure, default: nil)
///         }
///         
///         var auth: Auth { Auth() }
///         
///         struct Auth: ConfigNamespaceKeys {
///             var biometricEnabled: RWConfigKey<Bool> {
///                 key("biometric", in: .default, default: false)
///             }
///         }
///     }
/// }
///
/// // Access: configs.security.apiToken, configs.security.auth.biometricEnabled
/// ```
///
/// ## Value Types
///
/// All conforming types are value types. Operations like `with(...)` return new instances
/// rather than mutating the existing one, ensuring immutable, predictable behavior.
///
/// - Note: Key prefixes are empty by default - add them only when needed.
public protocol ConfigsType {

    associatedtype Keys
    var keys: Keys { get }
    var configs: Configs { get set }
}

public extension ConfigsType {

    /// Creates a nested namespace from a key path
    ///
    /// This subscript enables seamless navigation through namespace hierarchies using
    /// dynamic member lookup for compile-time organization of related keys.
    ///
    /// ```swift
    /// let secureConfigs = configs.security  // Returns ConfigNamespace<Security>
    /// let authSettings = configs.security.auth  // Nested namespace access
    /// ```
    @inlinable subscript<Scope: ConfigNamespaceKeys>(dynamicMember keyPath: KeyPath<Keys, Scope>) -> ConfigNamespace<Scope> {
        ConfigNamespace(keys[keyPath: keyPath], base: self)
    }

    /// Direct access to read-only configuration values
    ///
    /// Provides seamless access to configuration values through dynamic member lookup
    /// with compile-time type safety and organization.
    ///
    /// ```swift
    /// let userId = configs.userId  // Direct value access
    /// let secureToken = configs.security.apiToken  // Namespace access
    /// ```
    @inlinable subscript<Value>(dynamicMember keyPath: KeyPath<Keys, ConfigKey<Value, ReadOnly>>) -> Value {
        self.get(keyPath)
    }

    /// Direct access to read-write configuration values
    ///
    /// Provides seamless read and write access to configuration values with
    /// compile-time type safety through namespace organization.
    ///
    /// ```swift
    /// configs.apiToken = "new-token"  // Direct value assignment
    /// configs.security.userPrefs = prefs  // Namespace assignment
    /// ```
    @inlinable subscript<Value>(dynamicMember keyPath: KeyPath<Keys, ConfigKey<Value, ReadWrite>>) -> Value {
        get {
            get(keyPath)
        }
        nonmutating set {
            set(keyPath, newValue)
        }
    }

    /// Gets a configuration value using a key path
    @inlinable func get<Value, P: KeyAccess>(_ keyPath: KeyPath<Keys, ConfigKey<Value, P>>) -> Value {
        get(keys[keyPath: keyPath])
    }
    
    /// Gets a configuration value using a config key
    func get<Value, P: KeyAccess>(_ key: ConfigKey<Value, P>) -> Value {
        if let overwrittenValue = configs.values[key.name], let result = overwrittenValue as? Value {
            return result
        }
        return key.get(registry: configs.registry)
    }
    
    /// Sets a configuration value using a config key
    @inlinable func set<Value>(_ key: ConfigKey<Value, ReadWrite>, _ newValue: Value) {
        key.set(registry: configs.registry, newValue)
    }
    
    /// Sets a configuration value using a key path
    @inlinable func set<Value>(_ keyPath: KeyPath<Keys, ConfigKey<Value, ReadWrite>>, _ newValue: Value) {
        let key = keys[keyPath: keyPath]
        set(key, newValue)
    }
    
    /// Removes a configuration value using a key path
    @inlinable func remove<Value>(_ keyPath: KeyPath<Keys, ConfigKey<Value, ReadWrite>>) {
        let key = keys[keyPath: keyPath]
        remove(key)
    }
    
    /// Removes a configuration value using a config key
    @inlinable func remove<Value>(_ key: ConfigKey<Value, ReadWrite>) {
        key.remove(registry: configs.registry)
    }
    
    /// Checks if a configuration value exists using a key path
    @inlinable func exists<Value, P: KeyAccess>(_ keyPath: KeyPath<Keys, ConfigKey<Value, P>>) -> Bool {
        let key = keys[keyPath: keyPath]
        return exists(key)
    }
    
    /// Checks if a configuration value exists using a config key
    func exists<Value, P: KeyAccess>(_ key: ConfigKey<Value, P>) -> Bool {
        if let overwrittenValue = configs.values[key.name] {
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
        result.configs.values[key.name] = value
        return result
    }

    /// Overwrites the value of a key.
    /// - Parameters:
    ///   - key: The key to overwrite.
    ///   - value: The value to set.
    @inlinable func with<Value, P: KeyAccess>(_ key: KeyPath<Keys, ConfigKey<Value, P>>, _ value: Value?) -> Self {
        with(keys[keyPath: key], value)
    }

    /// Creates a new instance with a different store for the specified category
    /// - Parameters:
    ///   - store: The configuration store to use
    ///   - category: The category to assign the store to
    /// - Returns: A new Configs instance with the updated store mapping
    func with(store: ConfigStore, for category: ConfigCategory) -> Self {
        var result = self
        var stores = configs.registry.stores
        stores[category] = store
        result.configs = Configs(
            registry: StoreRegistry(stores, fallback: configs.registry.fallbackStore),
            values: configs.values
        )
        return result
    }

    /// Fetches if needed and returns the value for a specific key
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    @inlinable func fetchIfNeeded<Value, P: KeyAccess>(_ key: ConfigKey<Value, P>) async throws -> Value {
        try await configs.fetchIfNeeded()
        return get(key)
    }
    
    /// Fetches configuration values and returns the value for a specific key
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    @inlinable func fetch<Value, P: KeyAccess>(_ key: ConfigKey<Value, P>) async throws -> Value {
        try await configs.fetch()
        return get(key)
    }
    
    /// Fetches if needed and returns the value for a specific key path
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    @inlinable func fetchIfNeeded<Value, P: KeyAccess>(_ keyPath: KeyPath<Keys, ConfigKey<Value, P>>) async throws -> Value {
        try await fetchIfNeeded(keys[keyPath: keyPath])
    }
    
    /// Fetches configuration values and returns the value for a specific key path
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    @inlinable func fetch<Value, P: KeyAccess>(_ keyPath: KeyPath<Keys, ConfigKey<Value, P>>) async throws -> Value {
        try await fetch(keys[keyPath: keyPath])
    }
    
    /// Registers a listener for changes to a specific configuration key
    func onChange<Value, P: KeyAccess>(of key: ConfigKey<Value, P>, _ observer: @escaping (Value) -> Void) -> Cancellation {
        let overriden = configs.values[key.name]
        return key.onChange(registry: configs.registry) { [overriden] value in
            if let overriden, let result = overriden as? Value {
                observer(result)
                return
            }
            observer(value)
        }
    }
    
    /// Registers a listener for changes to a specific configuration key path
    @inlinable func onChange<Value, P: KeyAccess>(of keyPath: KeyPath<Keys, ConfigKey<Value, P>>, _ observer: @escaping (Value) -> Void) -> Cancellation {
        let key = keys[keyPath: keyPath]
        return onChange(of: key, observer)
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
    
    /// Returns an async sequence for changes to a specific configuration key path
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    @inlinable func changes<Value, P: KeyAccess>(of keyPath: KeyPath<Keys, ConfigKey<Value, P>>) -> ConfigChangesSequence<Value> {
        let key = keys[keyPath: keyPath]
        return changes(of: key)
    }
}
