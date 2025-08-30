import Foundation

/// Protocol for configuration property wrappers
///
/// Defines the common interface for both read-only and read-write configuration
/// property wrappers. This protocol enables shared functionality while maintaining
/// type safety for access permissions.
public protocol ConfigWrapper<Value> {
    associatedtype Value
    /// The configuration key access type (ReadOnly or ReadWrite)
    associatedtype Access: KeyAccess

    /// The configuration management instance
    var configs: Configs { get }
    /// The configuration key defining the value's storage and behavior
    var key: ConfigKey<Value, Access> { get }
    /// Creates a wrapper with the specified key and configuration instance
    init(_ key: ConfigKey<Value, Access>, configs: Configs)
}

public extension ConfigWrapper {

    /// Creates a wrapper using a key path to the configuration key
    ///
    /// This convenience initializer allows using key paths for cleaner syntax when
    /// declaring configuration properties.
    ///
    /// - Parameters:
    ///   - key: Key path to the configuration key in the Configs.Keys namespace
    ///   - configs: Configuration instance (uses default system if not specified)
    init(_ key: KeyPath<Configs.Keys, ConfigKey<Value, Access>>, configs: Configs = Configs()) {
        self.init(Configs.Keys()[keyPath: key], configs: configs)
    }

    /// Checks whether a value exists for this configuration key
    ///
    /// - Returns: `true` if the key has a stored value, `false` otherwise
    /// - Note: Returns `false` if the key only has a default value but no stored value
    func exists() -> Bool {
        configs.exists(key)
    }

    /// Registers a listener for changes to this configuration key
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    var changes: ConfigChangesSequence<Value> {
        configs.changes(of: key)
    }
}

public extension ConfigWrapper where Access == ReadOnly {

    /// The current configuration value
    var value: Value {
        configs.get(key)
    }
}


public extension ConfigWrapper where Access == ReadWrite {

    /// The current configuration value
    var value: Value {
        get {
            configs.get(key)
        }
        nonmutating set {
            configs.set(key, newValue)
        }
    }

    /// Removes the stored value, falling back to the key's default
    ///
    /// After deletion, accessing the wrapped value will return the key's default value.
    /// This operation is persisted to the underlying store and triggers change notifications.
    func remove() {
        configs.remove(key)
    }
}

/// Property wrapper for read-only configuration values
///
/// Use this property wrapper for configuration values that should not be modified
/// at runtime. The wrapped value is retrieved from the configuration system each
/// time it's accessed, allowing for reactive updates when underlying values change.
///
/// ## Usage Example
///
/// ```swift
/// struct Settings {
///     @ROConfig(\.apiBaseURL)
///     var baseURL: String
///
///     @ROConfig(\.maxRetryAttempts)
///     var retries: Int
/// }
/// ```
@propertyWrapper
public struct ROConfig<Value>: ConfigWrapper {
    public let configs: Configs
    public let key: ConfigKey<Value, ReadOnly>

    /// The current configuration value
    ///
    /// This value is fetched from the configuration system on each access,
    /// ensuring it reflects the most current stored or default value.
    public var wrappedValue: Value {
        configs.get(key)
    }

    /// Provides access to the wrapper itself for advanced operations
    public var projectedValue: Self {
        self
    }

    public init(_ key: ROConfigKey<Value>, configs: Configs) {
        self.key = key
        self.configs = configs
    }
}

/// Property wrapper for read-write configuration values
///
/// Use this property wrapper for configuration values that can be modified at runtime.
/// Changes are immediately persisted to the underlying configuration store and will
/// trigger change notifications for observers.
///
/// ## Usage Example
///
/// ```swift
/// struct UserSettings {
///     @RWConfig(\.themeName)
///     var theme: String
///
///     @RWConfig(\.notificationsEnabled)
///     var notifications: Bool
///
///     func resetTheme() {
///         $theme.delete() // Removes stored value, falls back to default
///     }
/// }
/// ```
@propertyWrapper
public struct RWConfig<Value>: ConfigWrapper {
    public let configs: Configs
    public let key: ConfigKey<Value, ReadWrite>

    /// The configuration value with read and write access
    ///
    /// Reading fetches the current value from the configuration system.
    /// Writing immediately persists the value to the configured store.
    public var wrappedValue: Value {
        get {
            configs.get(key)
        }
        nonmutating set {
            configs.set(key, newValue)
        }
    }

