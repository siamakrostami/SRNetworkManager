//
//  VPNChecking.swift
//  SRNetworkManager
//
//  Created by Siamak Rostami on 1/30/25.
//

#if canImport(CFNetwork) && !os(watchOS)
import CFNetwork
#endif
import Foundation

// MARK: - VPNChecking

/// A protocol that defines the interface for VPN connection detection.
///
/// ## Overview
/// `VPNChecking` provides a standardized way to detect VPN connections across
/// different platforms and implementations. This protocol allows for flexible
/// VPN detection strategies and easy testing through mock implementations.
///
/// ## Protocol Requirements
/// - **isVPNActive()**: Returns whether a VPN connection is currently active
///
/// ## Usage Examples
///
/// ### Basic VPN Detection
/// ```swift
/// let vpnChecker: VPNChecking = VPNChecker()
/// if vpnChecker.isVPNActive() {
///     print("VPN is connected")
/// }
/// ```
///
/// ### Mock Implementation for Testing
/// ```swift
/// class MockVPNChecker: VPNChecking {
///     private let isActive: Bool
///     
///     init(isActive: Bool) {
///         self.isActive = isActive
///     }
///     
///     func isVPNActive() -> Bool {
///         return isActive
///     }
/// }
/// 
/// // Use in tests
/// let mockChecker = MockVPNChecker(isActive: true)
/// ```
///
/// ### Conditional VPN Handling
/// ```swift
/// func handleNetworkRequest() {
///     if vpnChecker.isVPNActive() {
///         // Adjust request behavior for VPN
///         adjustRequestForVPN()
///     } else {
///         // Normal request handling
///         performNormalRequest()
///     }
/// }
/// ```
///
/// ## Platform Support
/// The protocol is designed to work across all Apple platforms, with
/// implementations that adapt to platform-specific capabilities.
public protocol VPNChecking: Sendable {
    /// Checks if a VPN connection is currently active.
    /// - Returns: `true` if a VPN connection is detected, `false` otherwise
    func isVPNActive() -> Bool
}

// MARK: - VPNChecker

/// A concrete implementation of VPNChecking that detects VPN connections by analyzing system proxy settings.
///
/// ## Overview
/// `VPNChecker` provides reliable VPN detection by monitoring system network interfaces
/// and proxy settings. It uses Apple's CFNetwork framework to access system-level
/// network configuration information.
///
/// ## Key Features
/// - **System-Level Detection**: Uses CFNetwork to access system proxy settings
/// - **Multiple Interface Support**: Detects various VPN interface types
/// - **Platform Compatibility**: Works across iOS, macOS, and tvOS
/// - **Lightweight**: Minimal performance impact
/// - **Configurable**: Can be bypassed for testing or specific use cases
///
/// ## Usage Examples
///
/// ### Basic VPN Detection
/// ```swift
/// let checker = VPNChecker()
/// if checker.isVPNActive() {
///     print("VPN is connected")
///     // Handle VPN-specific logic
/// }
/// ```
///
/// ### Bypass VPN Checking
/// ```swift
/// // Disable VPN checking (always returns false)
/// let bypassedChecker = VPNChecker(shouldBypassVpnCheck: true)
/// 
/// // This will always return false
/// let isVPNActive = bypassedChecker.isVPNActive()
/// ```
///
/// ### Integration with Network Monitoring
/// ```swift
/// let vpnChecker = VPNChecker()
/// let networkMonitor = NetworkMonitor(shouldDetectVpnAutomatically: true)
/// 
/// networkMonitor.status
///     .sink { connectivity in
///         if case .connected(.vpn) = connectivity {
///             print("VPN detected via network monitor")
///         }
///         
///         // Double-check with direct VPN checker
///         if vpnChecker.isVPNActive() {
///             print("VPN confirmed via direct check")
///         }
///     }
///     .store(in: &cancellables)
/// ```
///
/// ### VPN-Aware Network Operations
/// ```swift
/// class VPNAwareNetworkService {
///     private let vpnChecker = VPNChecker()
///     
///     func performNetworkOperation() {
///         if vpnChecker.isVPNActive() {
///             // Adjust behavior for VPN
///             adjustForVPN()
///         } else {
///             // Normal operation
///             performNormalOperation()
///         }
///     }
///     
///     private func adjustForVPN() {
///         // VPN-specific adjustments
///         // - Different timeout values
///         // - Alternative endpoints
///         // - Modified headers
///     }
/// }
/// ```
///
/// ### Testing with Mock VPN States
/// ```swift
/// class NetworkServiceTests {
///     func testVPNDetection() {
///         // Test with VPN active
///         let vpnActiveChecker = MockVPNChecker(isActive: true)
///         XCTAssertTrue(vpnActiveChecker.isVPNActive())
///         
///         // Test with VPN inactive
///         let vpnInactiveChecker = MockVPNChecker(isActive: false)
///         XCTAssertFalse(vpnInactiveChecker.isVPNActive())
///     }
/// }
/// ```
///
/// ## VPN Interface Detection
/// The checker detects VPN connections by looking for known VPN interface prefixes:
/// - **tap**: TAP (Ethernet) VPN interfaces
/// - **tun**: TUN (IP) VPN interfaces
/// - **ppp**: Point-to-Point Protocol interfaces
/// - **ipsec**: IPsec VPN interfaces
/// - **utun**: User-mode tunnel interfaces
///
/// ## Platform Support
/// - **iOS**: Full VPN detection support
/// - **macOS**: Full VPN detection support
/// - **tvOS**: Full VPN detection support
/// - **watchOS**: Returns false (no CFNetwork support)
///
/// ## Performance Considerations
/// - **Efficient**: Uses system-level APIs for fast detection
/// - **Lightweight**: Minimal memory and CPU usage
/// - **Cached**: System proxy settings are cached by the OS
/// - **Safe**: Graceful handling of unsupported platforms
///
/// ## Security Considerations
/// - **Privacy**: Only detects VPN presence, not VPN details
/// - **No Data Access**: Doesn't access VPN traffic or configuration
/// - **System-Level**: Uses official system APIs only
/// - **No Persistence**: Doesn't store VPN detection results
///
/// ## Best Practices
/// - **Regular Checks**: Check VPN status when network conditions change
/// - **Graceful Degradation**: Handle cases where VPN detection fails
/// - **User Privacy**: Respect user privacy when handling VPN detection
/// - **Testing**: Use mock implementations for unit testing
/// - **Platform Awareness**: Handle platform-specific limitations
public final class VPNChecker: VPNChecking {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Initialize VPNChecker with optional bypass configuration.
    /// - Parameter shouldBypassVpnCheck: If `true`, VPN checking will be disabled and always return `false`
    ///
    /// ## Usage Examples
    /// ```swift
    /// // Normal VPN checking
    /// let checker = VPNChecker()
    ///
    /// // Bypass VPN checking (always returns false)
    /// let bypassedChecker = VPNChecker(shouldBypassVpnCheck: true)
    /// ```
    public init(shouldBypassVpnCheck: Bool = false) {
        self.shouldBypassVpnCheck = shouldBypassVpnCheck
    }

