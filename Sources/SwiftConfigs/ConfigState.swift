#if canImport(SwiftUI)
import SwiftUI

/// SwiftUI property wrapper for read-only configuration values.
/// Automatically updates views when configuration changes.
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
@propertyWrapper
public struct ROConfigState<Value>: DynamicProperty, ConfigWrapper {

    public var wrappedValue: Value {
        configs.get(key)
    }

    public let key: ROKey<Value>
    public let configs: Configs
    @StateObject private var observer: ConfigObserver<Value>

    public init(_ key: ROKey<Value>, configs: Configs) {
        self.key = key
        self.configs = configs
        _observer = StateObject(wrappedValue: ConfigObserver(configs: configs, key: key))
    }
}

/// SwiftUI property wrapper for read-write configuration values.
/// Automatically updates views when configuration changes.
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
@propertyWrapper
public struct RWConfigState<Value>: DynamicProperty, ConfigWrapper {

    public var wrappedValue: Value {
        get { configs.get(key) }
        nonmutating set { configs.set(key, newValue) }
    }

    public let key: RWKey<Value>
    public let configs: Configs
    @StateObject private var observer: ConfigObserver<Value>

    public init(_ key: RWKey<Value>, configs: Configs) {
        self.key = key
        self.configs = configs
        _observer = StateObject(wrappedValue: ConfigObserver(configs: configs, key: key))
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
@MainActor
private final class ConfigObserver<Value>: ObservableObject {

    private var cancellation: Cancellation?
    @Published var updater = false
    
    init<Access>(configs: Configs, key: Configs.Keys.Key<Value, Access>) {
        startObservingIfNeeded(configs: configs, key: key)
    }

    private func startObservingIfNeeded<Access>(configs: Configs, key: Configs.Keys.Key<Value, Access>) {
        guard cancellation == nil else { return }
        cancellation = configs.onChange(of: key) { @MainActor [weak self] newValue in
            self?.updater.toggle()
        }
    }

    deinit {
        cancellation?.cancel()
    }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
enum ConfigStatePreviews: PreviewProvider {
    
    static var previews: Previews {
        Previews()
    }
    
    struct Previews: View {

        @RWConfigState("counter", in: .inMemory) var counter = 0

        var body: some View {
            VStack {
                Text("\(counter)")
                    .font(.system(size: 200, weight: .medium))
                    .frame(maxHeight: .infinity)
                
                Spacer()
                    
                Button {
                    counter += 1
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                        .padding(20)
                        .font(.system(size: 60, weight: .regular))
                        .background(
                            Circle().fill(Color.blue)
                        )
                }
                .padding(40)
            }
        }
    }
}
#endif
