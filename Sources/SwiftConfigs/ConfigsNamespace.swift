import Foundation

/// Defines the structure and prefix for a configuration namespace
///
/// Types conforming to `ConfigNamespaceKeys` define configuration key collections
/// with an optional prefix that gets applied to all keys within the namespace.
/// This enables hierarchical organization and runtime key prefixing.
///
/// ## Defining Namespaces
///
/// ```swift
/// struct SecurityKeys: ConfigNamespaceKeys {
///     var keyPrefix: String { "security/" }
///     
///     var apiToken: RWConfigKey<String?> {
///         RWConfigKey("api-token", in: .secure, default: nil)
///         // Final key name: "security/api-token"
///     }
/// }
/// 
/// extension Configs.Keys {
///     var security: SecurityKeys { SecurityKeys() }
/// }
/// ```
///
/// ## Prefix Flexibility
///
/// You have complete control over the separator and format:
/// - `"feature/"` - Slash-separated paths
/// - `"module."` - Dot-separated identifiers
/// - `"env_"` - Underscore prefixes
/// - `""` - No prefix (default behavior)
///
/// - Note: Prefixes from nested namespaces are concatenated automatically
public protocol ConfigNamespaceKeys {

    /// The prefix applied to all keys in this namespace
    ///
    /// Define this property to specify how keys in this namespace should be prefixed.
    /// When namespaces are nested, prefixes are concatenated in order.
    ///
    /// ```swift
    /// // Example: "feature/auth." results in keys like "feature/auth.token"
    /// var keyPrefix: String { "feature/auth." }
    /// ```
    ///
    /// - Returns: The prefix string, or empty string for no prefix
    var keyPrefix: String { get }
}

extension ConfigNamespaceKeys {

    /// Default implementation provides no prefix
    ///
    /// Override this property in your namespace types to provide custom prefixing.
    public var keyPrefix: String { "" }
}

/// A configuration namespace that provides hierarchical key organization
///
/// `ConfigNamespace` wraps a `ConfigNamespaceKeys` type and enables hierarchical
/// access to configuration values with automatic key prefixing. Namespaces can be
/// nested to create deep organizational structures.
///
/// ## Usage
///
/// ```swift
/// // Access through nested namespaces
/// let secureToken = configs.security.auth.apiToken
/// 
/// // Equivalent direct access with manual prefixing
/// let directToken = configs.get(apiTokenKey.prefix("security/auth."))
/// 
/// // Set values through namespaces
/// configs.security.auth.apiToken = "new-token"
/// ```
///
/// ## Value Semantics
///
/// Like all `ConfigsType` conforming types, `ConfigNamespace` is a value type.
/// Operations return new instances rather than modifying the existing one.
///
/// - Note: The `keyPrefix` property automatically concatenates the current namespace
///   prefix with any base prefix, enabling seamless nesting.
@dynamicMemberLookup
public struct ConfigNamespace<Keys: ConfigNamespaceKeys>: ConfigsType {

    public let keys: Keys
    public var base: any ConfigsType
    public var configs: Configs {
        get { base.configs }
        set { base.configs = newValue }
    }

    /// The accumulated prefix from all parent namespaces plus this namespace's prefix
    ///
    /// This property automatically concatenates prefixes as you navigate deeper into
    /// the namespace hierarchy, ensuring proper key qualification.
    ///
    /// ```swift
    /// // If base has "app/" and keys has "secure.", keyPrefix returns "app/secure."
    /// ```
    public var keyPrefix: String {
        base.keyPrefix + keys.keyPrefix
    }

    /// Creates a new namespace instance
    ///
    /// - Parameters:
    ///   - keys: The namespace keys that define available configuration options
    ///   - base: The parent configuration context this namespace operates within
    /// - Note: Typically created automatically through dynamic member lookup rather than directly
    public init(
        _ keys: Keys,
        base: any ConfigsType
    ) {
        self.keys = keys
        self.base = base
    }
}
