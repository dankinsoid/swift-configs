#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Foundation

/// Read-only configuration store backed by an app bundle's Info.plist
public final class InfoPlistConfigStore: ConfigStore {

    public let isWritable = false
    /// The bundle whose Info.plist is used as the configuration source
    public let bundle: Bundle
    @Locked private var cache: [String: String] = [:]
    @Locked private var missing: Set<String> = []
    private let encoder = JSONEncoder()

    /// Shared instance for the main app bundle
    public static let main = InfoPlistConfigStore(bundle: .main)

    /// Creates a configuration store for the specified bundle
    /// - Parameter bundle: Bundle to read Info.plist from
    public init(bundle: Bundle) {
        self.bundle = bundle
    }

    /// Retrieves and converts Info.plist values to strings with caching
    public func get(_ key: String) throws -> String? {
        if let cached = cache[key] {
            return cached
        }
        if missing.contains(key) {
            return nil
        }
        guard let value = bundle.object(forInfoDictionaryKey: key) else {
            missing.insert(key)
            return nil
        }
        let result = stringifyPlist(value)
        cache[key] = result
        return result
    }

    public func keys() -> Set<String>? {
        guard let dict = bundle.infoDictionary else {
            return nil
        }
        return Set(dict.keys)
    }

    public func set(_ value: String?, for key: String) throws { throw Unsupported() }
    public func fetch(completion: @escaping ((any Error)?) -> Void) { completion(nil) }
    public func onChange(_ listener: @escaping () -> Void) -> Cancellation { Cancellation {} }
    public func onChangeOfKey(_ key: String, _ listener: @escaping (String?) -> Void) -> Cancellation { Cancellation {} }
    public func removeAll() throws { throw Unsupported() }

    private func stringifyPlist(_ value: Any) -> String {
        if let s = value as? String { return s }
        if let b = value as? Bool { return b ? "true" : "false" }
        if let n = value as? NSNumber { return numberString(n) }
        return jsonString(normalizeForJSON(value))
    }

    private func normalizeForJSON(_ value: Any) -> AnyEncodable {
        if let b = value as? Bool { return AnyEncodable(value: b) } // Bool must be checked before NSNumber
        if let s = value as? String { return AnyEncodable(value: s) }
        if let n = value as? NSNumber {
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return  AnyEncodable(value: n.boolValue) }
            return AnyEncodable(value: CFNumberIsFloatType(n) ? n.doubleValue : n.int64Value)
        }
        if let arr = value as? [Any] {
            return AnyEncodable(value: arr.compactMap { normalizeForJSON($0) })
        }
        if let dict = value as? [String: Any] {
            return AnyEncodable(value: dict.mapValues { normalizeForJSON($0) })
        }
        if let encodable = value as? Encodable { return AnyEncodable(value: encodable) }
        return AnyEncodable(value: "\(value)")
    }
    
    private func numberString(_ n: NSNumber) -> String {
        // избегаем путаницы с Bool (NSNumber(b: true))
        if CFGetTypeID(n) == CFBooleanGetTypeID() { return (n.boolValue ? "true" : "false") }
        // целое vs вещественное
        if CFNumberIsFloatType(n) {
            return String(describing: n.doubleValue)
        } else {
            return String(n.int64Value)
        }
    }

    private func jsonString(_ obj: AnyEncodable) -> String {
        do {
            let data = try encoder.encode(obj)
            if let string = String(data: data, encoding: .utf8) {
                return string
            } else {
                throw Unsupported()
            }
        } catch {
            return "\(obj.value)"
        }
    }
}

private struct AnyEncodable: Encodable, CustomStringConvertible {

    let value: Encodable

    var description: String {
        "\(value)"
    }

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

extension ConfigStore where Self == InfoPlistConfigStore {

    /// Main bundle Info.plist configuration store
    public static var infoPlist: InfoPlistConfigStore {
        .main
    }

    /// Creates an Info.plist configuration store for the specified bundle
    /// - Parameter bundle: The bundle to use (default is main bundle)
    public static func infoPlist(for bundle: Bundle) -> InfoPlistConfigStore {
        InfoPlistConfigStore(bundle: bundle)
    }
}

/// Common Info.plist configuration keys
public extension Configs.Keys {

    /// App bundle identifier (CFBundleIdentifier)
    var bundleIdentifier: Key<String, ReadOnly> {
        Key("CFBundleIdentifier", in: .manifest, default: "unknown.bundle.id")
    }

    /// App bundle display name (CFBundleName)
    var bundleName: Key<String, ReadOnly> {
        Key("CFBundleName", in: .manifest, default: "App")
    }

    /// Executable file name (CFBundleExecutable)
    var executableName: Key<String, ReadOnly> {
        Key("CFBundleExecutable", in: .manifest, default: "")
    }

    /// Build number (CFBundleVersion)
    var buildNumber: Key<String, ReadOnly> {
        Key("CFBundleVersion", in: .manifest, default: "0")
    }

    /// Marketing version string (CFBundleShortVersionString)
    var versionString: Key<String, ReadOnly> {
        Key("CFBundleShortVersionString", in: .manifest, default: "0.0")
    }

    /// Bundle package type (CFBundlePackageType)
    var packageType: Key<String, ReadOnly> {
        Key("CFBundlePackageType", in: .manifest, default: "APPL")
    }

    /// User-visible app name (CFBundleDisplayName)
    var displayName: Key<String?, ReadOnly> {
        Key("CFBundleDisplayName", in: .manifest, default: nil)
    }

    /// Minimum OS version required (MinimumOSVersion)
    var minimumOSVersion: Key<String?, ReadOnly> {
        Key("MinimumOSVersion", in: .manifest, default: nil)
    }

    /// Launch storyboard file name (UILaunchStoryboardName)
    var launchStoryboardName: Key<String?, ReadOnly> {
        Key("UILaunchStoryboardName", in: .manifest, default: nil)
    }

    /// Required device capabilities (UIRequiredDeviceCapabilities)
    var requiredDeviceCapabilities: Key<[String]?, ReadOnly> {
        Key("UIRequiredDeviceCapabilities", in: .manifest, default: nil)
    }

    /// Supported interface orientations for iPhone (UISupportedInterfaceOrientations)
    var supportedInterfaceOrientations: Key<[String]?, ReadOnly> {
        Key("UISupportedInterfaceOrientations", in: .manifest, default: nil)
    }

    /// Supported interface orientations for iPad (UISupportedInterfaceOrientations~ipad)
    var supportedInterfaceOrientationsIpad: Key<[String]?, ReadOnly> {
        Key("UISupportedInterfaceOrientations~ipad", in: .manifest, default: nil)
    }

    /// Main storyboard file name (UIMainStoryboardFile)
    var mainStoryboardFile: Key<String?, ReadOnly> {
        Key("UIMainStoryboardFile", in: .manifest, default: nil)
    }

    /// Application category type (LSApplicationCategoryType)
    var applicationCategory: Key<String?, ReadOnly> {
        Key("LSApplicationCategoryType", in: .manifest, default: nil)
    }
}
#endif
