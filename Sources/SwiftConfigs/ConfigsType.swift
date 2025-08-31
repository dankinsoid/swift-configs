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
        configs.get(keys[keyPath: keyPath])
    }

    /// Sets a configuration value using a key path
    @inlinable func set<Value>(_ keyPath: KeyPath<Keys, ConfigKey<Value, ReadWrite>>, _ newValue: Value) {
        let key = keys[keyPath: keyPath]
        configs.set(key, newValue)
    }
    
    /// Removes a configuration value using a key path
    @inlinable func remove<Value>(_ keyPath: KeyPath<Keys, ConfigKey<Value, ReadWrite>>) {
        let key = keys[keyPath: keyPath]
        configs.remove(key)
    }
    
    /// Checks if a configuration value exists using a key path
    @inlinable func exists<Value, P: KeyAccess>(_ keyPath: KeyPath<Keys, ConfigKey<Value, P>>) -> Bool {
        let key = keys[keyPath: keyPath]
        return configs.exists(key)
    }

    /// Overwrites the value of a key.
    /// - Parameters:
    ///   - key: The key to overwrite.
    ///   - value: The value to set.
    @inlinable func with<Value, P: KeyAccess>(_ key: KeyPath<Keys, ConfigKey<Value, P>>, _ value: Value?) -> Self {
        var result = self
        result.configs = result.configs.with(keys[keyPath: key], value)
        return result
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

    /// Fetches if needed and returns the value for a specific key path
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    @inlinable func fetchIfNeeded<Value, P: KeyAccess>(_ keyPath: KeyPath<Keys, ConfigKey<Value, P>>) async throws -> Value {
        try await configs.fetchIfNeeded(keys[keyPath: keyPath])
    }
    
    /// Fetches configuration values and returns the value for a specific key path
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    @inlinable func fetch<Value, P: KeyAccess>(_ keyPath: KeyPath<Keys, ConfigKey<Value, P>>) async throws -> Value {
        try await configs.fetch(keys[keyPath: keyPath])
    }
    
    /// Registers a listener for changes to a specific configuration key path
    @inlinable func onChange<Value, P: KeyAccess>(of keyPath: KeyPath<Keys, ConfigKey<Value, P>>, _ observer: @escaping (Value) -> Void) -> Cancellation {
        let key = keys[keyPath: keyPath]
        return configs.onChange(of: key, observer)
    }

    /// Returns an async sequence for changes to a specific configuration key path
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    @inlinable func changes<Value, P: KeyAccess>(of keyPath: KeyPath<Keys, ConfigKey<Value, P>>) -> ConfigChangesSequence<Value> {
        let key = keys[keyPath: keyPath]
        return configs.changes(of: key)
    }
}
