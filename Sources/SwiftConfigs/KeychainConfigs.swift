import Foundation
#if canImport(Security)
	import Security
	#if canImport(UIKit)
		import UIKit
	#endif

	/// Configuration store backed by iOS/macOS Keychain for secure storage
	public final class KeychainConfigStore: ConfigStore {
		/// Optional service identifier for keychain items
		public let service: String?
		/// Security class for keychain items
		public let secClass: SecClass
		/// Whether to sync keychain items with iCloud
		public let iCloudSync: Bool
		/// Accessibility level for keychain items
		public let attrAccessible: SecAttrAccessible
		/// Whether to use Secure Enclave for enhanced security
		public let useSecureEnclave: Bool
		/// Access control options when using Secure Enclave
		public let secureEnclaveAccessControl: SecureEnclaveAccessControl?
		private var observers: [UUID: () -> Void] = [:]
		private let lock = ReadWriteLock()

		/// Shared default keychain configuration store
		public static var `default` = KeychainConfigStore()

		/// Creates a keychain configs store
		/// - Parameters:
		///   - service: Optional service identifier for keychain items
		///   - secClass: Security class for keychain items
		///   - iCloudSync: Whether to enable iCloud Keychain synchronization
		///   - useSecureEnclave: Whether to use Secure Enclave for key storage
		///   - secureEnclaveAccessControl: Secure Enclave access control options
		/// - Warning: iCloud sync and Secure Enclave cannot be used together. Secure Enclave items are device-specific and cannot be synced across devices.
		public init(
			service: String? = nil,
			class secClass: SecClass = .genericPassowrd,
			attrAccessible: SecAttrAccessible = .afterFirstUnlock,
			iCloudSync: Bool = false,
			useSecureEnclave: Bool = false,
			secureEnclaveAccessControl: SecureEnclaveAccessControl? = nil
		) {
			// Validate that iCloud sync and Secure Enclave are not used together
			if iCloudSync && useSecureEnclave {
				fatalError("iCloud sync and Secure Enclave cannot be used together. Secure Enclave items are device-specific and cannot be synced across devices.")
			}
			
			self.service = service
			self.secClass = secClass
			self.iCloudSync = iCloudSync
			self.attrAccessible = attrAccessible
			self.useSecureEnclave = useSecureEnclave
			self.secureEnclaveAccessControl = secureEnclaveAccessControl
		}

		/// Retrieves a value from the keychain
		public func get(_ key: String) -> String? {
			let (_, item, status) = loadStatus(for: key)
			return try? load(item: item, status: status)
		}

		/// Waits for protected data to become available
		public func fetch(completion: @escaping ((any Error)?) -> Void) {
			waitForProtectedDataAvailable(completion: completion)
		}

		/// Registers a listener for keychain changes
		public func onChange(_ listener: @escaping () -> Void) -> Cancellation? {
			let id = UUID()
			lock.withWriterLock {
				observers[id] = listener
			}
			return Cancellation { [weak self] in
				self?.lock.withWriterLockVoid {
					self?.observers.removeValue(forKey: id)
				}
			}
		}

		/// Returns all keychain keys for this store
		public func keys() -> Set<String>? {
			var query: [String: Any] = [
				kSecReturnAttributes as String: kCFBooleanTrue!,
				kSecMatchLimit as String: kSecMatchLimitAll,
			]
			configureAccess(query: &query)
			
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
			} else if lastResultCode != errSecItemNotFound {
				// Handle actual errors (but not "no items found")
				return nil
			}
			
			return keys
		}
		
		/// Keychain store supports writing operations
		public var isWritable: Bool { true }

		/// Writes a value to the keychain
		public func set(_ value: String?, for key: String) throws {
			// Create a query for saving the value
			var query: [String: Any] = [
				kSecAttrAccount as String: key,
			]
			configureAccess(query: &query)

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
        
        public func exists(_ key: String) throws -> Bool {
            let (_, _, status) = loadStatus(for: key)
            switch status {
            case noErr, errSecSuccess:
                return true
            case errSecItemNotFound, errSecNoSuchAttr, errSecNoSuchClass, errSecNoDefaultKeychain:
                return false
            default:
                throw KeychainError("Failed to check existence of the key in the Keychain. Status: \(status)")
            }
        }

		/// Clears all keychain items for this store
		public func removeAll() throws {
			var query: [String: Any] = [:]
			configureAccess(query: &query)

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
		
		/// Keychain accessibility levels
		public struct SecAttrAccessible: RawRepresentable, CaseIterable {
			public let rawValue: CFString

			/// All available accessibility cases
			public static var allCases: [SecAttrAccessible] {
				[.whenUnlocked, .afterFirstUnlock, .always, .whenUnlockedThisDeviceOnly]
			}

			public init(rawValue: CFString) {
				self.rawValue = rawValue
			}

			/// The value that indicates the item is accessible only when the device is unlocked.
			public static let whenUnlocked = SecAttrAccessible(rawValue: kSecAttrAccessibleWhenUnlocked)
			/// The value that indicates the item is accessible after the first unlock.
			public static let afterFirstUnlock = SecAttrAccessible(rawValue: kSecAttrAccessibleAfterFirstUnlock)
			/// The value that indicates the item is always accessible.
			public static let always = SecAttrAccessible(rawValue: kSecAttrAccessibleAlways)
			/// The value that indicates the item is accessible only when the device is unlocked and this item is not synced with iCloud.
			public static let whenUnlockedThisDeviceOnly = SecAttrAccessible(rawValue: kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
		}

		/// Access control options for Secure Enclave operations
		public struct SecureEnclaveAccessControl: RawRepresentable, CaseIterable {
			public let rawValue: SecAccessControlCreateFlags

			/// All available access control cases
			public static var allCases: [SecureEnclaveAccessControl] {
				var cases: [SecureEnclaveAccessControl] = [.userPresence, .devicePasscode, .privateKeyUsage]
				#if os(iOS)
				cases.append(contentsOf: [.biometryAny, .biometryCurrentSet])
				#elseif os(macOS)
				if #available(macOS 10.13.4, *) {
					cases.append(contentsOf: [.biometryAny, .biometryCurrentSet])
				}
				#endif
				return cases
			}

			public init(rawValue: SecAccessControlCreateFlags) {
				self.rawValue = rawValue
			}

			/// Requires user presence (Touch ID, Face ID, or device passcode)
			public static let userPresence = SecureEnclaveAccessControl(rawValue: .userPresence)
			/// Requires device passcode
			public static let devicePasscode = SecureEnclaveAccessControl(rawValue: .devicePasscode)
			/// Allows private key usage
			public static let privateKeyUsage = SecureEnclaveAccessControl(rawValue: .privateKeyUsage)
			
			#if os(iOS)
			/// Requires any biometric authentication
			public static let biometryAny = SecureEnclaveAccessControl(rawValue: .biometryAny)
			/// Requires current biometric set
			public static let biometryCurrentSet = SecureEnclaveAccessControl(rawValue: .biometryCurrentSet)
			#elseif os(macOS)
			@available(macOS 10.13.4, *)
			/// Requires any biometric authentication
			public static let biometryAny = SecureEnclaveAccessControl(rawValue: .biometryAny)
			@available(macOS 10.13.4, *)
			/// Requires current biometric set
			public static let biometryCurrentSet = SecureEnclaveAccessControl(rawValue: .biometryCurrentSet)
			#endif
		}

		/// Keychain security class types
		public struct SecClass: RawRepresentable, CaseIterable {
			public let rawValue: CFString

			/// All available security classes
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
				kSecAttrAccount as String: key,
				kSecReturnData as String: kCFBooleanTrue!,
				kSecMatchLimit as String: kSecMatchLimitOne,
			]
			configureAccess(query: &query)
			
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
			query[kSecAttrAccessible as String] = attrAccessible.rawValue
			query[kSecClass as String] = secClass.rawValue

			if iCloudSync {
				query[kSecAttrSynchronizable as String] = kCFBooleanTrue
			}

			if let service {
				query[kSecAttrService as String] = service
			}

			// Configure Secure Enclave if enabled
			if useSecureEnclave {
				configureSecureEnclave(query: &query)
			}

			#if os(macOS)
				if #available(macOS 10.15, *) {
					query[kSecUseDataProtectionKeychain as String] = true
				}
			#endif
		}

		private func configureSecureEnclave(query: inout [String: Any]) {
			// Set the token ID to use Secure Enclave
			query[kSecAttrTokenID as String] = kSecAttrTokenIDSecureEnclave

			// Configure access control if specified
			if let accessControl = secureEnclaveAccessControl {
				var error: Unmanaged<CFError>?
				let secAccessControl = SecAccessControlCreateWithFlags(
					kCFAllocatorDefault,
					kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
					accessControl.rawValue,
					&error
				)
				
				if let secAccessControl = secAccessControl {
					query[kSecAttrAccessControl as String] = secAccessControl
				} else if let error = error {
					// Log error but continue without access control
					print("Failed to create access control for Secure Enclave: \(error.takeRetainedValue())")
				}
			}
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

extension ConfigStore where Self == KeychainConfigStore {

	/// Creates a default Keychain configs store
	public static var keychain: KeychainConfigStore {
		KeychainConfigStore.default
	}
	
	/// Creates a Keychain configs store with the specified service identifier
	/// - Parameters:
	///  - service: Optional service identifier for keychain items
	///  - secClass: Security class for keychain items
	///  - iCloudSync: Whether to enable iCloud Keychain synchronization
	///  - useSecureEnclave: Whether to use Secure Enclave for key storage
	///  - secureEnclaveAccessControl: Secure Enclave access control options
	/// - Warning: iCloud sync and Secure Enclave cannot be used together. Secure Enclave items are device-specific and cannot be synced across devices.
	public static func keychain(
		service: String? = nil,
		class secClass: KeychainConfigStore.SecClass = .genericPassowrd,
		attrAccessible: KeychainConfigStore.SecAttrAccessible = .afterFirstUnlock,
		iCloudSync: Bool = false,
		useSecureEnclave: Bool = false,
		secureEnclaveAccessControl: KeychainConfigStore.SecureEnclaveAccessControl? = nil
	) -> KeychainConfigStore {
		KeychainConfigStore(
			service: service, 
			class: secClass, 
			attrAccessible: attrAccessible, 
			iCloudSync: iCloudSync,
			useSecureEnclave: useSecureEnclave,
			secureEnclaveAccessControl: secureEnclaveAccessControl
		)
	}
	
	/// Creates a Secure Enclave Keychain configs store with user presence requirement
	/// - Parameters:
	///  - service: Optional service identifier for keychain items
	///  - accessControl: Secure Enclave access control options (defaults to user presence)
	/// - Note: Secure Enclave items are device-specific and cannot be synced with iCloud.
	public static func secureEnclave(
		service: String? = nil,
		accessControl: KeychainConfigStore.SecureEnclaveAccessControl = .userPresence
	) -> KeychainConfigStore {
		KeychainConfigStore(
			service: service,
			useSecureEnclave: true,
			secureEnclaveAccessControl: accessControl
		)
	}
	
	/// Creates a Secure Enclave Keychain configs store with biometric authentication
	/// - Parameters:
	///  - service: Optional service identifier for keychain items
	/// - Note: Secure Enclave items are device-specific and cannot be synced with iCloud.
	#if os(iOS)
	public static func biometricSecureEnclave(service: String? = nil) -> KeychainConfigStore {
		KeychainConfigStore(
			service: service,
			useSecureEnclave: true,
			secureEnclaveAccessControl: .biometryAny
		)
	}
	#elseif os(macOS)
	@available(macOS 10.13.4, *)
	/// Creates a Secure Enclave Keychain configs store with biometric authentication
	/// - Note: Secure Enclave items are device-specific and cannot be synced with iCloud.
	public static func biometricSecureEnclave(service: String? = nil) -> KeychainConfigStore {
		KeychainConfigStore(
			service: service,
			useSecureEnclave: true,
			secureEnclaveAccessControl: .biometryAny
		)
	}
	#endif
	
	/// Creates a Secure Enclave Keychain configs store with device passcode requirement
	/// - Parameters:
	///  - service: Optional service identifier for keychain items
	/// - Note: Secure Enclave items are device-specific and cannot be synced with iCloud.
	public static func passcodeSecureEnclave(service: String? = nil) -> KeychainConfigStore {
		KeychainConfigStore(
			service: service,
			useSecureEnclave: true,
			secureEnclaveAccessControl: .devicePasscode
		)
	}
}
#endif
