import Foundation

/// Defines permission types for configuration keys
///
/// Used to enforce read-only or read-write access at compile time.
public protocol KeyAccess {
    /// Whether this permission type supports writing operations
    static var isWritable: Bool { get }
}

public typealias ROKey<Value> = Configs.Keys.Key<Value, Configs.Keys.ReadOnly>
public typealias RWKey<Value> = Configs.Keys.Key<Value, Configs.Keys.ReadWrite>

public extension Configs {
    struct Keys {
        public init() {}

        /// Read-only permission for configuration keys
        ///
        /// Keys with this permission cannot be modified through the configuration system.
        public enum ReadOnly: KeyAccess {
            public static var isWritable: Bool { false }
        }

        /// Read-write permission for configuration keys
        ///
        /// Keys with this permission support both reading and writing operations.
        public enum ReadWrite: KeyAccess {
            public static var isWritable: Bool { true }
        }

        /// Configuration key with specified value type and access permissions
        ///
        /// Encapsulates all operations for a configuration value, including reading, writing,
        /// existence checking, and change observation. The `Access` type parameter enforces
        /// read-only or read-write permissions at compile time.
        public struct Key<Value, Access: KeyAccess> {
            public let name: String
            private let _get: (StoreRegistry) -> Value
            private let _set: (StoreRegistry, Value) -> Void
            private let _remove: (StoreRegistry) throws -> Void
            private let _exists: (StoreRegistry) -> Bool
            private let _listen: (StoreRegistry, @escaping (Value) -> Void) -> Cancellation

            /// Creates a configuration key with custom behavior
            ///
            /// - Parameters:
            ///   - key: The unique identifier for this configuration key
            ///   - get: Closure to retrieve the current value
            ///   - set: Closure to store a new value
            ///   - delete: Closure to remove the stored value
            ///   - exists: Closure to check if a value exists
            ///   - onChange: Closure to observe value changes
            ///
            /// - Note: Most users should use the convenience initializers instead of this low-level constructor.
            public init(
                _ key: String,
                get: @escaping (StoreRegistry) -> Value,
                set: @escaping (StoreRegistry, Value) -> Void,
                remove: @escaping (StoreRegistry) throws -> Void,
                exists: @escaping (StoreRegistry) -> Bool,
                onChange: @escaping (StoreRegistry, @escaping (Value) -> Void) -> Cancellation
            ) {
                name = key
                _get = get
                _set = set
                _remove = remove
                _exists = exists
                _listen = onChange
            }

            public func get(registry: StoreRegistry) -> Value {
                _get(registry)
            }

            public func set(registry: StoreRegistry, _ newValue: Value) {
                _set(registry, newValue)
            }

            /// Removes the stored value for this key
            ///
            /// - Warning: Silently ignores deletion errors. Use `try _remove(registry)` directly if error handling is needed.
            public func remove(registry: StoreRegistry) {
                try? _remove(registry)
            }

            public func exists(registry: StoreRegistry) -> Bool {
                _exists(registry)
            }

            public func onChange(registry: StoreRegistry, _ observer: @escaping (Value) -> Void) -> Cancellation {
                _listen(registry, observer)
            }

            /// Transforms this key to work with a different value type
            ///
            /// - Parameters:
            ///   - transform: Function to convert from this key's value type to the target type
            ///   - reverseTransform: Function to convert from the target type back to this key's value type
            /// - Returns: A new key that operates on the transformed value type
            /// - Note: Both transform functions must be pure and reversible for consistent behavior.
            public func map<T>(
                _ transform: @escaping (Value) -> T,
                _ reverseTransform: @escaping (T) -> Value
            ) -> Configs.Keys.Key<T, Access> {
                Configs.Keys.Key<T, Access>(
                    name,
                    get: { registry in
                        transform(self.get(registry: registry))
                    },
                    set: { registry, newValue in
                        self.set(registry: registry, reverseTransform(newValue))
                    },
                    remove: { registry in
                        self.remove(registry: registry)
                    },
                    exists: { registry in
                        self.exists(registry: registry)
                    },
                    onChange: { registry, observer in
                        self.onChange(registry: registry) { newValue in
                            observer(transform(newValue))
                        }
                    }
                )
            }
        }
    }
}

