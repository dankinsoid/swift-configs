import Foundation

/// Represents a configuration category for organizing configuration keys
public struct ConfigCategory: Hashable, CustomStringConvertible {

	private let uuid = UUID()
	/// The human-readable name of the category
	public let name: String

	/// Creates a new configuration category
	public init(_ name: String) {
		self.name = name
    }
    
    public var description: String {
        name
    }

    /// Default configuration category using UserDefaults
    public static let `default` = ConfigCategory("Default")
    /// Secure configuration category using Keychain
    public static let secure = ConfigCategory("Secure")
    /// Critical security configuration category for maximum protection
    public static let critical = ConfigCategory("Critical")
    /// Remote configuration category for server-based configs
    public static let remote = ConfigCategory("Remote")
    /// Synced secure configuration category using iCloud Keychain
	public static let syncedSecure = ConfigCategory("Synced Secure")
    /// General synced configuration category
	public static let synced = ConfigCategory("Synced")
    /// Environment variables configuration category
	public static let environment = ConfigCategory("Environment")
    /// In-memory configuration category for testing
	public static let inMemory = ConfigCategory("In Memory")
    /// Static app metadata from Info.plist or other bundled manifests
    public static let manifest = ConfigCategory("Manifest")
}

#if compiler(>=5.6)
    extension ConfigCategory: Sendable {}
#endif
