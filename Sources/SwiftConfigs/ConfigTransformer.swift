import Foundation

/// Handles encoding and decoding of configuration values to/from strings
public struct ConfigTransformer<Value> {
	/// Decodes a string to the value type
	public let decode: (String) throws -> Value
	/// Encodes a value to a string
    public let encode: (Value) throws -> String?
	
	/// Creates a transformer with custom encode/decode functions
	public init(decode: @escaping (String) throws -> Value, encode: @escaping (Value) throws -> String?) {
		self.decode = decode
		self.encode = encode
	}
}

extension ConfigTransformer {

	/// Creates a transformer for optional values by wrapping another transformer
    public static func optional<T>(_ wrapped: ConfigTransformer<T>) -> ConfigTransformer where T? == Value {
		ConfigTransformer {
			try wrapped.decode($0)
		} encode: { value in
            guard let value else {
                return nil
            }
            return try wrapped.encode(value)
		}
	}
}

extension ConfigTransformer where Value: LosslessStringConvertible {
	
	/// Creates a transformer for LosslessStringConvertible types
	public init() {
		self.init(
            decode: {
                guard let value = Value($0) else {
                    throw InvalidString(string: $0, type: Value.self)
                }
                return value
            },
			encode: \.description
		)
	}
	
	/// A transformer for LosslessStringConvertible types
	public static var stringConvertable: ConfigTransformer {
		ConfigTransformer()
	}
}

extension ConfigTransformer where Value: RawRepresentable, Value.RawValue: LosslessStringConvertible {

	/// Creates a transformer for RawRepresentable types
	public init() {
		self.init(
			decode: {
                guard let rawValue = Value.RawValue($0) else {
                    throw InvalidString(string: $0, type: Value.RawValue.self)
                }
                guard let value = Value(rawValue: rawValue) else {
                    throw InvalidString(string: $0, type: Value.self)
                }
                return value
            },
			encode: \.rawValue.description
		)
	}

	/// A transformer for RawRepresentable types
	public static var rawRepresentable: ConfigTransformer {
		ConfigTransformer()
	}
}

extension ConfigTransformer where Value: Codable {

	/// Creates a JSON transformer with custom encoder/decoder
	public init(
		decoder: JSONDecoder = JSONDecoder(),
		encoder: JSONEncoder = JSONEncoder()
	) {
		self.init(
            decode: {
                guard let data = $0.data(using: .utf8) else {
                    throw InvalidString(string: $0, type: Data.self)
                }
                return try decoder.decode(Value.self, from: data)
            },
            encode: {
                guard let string = try String(data: encoder.encode($0), encoding: .utf8) else {
                    throw InvalidString(string: "\($0)", type: String.self)
                }
                return string
            }
		)
	}

	/// A JSON transformer using default encoder/decoder
	public static var json: ConfigTransformer {
		ConfigTransformer()
	}
	
	/// Creates a JSON transformer with custom encoder/decoder
	public static func json(
		decoder: JSONDecoder = JSONDecoder(),
		encoder: JSONEncoder = JSONEncoder()
	) -> ConfigTransformer {
		ConfigTransformer(decoder: decoder, encoder: encoder)
	}
}

extension ConfigTransformer where Value == String {

    /// A transformer for String values (no-op)
    public static var string: ConfigTransformer {
        ConfigTransformer(
            decode: { $0 },
            encode: { $0 }
        )
    }
}

private struct InvalidString: LocalizedError {
    
    let string: String
    let type: Any.Type
    var errorDescription: String? {
        "Invalid value: \(string) for type: \(type)"
    }
}
