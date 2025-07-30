import Foundation

/// A ConfigsHandler implementation backed by environment variables
public final class EnvironmentVariableConfigsHandler: ConfigsHandler {
    private let processInfo: ProcessInfo
    private var observers: [UUID: () -> Void] = [:]
    private let lock = ReadWriteLock()
    
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
        let id = UUID()
        lock.withWriterLockVoid {
            observers[id] = listener
        }
        
        return ConfigsCancellation { [weak self] in
            self?.lock.withWriterLockVoid {
                self?.observers.removeValue(forKey: id)
            }
        }
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
	public static var environment: EnvironmentVariableConfigsHandler {
		EnvironmentVariableConfigsHandler()
	}
}

#if compiler(>=5.6)
    extension EnvironmentVariableConfigsHandler: @unchecked Sendable {}
#endif
