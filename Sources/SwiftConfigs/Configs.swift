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
		if let value = handler.value(for: key.name, in: key.readCategory), let decoded = (value as? Key.Value) ?? key.decode(value.description) {
			return decoded
		}
		let result = key.defaultValue()
		if key.cacheDefaultValue, let value = key.encode(result) {
			try? handler.writeValue(value, for: key.name, in: key.writeCategory)
		}
		return result
	}

	public func set<Key: WritableConfigKey>(_ key: Key, _ newValue: Key.Value) {
		if let value = key.encode(newValue) {
			try? handler.writeValue(value, for: key.name, in: key.writeCategory)
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
		try handler.writeValue(nil, for: key.name, in: key.writeCategory)
	}

	public func exists<Key: ConfigKey>(_ keyPath: KeyPath<Configs.Keys, Key>) -> Bool {
		let key = Keys()[keyPath: keyPath]
		return exists(key)
	}

	public func exists<Key: ConfigKey>(_ key: Key) -> Bool {
		if let overwrittenValue = values[key.name] {
			return overwrittenValue is Key.Value
		}
		if let value = handler.value(for: key.name, in: key.readCategory) {
			return key.decode(value.description) != nil
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

	public struct Keys {
		public init() {}

		public struct Key<Value>: ConfigKey {
			public let name: String
			public let cacheDefaultValue: Bool
			public let readCategory: ConfigsCategory?
			public let writeCategory: ConfigsCategory
			public let defaultValue: () -> Value
			public let decode: (String) -> Value?
			public let encode: (Value) -> String?

			public init(
				_ key: String,
				from readCategory: ConfigsCategory? = nil,
				to writeCategory: ConfigsCategory = .default,
				decode: @escaping (String) -> Value?,
				encode: @escaping (Value) -> String?,
				default defaultValue: @escaping @autoclosure () -> Value,
				cacheDefaultValue: Bool = false
			) {
				name = key
				self.readCategory = readCategory
				self.writeCategory = writeCategory
				self.decode = decode
				self.encode = encode
				self.defaultValue = defaultValue
				self.cacheDefaultValue = cacheDefaultValue
			}

			public init(
				_ key: String,
				in category: ConfigsCategory,
				decode: @escaping (String) -> Value?,
				encode: @escaping (Value) -> String?,
				default defaultValue: @escaping @autoclosure () -> Value,
				cacheDefaultValue: Bool = false
			) {
				self.init(
					key,
					from: category,
					to: category,
					decode: decode,
					encode: encode,
					default: defaultValue(),
					cacheDefaultValue: cacheDefaultValue
				)
			}
		}

		public struct WritableKey<Value>: WritableConfigKey {
			public let name: String
			public let cacheDefaultValue: Bool
			public let readCategory: ConfigsCategory?
			public let writeCategory: ConfigsCategory
			public let defaultValue: () -> Value
			public let decode: (String) -> Value?
			public let encode: (Value) -> String?

			public init(
				_ key: String,
				from readCategory: ConfigsCategory? = nil,
				to writeCategory: ConfigsCategory = .default,
				decode: @escaping (String) -> Value?,
				encode: @escaping (Value) -> String?,
				default defaultValue: @escaping @autoclosure () -> Value,
				cacheDefaultValue: Bool = false
			) {
				name = key
				self.readCategory = readCategory
				self.writeCategory = writeCategory
				self.decode = decode
				self.encode = encode
				self.defaultValue = defaultValue
				self.cacheDefaultValue = cacheDefaultValue
			}

			public init(
				_ key: String,
				in category: ConfigsCategory,
				decode: @escaping (String) -> Value?,
				encode: @escaping (Value) -> String?,
				default defaultValue: @escaping @autoclosure () -> Value,
				cacheDefaultValue: Bool = false
			) {
				self.init(
					key,
					from: category,
					to: category,
					decode: decode,
					encode: encode,
					default: defaultValue(),
					cacheDefaultValue: cacheDefaultValue
				)
			}
		}
	}
}

public protocol ConfigKey<Value> {
	associatedtype Value
	var name: String { get }
	var cacheDefaultValue: Bool { get }
	var readCategory: ConfigsCategory? { get }
	var writeCategory: ConfigsCategory { get }
	var encode: (Value) -> String? { get }
	var defaultValue: () -> Value { get }
	var decode: (String) -> Value? { get }
}

public protocol WritableConfigKey<Value>: ConfigKey {}

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

public extension Configs.Keys.Key where Value: LosslessStringConvertible {
	/// Returns the key instance.
	///
	/// - Parameters:
	///   - key: The key string.
	///   - default: The default value to use if the key is not found.
	init(
		_ key: String,
		from readCategory: ConfigsCategory? = nil,
		to writeCategory: ConfigsCategory = .default,
		default defaultValue: @escaping @autoclosure () -> Value,
		cacheDefaultValue: Bool = false
	) {
		self.init(
			key,
			from: readCategory,
			to: writeCategory,
			decode: Value.init,
			encode: \.description,
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
	) {
		self.init(key, from: category, to: category, default: defaultValue(), cacheDefaultValue: cacheDefaultValue)
	}
}

public extension Configs.Keys.Key where Value: RawRepresentable, Value.RawValue: LosslessStringConvertible {
	/// Returns the key instance.
	///
	/// - Parameters:
	///   - key: The key string.
	///   - default: The default value to use if the key is not found.
	init(
		_ key: String,
		from readCategory: ConfigsCategory? = nil,
		to writeCategory: ConfigsCategory = .default,
		default defaultValue: @escaping @autoclosure () -> Value,
		cacheDefaultValue: Bool = false
	) {
		self.init(
			key,
			from: readCategory,
			to: writeCategory,
			decode: { Value.RawValue($0).flatMap { Value(rawValue: $0) } },
			encode: \.rawValue.description,
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
	) {
		self.init(
			key,
			from: category,
			to: category,
			default: defaultValue(),
			cacheDefaultValue: cacheDefaultValue
		)
	}
}

public extension Configs.Keys.WritableKey where Value: LosslessStringConvertible {
	/// Returns the key instance.
	///
	/// - Parameters:
	///   - key: The key string.
	///   - default: The default value to use if the key is not found.
	init(
		_ key: String,
		from readCategory: ConfigsCategory? = nil,
		to writeCategory: ConfigsCategory = .default,
		default defaultValue: @escaping @autoclosure () -> Value,
		cacheDefaultValue: Bool = false
	) {
		self.init(
			key,
			from: readCategory,
			to: writeCategory,
			decode: Value.init,
			encode: \.description,
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
	) {
		self.init(key, from: category, to: category, default: defaultValue(), cacheDefaultValue: cacheDefaultValue)
	}
}

public extension Configs.Keys.WritableKey where Value: RawRepresentable, Value.RawValue: LosslessStringConvertible {
	/// Returns the key instance.
	///
	/// - Parameters:
	///   - key: The key string.
	///   - default: The default value to use if the key is not found.
	init(
		_ key: String,
		from readCategory: ConfigsCategory? = nil,
		to writeCategory: ConfigsCategory = .default,
		default defaultValue: @escaping @autoclosure () -> Value,
		cacheDefaultValue: Bool = false
	) {
		self.init(
			key,
			from: readCategory,
			to: writeCategory,
			decode: { Value.RawValue($0).flatMap { Value(rawValue: $0) } },
			encode: \.rawValue.description,
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
	) {
		self.init(
			key,
			from: category,
			to: category,
			default: defaultValue(),
			cacheDefaultValue: cacheDefaultValue
		)
	}
}

public extension Configs.Keys.Key where Value: Codable {
	/// Returns the key instance.
	///
	/// - Parameters:
	///   - key: The key string.
	///   - default: The default value to use if the key is not found.
	///   - decoder: The JSON decoder to use for decoding the value.
	@_disfavoredOverload
	init(
		_ key: String,
		from readCategory: ConfigsCategory? = nil,
		to writeCategory: ConfigsCategory = .default,
		default defaultValue: @escaping @autoclosure () -> Value,
		cacheDefaultValue: Bool = false,
		decoder: JSONDecoder = JSONDecoder(),
		encoder: JSONEncoder = JSONEncoder()
	) {
		self.init(
			key,
			from: readCategory,
			to: writeCategory,
			decode: { $0.data(using: .utf8).flatMap { try? decoder.decode(Value.self, from: $0) } },
			encode: { try? String(data: encoder.encode($0), encoding: .utf8) },
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
		decoder _: JSONDecoder = JSONDecoder(),
		encoder _: JSONEncoder = JSONEncoder()
	) {
		self.init(
			key,
			from: category,
			to: category,
			default: defaultValue(),
			cacheDefaultValue: cacheDefaultValue
		)
	}
}

public extension Configs.Keys.WritableKey where Value: Codable {
	/// Returns the key instance.
	///
	/// - Parameters:
	///   - key: The key string.
	///   - default: The default value to use if the key is not found.
	///   - decoder: The JSON decoder to use for decoding the value.
	@_disfavoredOverload
	init(
		_ key: String,
		from readCategory: ConfigsCategory? = nil,
		to writeCategory: ConfigsCategory = .default,
		default defaultValue: @escaping @autoclosure () -> Value,
		cacheDefaultValue: Bool = false,
		decoder: JSONDecoder = JSONDecoder(),
		encoder: JSONEncoder = JSONEncoder()
	) {
		self.init(
			key,
			from: readCategory,
			to: writeCategory,
			decode: { $0.data(using: .utf8).flatMap { try? decoder.decode(Value.self, from: $0) } },
			encode: { try? String(data: encoder.encode($0), encoding: .utf8) },
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
	) {
		self.init(
			key,
			from: category,
			to: category,
			default: defaultValue(),
			cacheDefaultValue: cacheDefaultValue,
			decoder: decoder,
			encoder: encoder
		)
	}
}

#if compiler(>=5.6)
	extension Configs: @unchecked Sendable {}
	extension Configs.Keys: Sendable {}
	extension Configs.Keys.Key: @unchecked Sendable {}
	extension Configs.Keys.WritableKey: @unchecked Sendable {}
#endif