    /// Provides access to the wrapper itself for advanced operations
    public var projectedValue: Self {
        self
    }

    public init(_ key: ConfigKey<Value, Access>, configs: Configs) {
        self.key = key
        self.configs = configs
    }
}

public extension ConfigWrapper where Value: LosslessStringConvertible {
    /// Creates a configuration wrapper for string-convertible values in a category
    ///
    /// - Parameters:
    ///   - defaultValue: The default value to use if the key is not found
    ///   - key: The configuration key name
    ///   - category: The configuration category (determines which store to use)
    ///   - cacheDefaultValue: Whether to store the default value on first access
    /// - Note: Recommended for most use cases as it integrates with the configuration system. For direct store access, use `init(_:store:cacheDefaultValue:)`
    init(
        wrappedValue defaultValue: @escaping @autoclosure () -> Value,
        _ key: String,
        in category: ConfigCategory,
        cacheDefaultValue: Bool = false,
        configs: Configs = Configs()
    ) {
        self.init(
            configs.keys.key(
                key,
                store: { $0.store(for: category) },
                as: .stringConvertable,
                default: defaultValue(),
                cacheDefaultValue: cacheDefaultValue
            ),
            configs: configs
        )
    }

    /// Creates a configuration wrapper for string-convertible values with a specific store
    ///
    /// - Parameters:
    ///   - defaultValue: The default value to use if the key is not found
    ///   - key: The configuration key name
    ///   - store: The specific configuration store to use
    ///   - cacheDefaultValue: Whether to store the default value on first access
    /// - Tip: Use when you need to ensure the key is written to a specific store or when the key may be useful before the config system is bootstrapped. For most use cases, prefer `init(_:in:cacheDefaultValue:)`
    init(
        wrappedValue defaultValue: @escaping @autoclosure () -> Value,
        _ key: String,
        store: ConfigStore,
        cacheDefaultValue: Bool = false,
        configs: Configs = Configs()
    ) {
        self.init(
            configs.keys.key(
                key,
                store: store,
                as: .stringConvertable,
                default: defaultValue(),
                cacheDefaultValue: cacheDefaultValue
            ),
            configs: configs
        )
    }
}

public extension ConfigWrapper where Value: RawRepresentable, Value.RawValue: LosslessStringConvertible {
    /// Creates a configuration wrapper for enum and raw representable values in a category
    ///
    /// - Parameters:
    ///   - defaultValue: The default value to use if the key is not found
    ///   - key: The configuration key name
    ///   - category: The configuration category (determines which store to use)
    ///   - cacheDefaultValue: Whether to store the default value on first access
    /// - Note: Recommended for most use cases as it integrates with the configuration system. For direct store access, use `init(_:store:cacheDefaultValue:)`
    init(
        wrappedValue defaultValue: @escaping @autoclosure () -> Value,
        _ key: String,
        in category: ConfigCategory,
        cacheDefaultValue: Bool = false,
        configs: Configs = Configs()
    ) {
        self.init(
            configs.keys.key(
                key,
                in: category,
                as: .rawRepresentable,
                default: defaultValue(),
                cacheDefaultValue: cacheDefaultValue
            ),
            configs: configs
        )
    }

    /// Creates a configuration wrapper for enum and raw representable values with a specific store
    ///
    /// - Parameters:
    ///   - defaultValue: The default value to use if the key is not found
    ///   - key: The configuration key name
    ///   - store: The specific configuration store to use
    ///   - cacheDefaultValue: Whether to store the default value on first access
    /// - Tip: Use when you need to ensure the key is written to a specific store or when the key may be useful before the config system is bootstrapped. For most use cases, prefer `init(_:in:cacheDefaultValue:)`
    init(
        wrappedValue defaultValue: @escaping @autoclosure () -> Value,
        _ key: String,
        store: ConfigStore,
        cacheDefaultValue: Bool = false,
        configs: Configs = Configs()
    ) {
        self.init(
            configs.keys.key(
                key,
                store: store,
                as: .rawRepresentable,
                default: defaultValue(),
                cacheDefaultValue: cacheDefaultValue
            ),
            configs: configs
        )
    }
}

