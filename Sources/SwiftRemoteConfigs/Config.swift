import Foundation

@propertyWrapper
public struct Config<Key: ConfigKey> {
	public let configs: Configs
	public let key: KeyPath<Configs.Keys, Key>

	public var wrappedValue: Key.Value {
		configs[dynamicMember: key]
	}

	public init(_ key: KeyPath<Configs.Keys, Key>, configs: Configs = Configs()) {
		self.key = key
		self.configs = configs
	}
}

@propertyWrapper
public struct WritableConfig<Key: WritableConfigKey> {
	public let configs: Configs
	public let key: KeyPath<Configs.Keys, Key>

	public var wrappedValue: Key.Value {
		get { configs[dynamicMember: key] }
		nonmutating set {
			configs[dynamicMember: key] = newValue
		}
	}

	public init(_ key: KeyPath<Configs.Keys, Key>, configs: Configs = Configs()) {
		self.key = key
		self.configs = configs
	}
}
