import Foundation
#if canImport(Security)
	import Security
	#if canImport(UIKit)
		import UIKit
	#endif

	/// A ConfigsHandler implementation backed by iOS/macOS Keychain
	public final class KeychainConfigsHandler: ConfigsHandler {
		/// The keychain service identifier
		public let service: String?
		/// The keychain security class
		public let secClass: SecClass
		/// Whether to sync keychain items with iCloud
		public let iCloudSync: Bool
		private var observers: [UUID: () -> Void] = [:]
		private let lock = ReadWriteLock()

		/// The default Keychain configs handler
		public static var `default` = KeychainConfigsHandler()

		/// Creates a keychain configs handler
		/// - Parameters:
		///   - service: Optional service identifier for keychain items
		///   - secClass: Security class for keychain items
		///   - iCloudSync: Whether to enable iCloud Keychain synchronization
		public init(service: String? = nil, class secClass: SecClass = .genericPassowrd, iCloudSync: Bool = false) {
			self.service = service
			self.secClass = secClass
			self.iCloudSync = iCloudSync
		}

		public func value(for key: String) -> String? {
			let (_, item, status) = loadStatus(for: key)
			return try? load(item: item, status: status)
		}

		public func fetch(completion: @escaping ((any Error)?) -> Void) {
			waitForProtectedDataAvailable(completion: completion)
		}

		public func listen(_ listener: @escaping () -> Void) -> ConfigsCancellation? {
			let id = UUID()
			lock.withWriterLock {
				observers[id] = listener
			}
			return ConfigsCancellation { [weak self] in
				self?.lock.withWriterLockVoid {
					self?.observers.removeValue(forKey: id)
				}
			}
		}

		public func allKeys() -> Set<String>? {
			var query: [String: Any] = [
				kSecClass as String: secClass.rawValue,
				kSecReturnData as String: kCFBooleanTrue!,
				kSecReturnAttributes as String: kCFBooleanTrue!,
				kSecReturnRef as String: kCFBooleanTrue!,
				kSecMatchLimit as String: kSecMatchLimitAll,
			]

			if iCloudSync {
				query[kSecAttrSynchronizable as String] = kCFBooleanTrue
			}
			if let service {
				query[kSecAttrService as String] = service
			}

			var result: AnyObject?

			let lastResultCode = withUnsafeMutablePointer(to: &result) {
				SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
			}

			var keys = Set<String>()
			if lastResultCode == noErr {
				if let array = result as? [[String: Any]] {
					for item in array {
						if let key = item[kSecAttrAccount as String] as? String {
							keys.insert(key)
						}
					}
				}
			} else {}

			return keys
		}

		public func writeValue(_ value: String?, for key: String) throws {
			// Create a query for saving the token
			var query: [String: Any] = [
				kSecClass as String: secClass.rawValue,
				kSecAttrAccount as String: key,
			]
			configureAccess(query: &query)

			if let service {
				query[kSecAttrService as String] = service
			}

			// Try to delete the old value if it exists
			SecItemDelete(query as CFDictionary)

			if let value {
				query[kSecValueData as String] = value.data(using: .utf8)
				// Add the new token to the Keychain
				var status = SecItemAdd(query as CFDictionary, nil)
				if status == errSecInteractionNotAllowed {
					//		try await waitForProtectedDataAvailable()
					status = SecItemAdd(query as CFDictionary, nil)
				}
				// Check the result
				guard status == noErr || status == errSecSuccess else {
					throw KeychainError("Failed to save the value to the Keychain. Status: \(status)")
				}
			}

			// Notify observers
			lock.withWriterLock {
				observers.values
			}
			.forEach { $0() }
		}

		public func clear() throws {
			var query: [String: Any] = [
				kSecClass as String: secClass.rawValue,
			]
			configureAccess(query: &query)

			if let service {
				query[kSecAttrService as String] = service
			}

			var status = SecItemDelete(query as CFDictionary)
			if status == errSecInteractionNotAllowed {
				//	  try await waitForProtectedDataAvailable()
				status = SecItemDelete(query as CFDictionary)
			}

			guard status == noErr || status == errSecSuccess else {
				throw KeychainError("Failed to clear the Keychain cache. Status: \(status)")
			}

			// Notify observers
			lock.withWriterLock {
				observers.values
			}
			.forEach { $0() }
		}

		/// Keychain security class options
		public struct SecClass: RawRepresentable, CaseIterable {
			public let rawValue: CFString

			public static var allCases: [SecClass] {
				[.genericPassowrd, .internetPassword, .certificate, .key, .identity]
			}

			public init(rawValue: CFString) {
				self.rawValue = rawValue
			}

			/// The value that indicates a generic password item.
			public static let genericPassowrd = SecClass(rawValue: kSecClassGenericPassword)
			/// The value that indicates an Internet password item.
			public static let internetPassword = SecClass(rawValue: kSecClassInternetPassword)
			/// The value that indicates a certificate item.
			public static let certificate = SecClass(rawValue: kSecClassCertificate)
			/// The value that indicates a cryptographic key item.
			public static let key = SecClass(rawValue: kSecClassKey)
			/// The value that indicates an identity item.
			public static let identity = SecClass(rawValue: kSecClassIdentity)
		}

		struct KeychainError: Error {
			let message: String

			init(_ message: String) {
				self.message = message
			}
		}

		private func loadStatus(for key: String) -> ([String: Any], CFTypeRef?, OSStatus) {
			// Create a query for retrieving the value
			var query: [String: Any] = [
				kSecClass as String: secClass.rawValue,
				kSecAttrAccount as String: key,
				kSecReturnData as String: kCFBooleanTrue!,
				kSecMatchLimit as String: kSecMatchLimitOne,
			]
			configureAccess(query: &query)
			if let service {
				query[kSecAttrService as String] = service
			}

			var item: CFTypeRef?
			let status = SecItemCopyMatching(query as CFDictionary, &item)
			return (query, item, status)
		}

		private func load(item: CFTypeRef?, status: OSStatus) throws -> String? {
			guard let data = item as? Data else {
				if [errSecItemNotFound, errSecNoSuchAttr, errSecNoSuchClass, errSecNoDefaultKeychain]
					.contains(status)
				{
					return nil
				} else {
					throw KeychainError("Failed to load the value from the Keychain. Status: \(status)")
				}
			}

			guard let value = String(data: data, encoding: .utf8) else {
				throw KeychainError("Failed to convert the data to a string.")
			}

			return value
		}

		private func configureAccess(query: inout [String: Any]) {
			query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

			if iCloudSync {
				query[kSecAttrSynchronizable as String] = kCFBooleanTrue
			}

			#if os(macOS)
				if #available(macOS 10.15, *) {
					query[kSecUseDataProtectionKeychain as String] = true
				}
			#endif
		}
	}

	private func waitForProtectedDataAvailable(completion: @escaping (Error?) -> Void) {
		#if canImport(UIKit)
			guard !UIApplication.shared.isProtectedDataAvailable else {
				completion(nil)
				return
			}
			let name = UIApplication.protectedDataDidBecomeAvailableNotification
			let holder = Holder(completion: completion)
			holder.setObserver(
				NotificationCenter.default.addObserver(
					forName: name, object: nil, queue: .main
				) { _ in
					holder.resume()
				}
			)
		#endif
	}

	#if canImport(UIKit)
		private final class Holder {
			var observer: NSObjectProtocol?
			let completion: (Error?) -> Void
			let lock = NSLock()

			init(completion: @escaping (Error?) -> Void) {
				self.completion = completion
			}

			func setObserver(_ observer: NSObjectProtocol) {
				lock.withLock {
					self.observer = observer
				}
				DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
					self?.resume(error: TimeoutError())
				}
			}

			func resume(error: Error? = nil) {
				let observer = lock.withLock { self.observer }
				guard let observer else {
					return
				}
				lock.withLock { self.observer = nil }
				completion(error)
				NotificationCenter.default.removeObserver(observer)
			}

			deinit {
				let observer = lock.withLock { self.observer }
				if let observer {
					NotificationCenter.default.removeObserver(observer)
				}
			}
		}

		private struct TimeoutError: Error {}
	#endif
#endif
