import Foundation
import Network

/// Monitors network connectivity status
class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private(set) var isConnected: Bool
    private(set) var connectionType: ConnectionType = .unknown
    
    /// Callback for network status changes
    var onStatusChange: ((Bool) -> Void)?
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }
    
    private init() {
        monitor = NWPathMonitor()
        
        // Read the current path immediately so we know if we're offline on launch
        let initialPath = monitor.currentPath
        isConnected = (initialPath.status == .satisfied)
        updateConnectionType(initialPath)
        
        startMonitoring()
    }
    
    /// Start monitoring network changes
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            let newConnectionState = path.status == .satisfied
            let previousState = self?.isConnected ?? false
            
            self?.isConnected = newConnectionState
            self?.updateConnectionType(path)
            
            if previousState != newConnectionState {
                ARLog.debug("Network status changed: \(newConnectionState ? "connected" : "disconnected")")
                DispatchQueue.main.async {
                    self?.onStatusChange?(newConnectionState)
                }
            }
        }
        
        monitor.start(queue: queue)
    }
    
    /// Update the connection type based on the available interfaces
    private func updateConnectionType(_ path: NWPath) {
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }
    }
    
    /// Stop the network monitoring
    func stopMonitoring() {
        monitor.cancel()
    }
} 