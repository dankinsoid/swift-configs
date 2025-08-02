import Foundation

public struct ConfigsCategory: Hashable, CustomStringConvertible {

	private let uuid = UUID()
	public let description: String

	public init(_ name: String) {
		self.description = name
    }

    public static let `default` = ConfigsCategory("Default")
    public static let secure = ConfigsCategory("Secure")
    public static let remote = ConfigsCategory("Remote")
	public static let syncedSecure = ConfigsCategory("Synced Secure")
	public static let synced = ConfigsCategory("Synced")
	public static let environments = ConfigsCategory("Environments")
	public static let memory = ConfigsCategory("In Memory")
}

#if compiler(>=5.6)
    extension ConfigsCategory: Sendable {}
#endif
