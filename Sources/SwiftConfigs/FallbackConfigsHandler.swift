import Foundation

/// A ConfigsHandler that reads from a specified handler first, then falls back to the write handler, but only writes to the write handler
public struct FallbackConfigsHandler: ConfigsHandler {
    public let readHandler: ConfigsHandler
    public let writeHandler: ConfigsHandler

    /// Creates a fallback handler that reads from readHandler first, then writeHandler, but only writes to writeHandler
    /// - Parameters:
    ///   - readHandler: The primary handler to read from
    ///   - writeHandler: The handler to write to and use as fallback for reads
    public init(readHandler: ConfigsHandler, writeHandler: ConfigsHandler) {
        self.readHandler = readHandler
        self.writeHandler = writeHandler
    }

    public func value(for key: String) -> String? {
        // Try the read handler first, then fall back to the write handler
        if let value = readHandler.value(for: key) {
            return value
        }
        return writeHandler.value(for: key)
    }

    public func fetch(completion: @escaping (Error?) -> Void) {
        // Fetch from both handlers
        let multiplexCompletion = FallbackCompletion(count: 2, completion: completion)

        readHandler.fetch { error in
            multiplexCompletion.call(with: error)
        }

        writeHandler.fetch { error in
            multiplexCompletion.call(with: error)
        }
    }

    public func listen(_ listener: @escaping () -> Void) -> ConfigsCancellation? {
        // Listen to both handlers
        let readCancellation = readHandler.listen(listener)
        let writeCancellation = writeHandler.listen(listener)

        let cancellables = [readCancellation, writeCancellation].compactMap { $0 }

        return cancellables.isEmpty ? nil : ConfigsCancellation {
            cancellables.forEach { $0.cancel() }
        }
    }

    public func allKeys() -> Set<String>? {
        // Combine keys from both handlers
        let readKeys = readHandler.allKeys()
        let writeKeys = writeHandler.allKeys()

        switch (readKeys, writeKeys) {
        case (nil, nil):
            return nil
        case let (keys?, nil), let (nil, keys?):
            return keys
        case let (readKeys?, writeKeys?):
            return readKeys.union(writeKeys)
        }
    }
	
	public var supportWriting: Bool {
		writeHandler.supportWriting
	}

    public func writeValue(_ value: String?, for key: String) throws {
        // Write only to the write handler
        try writeHandler.writeValue(value, for: key)
    }

    public func clear() throws {
        // Clear only the write handler
        try writeHandler.clear()
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
    static func fallback(read readHandler: ConfigsHandler, write writeHandler: ConfigsHandler) -> FallbackConfigsHandler {
        FallbackConfigsHandler(readHandler: readHandler, writeHandler: writeHandler)
    }
}
