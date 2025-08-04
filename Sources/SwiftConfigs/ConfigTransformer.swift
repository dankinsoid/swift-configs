import Foundation

public struct ConfigTransformer<Value> {
	
	public let decode: (String) -> Value?
	public let encode: (Value) -> String?
	
	public init(decode: @escaping (String) -> Value?, encode: @escaping (Value) -> String?) {
		self.decode = decode
		self.encode = encode
	}
}

extension ConfigTransformer where Value: LosslessStringConvertible {
	
	public init() {
		self.init(
			decode: Value.init,
			encode: \.description
		)
	}
	
	public static var stringConvertable: ConfigTransformer {
		ConfigTransformer()
	}
}

extension ConfigTransformer where Value: RawRepresentable, Value.RawValue: LosslessStringConvertible {

	public init() {
		self.init(
			decode: { Value.RawValue($0).flatMap { Value(rawValue: $0) } },
			encode: \.rawValue.description
		)
	}

	public static var rawRepresentable: ConfigTransformer {
		ConfigTransformer()
	}
}

extension ConfigTransformer where Value: Codable {

	public init(
		decoder: JSONDecoder = JSONDecoder(),
		encoder: JSONEncoder = JSONEncoder()
	) {
		self.init(
			decode: { $0.data(using: .utf8).flatMap { try? decoder.decode(Value.self, from: $0) } },
			encode: { try? String(data: encoder.encode($0), encoding: .utf8) }
		)
	}

	public static var json: ConfigTransformer {
		ConfigTransformer()
	}
	
	public static func json(
		decoder: JSONDecoder = JSONDecoder(),
		encoder: JSONEncoder = JSONEncoder()
	) -> ConfigTransformer {
		ConfigTransformer(decoder: decoder, encoder: encoder)
	}
}
