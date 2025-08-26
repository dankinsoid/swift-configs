import Foundation

/// Configuration store that reads from environment variables
public struct EnvironmentVariableConfigStore: ConfigStore {

    private let processInfo: ProcessInfo

    /// Creates an environment variable configuration store
    /// - Parameter processInfo: The ProcessInfo instance to use (defaults to ProcessInfo.processInfo)
    public init(processInfo: ProcessInfo = ProcessInfo.processInfo) {
        self.processInfo = processInfo
    }
    
    // MARK: - ConfigStore Implementation
    
    /// Environment variables are always available, no fetching required
    public func fetch(completion: @escaping (Error?) -> Void) {
        completion(nil)
    }
    
    /// Environment variables don't support change notifications
    public func onChange(_ listener: @escaping () -> Void) -> Cancellation? {
        nil
    }
    
    public func onChangeOfKey(_ key: String, _ listener: @escaping (String?) -> Void) -> Cancellation? {
        nil
    }
    
    /// Retrieves an environment variable value
    public func get(_ key: String) -> String? {
        processInfo.environment[key]
    }
    
    public func exists(_ key: String) throws -> Bool {
        processInfo.environment[key] != nil
    }
	
	/// Environment variables are read-only
	public var isWritable: Bool {
		false
	}
    
    /// Writing to environment variables is not supported
    public func set(_ value: String?, for key: String) throws {
        throw Unsupported()
    }
    
    /// Clearing environment variables is not supported
    public func removeAll() throws {
        throw Unsupported()
    }
    
    /// Returns all environment variable keys
    public func keys() -> Set<String>? {
        Set(processInfo.environment.keys)
    }
}

extension ConfigStore where Self == EnvironmentVariableConfigStore {

	/// Creates an environment variable configuration store
	public static var environments: EnvironmentVariableConfigStore {
		EnvironmentVariableConfigStore()
	}
}
