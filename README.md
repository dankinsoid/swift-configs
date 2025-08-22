
# SwiftConfigs

A Swift library for managing configuration values with support for multiple storage backends including Keychain with Secure Enclave support.

## Features

- Multiple storage backends (UserDefaults, Keychain, Environment Variables, etc.)
- **Secure Enclave support** for enhanced security
- Type-safe configuration management
- Fallback and multiplex configurations
- Real-time configuration updates

## Secure Enclave Support

SwiftConfigs now supports Secure Enclave for storing sensitive configuration values with enhanced security. The Secure Enclave is a hardware-based key manager that provides an isolated environment for cryptographic operations.

### Using the Default Secure Enclave Category

The easiest way to use Secure Enclave is with the built-in `.secureEnclave` category:

```swift
import SwiftConfigs

// Bootstrap with default handlers (includes Secure Enclave)
ConfigsSystem.defaultBootstrap([:])

// Define keys that use Secure Enclave
public extension Configs.Keys {
    var apiKey: Key<String> { Key("api-key", from: .secureEnclave, default: "") }
    var authToken: Key<String> { Key("auth-token", from: .secureEnclave, default: "") }
}

// Use in your app
let configs = Configs()

// Store sensitive data (automatically uses Secure Enclave)
try configs.writeValue("your-secret-api-key", for: "api-key")

// Retrieve (will require user authentication)
let apiKey = configs.value(for: "api-key")
```

### Custom Secure Enclave Handlers

You can also create custom Secure Enclave handlers with specific configurations:

```swift
import SwiftConfigs

// Basic Secure Enclave with user presence
let secureKeychain = KeychainConfigsHandler.secureEnclave(
    service: "com.yourapp.secure"
)

// Biometric authentication
let biometricKeychain = KeychainConfigsHandler.biometricSecureEnclave(
    service: "com.yourapp.biometric"
)

// Device passcode protection
let passcodeKeychain = KeychainConfigsHandler.passcodeSecureEnclave(
    service: "com.yourapp.passcode"
)

// Custom access control
let customKeychain = KeychainConfigsHandler.secureEnclave(
    service: "com.yourapp.custom",
    accessControl: .userPresence
)

// Use with your configuration system
let configs = Configs()
    .with(secureKeychain)
    .with(biometricKeychain)
    .with(passcodeKeychain)

// Store sensitive data
try configs.writeValue("sensitive-data", for: "api-key")
```

### Access Control Options

The Secure Enclave supports various access control options:

- `.userPresence` - Requires user presence (Touch ID, Face ID, or device passcode)
- `.devicePasscode` - Requires device passcode
- `.privateKeyUsage` - Allows private key usage
- `.biometryAny` - Requires any biometric authentication (iOS only)
- `.biometryCurrentSet` - Requires current biometric set (iOS only)

### Example with Biometric Authentication

```swift
// Require biometric authentication for access
let biometricKeychain = KeychainConfigsHandler(
    service: "com.yourapp.biometric",
    useSecureEnclave: true,
    secureEnclaveAccessControl: .biometryAny
)

// Store sensitive data
try configs.writeValue("super-secret-token", for: "auth-token")

// When retrieving, user will be prompted for biometric authentication
let token = configs.value(for: "auth-token")
```

### Availability

Secure Enclave support is available on:
- iOS devices with Touch ID or Face ID
- Mac computers with Apple Silicon (M1/M2/M3) or T2 Security Chip
- Devices running iOS 9.0+ or macOS 10.12+

### Important Limitations

⚠️ **iCloud Sync Incompatibility**: Secure Enclave items are device-specific and cannot be synced with iCloud. If you attempt to use both `iCloudSync: true` and `useSecureEnclave: true`, the library will throw a fatal error to prevent data loss.

```swift
// ❌ This will crash - incompatible options
let invalidHandler = KeychainConfigsHandler(
    iCloudSync: true,
    useSecureEnclave: true
)

// ✅ Use either iCloud sync OR Secure Enclave, not both
let iCloudHandler = KeychainConfigsHandler(iCloudSync: true)
let secureEnclaveHandler = KeychainConfigsHandler(useSecureEnclave: true)
```

## Installation

Add SwiftConfigs to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/swift-configs.git", from: "1.0.0")
]
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.
