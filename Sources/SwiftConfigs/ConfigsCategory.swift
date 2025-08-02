import Foundation

public struct ConfigsCategory: Hashable {

	private let id = UUID()

    public init() {
    }

    public static let `default` = ConfigsCategory()
    public static let secure = ConfigsCategory()
    public static let remote = ConfigsCategory()
	public static let secureRemote = ConfigsCategory()
	public static let environment = ConfigsCategory()
	public static let memory = ConfigsCategory()
}

#if compiler(>=5.6)
    extension ConfigsCategory: Sendable {}
#endif
