import Foundation

/// Protocol that defines permission types for configuration keys
public protocol ConfigKeyPermission {
    /// Whether this permission type supports writing operations
    static var supportWriting: Bool { get }
}

/// Protocol that defines a configuration key with associated value type and permissions
public protocol ConfigKey<Value> {
    /// The type of value stored by this key
    associatedtype Value
    /// The permission type for this key (ReadOnly or ReadWrite)
    associatedtype Permission: ConfigKeyPermission
    /// The unique identifier for this configuration key
    var name: String { get }
    /// Gets the value from the handler
    func get(handler: ConfigsSystem.Handler) -> Value
    /// Sets a new value using the handler
    func set(handler: ConfigsSystem.Handler, _ newValue: Value)
    /// Removes the value from the handler
    func remove(handler: ConfigsSystem.Handler) throws
    /// Checks if the value exists in the handler
    func exists(handler: ConfigsSystem.Handler) -> Bool
    /// Registers a listener for value changes
    func listen(handler: ConfigsSystem.Handler, _ observer: @escaping (Value) -> Void) -> ConfigsCancellation
    
    init(
        _ key: String,
        get: @escaping (ConfigsSystem.Handler) -> Value,
        set: @escaping (ConfigsSystem.Handler, Value) -> Void,
        remove: @escaping (ConfigsSystem.Handler) throws -> Void,
        exists: @escaping (ConfigsSystem.Handler) -> Bool,
        listen: @escaping (ConfigsSystem.Handler, @escaping (Value) -> Void) -> ConfigsCancellation
    )
}

extension ConfigKey {

    public init(
        _ name: String,
        handler: @escaping (ConfigsSystem.Handler) -> ConfigsHandler,
        as transformer: ConfigTransformer<Value>,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool
    ) {
        self.init(name) { h in
            if let value = handler(h).value(for: name), let decoded = (value as? Value) ?? transformer.decode(value.description) {
                return decoded
            }
            let result = defaultValue()
            if cacheDefaultValue, let value = transformer.encode(result) {
                try? handler(h).writeValue(value, for: name)
            }
            return result
        } set: { h, newValue in
            if let value = transformer.encode(newValue) {
                try? handler(h).writeValue(value, for: name)
            }
        } remove: { h in
            try handler(h).writeValue(nil, for: name)
        } exists: { h in
            handler(h).value(for: name) != nil
        } listen: { h, observer in
            let cancellation = handler(h).listen { [weak h] in
                guard let h else { return }
                observer(handler(h).value(for: name, as: transformer) ?? defaultValue())
            }
            return cancellation ?? ConfigsCancellation {}
        }
    }
}

extension Configs {

    public struct Keys {

        public init() {}
        
        /// Read-only permission type for configuration keys
        public enum ReadOnly: ConfigKeyPermission {
            /// Read-only keys do not support writing
            public static var supportWriting: Bool { false }
        }
        
        /// Read-write permission type for configuration keys
        public enum ReadWrite: ConfigKeyPermission {
            /// Read-write keys support writing operations
            public static var supportWriting: Bool { true }
        }

        /// A concrete implementation of ConfigKey with specified value type and permission
        public struct Key<Value, Permission: ConfigKeyPermission>: ConfigKey {
            
            public let name: String
            private let _get: (ConfigsSystem.Handler) -> Value
            private let _set: (ConfigsSystem.Handler, Value) -> Void
            private let _remove: (ConfigsSystem.Handler) throws -> Void
            private let _exists: (ConfigsSystem.Handler) -> Bool
            private let _listen: (ConfigsSystem.Handler, @escaping (Value) -> Void) -> ConfigsCancellation
            
            /// Creates a new configuration key with custom behavior
            public init(
                _ key: String,
                get: @escaping (ConfigsSystem.Handler) -> Value,
                set: @escaping (ConfigsSystem.Handler, Value) -> Void,
                remove: @escaping (ConfigsSystem.Handler) throws -> Void,
                exists: @escaping (ConfigsSystem.Handler) -> Bool,
                listen: @escaping (ConfigsSystem.Handler, @escaping (Value) -> Void) -> ConfigsCancellation
            ) {
                name = key
                _get = get
                _set = set
                _remove = remove
                _exists = exists
                _listen = listen
            }
            
            public func get(handler: ConfigsSystem.Handler) -> Value {
                _get(handler)
            }
            
            public func set(handler: ConfigsSystem.Handler, _ newValue: Value) {
                _set(handler, newValue)
            }
            
