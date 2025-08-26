//
//  Connectivity.swift
//  SRNetworkManager
//
//  Created by Siamak Rostami on 1/30/25.
//

// MARK: - Connectivity

/// Represents the high-level connectivity state of the device.
///
/// ## Overview
/// `Connectivity` provides a simple way to represent whether the device has
/// network connectivity and what type of network connection is available.
/// This enum is used by the network monitoring system to track connectivity changes.
///
/// ## States
///
/// ### disconnected
/// The device has no network connectivity. This state indicates that the device
/// cannot reach any external networks and network requests will likely fail.
///
/// ### connected(NetworkType)
/// The device has network connectivity through a specific network interface.
/// The associated `NetworkType` value indicates the type of connection.
///
/// ## Usage Examples
///
/// ### Basic Connectivity Check
/// ```swift
/// switch connectivity {
/// case .disconnected:
///     print("No network connection available")
/// case .connected(let networkType):
///     print("Connected via \(networkType)")
/// }
/// ```
///
/// ### Network-Aware Operations
/// ```swift
/// func performNetworkOperation() {
///     switch connectivity {
///     case .disconnected:
///         showOfflineMessage()
///         return
///     case .connected(let networkType):
///         if networkType == .cellular {
///             showCellularWarning()
///         }
///         startNetworkRequest()
///     }
/// }
/// ```
///
/// ### Connectivity Monitoring
/// ```swift
/// networkMonitor.onConnectivityChange = { connectivity in
///     switch connectivity {
///     case .disconnected:
///         pauseBackgroundTasks()
///         showOfflineIndicator()
///     case .connected(let networkType):
///         resumeBackgroundTasks()
///         hideOfflineIndicator()
///         
///         if networkType == .wifi {
///             startLargeDownloads()
///         }
///     }
/// }
/// ```
///
/// ## Integration with NetworkManager
/// ```swift
/// let client = APIClient()
/// 
/// // Check connectivity before making requests
/// if case .connected = connectivity {
///     client.request(endpoint)
///         .sink(receiveCompletion: { ... }, receiveValue: { ... })
///         .store(in: &cancellables)
/// } else {
///     // Handle offline state
///     showOfflineMessage()
/// }
/// ```
///
/// ## Equatable and Sendable
/// The enum conforms to `Equatable` for easy comparison and `Sendable` for
/// safe concurrent usage across threads.
public enum Connectivity: Equatable, Sendable {
    /// No network connectivity available
    case disconnected
    /// Network connectivity available with specific network type
    case connected(NetworkType)
}

// MARK: - NetworkType

/// Represents the underlying network interface type.
///
/// ## Overview
/// `NetworkType` provides detailed information about the type of network
/// connection being used. This information can be used to make decisions
/// about network usage, such as whether to perform large downloads or
/// show warnings about data usage.
///
/// ## Network Types
///
/// ### wifi
/// Wireless local area network connection. Typically provides high bandwidth
/// and is often unmetered, making it suitable for large downloads and
/// bandwidth-intensive operations.
///
/// ### cellular
/// Mobile network connection (3G, 4G, 5G, etc.). May have data usage limits
/// and varying bandwidth. Consider showing warnings for large operations.
///
/// ### ethernet
/// Wired network connection. Provides stable, high-bandwidth connectivity
/// suitable for all types of network operations.
///
/// ### vpn
/// Virtual Private Network connection. May have bandwidth limitations or
/// routing restrictions depending on the VPN configuration.
///
/// ### other
/// Other network types not specifically categorized. This includes
/// connections that don't fit into the standard categories.
///
/// ## Usage Examples
///
/// ### Bandwidth-Aware Downloads
/// ```swift
/// func startDownload() {
///     switch networkType {
///     case .wifi, .ethernet:
///         // High bandwidth, start large downloads
///         downloadLargeFile()
///     case .cellular:
///         // Limited bandwidth, show warning
///         showCellularWarning {
///             downloadLargeFile()
///         }
///     case .vpn:
///         // VPN may have restrictions
///         checkVPNRestrictions()
///     case .other:
///         // Unknown network type, be conservative
///         downloadSmallFile()
///     }
/// }
/// ```
///
/// ### Data Usage Warnings
/// ```swift
/// func uploadLargeFile() {
///     if networkType == .cellular {
///         let alert = UIAlertController(
///             title: "Cellular Network",
///             message: "This upload will use cellular data. Continue?",
///             preferredStyle: .alert
///         )
///         // Show confirmation dialog
///     } else {
///         // Proceed without warning
///         startUpload()
///     }
/// }
/// ```
///
/// ### Network Quality Indicators
/// ```swift
/// func getNetworkQuality() -> NetworkQuality {
///     switch networkType {
///     case .wifi, .ethernet:
///         return .excellent
///     case .cellular:
///         return .good
///     case .vpn:
///         return .fair
///     case .other:
///         return .unknown
///     }
/// }
/// ```
///
/// ### Adaptive Content Loading
/// ```swift
/// func loadContent() {
///     switch networkType {
///     case .wifi, .ethernet:
///         // Load high-quality content
///         loadHighQualityImages()
///         enableAutoPlay()
///     case .cellular:
///         // Load optimized content
///         loadOptimizedImages()
///         disableAutoPlay()
///     case .vpn, .other:
///         // Load basic content
///         loadBasicContent()
///     }
/// }
/// ```
///
/// ## Network Type Detection
/// The network type is automatically detected by the system's network monitoring
/// capabilities. The detection is based on the active network interfaces and
/// their characteristics.
///
/// ## Best Practices
/// - **Cellular Warnings**: Always warn users before large operations on cellular
/// - **Bandwidth Adaptation**: Adjust content quality based on network type
/// - **Fallback Handling**: Handle unknown network types conservatively
/// - **User Preferences**: Respect user preferences for network usage
/// - **Battery Consideration**: Consider battery impact of network operations
///
/// ## Equatable and Sendable
/// The enum conforms to `Equatable` for easy comparison and `Sendable` for
/// safe concurrent usage across threads.
public enum NetworkType: Equatable, Sendable {
    /// Wireless local area network connection
    case wifi
    /// Mobile network connection (3G, 4G, 5G, etc.)
    case cellular
    /// Wired network connection
    case ethernet
    /// Other network types not specifically categorized
    case other
    /// Virtual Private Network connection
    case vpn
}
