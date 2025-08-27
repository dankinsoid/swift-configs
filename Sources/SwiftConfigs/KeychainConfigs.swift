import Foundation
#if canImport(Security)
	import Security
	#if canImport(UIKit)
		import UIKit
	#endif

	/// Configuration store backed by iOS/macOS Keychain for secure storage
	///
	/// This store provides secure storage for sensitive configuration data using the system's
	/// Keychain services. It supports various security levels from basic encrypted storage
	/// to hardware-backed Secure Enclave protection with biometric authentication.
	///
	/// ## Security Features
	///
	/// - **Encrypted Storage**: All values are encrypted and protected by the system
	/// - **Secure Enclave**: Hardware-backed security for maximum protection (iOS/macOS with T-series chips)
	/// - **Biometric Protection**: Touch ID/Face ID authentication for key access
	/// - **iCloud Sync**: Optional synchronization across user's devices (incompatible with Secure Enclave)
	/// - **Access Controls**: Fine-grained control over when items can be accessed
	///
	/// ## Performance Considerations
	///
	/// - **Slower than UserDefaults**: Keychain operations involve cryptographic operations
	/// - **Background Limitations**: Some accessibility levels restrict background access
	/// - **User Interaction**: Biometric authentication may require user presence
	/// - **Device Dependencies**: Secure Enclave items are tied to specific hardware
	///
	/// ## Usage Examples
	///
	/// ```swift
	/// // Basic secure storage
	/// ConfigSystem.bootstrap([.secure: .keychain])
	///
	/// // Secure Enclave with biometric protection
	/// ConfigSystem.bootstrap([.critical: .biometricSecureEnclave()])
	///
	/// // iCloud Keychain sync (not compatible with Secure Enclave)
	/// ConfigSystem.bootstrap([.secure: .keychain(iCloudSync: true)])
	/// ```
	public final class KeychainConfigStore: ConfigStore {

		/// Service identifier for grouping related keychain items
		///
		/// Items with the same service are grouped together in keychain queries.
		/// Use different services to separate unrelated configuration domains.
		public let service: String?
		
		/// Keychain security class determining the type of item stored
		public let secClass: SecClass
		
		/// Whether items sync across devices via iCloud Keychain
		///
		/// - Warning: Cannot be used with Secure Enclave (device-specific by nature)
		public let iCloudSync: Bool
		
		/// Accessibility level controlling when items can be accessed
		public let attrAccessible: SecAttrAccessible
		
		/// Whether to use hardware-backed Secure Enclave protection
		///
		/// - Note: Requires devices with T-series chips or newer (iPhone 5s+, iPad Air+, Mac with T1+)
		/// - Warning: Items are device-specific and cannot sync via iCloud
		public let useSecureEnclave: Bool
		
		/// Access control requirements for Secure Enclave protected items
		///
		/// Specifies authentication requirements (biometrics, passcode, etc.) for accessing protected keys.
		public let secureEnclaveAccessControl: SecureEnclaveAccessControl?
    
        // Observers for keychain changes
        private let listenHelper = ConfigStoreObserver()

		/// Shared default keychain configuration store
		public static var `default` = KeychainConfigStore()

		/// Creates a keychain configuration store with specified security options
		///
		/// - Parameters:
		///   - service: Service identifier for grouping related items (nil for default)
		///   - secClass: Keychain security class (default: generic password)
		///   - attrAccessible: When the keychain item can be accessed (default: after first unlock)
		///   - iCloudSync: Whether to sync items across devices via iCloud Keychain
		///   - useSecureEnclave: Whether to use hardware-backed Secure Enclave protection
		///   - secureEnclaveAccessControl: Authentication requirements for Secure Enclave items
		/// - Warning: iCloud sync and Secure Enclave are mutually exclusive - Secure Enclave items cannot sync across devices
		public init(
			service: String? = nil,
			class secClass: SecClass = .genericPassword,
			attrAccessible: SecAttrAccessible = .afterFirstUnlock,
			iCloudSync: Bool = false,
			useSecureEnclave: Bool = false,
			secureEnclaveAccessControl: SecureEnclaveAccessControl? = nil
		) {
			// Validate that iCloud sync and Secure Enclave are not used together
			if iCloudSync && useSecureEnclave {
                ConfigSystem.fail(.iCloudSyncAndSecureEnclaveAreIncompatible)
			}
			
			self.service = service
			self.secClass = secClass
			self.iCloudSync = iCloudSync
			self.attrAccessible = attrAccessible
			self.useSecureEnclave = useSecureEnclave
			self.secureEnclaveAccessControl = secureEnclaveAccessControl
		}

		public func get(_ key: String) throws -> String? {
			let (_, item, status) = loadStatus(for: key)
			return try load(item: item, status: status)
		}

		/// Ensures keychain is available and protected data can be accessed
		///
		/// On iOS, waits for device unlock if necessary. On macOS, completes immediately.
		///
		/// - Parameter completion: Called when keychain access is available or timeout occurs
		/// - Note: May require user interaction (device unlock) on iOS
		public func fetch(completion: @escaping ((any Error)?) -> Void) {
			waitForProtectedDataAvailable(completion: completion)
		}

		public func onChange(_ listener: @escaping () -> Void) -> Cancellation {
            listenHelper.onChange(listener)
		}
        
        public func onChangeOfKey(_ key: String, _ listener: @escaping (String?) -> Void) -> Cancellation {
            listenHelper.onChangeOfKey(key, value: try? get(key), listener)
        }

		/// Returns all configuration keys stored in the keychain
		///
		/// - Returns: Set of all keys, or `nil` if enumeration fails due to keychain errors
		/// - Note: May require device unlock or biometric authentication depending on access controls
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
		
		public var isWritable: Bool { true }

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
            listenHelper.notifyChange(for: key, newValue: value)
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

		/// Removes all configuration items from the keychain
		///
		/// - Throws: KeychainError if the operation fails
		/// - Warning: This permanently deletes all stored configuration data and cannot be undone
		/// - Note: May require user authentication depending on access controls
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
            listenHelper.notifyChange(values: { _ in nil })
		}
		
		/// Keychain accessibility levels controlling when items can be accessed
		///
		/// These values determine when your configuration values are accessible relative to
		/// device lock state and synchronization capabilities.
		public struct SecAttrAccessible: RawRepresentable, CaseIterable {
			public let rawValue: CFString

			public static var allCases: [SecAttrAccessible] {
				[.whenUnlocked, .afterFirstUnlock, .always, .whenUnlockedThisDeviceOnly]
			}

			public init(rawValue: CFString) {
				self.rawValue = rawValue
			}

			/// Item is accessible only when the device is unlocked
			///
			/// Most secure option for normal use. Requires the device to be actively unlocked.
			/// - Note: May cause issues for background app operations
			public static let whenUnlocked = SecAttrAccessible(rawValue: kSecAttrAccessibleWhenUnlocked)
			
			/// Item is accessible after the first device unlock (default)
			///
			/// Recommended for most configuration data. Accessible once the device has been
			/// unlocked at least once since boot, even when subsequently locked.
			public static let afterFirstUnlock = SecAttrAccessible(rawValue: kSecAttrAccessibleAfterFirstUnlock)
			
			/// Item is always accessible regardless of device lock state
			///
			/// - Warning: Least secure option. Use only for non-sensitive configuration data
			public static let always = SecAttrAccessible(rawValue: kSecAttrAccessibleAlways)
			
			/// Item is accessible only when unlocked and never syncs to iCloud
			///
			/// Like `whenUnlocked` but explicitly prevents iCloud synchronization.
			public static let whenUnlockedThisDeviceOnly = SecAttrAccessible(rawValue: kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
		}

		/// Access control requirements for Secure Enclave protected items
		///
		/// These options specify authentication requirements when accessing keys stored in the Secure Enclave.
		/// Multiple options can be combined for layered security.
		public struct SecureEnclaveAccessControl: RawRepresentable, CaseIterable {
			public let rawValue: SecAccessControlCreateFlags

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

			/// Requires user presence via biometrics or device passcode
			///
			/// The most common requirement - accepts Touch ID, Face ID, or device passcode.
			/// Recommended for most Secure Enclave use cases.
			public static let userPresence = SecureEnclaveAccessControl(rawValue: .userPresence)
			
			/// Requires device passcode entry (no biometrics accepted)
			///
			/// Forces passcode entry even if biometrics are available. Use when requiring
			/// the highest level of deliberate user action.
			public static let devicePasscode = SecureEnclaveAccessControl(rawValue: .devicePasscode)
			
			/// Allows cryptographic operations with private keys
			///
			/// Required for key generation and signing operations in the Secure Enclave.
			public static let privateKeyUsage = SecureEnclaveAccessControl(rawValue: .privateKeyUsage)
			
			#if os(iOS)
			/// Requires biometric authentication (Touch ID or Face ID)
			///
			/// Accepts any enrolled biometric, even if additional biometrics are enrolled later.
			/// Falls back to passcode if biometrics are unavailable.
			public static let biometryAny = SecureEnclaveAccessControl(rawValue: .biometryAny)
			
			/// Requires biometric authentication from the current biometric set
			///
			/// Invalidated when new biometrics are enrolled. More secure than `biometryAny`
			/// as it ensures only the originally enrolled biometrics can access the data.
			public static let biometryCurrentSet = SecureEnclaveAccessControl(rawValue: .biometryCurrentSet)
			#elseif os(macOS)
			@available(macOS 10.13.4, *)
			/// Requires biometric authentication (Touch ID)
			///
			/// Accepts any enrolled biometric, even if additional biometrics are enrolled later.
			/// Falls back to passcode if biometrics are unavailable.
			public static let biometryAny = SecureEnclaveAccessControl(rawValue: .biometryAny)
			
			@available(macOS 10.13.4, *)
			/// Requires biometric authentication from the current biometric set
			///
			/// Invalidated when new biometrics are enrolled. More secure than `biometryAny`
			/// as it ensures only the originally enrolled biometrics can access the data.
			public static let biometryCurrentSet = SecureEnclaveAccessControl(rawValue: .biometryCurrentSet)
			#endif
		}

		/// Keychain security class types determining how items are stored and accessed
		///
		/// Each security class has different attributes and behaviors in the keychain.
		/// Most configuration stores should use `genericPassword`.
		public struct SecClass: RawRepresentable, CaseIterable {
			public let rawValue: CFString

			public static var allCases: [SecClass] {
				[.genericPassword, .internetPassword, .certificate, .key, .identity]
			}

			public init(rawValue: CFString) {
				self.rawValue = rawValue
			}

			/// Generic password items (recommended for configuration data)
			///
			/// The most common and flexible keychain item type. Suitable for storing
			/// configuration values, tokens, and other password-like data.
			public static let genericPassword = SecClass(rawValue: kSecClassGenericPassword)
			
			/// Internet password items for web credentials
			///
			/// Specifically designed for storing credentials associated with internet services.
			/// Includes additional attributes like server, protocol, and path.
			public static let internetPassword = SecClass(rawValue: kSecClassInternetPassword)
			
			/// Digital certificates
			///
			/// For storing X.509 certificates and other certificate data.
			public static let certificate = SecClass(rawValue: kSecClassCertificate)
			
			/// Cryptographic keys
			///
			/// For storing public/private key pairs and symmetric keys.
			/// Used with Secure Enclave for hardware-backed key storage.
			public static let key = SecClass(rawValue: kSecClassKey)
			
			/// Identity items (certificate + private key pairs)
			///
			/// Combines a certificate with its associated private key.
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

	/// Default keychain configuration store
	public static var keychain: KeychainConfigStore {
		KeychainConfigStore.default
	}
	
	/// Creates a customized keychain configuration store
	///
	/// - Parameters:
	///   - service: Service identifier for grouping related items (nil for default)
	///   - secClass: Keychain security class (default: generic password)
	///   - attrAccessible: When the keychain item can be accessed (default: after first unlock)
	///   - iCloudSync: Whether to sync items across devices via iCloud Keychain
	///   - useSecureEnclave: Whether to use hardware-backed Secure Enclave protection
	///   - secureEnclaveAccessControl: Authentication requirements for Secure Enclave items
	/// - Returns: A keychain store configured with the specified options
	/// - Warning: iCloud sync and Secure Enclave are mutually exclusive
	public static func keychain(
		service: String? = nil,
		class secClass: KeychainConfigStore.SecClass = .genericPassword,
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
	
	/// Creates a Secure Enclave keychain store with customizable authentication
	///
	/// - Parameters:
	///   - service: Service identifier for grouping related items (nil for default)
	///   - accessControl: Authentication requirements (default: user presence via biometrics or passcode)
	/// - Returns: A keychain store using hardware-backed Secure Enclave protection
	/// - Note: Secure Enclave items are device-specific and cannot sync via iCloud
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
	
	/// Creates a Secure Enclave keychain store requiring biometric authentication
	///
	/// - Parameter service: Service identifier for grouping related items (nil for default)
	/// - Returns: A keychain store requiring Touch ID or Face ID for access
	/// - Note: Falls back to passcode if biometrics are unavailable. Items are device-specific and cannot sync via iCloud.
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
	/// Creates a Secure Enclave keychain store requiring biometric authentication
	///
	/// - Parameter service: Service identifier for grouping related items (nil for default)
	/// - Returns: A keychain store requiring Touch ID for access
	/// - Note: Falls back to passcode if biometrics are unavailable. Items are device-specific and cannot sync via iCloud.
	public static func biometricSecureEnclave(service: String? = nil) -> KeychainConfigStore {
		KeychainConfigStore(
			service: service,
			useSecureEnclave: true,
			secureEnclaveAccessControl: .biometryAny
		)
	}
	#endif
	
	/// Creates a Secure Enclave keychain store requiring device passcode
	///
	/// - Parameter service: Service identifier for grouping related items (nil for default)
	/// - Returns: A keychain store requiring device passcode entry (no biometrics accepted)
	/// - Note: Ensures the highest level of deliberate user authentication. Items are device-specific and cannot sync via iCloud.
	public static func passcodeSecureEnclave(service: String? = nil) -> KeychainConfigStore {
		KeychainConfigStore(
			service: service,
			useSecureEnclave: true,
			secureEnclaveAccessControl: .devicePasscode
		)
	}
}
#endif
