//
//  NetworkMonitor.swift
//  SRNetworkManager
//
//  Created by Siamak Rostami on 1/30/25.
//

import Combine
import Foundation
import Network

public final class NetworkMonitor: @unchecked Sendable {
    // MARK: - Public Properties
    
    /// A Combine publisher that emits changes to the network status.
    public var status: AnyPublisher<Connectivity, Never> {
        $_status.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    
    /// Current computed network status (WiFi, cellular, VPN, etc.).
    @Published private var _status: Connectivity = .disconnected
    
    private let monitor: NWPathMonitor
    private let monitorQueue: DispatchQueue
    private let vpnChecker: VPNChecking?
    private let lock = NSLock()
    
    /// For AsyncStream usage, we store continuations in a thread-safe manner
    private var asyncContinuations: [UUID: AsyncStream<Connectivity>.Continuation] = [:]
    
    // MARK: - Initialization
    
    public init(
        shouldDetectVpnAutomatically: Bool = true,
        queue: DispatchQueue? = nil
    ) {
        self.monitor = NWPathMonitor()
        self.monitorQueue = queue ?? DispatchQueue(
            label: "com.srnetworkmanager.networkmonitor.queue",
            qos: .userInitiated
        )
        self.vpnChecker = shouldDetectVpnAutomatically ? VPNChecker() : nil
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring network changes.
    public func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.updateStatus(with: path)
        }
        monitor.start(queue: monitorQueue)
    }
    
    /// Stop monitoring network changes.
    public func stopMonitoring() {
        monitor.cancel()
        
        // Thread-safely finish all continuations
        lock.lock()
        let continuations = asyncContinuations
        asyncContinuations.removeAll()
        lock.unlock()
        
        // Finish each continuation outside the lock
        continuations.values.forEach { $0.finish() }
    }
    
    /// Returns an AsyncStream emitting NetworkStatus updates whenever
    /// the NWPathMonitor sees a change.
    public func statusStream() -> AsyncStream<Connectivity> {
        AsyncStream { continuation in
            let id = UUID()
            
            // Add the continuation to our tracked continuations
            lock.lock()
            asyncContinuations[id] = continuation
            let currentStatus = _status
            lock.unlock()
            
            // Immediately send the current status
            continuation.yield(currentStatus)
            
            // Set up cleanup when the stream is cancelled
            continuation.onTermination = { [weak self] _ in
                guard let self = self else { return }
                
                self.lock.lock()
                self.asyncContinuations.removeValue(forKey: id)
                self.lock.unlock()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func updateStatus(with path: NWPath) {
        var newStatus: Connectivity
        
        // If there's no connection or requires a connection (inactive)
        guard path.status == .satisfied else {
            newStatus = .disconnected
            setStatus(newStatus)
            return
        }
        
        // Check for known VPN interfaces first
        if let vpnChecker = vpnChecker, vpnChecker.isVPNActive() {
            newStatus = .connected(.vpn)
        } else if path.usesInterfaceType(.wifi) {
            newStatus = .connected(.wifi)
        } else if path.usesInterfaceType(.cellular) {
            newStatus = .connected(.cellular)
        } else if path.usesInterfaceType(.wiredEthernet) {
            newStatus = .connected(.ethernet)
        } else {
            // Could be loopback, other, etc.
            newStatus = .connected(.other)
        }
        
        setStatus(newStatus)
    }
    
    /// Thread-safely set status (updates @Published, sends to async continuations)
    private func setStatus(_ newStatus: Connectivity) {
        // Capture current continuations under the lock
        lock.lock()
        let currentContinuations = asyncContinuations.values
        lock.unlock()
        
        // Update Combine publisher on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self._status = newStatus
        }
        
        // Notify all AsyncStream continuations without holding the lock
        currentContinuations.forEach { continuation in
            continuation.yield(newStatus)
        }
    }
}
