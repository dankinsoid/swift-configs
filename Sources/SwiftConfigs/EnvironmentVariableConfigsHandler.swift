import Foundation

/// Configuration store that reads values from environment variables
///
/// This store provides read-only access to environment variables set in the process.
/// It's commonly used for application configuration that varies by deployment environment.
///
/// ## Usage Example
///
/// ```swift
/// // Using with specific environment variables
/// extension Configs.Keys {
///     static let apiBaseURL = RWConfigKey("API_BASE_URL", in: .environment, default: "https://api.example.com")
///     static let debugEnabled = RWConfigKey("DEBUG_ENABLED", in: .environment, default: false)
/// }
/// ```
///
/// ## Characteristics
///
/// - **Read-Only**: Environment variables cannot be modified at runtime
/// - **No Change Notifications**: Environment variables are static during process lifetime  
/// - **Platform Agnostic**: Works on all platforms that support environment variables
/// - **Case Sensitive**: Environment variable names are case-sensitive on most platforms
public struct EnvironmentVariableConfigStore: ConfigStore {

    private let processInfo: ProcessInfo

    /// Creates an environment variable configuration store
    ///
    /// - Parameter processInfo: The ProcessInfo instance to use for reading environment variables
    /// - Note: Use the default parameter unless you need to inject a different ProcessInfo for testing
    public init(processInfo: ProcessInfo = ProcessInfo.processInfo) {
        self.processInfo = processInfo
    }
    
    // MARK: - ConfigStore Implementation
    
    public func fetch(completion: @escaping (Error?) -> Void) {
        completion(nil)
    }
    
    public func onChange(_ listener: @escaping () -> Void) -> Cancellation {
        Cancellation {}
    }

    public func onChangeOfKey(_ key: String, _ listener: @escaping (String?) -> Void) -> Cancellation {
        Cancellation {}
    }
    
    public func get(_ key: String) -> String? {
        processInfo.environment[key]
    }
    
    public func exists(_ key: String) throws -> Bool {
        processInfo.environment[key] != nil
    }
	
	public var isWritable: Bool {
		false
	}
    
    public func set(_ value: String?, for key: String) throws {
        throw Unsupported()
    }
    
    public func removeAll() throws {
        throw Unsupported()
    }
    
    public func keys() -> Set<String>? {
        Set(processInfo.environment.keys)
    }
}

extension ConfigStore where Self == EnvironmentVariableConfigStore {

	/// Shared environment variable configuration store
	public static var environment: EnvironmentVariableConfigStore {
		EnvironmentVariableConfigStore()
	}
}
