import Foundation

public enum ConfigFail: Error, LocalizedError {
    
    case retrievalFailed(key: String, Error)
    case storingFailed(key: String, Error)
    case existenceCheckFailed(key: String, Error)
    case iCloudSyncAndSecureEnclaveAreIncompatible
    case noStoresAvailable(category: ConfigCategory?)
    case bootstrapCanBeCalledOnlyOnce
    case bootstrapMustBeCalledBeforeUsingConfigs(Set<ConfigCategory?>)
    
    public var errorDescription: String? {
        switch self {
        case let .retrievalFailed(key, error):
            return "Failed to retrieve config value for key '\(key)': \(error)"
        case let .storingFailed(key, error):
            return "Failed to store config value for key '\(key)': \(error)"
        case let .existenceCheckFailed(key, error):
            return "Failed to check existence of config key '\(key)': \(error)"
        case .iCloudSyncAndSecureEnclaveAreIncompatible:
            return "iCloud sync and Secure Enclave cannot be used together. Secure Enclave items are device-specific and cannot be synced across devices."
        case let .noStoresAvailable(category):
            if let category {
                return "No stores configured for \(category) category."
            } else {
                return "No stores configured."
            }
        case .bootstrapCanBeCalledOnlyOnce:
            return "Configs.bootstrap() can only be called once."
        case let .bootstrapMustBeCalledBeforeUsingConfigs(categories):
            return "Configs.bootstrap() must be called before accessing any configs. Accessed categories: \(categories.map { $0?.description ?? "all" }.joined(separator: ", "))"
        }
    }

    public var localizedDescription: String {
        errorDescription ?? "An unknown error occurred."
    }
}
