import Foundation

/// Handles encoding and decoding of configuration values to/from strings
public struct ConfigTransformer<Value> {
	/// Decodes a string to the value type
	public let decode: (String) -> Value?
	/// Encodes a value to a string
	public let encode: (Value) -> String?
	
	/// Creates a transformer with custom encode/decode functions
	public init(decode: @escaping (String) -> Value?, encode: @escaping (Value) -> String?) {
		self.decode = decode
		self.encode = encode
	}
}

extension ConfigTransformer {

	/// Creates a transformer for optional values by wrapping another transformer
	public static func optional<T>(_ wrapped: ConfigTransformer<T>) -> ConfigTransformer where T? == Value {
		ConfigTransformer {
			wrapped.decode($0)
		} encode: { value in
			value.flatMap(wrapped.encode)
		}
	}
}

extension ConfigTransformer where Value: LosslessStringConvertible {
	
	/// Creates a transformer for LosslessStringConvertible types
	public init() {
		self.init(
			decode: Value.init,
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
			decode: { Value.RawValue($0).flatMap { Value(rawValue: $0) } },
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
			decode: { $0.data(using: .utf8).flatMap { try? decoder.decode(Value.self, from: $0) } },
			encode: { try? String(data: encoder.encode($0), encoding: .utf8) }
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