            public func remove(handler: ConfigsSystem.Handler) throws {
                try _remove(handler)
            }
            
            public func exists(handler: ConfigsSystem.Handler) -> Bool {
                _exists(handler)
            }
            
            public func listen(handler: ConfigsSystem.Handler, _ observer: @escaping (Value) -> Void) -> ConfigsCancellation {
                _listen(handler, observer)
            }
        }
        
        /// Shorthand for read-only configuration keys
        public typealias ROKey<Value> = Key<Value, ReadOnly>
        /// Shorthand for read-write configuration keys
        public typealias RWKey<Value> = Key<Value, ReadWrite>
        
        @available(*, deprecated, renamed: "RWKey")
        public typealias WritableKey<Value> = Key<Value, ReadWrite>
    }
}

public extension ConfigKey {

    /// Creates a configuration key with a specific handler and transformer
    init(
        _ key: String,
        handler: ConfigsHandler,
        as transformer: ConfigTransformer<Value>,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false
    ) {
        self.init(
            key,
            handler: { _ in handler },
            as: transformer,
            default: defaultValue(),
            cacheDefaultValue: cacheDefaultValue
        )
    }

    /// Creates a configuration key for a specific category with a transformer
    init(
        _ key: String,
        in category: ConfigsCategory,
        as transformer: ConfigTransformer<Value>,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false
    ) {
        self.init(
            key,
            handler: { $0.handler(for: category) },
            as: transformer,
            default: defaultValue(),
            cacheDefaultValue: cacheDefaultValue
        )
    }

    /// Creates a configuration key for LosslessStringConvertible values
    ///
    /// - Parameters:
    ///   - key: The key string
    ///   - handler: The configuration handler
    ///   - defaultValue: The default value to use if the key is not found
    ///   - cacheDefaultValue: Whether to cache the default value when first accessed
    init(
        _ key: String,
        handler: ConfigsHandler,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false
    ) where Value: LosslessStringConvertible {
        self.init(
            key,
            handler: { _ in handler },
            as: .stringConvertable,
            default: defaultValue(),
            cacheDefaultValue: cacheDefaultValue
        )
    }
    
    /// Creates an optional configuration key for LosslessStringConvertible values
    init<T>(
        _ key: String,
        handler: ConfigsHandler,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false
    ) where T: LosslessStringConvertible, Value == T? {
        self.init(
            key,
            handler: handler,
            as: .optional(.stringConvertable),
            default: defaultValue(),
            cacheDefaultValue: cacheDefaultValue
        )
    }

    /// Creates a configuration key in a category for LosslessStringConvertible values
    init(
        _ key: String,
        in category: ConfigsCategory,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false
    ) where Value: LosslessStringConvertible {
        self.init(
            key,
            handler: { $0.handler(for: category) },
            as: .stringConvertable,
            default: defaultValue(),
            cacheDefaultValue: cacheDefaultValue
        )
    }

    /// Creates an optional configuration key in a category for LosslessStringConvertible values
    init<T>(
        _ key: String,
        in category: ConfigsCategory,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false
    ) where T: LosslessStringConvertible, Value == T? {
        self.init(
            key,
            handler: { $0.handler(for: category) },
            as: .optional(.stringConvertable),
            default: defaultValue(),
            cacheDefaultValue: cacheDefaultValue
        )
    }
    
    /// Creates a configuration key for RawRepresentable values
    init(
        _ key: String,
        handler: ConfigsHandler,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false
    ) where Value: RawRepresentable, Value.RawValue: LosslessStringConvertible {
        self.init(
            key,
            handler: handler,
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
        in category: ConfigsCategory,
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
        in category: ConfigsCategory,
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
        handler: ConfigsHandler,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false
    ) where T: RawRepresentable, T.RawValue: LosslessStringConvertible, T? == Value {
        self.init(
            key,
            handler: handler,
            as: .optional(.rawRepresentable),
            default: defaultValue(),
            cacheDefaultValue: cacheDefaultValue
        )
    }
    
    @_disfavoredOverload
    init(
        _ key: String,
        handler: ConfigsHandler,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) where Value: Codable {
        self.init(
            key,
            handler: handler,
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
        in category: ConfigsCategory,
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
        in category: ConfigsCategory,
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
        handler: ConfigsHandler,
        default defaultValue: @escaping @autoclosure () -> Value,
        cacheDefaultValue: Bool = false,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) where T: Codable, T? == Value {
        self.init(
            key,
            handler: handler,
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

