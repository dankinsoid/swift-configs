import Foundation

public protocol ConfigWrapper<Key> {
	
	associatedtype Key: ConfigKey
	var configs: Configs { get }
	var key: Key { get }
	init(_ key: Key, configs: Configs)
}

public extension ConfigWrapper {
	
	init(_ key: KeyPath<Configs.Keys, Key>, configs: Configs = Configs()) {
		self.init(Configs.Keys()[keyPath: key], configs: Configs())
	}
	
	func exists() -> Bool {
		configs.exists(key)
	}
}

@propertyWrapper
public struct Config<Value>: ConfigWrapper {

	public let configs: Configs
	public let key: Configs.Keys.Key<Value>

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

@propertyWrapper
public struct WritableConfig<Value>: ConfigWrapper {

	public let configs: Configs
	public let key: Configs.Keys.WritableKey<Value>

	public var wrappedValue: Key.Value {
		get { configs.get(key) }
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
	
	public func remove() throws {
		try configs.remove(key)
	}
}

public extension ConfigWrapper where Key.Value: LosslessStringConvertible {

	init(
		_ key: String,
		in category: ConfigsCategory,
		cacheDefaultValue: Bool = false,
		wrappedValue defaultValue: @escaping @autoclosure () -> Key.Value
	) {
		self.init(
			Key(
				key,
				handler: { $0.handler(for: category) },
				as: .stringConvertable,
				default: defaultValue(),
				cacheDefaultValue: false
			),
			configs: Configs()
		)
	}
}

public extension ConfigWrapper where Key.Value: RawRepresentable, Key.Value.RawValue: LosslessStringConvertible {

	init(
		_ key: String,
		in category: ConfigsCategory,
		cacheDefaultValue: Bool = false,
		wrappedValue defaultValue: @escaping @autoclosure () -> Key.Value
	) {
		self.init(
			Key(
				key,
				in: category,
				as: .rawRepresentable,
				default: defaultValue(),
				cacheDefaultValue: false
			),
			configs: Configs()
		)
	}
}

public extension ConfigWrapper where Key.Value: Codable {

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
		cacheDefaultValue: Bool = false,
		decoder: JSONDecoder = JSONDecoder(),
		encoder: JSONEncoder = JSONEncoder(),
		wrappedValue defaultValue: @escaping @autoclosure () -> Key.Value
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
		_ key: String,
		in category: ConfigsCategory,
		cacheDefaultValue: Bool = false,
		wrappedValue defaultValue: @escaping @autoclosure () -> Key.Value = nil
	)  where Key.Value == T? {
		self.init(
			Key(
				key,
				in: category,
				as: .optional(.stringConvertable),
				default: nil,
				cacheDefaultValue: false
			),
			configs: Configs()
		)
	}

	init<T: RawRepresentable>(
		_ key: String,
		in category: ConfigsCategory,
		cacheDefaultValue: Bool = false,
		wrappedValue defaultValue: @escaping @autoclosure () -> Key.Value = nil
	) where T.RawValue: LosslessStringConvertible, Key.Value == T? {
		self.init(
			Key(
				key,
				in: category,
				as: .optional(.rawRepresentable),
				default: defaultValue(),
				cacheDefaultValue: false
			),
			configs: Configs()
		)
	}

	/// Returns the key instance.
	///
	/// - Parameters:
	///   - key: The key string.
	///   - default: The default value to use if the key is not found.
	///   - decoder: The JSON decoder to use for decoding the value.
	@_disfavoredOverload
	init<T: Codable>(
		_ key: String,
		in category: ConfigsCategory,
		cacheDefaultValue: Bool = false,
		decoder: JSONDecoder = JSONDecoder(),
		encoder: JSONEncoder = JSONEncoder(),
		wrappedValue defaultValue: @escaping @autoclosure () -> Key.Value = nil
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
extension Config: Sendable where Value: Sendable {}
extension WritableConfig: Sendable where Value: Sendable {}
#endif
