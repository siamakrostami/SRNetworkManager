//
//  NetworkMonitor.swift
//  SRNetworkManager
//
//  Created by Siamak Rostami on 1/30/25.
//

import Combine
import Foundation
import Network

/// A comprehensive network monitoring solution that tracks connectivity changes in real-time.
///
/// ## Overview
/// `NetworkMonitor` provides real-time monitoring of network connectivity changes using
/// Apple's Network framework. It supports both Combine and async/await patterns for
/// observing network status changes, including automatic VPN detection.
///
/// ## Key Features
/// - **Real-time Monitoring**: Instant notifications of network connectivity changes
/// - **Multiple Interfaces**: Support for WiFi, cellular, ethernet, VPN, and other connections
/// - **Dual Programming Models**: Both Combine publishers and AsyncStream support
/// - **Automatic VPN Detection**: Built-in VPN interface detection
/// - **Thread Safety**: Thread-safe operations with proper synchronization
/// - **Memory Management**: Automatic cleanup of resources
///
/// ## Usage Examples
///
/// ### Basic Monitoring with Combine
/// ```swift
/// let monitor = NetworkMonitor()
/// monitor.startMonitoring()
/// 
/// monitor.status
///     .sink { connectivity in
///         switch connectivity {
///         case .disconnected:
///             print("Network disconnected")
///         case .connected(let networkType):
///             print("Connected via \(networkType)")
///         }
///     }
///     .store(in: &cancellables)
/// ```
///
/// ### Async/Await Monitoring
/// ```swift
/// let monitor = NetworkMonitor()
/// monitor.startMonitoring()
/// 
/// Task {
///     for await connectivity in monitor.statusStream() {
///         switch connectivity {
///         case .disconnected:
///             await handleDisconnection()
///         case .connected(let networkType):
///             await handleConnection(networkType)
///         }
///     }
/// }
/// ```
///
/// ### Network-Aware Operations
/// ```swift
/// class NetworkAwareService {
///     private let monitor = NetworkMonitor()
///     private var cancellables = Set<AnyCancellable>()
///     
///     init() {
///         monitor.startMonitoring()
///         setupNetworkHandling()
///     }
///     
///     private func setupNetworkHandling() {
///         monitor.status
///             .sink { [weak self] connectivity in
///                 self?.handleConnectivityChange(connectivity)
///             }
///             .store(in: &cancellables)
///     }
///     
///     private func handleConnectivityChange(_ connectivity: Connectivity) {
///         switch connectivity {
///         case .disconnected:
///             pauseBackgroundTasks()
///             showOfflineIndicator()
///         case .connected(let networkType):
///             resumeBackgroundTasks()
///             hideOfflineIndicator()
///             
///             if networkType == .wifi {
///                 startLargeDownloads()
///             }
///         }
///     }
/// }
/// ```
///
/// ### VPN Detection
/// ```swift
/// let monitor = NetworkMonitor(shouldDetectVpnAutomatically: true)
/// monitor.startMonitoring()
/// 
/// monitor.status
///     .sink { connectivity in
///         if case .connected(.vpn) = connectivity {
///             print("VPN is active")
///             // Handle VPN-specific logic
///         }
///     }
///     .store(in: &cancellables)
/// ```
///
/// ### Custom Queue Configuration
/// ```swift
/// let customQueue = DispatchQueue(label: "custom.network.monitor", qos: .utility)
/// let monitor = NetworkMonitor(queue: customQueue)
/// monitor.startMonitoring()
/// ```
///
/// ### Integration with APIClient
/// ```swift
/// class NetworkAwareAPIClient {
///     private let client = APIClient()
///     private let monitor = NetworkMonitor()
///     private var pendingRequests: [() -> Void] = []
///     
///     init() {
///         monitor.startMonitoring()
///         setupNetworkHandling()
///     }
///     
///     private func setupNetworkHandling() {
///         monitor.status
///             .sink { [weak self] connectivity in
///                 if case .connected = connectivity {
///                     self?.processPendingRequests()
///                 }
///             }
///             .store(in: &cancellables)
///     }
///     
///     func makeRequest<T: Codable>(_ endpoint: NetworkRouter) -> AnyPublisher<T, NetworkError> {
///         if case .connected = monitor.currentStatus {
///             return client.request(endpoint)
///         } else {
///             // Queue the request for when network becomes available
///             return Future { promise in
///                 self.pendingRequests.append {
///                     self.client.request(endpoint)
///                         .sink(receiveCompletion: { promise($0) }, receiveValue: { promise(.success($0)) })
///                         .store(in: &self.cancellables)
///                 }
///             }
///             .eraseToAnyPublisher()
///         }
///     }
/// }
/// ```
///
/// ## Network Types Detected
/// - **WiFi**: Wireless local area network connections
/// - **Cellular**: Mobile network connections (3G, 4G, 5G, etc.)
/// - **Ethernet**: Wired network connections
/// - **VPN**: Virtual Private Network connections
/// - **Other**: Other network interface types
///
/// ## Thread Safety
/// The monitor uses proper synchronization mechanisms to ensure thread-safe
/// operations across multiple threads and concurrent access patterns.
///
/// ## Memory Management
/// - **Automatic Cleanup**: Resources are automatically cleaned up in deinit
/// - **Weak References**: Uses weak references to prevent retain cycles
/// - **Continuation Management**: Properly manages AsyncStream continuations
///
/// ## Performance Considerations
/// - **Efficient Monitoring**: Uses system-level network monitoring for efficiency
/// - **Minimal Overhead**: Low CPU and memory usage during monitoring
/// - **Background Operation**: Can operate in background queues
/// - **Battery Impact**: Minimal battery impact from monitoring
///
/// ## Best Practices
/// - **Start Early**: Start monitoring early in app lifecycle
/// - **Handle Disconnection**: Always handle disconnected states gracefully
/// - **Network Type Awareness**: Adapt behavior based on network type
/// - **Resource Cleanup**: Stop monitoring when no longer needed
/// - **Error Handling**: Handle network changes in UI updates
public final class NetworkMonitor: @unchecked Sendable {
    // MARK: - Public Properties
    
