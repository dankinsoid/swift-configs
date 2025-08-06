import Foundation

/// A ConfigsHandler that reads from a specified handler first, then falls back to the write handler, but only writes to the write handler
public struct FallbackConfigsHandler: ConfigsHandler {
    public let fallbackHandler: ConfigsHandler
    public let mainHandler: ConfigsHandler

    /// Creates a fallback handler that reads from readHandler first, then writeHandler, but only writes to writeHandler
    /// - Parameters:
    ///   - readHandler: The primary handler to read from
    ///   - writeHandler: The handler to write to and use as fallback for reads
    public init(mainHandler: ConfigsHandler, fallbackHandler: ConfigsHandler) {
        self.mainHandler = mainHandler
        self.fallbackHandler = fallbackHandler
    }

    public func value(for key: String) -> String? {
        // Try the read handler first, then fall back to the write handler
        if let value = mainHandler.value(for: key) {
            return value
        }
        return fallbackHandler.value(for: key)
    }

    public func fetch(completion: @escaping (Error?) -> Void) {
        // Fetch from both handlers
        let multiplexCompletion = FallbackCompletion(count: 2, completion: completion)

		mainHandler.fetch { error in
            multiplexCompletion.call(with: error)
        }

		fallbackHandler.fetch { error in
            multiplexCompletion.call(with: error)
        }
    }

    public func listen(_ listener: @escaping () -> Void) -> ConfigsCancellation? {
        // Listen to both handlers
        let mainCancellation = mainHandler.listen(listener)
        let fallbackCancellation = fallbackHandler.listen(listener)

        let cancellables = [mainCancellation, fallbackCancellation].compactMap { $0 }

        return cancellables.isEmpty ? nil : ConfigsCancellation {
            cancellables.forEach { $0.cancel() }
        }
    }

    public func allKeys() -> Set<String>? {
		mainHandler.allKeys()
    }
	
	public var supportWriting: Bool {
		mainHandler.supportWriting
	}

    public func writeValue(_ value: String?, for key: String) throws {
        // Write only to the write handler
        try mainHandler.writeValue(value, for: key)
    }

    public func clear() throws {
        // Clear only the write handler
        try mainHandler.clear()
    }
}

private final class FallbackCompletion {
    let lock = ReadWriteLock()
    var count: Int
    var errors: [Error?] = []
    let completion: (Error?) -> Void

    init(count: Int, completion: @escaping (Error?) -> Void) {
        self.completion = completion
        self.count = count
    }

    func call(with error: Error?) {
        lock.withWriterLock {
            count -= 1
            if let error {
                self.errors.append(error)
            }
        }
        let (isLast, errors) = lock.withReaderLock { (count == 0, self.errors) }
        if isLast {
            let error: Error?
            switch errors.count {
            case 0: error = nil
            case 1: error = errors[0]
            default: error = FallbackErrors(errors: errors)
            }
            completion(error)
        }
    }
}

/// Error type that wraps multiple errors from handlers
public struct FallbackErrors: Error {
    public let errors: [Error?]
}

public extension ConfigsHandler where Self == FallbackConfigsHandler {
    /// Creates a fallback configs handler that reads from readHandler first, then writeHandler, but only writes to writeHandler
    /// - Parameters:
    ///   - readHandler: The primary handler to read from
    ///   - writeHandler: The handler to write to and use as fallback for reads
    static func fallback(for mainHandler: ConfigsHandler, with fallbackHandler: ConfigsHandler) -> FallbackConfigsHandler {
        FallbackConfigsHandler(mainHandler: mainHandler, fallbackHandler: fallbackHandler)
    }
}
