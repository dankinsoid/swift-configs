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
	
	/// The default configuration handlers for each category
	public static let defaultHandlers: [ConfigsCategory: ConfigsHandler] = [
		.default: .userDefaults,
		.environments: .environments,
		.memory: .inMemory,
	]
		.withPlatformSpecific
	
	/// Mock configuration handlers for testing and previews
	public static let mockHandlers: [ConfigsCategory: ConfigsHandler] = [
		.default: .inMemory(),
		.environments: .inMemory(),
		.memory: .inMemory(),
		.secure: .inMemory(),
		.secureEnclave: .inMemory(),
		.syncedSecure: .inMemory(),
		.remote: .inMemory()
	]
	
	private static let _handler = HandlerBox(
		isPreview ? mockHandlers : defaultHandlers
	)
	
	/// Bootstraps the configuration system with a single handler
	/// 
	/// This function can only be called once per program execution.
	/// Multiple calls will lead to undefined behavior.
	///
	/// - Parameter handler: The configuration handler to use
	public static func bootstrap(_ handler: ConfigsHandler) {
		bootstrap([.default: handler])
	}
	
	/// Bootstraps the configuration system with category-specific handlers
	/// 
	/// This function can only be called once per program execution.
	/// Multiple calls will lead to undefined behavior.
	///
	/// - Parameter handlers: A dictionary mapping categories to their handlers
	public static func bootstrap(_ handlers: [ConfigsCategory: ConfigsHandler]) {
		_handler.replaceHandler(handlers)
	}
	
	/// Bootstraps with default handlers, overriding with provided handlers
	/// 
	/// This function merges the provided handlers with the default ones,
	/// with provided handlers taking precedence.
	/// Can only be called once per program execution.
	///
	/// - Parameter handlers: Custom handlers to override defaults
	public static func defaultBootstrap(_ handlers: [ConfigsCategory: ConfigsHandler]) {
		_handler.replaceHandler(handlers.merging(isPreview ? mockHandlers : defaultHandlers) { new, _ in new })
	}
	
	/// Returns a reference to the configured handler.
	static var handler: Handler {
		_handler.handler
	}
	
	private final class HandlerBox {
		let handler: Handler
		
		init(_ underlying: [ConfigsCategory: ConfigsHandler]) {
			handler = Handler(underlying)
		}
		
		func replaceHandler(_ factory: [ConfigsCategory: ConfigsHandler]) {
			self.handler.handlers = factory
		}
	}
	
	/// The main configuration handler that manages multiple category handlers
	public final class Handler {
		/// Whether any handler has completed a fetch operation
		var didFetch: Bool {
			lock.withReaderLock {
				_didFetch
			}
		}

		private let lock = ReadWriteLock()
		private let handlersLock = ReadWriteLock()
		private var _didFetch = false
		/// The category-specific configuration handlers
		fileprivate(set) public var handlers: [ConfigsCategory: ConfigsHandler] {
			get { handlersLock.withReaderLock { _handlers } }
			set { handlersLock.withWriterLockVoid { _handlers = newValue } }
		}
		private var _handlers: [ConfigsCategory: ConfigsHandler]
		private var observers: [UUID: () -> Void] = [:]
		private var didStartListen = false
		private var didStartFetch = false
		private var cancellation: ConfigsCancellation?
		
		/// Initializes with a set of category handlers
		public init(_ handlers: [ConfigsCategory: ConfigsHandler]) {
			_handlers = handlers
		}
		
		/// Fetches configuration values from all handlers
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
		
		/// Retrieves a value from the appropriate handler
		public func value(for key: String, in category: ConfigsCategory? = nil) -> String? {
			handler(for: category).value(for: key)
		}
		
		/// Writes a value using the appropriate handler
		public func writeValue(_ value: String?, for key: String, in category: ConfigsCategory) throws {
			try handler(for: category).writeValue(value, for: key)
		}
		
		/// Returns all keys from the appropriate handler
		public func allKeys(in category: ConfigsCategory? = nil) -> Set<String> {
			handler(for: category).allKeys() ?? []
		}
		
		/// Clears all values from the appropriate handler
		public func clear(in category: ConfigsCategory? = nil) throws {
			try handler(for: category).clear()
		}
		
		/// Registers a listener for configuration changes
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

		/// Gets the appropriate handler for a category
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
        #if canImport(Security)
            handlers[.secure] = .keychain
            handlers[.secureEnclave] = .keychain(useSecureEnclave: true, secureEnclaveAccessControl: .userPresence)
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
