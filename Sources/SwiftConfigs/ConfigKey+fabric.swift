import Foundation

public extension ConfigNamespaceKeys {

    @inlinable
    func key<Value, Access: KeyAccess>(
        _ name: String,
        get: @escaping (StoreRegistryType) -> Value,
        set: @escaping (StoreRegistryType, Value) -> Void,
        remove: @escaping (StoreRegistryType) throws -> Void,
        exists: @escaping (StoreRegistryType) -> Bool,
        onChange: @escaping (StoreRegistryType, @escaping (Value) -> Void) -> Cancellation
    ) -> ConfigKey<Value, Access> {
        ConfigKey(
            keyPrefix + name,
            get: get,
            set: set,
            remove: remove,
            exists: exists,
            onChange: onChange
        )
    }

    @inlinable
    func key<Value, Access: KeyAccess>(
        _ name: String,
        store: @escaping (StoreRegistryType) -> ConfigStore,
        as transformer: ConfigTransformer<Value>,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool
    ) -> ConfigKey<Value, Access> {
        ConfigKey(
            keyPrefix + name,
            store: store,
            as: transformer,
            default: defaultValue(),
            cacheDefaultValue: cacheDefaultValue
        )
    }

    /// Creates a configuration key with a specific store and transformer
    ///
    /// - Parameters:
    ///   - key: The configuration key name
    ///   - store: The configuration store to use
    ///   - transformer: How to encode/decode values for storage
    ///   - defaultValue: Value returned when key doesn't exist
    ///   - cacheDefaultValue: Whether to store the default value on first access
    /// - Tip: Use when you need to ensure the key is written to a specific store or when the key may be useful before the config system is bootstrapped. For most use cases, prefer `func key<Value, Access: KeyAccess>(_:in:as:default:cacheDefaultValue:)`
    @inlinable
    func key<Value, Access: KeyAccess>(
        _ key: String,
        store: ConfigStore,
        as transformer: ConfigTransformer<Value>,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false
    ) -> ConfigKey<Value, Access> {
        self.key(
            key,
            store: { _ in store },
            as: transformer,
            default: defaultValue(),
            cacheDefaultValue: cacheDefaultValue
        )
    }

    /// Creates a configuration key for a specific category with a transformer
    ///
    /// - Parameters:
    ///   - key: The configuration key name
    ///   - category: The configuration category (determines which store to use)
    ///   - transformer: How to encode/decode values for storage
    ///   - defaultValue: Value returned when key doesn't exist
    ///   - cacheDefaultValue: Whether to store the default value on first access
    /// - Note: Recommended for most use cases as it integrates with the configuration system. For direct store access, use `func key<Value, Access: KeyAccess>(_:store:as:default:cacheDefaultValue:)`
    @inlinable
    func key<Value, Access: KeyAccess>(
        _ key: String,
        in category: ConfigCategory,
        as transformer: ConfigTransformer<Value>,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false
    ) -> ConfigKey<Value, Access> {
        self.key(
            key,
            store: { $0.store(for: category) },
            as: transformer,
            default: defaultValue(),
            cacheDefaultValue: cacheDefaultValue
        )
    }

    /// Creates a configuration key for values that can be converted to/from strings
    ///
    /// - Parameters:
    ///   - key: The configuration key name
    ///   - store: The configuration store to use
    ///   - defaultValue: Value returned when key doesn't exist
    ///   - cacheDefaultValue: Whether to store the default value on first access
    /// - Note: Uses the built-in string conversion transformer for encoding/decoding
    /// - Tip: Use when you need to ensure the key is written to a specific store or when the key may be useful before the config system is bootstrapped. For most use cases, prefer `func key<Value, Access: KeyAccess>(_:in:default:cacheDefaultValue:)`
    @inlinable
    func key<Value: LosslessStringConvertible, Access: KeyAccess>(
        _ key: String,
        store: ConfigStore,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false
    ) -> ConfigKey<Value, Access> {
        self.key(
            key,
            store: { _ in store },
            as: .stringConvertable,
            default: defaultValue(),
            cacheDefaultValue: cacheDefaultValue
        )
    }

    /// Creates an optional configuration key for string-convertible values
    ///
    /// - Parameters:
    ///   - key: The configuration key name
    ///   - store: The configuration store to use
    ///   - defaultValue: Value returned when key doesn't exist (typically `nil`)
    ///   - cacheDefaultValue: Whether to store the default value on first access
    /// - Note: Returns `nil` when the key doesn't exist or conversion fails.
    @inlinable
    func key<Value: LosslessStringConvertible, Access: KeyAccess>(
        _ key: String,
        store: ConfigStore,
        default defaultValue: @escaping @autoclosure () -> Value? = nil,
        cacheDefaultValue: Bool = false
    ) -> ConfigKey<Value?, Access> {
        self.key(
            key,
            store: store,
            as: .optional(.stringConvertable),
            default: defaultValue(),
            cacheDefaultValue: cacheDefaultValue
        )
    }

