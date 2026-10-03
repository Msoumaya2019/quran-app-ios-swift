import Foundation
import Network

@MainActor final class ConnectivityService: ObservableObject {
    @Published private(set) var isOffline = false
    private let monitor = NWPathMonitor()
    var onAvailable: (() -> Void)?
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let available = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                let wasOffline = self.isOffline
                self.isOffline = !available
                if available && wasOffline { self.onAvailable?() }
            }
        }
        monitor.start(queue: DispatchQueue(label: "native.network.monitor"))
    }
    deinit { monitor.cancel() }
}