public extension Configs.Keys.Key {
    init(
        _ name: String,
        store: @escaping (StoreRegistry) -> ConfigStore,
        as transformer: ConfigTransformer<Value>,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool
    ) {
        self.init(name) { registry in
            let store = store(registry)
            do {
                if let value = try store.get(name, as: transformer) {
                    return value
                }
            } catch {
                ConfigSystem.fail(.retrievalFailed(key: name, error))
            }
            let result = defaultValue()
            do {
                if cacheDefaultValue, store.isWritable, let value = try transformer.encode(result) {
                    try store.set(value, for: name)
                }
            } catch {
                ConfigSystem.fail(.storingFailed(key: name, error))
            }
            return result
        } set: { registry, newValue in
            let store = store(registry)
            if store.isWritable {
                do {
                    try store.set(transformer.encode(newValue), for: name)
                } catch {
                    ConfigSystem.fail(.storingFailed(key: name, error))
                }
            }
        } remove: { registry in
            let store = store(registry)
            if store.isWritable {
                try store.set(nil, for: name)
            }
        } exists: { registry in
            let store = store(registry)
            do {
                return try store.exists(name)
            } catch {
                ConfigSystem.fail(.existenceCheckFailed(key: name, error))
                return false
            }
        } onChange: { registry, observer in
            let store = store(registry)
            let cancellation = store.onChangeOfKey(name) { value in
                do {
                    if let value {
                        try observer(transformer.decode(value))
                    }
                } catch {
                    ConfigSystem.fail(.retrievalFailed(key: name, error))
                }
            }
            return cancellation
        }
    }

    /// Creates a configuration key with a specific store and transformer
    ///
    /// - Parameters:
    ///   - key: The configuration key name
    ///   - store: The configuration store to use
    ///   - transformer: How to encode/decode values for storage
    ///   - defaultValue: Value returned when key doesn't exist
    ///   - cacheDefaultValue: Whether to store the default value on first access
    /// - Tip: Use when you need to ensure the key is written to a specific store or when the key may be useful before the config system is bootstrapped. For most use cases, prefer `init(_:in:as:default:cacheDefaultValue:)`
    init(
        _ key: String,
        store: ConfigStore,
        as transformer: ConfigTransformer<Value>,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false
    ) {
        self.init(
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
    /// - Note: Recommended for most use cases as it integrates with the configuration system. For direct store access, use `init(_:store:as:default:cacheDefaultValue:)`
    init(
        _ key: String,
        in category: ConfigCategory,
        as transformer: ConfigTransformer<Value>,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false
    ) {
        self.init(
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
    /// - Tip: Use when you need to ensure the key is written to a specific store or when the key may be useful before the config system is bootstrapped. For most use cases, prefer `init(_:in:default:cacheDefaultValue:)`
    init(
        _ key: String,
        store: ConfigStore,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false
    ) where Value: LosslessStringConvertible {
        self.init(
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
    init<T>(
        _ key: String,
        store: ConfigStore,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false
    ) where T: LosslessStringConvertible, Value == T? {
        self.init(
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
    /// - Note: Recommended for most use cases as it integrates with the configuration system. For direct store access, use `init(_:store:default:cacheDefaultValue:)`
    init(
        _ key: String,
        in category: ConfigCategory,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false
    ) where Value: LosslessStringConvertible {
        self.init(
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
    init<T>(
        _ key: String,
        in category: ConfigCategory,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false
    ) where T: LosslessStringConvertible, Value == T? {
        self.init(
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
    init(
        _ key: String,
        store: ConfigStore,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false
    ) where Value: RawRepresentable, Value.RawValue: LosslessStringConvertible {
        self.init(
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
    init(
        _ key: String,
        in category: ConfigCategory,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false
    ) where Value: RawRepresentable, Value.RawValue: LosslessStringConvertible {
        self.init(
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
    init<T>(
        _ key: String,
        in category: ConfigCategory,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false
    ) where T: RawRepresentable, T.RawValue: LosslessStringConvertible, T? == Value {
        self.init(
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
    init<T>(
        _ key: String,
        store: ConfigStore,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false
    ) where T: RawRepresentable, T.RawValue: LosslessStringConvertible, T? == Value {
        self.init(
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
    init(
        _ key: String,
        store: ConfigStore,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) where Value: Codable {
        self.init(
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
    init(
        _ key: String,
        in category: ConfigCategory,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) where Value: Codable {
        self.init(
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
    init<T>(
        _ key: String,
        in category: ConfigCategory,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) where T: Codable, T? == Value {
        self.init(
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
    init<T>(
        _ key: String,
        store: ConfigStore,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) where T: Codable, T? == Value {
        self.init(
            key,
            store: store,
            as: .optional(.json(decoder: decoder, encoder: encoder)),
            default: defaultValue(),
            cacheDefaultValue: cacheDefaultValue
        )
    }
}

#if compiler(>=5.6)
    extension Configs.Keys: Sendable {}
    extension Configs.Keys.Key: @unchecked Sendable {}
#endif
