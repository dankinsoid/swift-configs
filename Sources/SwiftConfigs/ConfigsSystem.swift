import Foundation
#if canImport(Security)
    import Security
#endif

@available(*, deprecated, renamed: "ConfigsSystem")
public typealias RemoteConfigsSystem = ConfigsSystem

/// The `ConfigsSystem` is a global facility where the default configs backend implementation (`ConfigsHandler`) can be
/// configured. `ConfigsSystem` is set up just once in a given program to set up the desired configs backend
/// implementation.
public enum ConfigsSystem {
	
	/// The default configs backend categories.
	public static let defaultHandlers: [ConfigsCategory: ConfigsHandler] = [
		.default: .userDefaults,
		.environments: .environments,
		.memory: .inMemory,
	]
		.withPlatformSpecific
	
	public static let mockHandlers: [ConfigsCategory: ConfigsHandler] = [
		.default: .inMemory(),
		.environments: .inMemory(),
		.memory: .inMemory(),
		.secure: .inMemory(),
		.syncedSecure: .inMemory(),
		.synced: .inMemory(),
		.remote: .inMemory()
	]
	
	private static let _handler = HandlerBox(
		isPreview ? mockHandlers : defaultHandlers
	)
	
	/// `bootstrap` is an one-time configuration function which globally selects the desired configs backend
	/// implementation. `bootstrap` can be called at maximum once in any given program, calling it more than once will
	/// lead to undefined behaviour, most likely a crash.
	///
	/// - parameters:
	///     - handler: The desired configs backend implementation.
	public static func bootstrap(_ handler: ConfigsHandler) {
		bootstrap([.default: handler])
	}
	
	/// `bootstrap` is an one-time configuration function which globally selects the desired configs backend
	/// implementation. `bootstrap` can be called at maximum once in any given program, calling it more than once will
	/// lead to undefined behaviour, most likely a crash.
	///
	/// - parameters:
	///     - handler: The desired configs backend implementation.
	public static func bootstrap(_ handlers: [ConfigsCategory: ConfigsHandler]) {
		_handler.replaceHandler(handlers)
	}
	
	/// `defaultBootstrap` is an one-time configuration function which globally selects the desired configs backend
	/// implementation. `defaultBootstrap` uses the default handlers and merges them with the provided handlers.
	/// `defaultBootstrap` can be called at maximum once in any given program, calling it more than once will
	/// lead to undefined behaviour, most likely a crash.
	///
	///
	/// - parameters:
	///     - handler: The desired configs backend implementation.
	public static func defaultBootstrap(_ handlers: [ConfigsCategory: ConfigsHandler]) {
		_handler.replaceHandler(handlers.merging(isPreview ? mockHandlers : defaultHandlers) { new, _ in new })
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
		
		func replaceHandler(_ factory: [ConfigsCategory: ConfigsHandler]) {
			withWriterLock {
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
		public let handlers: [ConfigsCategory: ConfigsHandler]
		private var observers: [UUID: () -> Void] = [:]
		private var didStartListen = false
		private var didStartFetch = false
		private var cancellation: ConfigsCancellation?
		
		public init(_ handlers: [ConfigsCategory: ConfigsHandler]) {
			self.handlers = handlers
		}
		
		func fetch(completion: @escaping (Error?) -> Void) {
			lock.withWriterLock {
				didStartFetch = true
			}
			handler(for: nil).fetch { [weak self] error in
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
		
		public func value(for key: String, in category: ConfigsCategory? = nil) -> String? {
			handler(for: category).value(for: key)
		}
		
		public func writeValue(_ value: String?, for key: String, in category: ConfigsCategory) throws {
			try handler(for: category).writeValue(value, for: key)
		}
		
		public func allKeys(in category: ConfigsCategory? = nil) -> Set<String> {
			handler(for: category).allKeys() ?? []
		}
		
		public func clear(in category: ConfigsCategory? = nil) throws {
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
					cancellation = handler(for: nil).listen { [weak self] in
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

		func handler(for category: ConfigsCategory?) -> ConfigsHandler {
			MultiplexConfigsHandler(
				handlers: category.map { category in handlers.compactMap { category == $0.key ? $0.value : nil } } ?? Array(handlers.values)
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

private extension [ConfigsCategory: ConfigsHandler] {
    var withPlatformSpecific: [ConfigsCategory: ConfigsHandler] {
        var handlers = self
        if #available(iOS 5.0, macOS 10.7, tvOS 9.0, watchOS 2.0, *) {
            handlers[.synced] = .ubiquitous
        }
        #if canImport(Security)
            handlers[.secure] = .keychain
			handlers[.syncedSecure] = .keychain(iCloudSync: true)
        #endif
        return handlers
    }
}

#if DEBUG
    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" || ProcessInfo.processInfo.processName == "XCPreviewAgent"
#else
    private let isPreview = false
#endif