public extension ConfigWrapper where Value: Codable {
    /// Creates a configuration wrapper for JSON-encoded Codable values in a category
    ///
    /// - Parameters:
    ///   - defaultValue: The default value to use if the key is not found
    ///   - key: The configuration key name
    ///   - category: The configuration category (determines which store to use)
    ///   - cacheDefaultValue: Whether to store the default value on first access
    ///   - decoder: The JSON decoder to use for deserialization
    ///   - encoder: The JSON encoder to use for serialization
    /// - Note: Recommended for most use cases as it integrates with the configuration system. For direct store access, use `init(_:store:cacheDefaultValue:)`
    @_disfavoredOverload
    init(
        wrappedValue defaultValue: @escaping @autoclosure () -> Value,
        _ key: String,
        in category: ConfigCategory,
        cacheDefaultValue: Bool = false,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder(),
        configs: Configs = Configs()
    ) {
        self.init(
            configs.keys.key(
                key,
                in: category,
                as: .json(decoder: decoder, encoder: encoder),
                default: defaultValue(),
                cacheDefaultValue: cacheDefaultValue
            ),
            configs: configs
        )
    }

    /// Creates a configuration wrapper for JSON-encoded Codable values with a specific store
    ///
    /// - Parameters:
    ///   - defaultValue: The default value to use if the key is not found
    ///   - key: The configuration key name
    ///   - store: The specific configuration store to use
    ///   - cacheDefaultValue: Whether to store the default value on first access
    ///   - decoder: The JSON decoder to use for deserialization
    ///   - encoder: The JSON encoder to use for serialization
    /// - Tip: Use when you need to ensure the key is written to a specific store or when the key may be useful before the config system is bootstrapped. For most use cases, prefer `init(_:in:cacheDefaultValue:)`
    @_disfavoredOverload
    init(
        wrappedValue defaultValue: @escaping @autoclosure () -> Value,
        _ key: String,
        store: ConfigStore,
        cacheDefaultValue: Bool = false,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder(),
        configs: Configs = Configs()
    ) {
        self.init(
            configs.keys.key(
                key,
                store: store,
                as: .json(decoder: decoder, encoder: encoder),
                default: defaultValue(),
                cacheDefaultValue: cacheDefaultValue
            ),
            configs: configs
        )
    }
}

public extension ConfigWrapper {
    /// Creates an optional configuration wrapper for string-convertible values in a category
    ///
    /// - Parameters:
    ///   - defaultValue: The default value to use if the key is not found (typically `nil`)
    ///   - key: The configuration key name
    ///   - category: The configuration category (determines which store to use)
    ///   - cacheDefaultValue: Whether to store the default value on first access
    /// - Note: Recommended for most use cases as it integrates with the configuration system. For direct store access, use `init(_:store:cacheDefaultValue:)`
    init<T: LosslessStringConvertible>(
        wrappedValue defaultValue: @escaping @autoclosure () -> Value = nil,
        _ key: String,
        in category: ConfigCategory,
        cacheDefaultValue: Bool = false,
        configs: Configs = Configs()
    ) where Value == T? {
        self.init(
            configs.keys.key(
                key,
                in: category,
                as: .optional(.stringConvertable),
                default: defaultValue(),
                cacheDefaultValue: cacheDefaultValue
            ),
            configs: configs
        )
    }

    /// Creates an optional configuration wrapper for string-convertible values with a specific store
    ///
    /// - Parameters:
    ///   - defaultValue: The default value to use if the key is not found (typically `nil`)
    ///   - key: The configuration key name
    ///   - store: The specific configuration store to use
    ///   - cacheDefaultValue: Whether to store the default value on first access
    /// - Tip: Use when you need to ensure the key is written to a specific store or when the key may be useful before the config system is bootstrapped. For most use cases, prefer `init(_:in:cacheDefaultValue:)`
    init<T: LosslessStringConvertible>(
        wrappedValue defaultValue: @escaping @autoclosure () -> Value = nil,
        _ key: String,
        store: ConfigStore,
        cacheDefaultValue: Bool = false,
        configs: Configs = Configs()
    ) where Value == T? {
        self.init(
            configs.keys.key(
                key,
                store: store,
                as: .optional(.stringConvertable),
                default: defaultValue(),
                cacheDefaultValue: cacheDefaultValue
            ),
            configs: configs
        )
    }

