import Foundation
import SwiftConfigs

/// Example demonstrating Secure Enclave usage with SwiftConfigs
class SecureEnclaveExample {
    
    // MARK: - Using Default Secure Enclave Category
    
    func defaultSecureEnclaveCategoryExample() {
        // Bootstrap with default stores (includes Secure Enclave)
        ConfigSystem.defaultBootstrap([:])
        
        // Define keys that use Secure Enclave
        public extension Configs.Keys {
            var apiKey: Key<String> { Key("api-key", from: .critical, default: "") }
            var authToken: Key<String> { Key("auth-token", from: .critical, default: "") }
        }
        
        let configs = Configs()
        
        do {
            // Store sensitive data (automatically uses Secure Enclave)
            try configs.set("your-secret-api-key", for: "api-key")
            print("✅ API key stored securely in Secure Enclave using default category")
            
            // Retrieve the key (will require user authentication)
            if let apiKey = configs.get("api-key") {
                print("✅ Retrieved API key: \(apiKey)")
            } else {
                print("❌ Failed to retrieve API key")
            }
        } catch {
            print("❌ Error: \(error)")
        }
    }
    
    // MARK: - Basic Secure Enclave Usage
    
    func basicSecureEnclaveExample() {
        // Create a Keychain store with Secure Enclave enabled
        let secureKeychain = KeychainConfigStore.secureEnclave(
            service: "com.example.secure"
        )
        
        let configs = Configs()
            .with(secureKeychain)
        
        do {
            // Store a sensitive API key
            try configs.set("your-secret-api-key", for: "api-key")
            print("✅ API key stored securely in Secure Enclave")
            
            // Retrieve the key (will require user authentication)
            if let apiKey = configs.get("api-key") {
                print("✅ Retrieved API key: \(apiKey)")
            } else {
                print("❌ Failed to retrieve API key")
            }
        } catch {
            print("❌ Error: \(error)")
        }
    }
    
    // MARK: - Biometric Authentication Example
    
    func biometricAuthenticationExample() {
        // Create a Keychain store requiring biometric authentication
        let biometricKeychain = KeychainConfigStore.biometricSecureEnclave(
            service: "com.example.biometric"
        )
        
        let configs = Configs()
            .with(biometricKeychain)
        
        do {
            // Store sensitive user data
            try configs.set("user-private-data", for: "user-secret")
            print("✅ User secret stored with biometric protection")
            
            // This will prompt for biometric authentication
            if let secret = configs.get("user-secret") {
                print("✅ Retrieved user secret: \(secret)")
            } else {
                print("❌ Failed to retrieve user secret")
            }
        } catch {
            print("❌ Error: \(error)")
        }
    }
    
    // MARK: - Device Passcode Example
    
    func devicePasscodeExample() {
        // Create a Keychain store requiring device passcode
        let passcodeKeychain = KeychainConfigStore.passcodeSecureEnclave(
            service: "com.example.passcode"
        )
        
        let configs = Configs()
            .with(passcodeKeychain)
        
        do {
            // Store critical system data
            try configs.set("system-critical-data", for: "system-secret")
            print("✅ System secret stored with passcode protection")
            
            // This will prompt for device passcode
            if let secret = configs.get("system-secret") {
                print("✅ Retrieved system secret: \(secret)")
            } else {
                print("❌ Failed to retrieve system secret")
            }
        } catch {
            print("❌ Error: \(error)")
        }
    }
    
    // MARK: - Multiple Security Levels Example
    
