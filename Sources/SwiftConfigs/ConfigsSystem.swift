import Foundation

@available(*, deprecated, renamed: "ConfigsSystem")
public typealias RemoteConfigsSystem = ConfigsSystem

/// The `ConfigsSystem` is a global facility where the default configs backend implementation (`ConfigsHandler`) can be
/// configured. `ConfigsSystem` is set up just once in a given program to set up the desired configs backend
/// implementation.
public enum ConfigsSystem {
    private static let _handler = HandlerBox([.all: NOOPConfigsHandler.instance])

    /// `bootstrap` is an one-time configuration function which globally selects the desired configs backend
    /// implementation. `bootstrap` can be called at maximum once in any given program, calling it more than once will
    /// lead to undefined behaviour, most likely a crash.
    ///
    /// - parameters:
    ///     - handler: The desired configs backend implementation.
    public static func bootstrap(_ handler: ConfigsHandler) {
        bootstrap([.all: handler])
    }

    /// `bootstrap` is an one-time configuration function which globally selects the desired configs backend
    /// implementation. `bootstrap` can be called at maximum once in any given program, calling it more than once will
    /// lead to undefined behaviour, most likely a crash.
    ///
    /// - parameters:
    ///     - handler: The desired configs backend implementation.
    public static func bootstrap(_ handlers: [ConfigsCategory: ConfigsHandler]) {
        _handler.replaceHandler(handlers, validate: true)
    }

    /// for our testing we want to allow multiple bootstrapping
    static func bootstrapInternal(_ handlers: [ConfigsCategory: ConfigsHandler]) {
        _handler.replaceHandler(handlers, validate: false)
    }

    /// Returns a reference to the configured handler.
    static var handler: Handler {
        _handler.underlying
    }

    /// Acquire a writer lock for the duration of the given block.
    ///
    /// - Parameter body: The block to execute while holding the lock.
    /// - Returns: The value returned by the block.
    public static func withWriterLock<T>(_ body: () throws -> T) rethrows -> T {
        try _handler.withWriterLock(body)
    }

    private final class HandlerBox {
        private let lock = ReadWriteLock()
        fileprivate var handler: Handler
        private var initialized = false

        init(_ underlying: [ConfigsCategory: ConfigsHandler]) {
            handler = Handler(underlying)
        }

        func replaceHandler(_ factory: [ConfigsCategory: ConfigsHandler], validate: Bool) {
            withWriterLock {
                precondition(!validate || !self.initialized, "configs system can only be initialized once per process.")
                self.handler = Handler(factory)
                self.initialized = true
            }
        }

        var underlying: Handler {
            lock.withReaderLock {
                handler
            }
        }

        func withWriterLock<T>(_ body: () throws -> T) rethrows -> T {
            try lock.withWriterLock(body)
        }
    }

    public final class Handler {
        var didFetch: Bool {
            lock.withReaderLock {
                _didFetch
            }
        }

        private let lock = ReadWriteLock()
        private var _didFetch = false
        private let handlers: [(ConfigsCategory, ConfigsHandler)]
        private var observers: [UUID: () -> Void] = [:]
        private var didStartListen = false
        private var didStartFetch = false
        private var cancellation: ConfigsCancellation?

        init(_ handlers: [ConfigsCategory: ConfigsHandler]) {
            self.handlers = handlers.sorted { $0.0 < $1.0 }
        }

        func fetch(completion: @escaping (Error?) -> Void) {
            lock.withWriterLock {
                didStartFetch = true
            }
            handler(for: .all).fetch { [weak self] error in
                self?.lock.withWriterLock { () -> [() -> Void] in
                    self?.didStartFetch = false
                    if error == nil {
                        self?._didFetch = true
                        return (self?.observers.values).map { Array($0) } ?? []
                    }
                    return []
                }
                .forEach { $0() }
                completion(error)
            }
        }

        public func value(for key: String, in category: ConfigsCategory = .default) -> String? {
            handler(for: category).value(for: key)
        }

        public func writeValue(_ value: String?, for key: String, in category: ConfigsCategory = .default) throws {
            try handler(for: category).writeValue(value, for: key)
        }

        public func allKeys(in category: ConfigsCategory = .default) -> Set<String> {
            handler(for: category).allKeys() ?? []
        }

        public func clear(in category: ConfigsCategory = .default) throws {
            try handler(for: category).clear()
        }

        func listen(_ observer: @escaping () -> Void) -> ConfigsCancellation {
            let didFetch = self.didFetch
            if !didFetch, !lock.withReaderLock({ didStartFetch }) {
                fetch { _ in }
            }
            defer {
                if didFetch {
                    observer()
                }
            }
            let id = UUID()
            lock.withWriterLockVoid {
                observers[id] = observer
                if !didStartListen {
                    didStartListen = true
                    cancellation = handler(for: .all).listen { [weak self] in
                        self?.lock.withReaderLock {
                            self?.observers ?? [:]
                        }
                        .values
                        .forEach { $0() }
                    }
                }
            }
            return ConfigsCancellation { self.cancel(id: id) }
        }

        private func handler(for category: ConfigsCategory) -> ConfigsHandler {
            MultiplexConfigsHandler(
                handlers: handlers.compactMap { category.isSuperset(of: $0.0) ? $0.1 : nil }
            )
        }

        private func cancel(id: UUID) {
            lock.withWriterLock { () -> ConfigsCancellation? in
                observers.removeValue(forKey: id)
                if observers.isEmpty {
                    let result = cancellation
                    cancellation = nil
                    didStartListen = false
                    return result
                }
                return nil
            }?.cancel()
        }
    }
}

// MARK: - Sendable support helpers

#if compiler(>=5.6)
    extension ConfigsSystem: Sendable {}
#endif