    /// Creates an optional configuration wrapper for enum and raw representable values in a category
    ///
    /// - Parameters:
    ///   - defaultValue: The default value to use if the key is not found (typically `nil`)
    ///   - key: The configuration key name
    ///   - category: The configuration category (determines which store to use)
    ///   - cacheDefaultValue: Whether to store the default value on first access
    /// - Note: Recommended for most use cases as it integrates with the configuration system. For direct store access, use `init(_:store:cacheDefaultValue:)`
    init<T: RawRepresentable>(
        wrappedValue defaultValue: @escaping @autoclosure () -> Value = nil,
        _ key: String,
        in category: ConfigCategory,
        cacheDefaultValue: Bool = false,
        configs: Configs = Configs()
    ) where T.RawValue: LosslessStringConvertible, Value == T? {
        self.init(
            configs.keys.key(
                key,
                in: category,
                as: .optional(.rawRepresentable),
                default: defaultValue(),
                cacheDefaultValue: cacheDefaultValue
            ),
            configs: configs
        )
    }

    /// Creates an optional configuration wrapper for enum and raw representable values with a specific store
    ///
    /// - Parameters:
    ///   - defaultValue: The default value to use if the key is not found (typically `nil`)
    ///   - key: The configuration key name
    ///   - store: The specific configuration store to use
    ///   - cacheDefaultValue: Whether to store the default value on first access
    /// - Tip: Use when you need to ensure the key is written to a specific store or when the key may be useful before the config system is bootstrapped. For most use cases, prefer `init(_:in:cacheDefaultValue:)`
    init<T: RawRepresentable>(
        wrappedValue defaultValue: @escaping @autoclosure () -> Value = nil,
        _ key: String,
        store: ConfigStore,
        cacheDefaultValue: Bool = false,
        configs: Configs = Configs()
    ) where T.RawValue: LosslessStringConvertible, Value == T? {
        self.init(
            configs.keys.key(
                key,
                store: store,
                as: .optional(.rawRepresentable),
                default: defaultValue(),
                cacheDefaultValue: cacheDefaultValue
            ),
            configs: configs
        )
    }

    /// Creates an optional configuration wrapper for JSON-encoded Codable values in a category
    ///
    /// - Parameters:
    ///   - defaultValue: The default value to use if the key is not found (typically `nil`)
    ///   - key: The configuration key name
    ///   - category: The configuration category (determines which store to use)
    ///   - cacheDefaultValue: Whether to store the default value on first access
    ///   - decoder: The JSON decoder to use for deserialization
    ///   - encoder: The JSON encoder to use for serialization
    /// - Note: Recommended for most use cases as it integrates with the configuration system. For direct store access, use `init(_:store:cacheDefaultValue:)`
    @_disfavoredOverload
    init<T: Codable>(
        wrappedValue defaultValue: @escaping @autoclosure () -> Value = nil,
        _ key: String,
        in category: ConfigCategory,
        cacheDefaultValue: Bool = false,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder(),
        configs: Configs = Configs()
    ) where Value == T? {
        self.init(
            configs.keys.key(
                key,
                in: category,
                as: .optional(.json(decoder: decoder, encoder: encoder)),
                default: defaultValue(),
                cacheDefaultValue: cacheDefaultValue
            ),
            configs: configs
        )
    }

    /// Creates an optional configuration wrapper for JSON-encoded Codable values with a specific store
    ///
    /// - Parameters:
    ///   - defaultValue: The default value to use if the key is not found (typically `nil`)
    ///   - key: The configuration key name
    ///   - store: The specific configuration store to use
    ///   - cacheDefaultValue: Whether to store the default value on first access
    ///   - decoder: The JSON decoder to use for deserialization
    ///   - encoder: The JSON encoder to use for serialization
    /// - Tip: Use when you need to ensure the key is written to a specific store or when the key may be useful before the config system is bootstrapped. For most use cases, prefer `init(_:in:cacheDefaultValue:)`
    @_disfavoredOverload
    init<T: Codable>(
        wrappedValue defaultValue: @escaping @autoclosure () -> Value = nil,
        _ key: String,
        store: ConfigStore,
        cacheDefaultValue: Bool = false,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder(),
        configs: Configs = Configs()
    ) where Value == T? {
        self.init(
            configs.keys.key(
                key,
                store: store,
                as: .optional(.json(decoder: decoder, encoder: encoder)),
                default: defaultValue(),
                cacheDefaultValue: cacheDefaultValue
            ),
            configs: configs
        )
    }
}

#if compiler(>=5.6)
    extension ROConfig: Sendable where Value: Sendable {}
    extension RWConfig: Sendable where Value: Sendable {}
#endif
