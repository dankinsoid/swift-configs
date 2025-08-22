import Foundation

/// Configuration handler that reads from environment variables
public struct EnvironmentVariableConfigsHandler: ConfigsHandler {

    private let processInfo: ProcessInfo

    /// Creates an environment variable configuration handler
    /// - Parameter processInfo: The ProcessInfo instance to use (defaults to ProcessInfo.processInfo)
    public init(processInfo: ProcessInfo = ProcessInfo.processInfo) {
        self.processInfo = processInfo
    }
    
    // MARK: - ConfigsHandler Implementation
    
    /// Environment variables are always available, no fetching required
    public func fetch(completion: @escaping (Error?) -> Void) {
        completion(nil)
    }
    
    /// Environment variables don't support change notifications
    public func listen(_ listener: @escaping () -> Void) -> ConfigsCancellation? {
        return nil
    }
    
    /// Retrieves an environment variable value
    public func value(for key: String) -> String? {
        processInfo.environment[key]
    }
	
	/// Environment variables are read-only
	public var supportWriting: Bool {
		false
	}
    
    /// Writing to environment variables is not supported
    public func writeValue(_ value: String?, for key: String) throws {
        throw Unsupported()
    }
    
    /// Clearing environment variables is not supported
    public func clear() throws {
        throw Unsupported()
    }
    
    /// Returns all environment variable keys
    public func allKeys() -> Set<String>? {
        Set(processInfo.environment.keys)
    }
}

extension ConfigsHandler where Self == EnvironmentVariableConfigsHandler {

	/// Creates an environment variable configuration handler
	public static var environments: EnvironmentVariableConfigsHandler {
		EnvironmentVariableConfigsHandler()
	}
}