    /// Creates a configuration key in a category for string-convertible values
    ///
    /// - Parameters:
    ///   - key: The configuration key name
    ///   - category: The configuration category (determines which store to use)
    ///   - defaultValue: Value returned when key doesn't exist
    ///   - cacheDefaultValue: Whether to store the default value on first access
    /// - Note: Recommended for most use cases as it integrates with the configuration system. For direct store access, use `func key<Value, Access: KeyAccess>(_:store:default:cacheDefaultValue:)`
    @inlinable
    func key<Value: LosslessStringConvertible, Access: KeyAccess>(
        _ key: String,
        in category: ConfigCategory,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false
    ) -> ConfigKey<Value, Access> {
        self.key(
            key,
            store: { $0.store(for: category) },
            as: .stringConvertable,
            default: defaultValue(),
            cacheDefaultValue: cacheDefaultValue
        )
    }

    /// Creates an optional configuration key in a category for string-convertible values
    ///
    /// - Parameters:
    ///   - key: The configuration key name
    ///   - category: The configuration category (determines which store to use)
    ///   - defaultValue: Value returned when key doesn't exist (typically `nil`)
    ///   - cacheDefaultValue: Whether to store the default value on first access
    /// - Note: Returns `nil` when the key doesn't exist or conversion fails. Recommended for most use cases as it integrates with the configuration system
    @inlinable
    func key<Value: LosslessStringConvertible, Access: KeyAccess>(
        _ key: String,
        in category: ConfigCategory,
        default defaultValue: @escaping @autoclosure () -> Value? = nil,
        cacheDefaultValue: Bool = false
    ) -> ConfigKey<Value?, Access> {
        self.key(
            key,
            store: { $0.store(for: category) },
            as: .optional(.stringConvertable),
            default: defaultValue(),
            cacheDefaultValue: cacheDefaultValue
        )
    }

    /// Creates a configuration key for enum and raw representable values
    ///
    /// - Parameters:
    ///   - key: The configuration key name
    ///   - store: The configuration store to use
    ///   - defaultValue: Value returned when key doesn't exist
    ///   - cacheDefaultValue: Whether to store the default value on first access
    /// - Note: Stores the raw value and converts back to the enum type on retrieval.
    @inlinable
    func key<Value: RawRepresentable, Access: KeyAccess>(
        _ key: String,
        store: ConfigStore,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false
    ) -> ConfigKey<Value, Access> where Value.RawValue: LosslessStringConvertible {
        self.key(
            key,
            store: store,
            as: .rawRepresentable,
            default: defaultValue(),
            cacheDefaultValue: cacheDefaultValue
        )
    }

    /// Creates a configuration key in a category for enum and raw representable values
    ///
    /// - Parameters:
    ///   - key: The configuration key name
    ///   - category: The configuration category (determines which store to use)
    ///   - defaultValue: Value returned when key doesn't exist
    ///   - cacheDefaultValue: Whether to store the default value on first access
    /// - Note: Stores the raw value and converts back to the enum type on retrieval.
    @inlinable
    func key<Value: RawRepresentable, Access: KeyAccess>(
        _ key: String,
        in category: ConfigCategory,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false
    ) -> ConfigKey<Value, Access> where Value.RawValue: LosslessStringConvertible {
        self.key(
            key,
            in: category,
            as: .rawRepresentable,
            default: defaultValue(),
            cacheDefaultValue: cacheDefaultValue
        )
    }

    /// Creates an optional configuration key in a category for enum and raw representable values
    ///
    /// - Parameters:
    ///   - key: The configuration key name
    ///   - category: The configuration category (determines which store to use)
    ///   - defaultValue: Value returned when key doesn't exist (typically `nil`)
    ///   - cacheDefaultValue: Whether to store the default value on first access
    /// - Note: Returns `nil` when the key doesn't exist or raw value conversion fails.
    @inlinable
    func key<Value: RawRepresentable, Access: KeyAccess>(
        _ key: String,
        in category: ConfigCategory,
        default defaultValue: @escaping @autoclosure () -> Value? = nil,
        cacheDefaultValue: Bool = false
    ) -> ConfigKey<Value?, Access> where Value.RawValue: LosslessStringConvertible {
        self.key(
            key,
            in: category,
            as: .optional(.rawRepresentable),
            default: defaultValue(),
            cacheDefaultValue: cacheDefaultValue
        )
    }