    func multipleSecurityLevelsExample() {
        // Create different stores for different security levels
        let publicKeychain = KeychainConfigStore(service: "com.example.public")
        let secureKeychain = KeychainConfigStore.secureEnclave(
            service: "com.example.secure"
        )
        let biometricKeychain = KeychainConfigStore.biometricSecureEnclave(
            service: "com.example.biometric"
        )
        
        let configs = Configs()
            .with(publicKeychain)
            .with(secureKeychain)
            .with(biometricKeychain)
        
        do {
            // Store public data (no special protection)
            try configs.set("public-data", for: "public-key")
            
            // Store sensitive data (requires user presence)
            try configs.set("sensitive-data", for: "sensitive-key")
            
            // Store highly sensitive data (requires biometric)
            try configs.set("highly-sensitive-data", for: "biometric-key")
            
            print("✅ All data stored with appropriate security levels")
            
            // Retrieve data with different security requirements
            let publicData = configs.get("public-key")
            let sensitiveData = configs.get("sensitive-key")
            let biometricData = configs.get("biometric-key")
            
            print("Public data: \(publicData ?? "nil")")
            print("Sensitive data: \(sensitiveData ?? "nil")")
            print("Biometric data: \(biometricData ?? "nil")")
            
        } catch {
            print("❌ Error: \(error)")
        }
    }
    
    // MARK: - iCloud Sync Incompatibility Example
    
    func iCloudSyncIncompatibilityExample() {
        print("⚠️  Demonstrating iCloud sync incompatibility with Secure Enclave")
        
        // This would crash at runtime - demonstrating the protection
        // Uncomment the following lines to see the fatal error:
        /*
        let invalidStore = KeychainConfigStore(
            service: "com.example.invalid",
            iCloudSync: true,
            useSecureEnclave: true
        )
        */
        
        print("✅ Library prevents incompatible configuration")
        print("✅ Use either iCloud sync OR Secure Enclave, not both")
        
        // Valid alternatives:
        let iCloudStore = KeychainConfigStore(
            service: "com.example.icloud",
            iCloudSync: true
        )
        
        let secureEnclaveStore = KeychainConfigStore.secureEnclave(
            service: "com.example.secure"
        )
        
        print("✅ iCloud store: \(iCloudStore.iCloudSync ? "enabled" : "disabled")")
        print("✅ Secure Enclave store: \(secureEnclaveStore.useSecureEnclave ? "enabled" : "disabled")")
    }
    
    // MARK: - Error Handling Example
    
    func errorHandlingExample() {
        let secureKeychain = KeychainConfigStore.secureEnclave(
            service: "com.example.error"
        )
        
        let configs = Configs()
            .with(secureKeychain)
        
        do {
            // Try to store data
            try configs.set("test-data", for: "test-key")
            print("✅ Data stored successfully")
            
            // Try to retrieve data
            if let data = configs.get("test-key") {
                print("✅ Data retrieved: \(data)")
            } else {
                print("❌ No data found")
            }
            
            // Try to retrieve non-existent data
            if let data = configs.get("non-existent-key") {
                print("Unexpected data: \(data)")
            } else {
                print("✅ Correctly returned nil for non-existent key")
            }
            
        } catch KeychainConfigStore.KeychainError(let message) {
            print("❌ Keychain error: \(message)")
        } catch {
            print("❌ Unexpected error: \(error)")
        }
    }
}

// MARK: - Usage Example

func runSecureEnclaveExamples() {
    let example = SecureEnclaveExample()
    
    print("🔐 Secure Enclave Examples")
    print("==========================")
    
    print("\n1. Default Secure Enclave Category:")
    example.defaultSecureEnclaveCategoryExample()
    
    print("\n2. Basic Secure Enclave Usage:")
    example.basicSecureEnclaveExample()
    
    print("\n3. Biometric Authentication:")
    example.biometricAuthenticationExample()
    
    print("\n4. Device Passcode Protection:")
    example.devicePasscodeExample()
    
    print("\n5. Multiple Security Levels:")
    example.multipleSecurityLevelsExample()
    
    print("\n6. iCloud Sync Incompatibility:")
    example.iCloudSyncIncompatibilityExample()
    
    print("\n7. Error Handling:")
    example.errorHandlingExample()
}

// Uncomment to run examples
// runSecureEnclaveExamples()
