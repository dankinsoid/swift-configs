import Foundation

/// Defines a collection of configuration keys for compile-time organization
///
/// Types conforming to `ConfigNamespaceKeys` group related configuration keys together,
/// providing compile-time structure and type safety. The primary purpose is organizational -
/// keeping related keys grouped in logical collections.
///
/// ## Defining Namespaces
///
/// ```swift
/// extension Configs.Keys {
///     var security: Security { Security() }
///     
///     struct Security: ConfigNamespaceKeys {
///         var apiToken: RWConfigKey<String?> {
///             key("api-token", in: .secure)
///         }
///         
///         var encryptionEnabled: ROConfigKey<Bool> {
///             key("encryption-enabled", in: .secure, default: true)
///         }
///     }
/// }
/// ```
///
/// ## Key Prefixing (Optional)
///
/// Optionally, you can add key prefixing by implementing `keyPrefix`:
///
/// ```swift
/// struct Security: ConfigNamespaceKeys {
///     var keyPrefix: String { "security/" }  // All keys get this prefix
///     // ...
/// }
/// ```
///
/// The default `keyPrefix` is empty, emphasizing that organization is the main benefit.
public protocol ConfigNamespaceKeys {

    /// Optional prefix applied to all keys in this namespace
    ///
    /// Most namespaces don't need prefixes - they're primarily for compile-time organization.
    /// Override this property only when you need key prefixing.
    ///
    /// ```swift
    /// var keyPrefix: String { "feature/" }  // Optional key prefixing
    /// ```
    ///
    /// - Returns: The prefix string, or empty string (default) for no prefix
    var keyPrefix: String { get }
}

extension ConfigNamespaceKeys {

    /// Default implementation provides no prefix - namespaces are primarily for organization
    ///
    /// Override this property only when runtime key prefixing is needed.
    public var keyPrefix: String { "" }
}

/// A configuration namespace that provides compile-time key organization
///
/// `ConfigNamespace` wraps a `ConfigNamespaceKeys` type to enable hierarchical
/// access to logically grouped configuration keys. The main benefit is compile-time
/// organization and type safety.
///
/// ## Usage
///
/// ```swift
/// // Access through organized namespaces
/// let secureToken = configs.security.apiToken
/// let authEnabled = configs.security.authEnabled
/// 
/// // Set values through namespaces
/// configs.security.apiToken = "new-token"
/// ```
///
/// ## Value Semantics
///
/// Like all `ConfigsType` conforming types, `ConfigNamespace` is a value type.
/// Operations return new instances rather than modifying the existing one.
///
/// - Note: The `keyPrefix` property automatically concatenates prefixes from nested
///   namespaces when they are non-empty.
@dynamicMemberLookup
public struct ConfigNamespace<Keys: ConfigNamespaceKeys>: ConfigsType {

    public let keys: Keys
    public var base: any ConfigsType
    public var configs: Configs {
        get { base.configs }
        set { base.configs = newValue }
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