    /// A Combine publisher that emits changes to the network status.
    ///
    /// This publisher emits `Connectivity` values whenever the network status changes.
    /// It can be used with Combine's reactive programming model to handle network
    /// connectivity changes in a declarative way.
    ///
    /// ## Usage
    /// ```swift
    /// monitor.status
    ///     .sink { connectivity in
    ///         // Handle connectivity change
    ///     }
    ///     .store(in: &cancellables)
    /// ```
    public var status: AnyPublisher<Connectivity, Never> {
        $_status.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    
    /// Current computed network status (WiFi, cellular, VPN, etc.).
    @Published private var _status: Connectivity = .disconnected
    
    /// Network path monitor for system-level network monitoring
    private let monitor: NWPathMonitor
    /// Dedicated queue for network monitoring operations
    private let monitorQueue: DispatchQueue
    /// Optional VPN checker for VPN detection
    private let vpnChecker: VPNChecking?
    /// Thread synchronization lock
    private let lock = NSLock()
    
    /// For AsyncStream usage, we store continuations in a thread-safe manner
    private var asyncContinuations: [UUID: AsyncStream<Connectivity>.Continuation] = [:]
    
    // MARK: - Initialization
    
    /// Initializes a new NetworkMonitor instance.
    /// - Parameters:
    ///   - shouldDetectVpnAutomatically: Whether to automatically detect VPN connections
    ///   - queue: Custom dispatch queue for monitoring operations (optional)
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
    
    /// Deinitializer that ensures proper cleanup of monitoring resources
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring network changes.
    ///
    /// This method begins monitoring network connectivity changes. The monitor
    /// will start receiving updates about network status changes and will emit
    /// these changes through the status publisher and AsyncStream.
    ///
    /// ## Usage
    /// ```swift
    /// let monitor = NetworkMonitor()
    /// monitor.startMonitoring()
    /// 
    /// // Now the monitor will emit connectivity changes
    /// monitor.status.sink { ... }.store(in: &cancellables)
    /// ```
    public func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.updateStatus(with: path)
        }
        monitor.start(queue: monitorQueue)
    }
    
    /// Stop monitoring network changes.
    ///
    /// This method stops the network monitoring and cleans up all resources.
    /// It should be called when the monitor is no longer needed to prevent
    /// unnecessary resource usage.
    ///
    /// ## Usage
    /// ```swift
    /// // Stop monitoring when no longer needed
    /// monitor.stopMonitoring()
    /// ```
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
    ///
    /// This method provides an AsyncStream that can be used with async/await
    /// programming model to handle network connectivity changes.
    ///
    /// ## Usage
    /// ```swift
    /// Task {
    ///     for await connectivity in monitor.statusStream() {
    ///         // Handle connectivity change
    ///         await handleConnectivityChange(connectivity)
    ///     }
    /// }
    /// ```
    ///
    /// - Returns: An AsyncStream that emits Connectivity values
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
    
    /// Updates the network status based on the provided NWPath.
    /// - Parameter path: The network path information from NWPathMonitor
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
    /// - Parameter newStatus: The new connectivity status to set
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
