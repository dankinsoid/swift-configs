import Foundation

/// Represents a configuration category for organizing configuration keys
public struct ConfigsCategory: Hashable, CustomStringConvertible {

	private let uuid = UUID()
	/// The human-readable name of the category
	public let description: String

	/// Creates a new configuration category
	public init(_ name: String) {
		self.description = name
    }

    /// Default configuration category using UserDefaults
    public static let `default` = ConfigsCategory("Default")
    /// Secure configuration category using Keychain
    public static let secure = ConfigsCategory("Secure")
    /// Critical security configuration category for maximum protection
    public static let critical = ConfigsCategory("Critical")
    /// Remote configuration category for server-based configs
    public static let remote = ConfigsCategory("Remote")
    /// Synced secure configuration category using iCloud Keychain
	public static let syncedSecure = ConfigsCategory("Synced Secure")
    /// General synced configuration category
	public static let synced = ConfigsCategory("Synced")
    /// Environment variables configuration category
	public static let environments = ConfigsCategory("Environments")
    /// In-memory configuration category for testing
	public static let memory = ConfigsCategory("In Memory")
}

#if compiler(>=5.6)
    extension ConfigsCategory: Sendable {}
#endif