    /// Creates an optional configuration key for enum and raw representable values
    ///
    /// - Parameters:
    ///   - key: The configuration key name
    ///   - store: The configuration store to use
    ///   - defaultValue: Value returned when key doesn't exist (typically `nil`)
    ///   - cacheDefaultValue: Whether to store the default value on first access
    /// - Note: Returns `nil` when the key doesn't exist or raw value conversion fails.
    @inlinable
    func key<Value: RawRepresentable, Access: KeyAccess>(
        _ key: String,
        store: ConfigStore,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false
    ) -> ConfigKey<Value?, Access> where Value.RawValue: LosslessStringConvertible {
        self.key(
            key,
            store: store,
            as: .optional(.rawRepresentable),
            default: defaultValue(),
            cacheDefaultValue: cacheDefaultValue
        )
    }

    /// Creates a configuration key for JSON-encoded Codable values
    ///
    /// - Parameters:
    ///   - key: The configuration key name
    ///   - store: The configuration store to use
    ///   - defaultValue: Value returned when key doesn't exist
    ///   - cacheDefaultValue: Whether to store the default value on first access
    ///   - decoder: The JSON decoder to use for deserialization
    ///   - encoder: The JSON encoder to use for serialization
    @_disfavoredOverload
    @inlinable
    func key<Value: Codable, Access: KeyAccess>(
        _ key: String,
        store: ConfigStore,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) -> ConfigKey<Value, Access> {
        self.key(
            key,
            store: store,
            as: .json(decoder: decoder, encoder: encoder),
            default: defaultValue(),
            cacheDefaultValue: cacheDefaultValue
        )
    }

    /// Creates a configuration key in a category for JSON-encoded Codable values
    ///
    /// - Parameters:
    ///   - key: The configuration key name
    ///   - category: The configuration category (determines which store to use)
    ///   - defaultValue: Value returned when key doesn't exist
    ///   - cacheDefaultValue: Whether to store the default value on first access
    ///   - decoder: The JSON decoder to use for deserialization
    ///   - encoder: The JSON encoder to use for serialization
    @_disfavoredOverload
    @inlinable
    func key<Value: Codable, Access: KeyAccess>(
        _ key: String,
        in category: ConfigCategory,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) -> ConfigKey<Value, Access> {
        self.key(
            key,
            in: category,
            as: .json(decoder: decoder, encoder: encoder),
            default: defaultValue(),
            cacheDefaultValue: cacheDefaultValue
        )
    }

    /// Creates an optional configuration key in a category for JSON-encoded Codable values
    ///
    /// - Parameters:
    ///   - key: The configuration key name
    ///   - category: The configuration category (determines which store to use)
    ///   - defaultValue: Value returned when key doesn't exist (typically `nil`)
    ///   - cacheDefaultValue: Whether to store the default value on first access
    ///   - decoder: The JSON decoder to use for deserialization
    ///   - encoder: The JSON encoder to use for serialization
    /// - Note: Returns `nil` when the key doesn't exist or JSON decoding fails.
    @_disfavoredOverload
    @inlinable
    func key<Value: Codable, Access: KeyAccess>(
        _ key: String,
        in category: ConfigCategory,
        default defaultValue: @escaping @autoclosure () -> Value? = nil,
        cacheDefaultValue: Bool = false,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    )  -> ConfigKey<Value?, Access> {
        self.key(
            key,
            in: category,
            as: .optional(.json(decoder: decoder, encoder: encoder)),
            default: defaultValue(),
            cacheDefaultValue: cacheDefaultValue
        )
    }

    /// Creates an optional configuration key for JSON-encoded Codable values
    ///
    /// - Parameters:
    ///   - key: The configuration key name
    ///   - store: The configuration store to use
    ///   - defaultValue: Value returned when key doesn't exist (typically `nil`)
    ///   - cacheDefaultValue: Whether to store the default value on first access
    ///   - decoder: The JSON decoder to use for deserialization
    ///   - encoder: The JSON encoder to use for serialization
    /// - Note: Returns `nil` when the key doesn't exist or JSON decoding fails.
    @_disfavoredOverload
    @inlinable
    func key<Value: Codable, Access: KeyAccess>(
        _ key: String,
        store: ConfigStore,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    )  -> ConfigKey<Value?, Access> {
        self.key(
            key,
            store: store,
            as: .optional(.json(decoder: decoder, encoder: encoder)),
            default: defaultValue(),
            cacheDefaultValue: cacheDefaultValue
        )
    }
}
