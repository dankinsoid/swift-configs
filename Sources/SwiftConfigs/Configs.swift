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
		get {
			get(keyPath)
		}
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
		let key = Keys()[keyPath: keyPath]
		if let overwrittenValue = values[key.name] as? Key.Value {
			return overwrittenValue
		}
		if let value = handler.value(for: key.name, in: key.readCategory), let decoded = (value as? Key.Value) ?? key.decode(value.description) {
			return decoded
		}
		let result = key.defaultValue()
		if let writable = key as? Keys.WritableKey<Key.Value>, writable.cacheDefaultValue, let value = writable.encode(result) {
			try? handler.writeValue(value, for: key.name, in: writable.writeCategory)
		}
		return result
	}

	public func set<Key: WritableConfigKey>(_ keyPath: KeyPath<Configs.Keys, Key>, _ newValue: Key.Value) {
		let key = Keys()[keyPath: keyPath]
		if let value = key.encode(newValue) {
			try? handler.writeValue(value, for: key.name, in: key.writeCategory)
		}
	}

	public func remove<Key: WritableConfigKey>(_ keyPath: KeyPath<Configs.Keys, Key>) throws {
		let key = Keys()[keyPath: keyPath]
		try handler.writeValue(nil, for: key.name, in: key.writeCategory)
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
            public let readCategory: ConfigsCategory?
            public let defaultValue: () -> Value
            public let decode: (String) -> Value?

            public init(
                _ key: String,
                from readCategory: ConfigsCategory? = nil,
                decode: @escaping (String) -> Value?,
                default defaultValue: @escaping @autoclosure () -> Value
            ) {
                name = key
                self.readCategory = readCategory
                self.decode = decode
                self.defaultValue = defaultValue
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
				cacheDefaultValue: Bool = true
            ) {
                name = key
                self.readCategory = readCategory
                self.writeCategory = writeCategory
                self.decode = decode
                self.encode = encode
                self.defaultValue = defaultValue
				self.cacheDefaultValue = cacheDefaultValue
            }
        }
    }
}

public protocol ConfigKey<Value> {
    associatedtype Value
    var name: String { get }
    var readCategory: ConfigsCategory? { get }
    var defaultValue: () -> Value { get }
    var decode: (String) -> Value? { get }
}

public protocol WritableConfigKey<Value>: ConfigKey {
    var writeCategory: ConfigsCategory { get }
    var encode: (Value) -> String? { get }
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

public extension Configs.Keys.Key where Value: LosslessStringConvertible {
    /// Returns the key instance.
    ///
    /// - Parameters:
    ///   - key: The key string.
    ///   - default: The default value to use if the key is not found.
    init(
        _ key: String,
		from readCategory: ConfigsCategory? = nil,
        default defaultValue: @escaping @autoclosure () -> Value
    ) {
        self.init(key, from: readCategory, decode: Value.init, default: defaultValue())
    }
}

public extension Configs.Keys.Key where Value: RawRepresentable, Value.RawValue == String {
    /// Returns the key instance.
    ///
    /// - Parameters:
    ///   - key: The key string.
    ///   - default: The default value to use if the key is not found.
    init(
        _ key: String,
		from readCategory: ConfigsCategory? = nil,
        default defaultValue: @escaping @autoclosure () -> Value
    ) {
        self.init(key, from: readCategory, decode: Value.init, default: defaultValue())
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
		cacheDefaultValue: Bool = true
    ) {
		self.init(key, from: readCategory, to: writeCategory, decode: Value.init, encode: \.description, default: defaultValue(), cacheDefaultValue: cacheDefaultValue)
    }
}

public extension Configs.Keys.WritableKey where Value: RawRepresentable, Value.RawValue == String {
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
		cacheDefaultValue: Bool = true
    ) {
		self.init(key, from: readCategory, to: writeCategory, decode: Value.init, encode: \.rawValue, default: defaultValue(), cacheDefaultValue: cacheDefaultValue)
    }
}

public extension Configs.Keys.Key where Value: Decodable {
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
        default defaultValue: @escaping @autoclosure () -> Value,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.init(
            key,
            from: readCategory,
            decode: { $0.data(using: .utf8).flatMap { try? decoder.decode(Value.self, from: $0) } },
            default: defaultValue()
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
		cacheDefaultValue: Bool = true,
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
}

#if compiler(>=5.6)
    extension Configs: @unchecked Sendable {}
    extension Configs.Keys: Sendable {}
    extension Configs.Keys.Key: @unchecked Sendable {}
    extension Configs.Keys.WritableKey: @unchecked Sendable {}
#endif