    // MARK: Public

    // MARK: - Public Methods

    /// Checks if a VPN connection is currently active.
    ///
    /// This method analyzes system proxy settings to detect VPN interfaces.
    /// It's designed to be lightweight and can be called frequently without
    /// significant performance impact.
    ///
    /// ## How It Works
    /// 1. Fetches system proxy settings using CFNetwork
    /// 2. Analyzes interface names for known VPN prefixes
    /// 3. Returns true if VPN interfaces are detected
    ///
    /// ## Platform Behavior
    /// - **iOS/macOS/tvOS**: Full VPN detection
    /// - **watchOS**: Always returns false (no CFNetwork support)
    /// - **Bypass Mode**: Always returns false when bypassed
    ///
    /// ## Usage Examples
    /// ```swift
    /// let checker = VPNChecker()
    /// 
    /// if checker.isVPNActive() {
    ///     print("VPN is active")
    ///     // Handle VPN-specific logic
    /// } else {
    ///     print("No VPN detected")
    ///     // Handle normal network logic
    /// }
    /// ```
    ///
    /// - Returns: `true` if a VPN connection is detected, `false` otherwise
    public func isVPNActive() -> Bool {
        guard !shouldBypassVpnCheck else {
            return false
        }
#if os(watchOS)
        return false
#else
        return checkVPNConnection()
#endif
    }

    // MARK: Private

    // MARK: - Properties

    /// Determines whether VPN checking should be bypassed.
    /// When `true`, the checker will always return `false` regardless of actual VPN status.
    private let shouldBypassVpnCheck: Bool

    /// Set of known VPN interface prefixes used for detection.
    /// These prefixes are commonly used by VPN software to create virtual network interfaces.
    private let vpnInterfaces = Set([
        "tap",      // TAP (Ethernet) VPN interfaces
        "tun",      // TUN (IP) VPN interfaces
        "ppp",      // Point-to-Point Protocol interfaces
        "ipsec",    // IPsec VPN interfaces
        "ipsec0",   // IPsec VPN interface variant
        "utun",     // User-mode tunnel interfaces
    ])

    // MARK: - Private Methods

#if !os(watchOS)
    /// Performs the actual VPN connection check by analyzing system proxy settings.
    /// - Returns: `true` if VPN interfaces are detected, `false` otherwise
    private func checkVPNConnection() -> Bool {
        guard let proxySettings = fetchSystemProxySettings() else {
            return false
        }
        return hasVPNInterface(in: proxySettings)
    }

    /// Fetches system proxy settings safely using CFNetwork.
    /// - Returns: Dictionary of proxy settings or `nil` if unavailable
    private func fetchSystemProxySettings() -> [String: Any]? {
#if canImport(CFNetwork)
        guard let cfDict = CFNetworkCopySystemProxySettings(),
              let proxySettings = (cfDict.takeRetainedValue() as NSDictionary)
                as? [String: Any],
              let scoped = proxySettings["__SCOPED__"] as? [String: Any]
        else {
            return nil
        }
        return scoped
#else
        return nil
#endif
    }

    /// Checks if any VPN interfaces are present in the proxy settings.
    /// - Parameter settings: Dictionary of proxy settings to analyze
    /// - Returns: `true` if VPN interfaces are found, `false` otherwise
    private func hasVPNInterface(in settings: [String: Any]) -> Bool {
        settings.keys.contains { interfaceName in
            vpnInterfaces.contains { prefix in
                interfaceName.lowercased().starts(with: prefix)
            }
        }
    }
#endif
}
