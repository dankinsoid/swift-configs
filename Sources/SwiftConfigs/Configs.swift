import Foundation

@available(*, deprecated, renamed: "Configs")
public typealias RemoteConfigs = Configs

/// A structure for handling configs and reading them from a configs provider.
@dynamicMemberLookup
public struct Configs {
	/// The configs handler responsible for querying and storing values.
	public let handler: ConfigsSystem.Handler
	private var values: [String: Any] = [:]

	/// Initializes the `Configs` instance with the default configs handler.
	public init() {
		self.handler = ConfigsSystem.handler
	}

	public subscript<Key: ConfigKey>(dynamicMember keyPath: KeyPath<Configs.Keys, Key>) -> Key.Value {
		self.get(keyPath)
	}

	public subscript<Key: WritableConfigKey>(dynamicMember keyPath: KeyPath<Configs.Keys, Key>) -> Key.Value {
		get {
			get(keyPath)
		}
		nonmutating set {
			set(keyPath, newValue)
		}
	}

	public func get<Key: ConfigKey>(_ keyPath: KeyPath<Configs.Keys, Key>) -> Key.Value {
		get(Keys()[keyPath: keyPath])
	}

	public func get<Key: ConfigKey>(_ key: Key) -> Key.Value {
		if let overwrittenValue = values[key.name] as? Key.Value {
			return overwrittenValue
		}
		if let value = key.handler(handler).value(for: key.name), let decoded = (value as? Key.Value) ?? key.transformer.decode(value.description) {
			return decoded
		}
		let result = key.defaultValue()
		if key.cacheDefaultValue, let value = key.transformer.encode(result) {
			try? key.handler(handler).writeValue(value, for: key.name)
		}
		return result
	}

	public func set<Key: WritableConfigKey>(_ key: Key, _ newValue: Key.Value) {
		if let value = key.transformer.encode(newValue) {
			try? key.handler(handler).writeValue(value, for: key.name)
		}
	}

	public func set<Key: WritableConfigKey>(_ keyPath: KeyPath<Configs.Keys, Key>, _ newValue: Key.Value) {
		let key = Keys()[keyPath: keyPath]
		set(key, newValue)
	}

	public func remove<Key: WritableConfigKey>(_ keyPath: KeyPath<Configs.Keys, Key>) throws {
		let key = Keys()[keyPath: keyPath]
		try remove(key)
	}

	public func remove<Key: WritableConfigKey>(_ key: Key) throws {
		try key.handler(handler).writeValue(nil, for: key.name)
	}

	public func exists<Key: ConfigKey>(_ keyPath: KeyPath<Configs.Keys, Key>) -> Bool {
		let key = Keys()[keyPath: keyPath]
		return exists(key)
	}

	public func exists<Key: ConfigKey>(_ key: Key) -> Bool {
		if let overwrittenValue = values[key.name] {
			return overwrittenValue is Key.Value
		}
		if let value = key.handler(handler).value(for: key.name) {
			return key.transformer.decode(value.description) != nil
		}
		return false
	}

	public var didFetch: Bool { handler.didFetch }

	@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
	public func fetch() async throws {
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			handler.fetch { error in
				if let error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume(returning: ())
				}
			}
		}
	}

	@discardableResult
	public func listen(_ listener: @escaping (Configs) -> Void) -> ConfigsCancellation {
		handler.listen {
			listener(self)
		}
	}
}

public extension Configs {

	/// Overwrites the value of a key.
	/// - Parameters:
	///   - key: The key to overwrite.
	///   - value: The value to set.
	func with<T: ConfigKey>(_ key: KeyPath<Configs.Keys, T>, _ value: T.Value?) -> Self {
		var copy = self
		copy.values[Keys()[keyPath: key].name] = value
		return copy
	}

	@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
	func fetchIfNeeded() async throws {
		guard !didFetch else { return }
		try await fetch()
	}

	@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
	func fetchIfNeeded<T: ConfigKey>(_ keyPath: KeyPath<Configs.Keys, T>) async throws -> T.Value {
		try await fetchIfNeeded()
		return self[dynamicMember: keyPath]
	}

	@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
	func fetch<T: ConfigKey>(_ keyPath: KeyPath<Configs.Keys, T>) async throws -> T.Value {
		try await fetch()
		return self[dynamicMember: keyPath]
	}

	@discardableResult
	func listen<T: ConfigKey>(_ keyPath: KeyPath<Configs.Keys, T>, _ observer: @escaping (T.Value) -> Void) -> ConfigsCancellation {
		listen {
			observer($0[dynamicMember: keyPath])
		}
	}
}

public protocol ConfigKey<Value> {

	associatedtype Value
	var name: String { get }
	var cacheDefaultValue: Bool { get }
	var handler: (ConfigsSystem.Handler) -> ConfigsHandler { get }
	var transformer: ConfigTransformer<Value> { get }
	var defaultValue: () -> Value { get }

	init(
		_ key: String,
		handler: @escaping (ConfigsSystem.Handler) -> ConfigsHandler,
		as transformer: ConfigTransformer<Value>,
		default defaultValue: @escaping @autoclosure () -> Value,
		cacheDefaultValue: Bool
	)
}

public protocol WritableConfigKey<Value>: ConfigKey {}

extension Configs {

	public struct Keys {

		public init() {}

		public struct Key<Value>: ConfigKey {
			public let name: String
			public let cacheDefaultValue: Bool
			public let handler: (ConfigsSystem.Handler) -> ConfigsHandler
			public let defaultValue: () -> Value
			public let transformer: ConfigTransformer<Value>
			
			public init(
				_ key: String,
				handler: @escaping (ConfigsSystem.Handler) -> ConfigsHandler,
				as transformer: ConfigTransformer<Value>,
				default defaultValue: @escaping @autoclosure () -> Value,
				cacheDefaultValue: Bool = false
			) {
				name = key
				self.handler = handler
				self.transformer = transformer
				self.defaultValue = defaultValue
				self.cacheDefaultValue = cacheDefaultValue
			}
		}

		public struct WritableKey<Value>: WritableConfigKey {
			public let name: String
			public let cacheDefaultValue: Bool
			public let handler: (ConfigsSystem.Handler) -> ConfigsHandler
			public let defaultValue: () -> Value
			public let transformer: ConfigTransformer<Value>
			
			public init(
				_ key: String,
				handler: @escaping (ConfigsSystem.Handler) -> ConfigsHandler,
				as transformer: ConfigTransformer<Value>,
				default defaultValue: @escaping @autoclosure () -> Value,
				cacheDefaultValue: Bool = false
			) {
				name = key
				self.handler = handler
				self.transformer = transformer
				self.defaultValue = defaultValue
				self.cacheDefaultValue = cacheDefaultValue
			}
		}
	}
}

public extension ConfigKey {

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
			cacheDefaultValue: false
		)
	}

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
			cacheDefaultValue: false
		)
	}
}

public extension ConfigKey {

	/// Returns the key instance.
	///
	/// - Parameters:
	///   - key: The key string.
	///   - default: The default value to use if the key is not found.
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
			cacheDefaultValue: false
		)
	}
	
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
			cacheDefaultValue: false
		)
	}

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
			cacheDefaultValue: false
		)
	}

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
			cacheDefaultValue: false
		)
	}
	
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
			cacheDefaultValue: false
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
	extension Configs: @unchecked Sendable {}
	extension Configs.Keys: Sendable {}
	extension Configs.Keys.Key: @unchecked Sendable {}
	extension Configs.Keys.WritableKey: @unchecked Sendable {}
#endif
