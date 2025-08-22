import Foundation

@available(*, deprecated, renamed: "MultiplexConfigsHandler")
public typealias MultiplexRemoteConfigsHandler = MultiplexConfigsHandler

/// Configuration handler that multiplexes operations across multiple handlers
public struct MultiplexConfigsHandler: ConfigsHandler {
    private let handlers: [ConfigsHandler]

    /// Creates a multiplex handler with an array of handlers
    public init(handlers: [ConfigsHandler]) {
        self.handlers = handlers
    }

    /// Creates a multiplex handler with variadic handlers
    public init(_ handlers: ConfigsHandler...) {
        self.init(handlers: handlers)
    }

    /// Retrieves value from the first handler that has it
    public func value(for key: String) -> String? {
        for handler in handlers {
            if let value = handler.value(for: key) {
                return value
            }
        }
        return nil
    }

    /// Fetches from all handlers and completes when all are done
    public func fetch(completion: @escaping (Error?) -> Void) {
        let multiplexCompletion = MultiplexCompletion(count: handlers.count, completion: completion)
        for handler in handlers {
            handler.fetch { error in
                multiplexCompletion.call(with: error)
            }
        }
    }

    /// Registers listeners on all handlers
    public func listen(_ listener: @escaping () -> Void) -> ConfigsCancellation? {
        let cancellables = handlers.compactMap { $0.listen(listener) }
        return cancellables.isEmpty ? nil : ConfigsCancellation {
            cancellables.forEach { $0.cancel() }
        }
    }

    /// Returns union of keys from all handlers
    public func allKeys() -> Set<String>? {
        handlers.reduce(into: Set<String>?.none) { result, handler in
            if let keys = handler.allKeys() {
                if result == nil {
                    result = []
                }
                result?.formUnion(keys)
            }
        }
    }
	
	/// Supports writing if any handler supports it
	public var supportWriting: Bool {
		handlers.contains(where: \.supportWriting)
	}

    /// Writes to all handlers, collecting any errors
    public func writeValue(_ value: String?, for key: String) throws {
        var errors: [Error] = []
        for handler in handlers {
            do {
                try handler.writeValue(value, for: key)
            } catch {
                errors.append(error)
            }
        }
        if !errors.isEmpty {
            throw errors.count == 1 ? errors[0] : Errors(errors: errors)
        }
    }

    /// Clears all handlers, collecting any errors
    public func clear() throws {
        var errors: [Error] = []
        for handler in handlers {
            do {
                try handler.clear()
            } catch {
                errors.append(error)
            }
        }
        if !errors.isEmpty {
            throw errors.count == 1 ? errors[0] : Errors(errors: errors)
        }
    }

    /// Error type that wraps multiple errors from handlers
    public struct Errors: Error {
        /// The collection of errors from different handlers
        public let errors: [Error?]
    }
}

final class MultiplexCompletion {
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
            default: error = MultiplexConfigsHandler.Errors(errors: errors)
            }
            completion(error)
        }
    }
}

public extension ConfigsHandler where Self == MultiplexConfigsHandler {
    /// Creates a multiplex configuration handler with an array of handlers
    static func multiple(_ handlers: [ConfigsHandler]) -> MultiplexConfigsHandler {
        MultiplexConfigsHandler(handlers: handlers)
    }

    /// Creates a multiplex configuration handler with variadic handlers
    static func multiple(_ handlers: ConfigsHandler...) -> MultiplexConfigsHandler {
        MultiplexConfigsHandler(handlers: handlers)
    }
}
