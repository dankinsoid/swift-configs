import Foundation

public struct ConfigsCategory: RawRepresentable, Hashable, OptionSet, Comparable {
    public var rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static var `default` = ConfigsCategory.all
    public static let all = ConfigsCategory(rawValue: 0xFFFF_FFFF)
    public static let secure = ConfigsCategory(rawValue: 0x0000_0001)
    public static let insecure = ConfigsCategory(rawValue: 0x0000_0002)
    public static let remote = ConfigsCategory(rawValue: 0x0000_0004)

    public static func < (lhs: ConfigsCategory, rhs: ConfigsCategory) -> Bool {
        if lhs.rawValue.nonzeroBitCount == rhs.rawValue.nonzeroBitCount {
            return lhs.rawValue < rhs.rawValue
        } else {
            return lhs.rawValue.nonzeroBitCount < rhs.rawValue.nonzeroBitCount
        }
    }
}

#if compiler(>=5.6)
    extension ConfigsCategory: Sendable {}
#endif
