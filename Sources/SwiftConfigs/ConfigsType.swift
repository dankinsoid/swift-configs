import Foundation

/// Defines a hierarchical configuration interface with namespace support
///
/// Types conforming to `ConfigsType` can expose configuration keys through namespaces,
/// allowing for organized, hierarchical access to configuration values. Each instance
/// maintains its own `keyPrefix` that is automatically applied to all key operations.
///
/// ## Namespace Hierarchy
///
/// Namespaces can be nested to create hierarchical organization:
///
/// ```swift
/// // Define nested namespaces
/// extension Configs.Keys {
///     var secure: SecureKeys { SecureKeys() }
/// }
///
/// struct SecureKeys: ConfigNamespaceKeys {
///     var keyPrefix: String { "secure/" }
///     var auth: AuthKeys { AuthKeys() }
/// }
///
/// struct AuthKeys: ConfigNamespaceKeys {
///     var keyPrefix: String { "auth." }
///     var apiToken: RWConfigKey<String?> {
///         RWConfigKey("token", in: .secure, default: nil)
///     }
/// }
///
/// // Access: configs.secure.auth.apiToken
/// // Final key name: "secure/auth.token"
/// ```
///
/// ## Value Types
///
/// All conforming types are value types. Operations like `with(...)` return new instances
/// rather than mutating the existing one, ensuring immutable, predictable behavior.
///
/// - Note: The `configs` property provides access to the underlying `Configs` instance,
///   while `keyPrefix` accumulates namespace prefixes as you navigate deeper into the hierarchy.
public protocol ConfigsType {

    associatedtype Keys
    var keys: Keys { get }
    var keyPrefix: String { get }
    var configs: Configs { get set }
}

public extension ConfigsType {

    /// Creates a nested namespace from a key path
    ///
    /// This subscript enables seamless navigation through namespace hierarchies using
    /// dynamic member lookup. The resulting namespace automatically inherits and
    /// extends the current key prefix.
    ///
    /// ```swift
    /// let secureConfigs = configs.secure  // Returns ConfigNamespace<SecureKeys>
    /// let authToken = configs.secure.auth.token  // Automatic prefix concatenation
    /// ```
    @inlinable subscript<Scope: ConfigNamespaceKeys>(dynamicMember keyPath: KeyPath<Keys, Scope>) -> ConfigNamespace<Scope> {
        ConfigNamespace(keys[keyPath: keyPath], base: self)
    }

    /// Direct access to read-only configuration values
    ///
    /// Provides seamless access to configuration values through dynamic member lookup.
    /// The key name is automatically prefixed with the current namespace path.
    ///
    /// ```swift
    /// let userId = configs.userId  // Direct value access
    /// let secureToken = configs.secure.token  // Nested namespace access
    /// ```
    @inlinable subscript<Value>(dynamicMember keyPath: KeyPath<Keys, ConfigKey<Value, ReadOnly>>) -> Value {
        self.get(keyPath)
    }

    /// Direct access to read-write configuration values
    ///
    /// Provides seamless read and write access to configuration values. The key name
    /// is automatically prefixed with the current namespace path.
    ///
    /// ```swift
    /// configs.apiToken = "new-token"  // Direct value assignment
    /// configs.secure.userPrefs = prefs  // Nested namespace assignment
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
        let key = transform(key: key)
        if let overwrittenValue = configs.values[key.name], let result = overwrittenValue as? Value {
            return result
        }
        return key.get(registry: configs.registry)
    }
    
    /// Sets a configuration value using a config key
    @inlinable func set<Value>(_ key: ConfigKey<Value, ReadWrite>, _ newValue: Value) {
        transform(key: key).set(registry: configs.registry, newValue)
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
        transform(key: key).remove(registry: configs.registry)
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
        return transform(key: key).exists(registry: configs.registry)
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
        result.configs.values[transform(key: key).name] = value
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
        let key = transform(key: key)
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

extension ConfigsType {

    @usableFromInline
    func transform<Value, Access>(key: ConfigKey<Value, Access>) -> ConfigKey<Value, Access> {
         if keyPrefix.isEmpty {
             return key
         } else {
             return key.prefix(keyPrefix)
         }
     }
}
