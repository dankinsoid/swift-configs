import Foundation

/// Protocol that defines permission types for configuration keys
public protocol KeyAccess {
    /// Whether this permission type supports writing operations
    static var isWritable: Bool { get }
}

public typealias ROKey<Value> = Configs.Keys.Key<Value, Configs.Keys.ReadOnly>
public typealias RWKey<Value> = Configs.Keys.Key<Value, Configs.Keys.ReadWrite>

public extension Configs {

    struct Keys {
    
        public init() {}

        /// Read-only permission type for configuration keys
        public enum ReadOnly: KeyAccess {
            /// Read-only keys do not support writing
            public static var isWritable: Bool { false }
        }

        /// Read-write permission type for configuration keys
        public enum ReadWrite: KeyAccess {
            /// Read-write keys support writing operations
            public static var isWritable: Bool { true }
        }

        /// A concrete implementation of ConfigKey with specified value type and permission
        public struct Key<Value, Access: KeyAccess> {

            public let name: String
            private let _get: (StoreRegistry) -> Value
            private let _set: (StoreRegistry, Value) -> Void
            private let _remove: (StoreRegistry) throws -> Void
            private let _exists: (StoreRegistry) -> Bool
            private let _listen: (StoreRegistry, @escaping (Value) -> Void) -> Cancellation

            /// Creates a new configuration key with custom behavior
            public init(
                _ key: String,
                get: @escaping (StoreRegistry) -> Value,
                set: @escaping (StoreRegistry, Value) -> Void,
                delete: @escaping (StoreRegistry) throws -> Void,
                exists: @escaping (StoreRegistry) -> Bool,
                onChange: @escaping (StoreRegistry, @escaping (Value) -> Void) -> Cancellation
            ) {
                name = key
                _get = get
                _set = set
                _remove = delete
                _exists = exists
                _listen = onChange
            }

            public func get(registry: StoreRegistry) -> Value {
                _get(registry)
            }

            public func set(registry: StoreRegistry, _ newValue: Value) {
                _set(registry, newValue)
            }

            public func delete(registry: StoreRegistry) {
                try? _remove(registry)
            }

            public func exists(registry: StoreRegistry) -> Bool {
                _exists(registry)
            }

            public func onChange(registry: StoreRegistry, _ observer: @escaping (Value) -> Void) -> Cancellation {
                _listen(registry, observer)
            }
            
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
                    delete: { registry in
                        self.delete(registry: registry)
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
#if DEBUG
                fatalError("Failed to retrieve config value for key '\(name)': \(error)")
#endif
            }
            let result = defaultValue()
            do {
                if cacheDefaultValue, let value = try transformer.encode(result) {
                    try store.set(value, for: name)
                }
            } catch {
#if DEBUG
                fatalError("Failed to cache default config value for key '\(name)': \(error)")
#endif
            }
            return result
        } set: { registry, newValue in
            let store = store(registry)
            do {
                try store.set(transformer.encode(newValue), for: name)
            } catch {
#if DEBUG
                fatalError("Failed to set config value for key '\(name)': \(error)")
#endif
            }
        } delete: { registry in
            try store(registry).set(nil, for: name)
        } exists: { registry in
            let store = store(registry)
            do {
                return try store.exists(name)
            } catch {
                #if DEBUG
                fatalError("Failed to check existence of config key '\(name)': \(error)")
                #endif
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
#if DEBUG
                    fatalError("Failed to retrieve updated config value for key '\(name)': \(error)")
#endif
                }
            }
            return cancellation ?? Cancellation {}
        }
    }

    /// Creates a configuration key with a specific store and transformer
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

    /// Creates a configuration key for LosslessStringConvertible values
    ///
    /// - Parameters:
    ///   - key: The key string
    ///   - store: The configuration store
    ///   - defaultValue: The default value to use if the key is not found
    ///   - cacheDefaultValue: Whether to cache the default value when first accessed
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

    /// Creates an optional configuration key for LosslessStringConvertible values
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

    /// Creates a configuration key in a category for LosslessStringConvertible values
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

    /// Creates an optional configuration key in a category for LosslessStringConvertible values
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

    /// Creates a configuration key for RawRepresentable values
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

    /// Returns the key instance.
    ///
    /// - Parameters:
    ///   - key: The key string.
    ///   - default: The default value to use if the key is not found.
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

    /// Returns the key instance.
    ///
    /// - Parameters:
    ///   - key: The key string.
    ///   - default: The default value to use if the key is not found.
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

    /// Returns the key instance.
    ///
    /// - Parameters:
    ///   - key: The key string.
    ///   - default: The default value to use if the key is not found.
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

    /// Returns the key instance.
    ///
    /// - Parameters:
    ///   - key: The key string.
    ///   - default: The default value to use if the key is not found.
    ///   - decoder: The JSON decoder to use for decoding the value.
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

    /// Returns the key instance.
    ///
    /// - Parameters:
    ///   - key: The key string.
    ///   - default: The default value to use if the key is not found.
    ///   - decoder: The JSON decoder to use for decoding the value.
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

    /// Returns the key instance.
    ///
    /// - Parameters:
    ///   - key: The key string.
    ///   - default: The default value to use if the key is not found.
    ///   - decoder: The JSON decoder to use for decoding the value.
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
