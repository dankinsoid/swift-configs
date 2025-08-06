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
        let multiplexCompletion = MultiplexCompletion(count: 2, completion: completion)

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
		if let keys = mainHandler.allKeys() {
			return keys.union(fallbackHandler.allKeys() ?? [])
		} else {
			return fallbackHandler.allKeys()
		}
    }
	
	public var supportWriting: Bool {
		mainHandler.supportWriting || fallbackHandler.supportWriting
	}

    public func writeValue(_ value: String?, for key: String) throws {
		if mainHandler.supportWriting {
			try mainHandler.writeValue(value, for: key)
		} else {
			try fallbackHandler.writeValue(value, for: key)
		}
    }

    public func clear() throws {
		do {
			try mainHandler.clear()
		} catch {
			try fallbackHandler.clear()
			throw error
		}
		try fallbackHandler.clear()
    }
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
