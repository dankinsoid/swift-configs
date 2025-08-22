import Foundation

/// Protocol for configuration property wrappers
public protocol ConfigWrapper<Key> {
    /// The configuration key type
    associatedtype Key: ConfigKey
    /// The configs instance used for operations
	var configs: Configs { get }
    /// The configuration key
	var key: Key { get }
    /// Initializes with a key and configs instance
	init(_ key: Key, configs: Configs)
}

public extension ConfigWrapper {

	/// Initializes with a key path and optional configs instance
	init(_ key: KeyPath<Configs.Keys, Key>, configs: Configs = Configs()) {
		self.init(Configs.Keys()[keyPath: key], configs: Configs())
	}

	/// Checks if the configuration value exists
	func exists() -> Bool {
		configs.exists(key)
	}
}
/// Property wrapper for read-only configuration values
@propertyWrapper
public struct ROConfig<Value>: ConfigWrapper {

    public let configs: Configs
    public let key: Configs.Keys.Key<Value, Configs.Keys.ReadOnly>

    /// The configuration value
    public var wrappedValue: Key.Value {
        configs.get(key)
    }

    public var projectedValue: Self {
        self
    }

    public init(_ key: Key, configs: Configs) {
        self.key = key
        self.configs = configs
    }
}

/// Property wrapper for read-write configuration values
@propertyWrapper
public struct RWConfig<Value>: ConfigWrapper {

    public let configs: Configs
    public let key: Configs.Keys.Key<Value, Configs.Keys.ReadWrite>

    /// The configuration value with getter and setter
    public var wrappedValue: Key.Value {
        get {
            configs.get(key)
        }
        nonmutating set {
            configs.set(key, newValue)
        }
    }

    public var projectedValue: Self {
        self
    }

    public init(_ key: Key, configs: Configs) {
        self.key = key
        self.configs = configs
    }
}

@available(*, deprecated, renamed: "ROConfig")
public typealias Config<Value> = ROConfig<Value>

@available(*, deprecated, renamed: "RWConfig")
public typealias WritableConfig<Value> = RWConfig<Value>

public extension ConfigWrapper where Key.Value: LosslessStringConvertible {

	init(
		wrappedValue defaultValue: @escaping @autoclosure () -> Key.Value,
		_ key: String,
		in category: ConfigsCategory,
		cacheDefaultValue: Bool = false
	) {
		self.init(
			Key(
				key,
				handler: { $0.handler(for: category) },
				as: .stringConvertable,
				default: defaultValue(),
				cacheDefaultValue: cacheDefaultValue
			),
			configs: Configs()
		)
	}
}

public extension ConfigWrapper where Key.Value: RawRepresentable, Key.Value.RawValue: LosslessStringConvertible {

	init(
		wrappedValue defaultValue: @escaping @autoclosure () -> Key.Value,
		_ key: String,
		in category: ConfigsCategory,
		cacheDefaultValue: Bool = false
	) {
		self.init(
			Key(
				key,
				in: category,
				as: .rawRepresentable,
				default: defaultValue(),
				cacheDefaultValue: cacheDefaultValue
			),
			configs: Configs()
		)
	}
}

public extension ConfigWrapper where Key.Value: Codable {

	/// Creates a configuration wrapper for Codable values
	///
	/// - Parameters:
	///   - defaultValue: The default value to use if the key is not found
	///   - key: The key string
	///   - category: The configuration category
	///   - cacheDefaultValue: Whether to cache the default value when first accessed
	///   - decoder: The JSON decoder to use for decoding values
	///   - encoder: The JSON encoder to use for encoding values
	@_disfavoredOverload
	init(
		wrappedValue defaultValue: @escaping @autoclosure () -> Key.Value,
		_ key: String,
		in category: ConfigsCategory,
		cacheDefaultValue: Bool = false,
		decoder: JSONDecoder = JSONDecoder(),
		encoder: JSONEncoder = JSONEncoder()
	) {
		self.init(
			Key(
				key,
				in: category,
				as: .json(decoder: decoder, encoder: encoder),
				default: defaultValue(),
				cacheDefaultValue: cacheDefaultValue
			),
			configs: Configs()
		)
	}
}

public extension ConfigWrapper {

	init<T: LosslessStringConvertible>(
		wrappedValue defaultValue: @escaping @autoclosure () -> Key.Value = nil,
		_ key: String,
		in category: ConfigsCategory,
		cacheDefaultValue: Bool = false
	)  where Key.Value == T? {
		self.init(
			Key(
				key,
				in: category,
				as: .optional(.stringConvertable),
				default: nil,
				cacheDefaultValue: cacheDefaultValue
			),
			configs: Configs()
		)
	}

	init<T: RawRepresentable>(
		wrappedValue defaultValue: @escaping @autoclosure () -> Key.Value = nil,
		_ key: String,
		in category: ConfigsCategory,
		cacheDefaultValue: Bool = false
	) where T.RawValue: LosslessStringConvertible, Key.Value == T? {
		self.init(
			Key(
				key,
				in: category,
				as: .optional(.rawRepresentable),
				default: defaultValue(),
				cacheDefaultValue: cacheDefaultValue
			),
			configs: Configs()
		)
	}

	/// Creates an optional configuration wrapper for Codable values
	///
	/// - Parameters:
	///   - defaultValue: The default value to use if the key is not found
	///   - key: The key string
	///   - category: The configuration category
	///   - cacheDefaultValue: Whether to cache the default value when first accessed
	///   - decoder: The JSON decoder to use for decoding values
	///   - encoder: The JSON encoder to use for encoding values
	@_disfavoredOverload
	init<T: Codable>(
		wrappedValue defaultValue: @escaping @autoclosure () -> Key.Value = nil,
		_ key: String,
		in category: ConfigsCategory,
		cacheDefaultValue: Bool = false,
		decoder: JSONDecoder = JSONDecoder(),
		encoder: JSONEncoder = JSONEncoder()
	) where Key.Value == T? {
		self.init(
			Key(
				key,
				in: category,
				as: .optional(.json(decoder: decoder, encoder: encoder)),
				default: defaultValue(),
				cacheDefaultValue: cacheDefaultValue
			),
			configs: Configs()
		)
	}
}

#if compiler(>=5.6)
extension ROConfig: Sendable where Value: Sendable {}
extension RWConfig: Sendable where Value: Sendable {}
#endif

