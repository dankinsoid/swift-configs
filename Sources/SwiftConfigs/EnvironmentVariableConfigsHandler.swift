import Foundation

/// A ConfigsHandler implementation backed by environment variables
public struct EnvironmentVariableConfigsHandler: ConfigsHandler {

    private let processInfo: ProcessInfo

    /// Creates an environment variable configs handler
    /// - Parameter processInfo: The ProcessInfo instance to use (defaults to ProcessInfo.processInfo)
    public init(processInfo: ProcessInfo = ProcessInfo.processInfo) {
        self.processInfo = processInfo
    }
    
    // MARK: - ConfigsHandler Implementation
    
    public func fetch(completion: @escaping (Error?) -> Void) {
        // Environment variables are synchronous and always available
        completion(nil)
    }
    
    public func listen(_ listener: @escaping () -> Void) -> ConfigsCancellation? {
        return nil
    }
    
    public func value(for key: String) -> String? {
        processInfo.environment[key]
    }
    
    public func writeValue(_ value: String?, for key: String) throws {
        throw Unsupported()
    }
    
    public func clear() throws {
        throw Unsupported()
    }
    
    public func allKeys() -> Set<String>? {
        Set(processInfo.environment.keys)
    }
}

extension ConfigsHandler where Self == EnvironmentVariableConfigsHandler {

	/// Creates an environment variable configs handler
	public static var environments: EnvironmentVariableConfigsHandler {
		EnvironmentVariableConfigsHandler()
	}
}
