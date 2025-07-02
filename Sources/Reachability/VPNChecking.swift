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

/// Protocol that describes a VPN checker.
public protocol VPNChecking: Sendable {
    func isVPNActive() -> Bool
}

// MARK: - VPNChecker

// A standalone class that detects VPN connections by checking system proxy settings.
// This class provides reliable VPN detection by monitoring system interfaces.
//
// Basic usage:
// ```swift
// let checker = VPNChecker()
// if checker.isVPNActive() {
//     print("VPN is connected")
// }
// ```
//

public final class VPNChecker: VPNChecking {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Initialize VPNChecker
    /// - Parameter shouldBypassVpnCheck: If true, VPN checking will be disabled and always return false
    ///
    /// Example:
    /// ```swift
    /// // Normal VPN checking
    /// let checker = VPNChecker()
    ///
    /// // Bypass VPN checking
    /// let bypassedChecker = VPNChecker(shouldBypassVpnCheck: true)
    /// ```
    public init(shouldBypassVpnCheck: Bool = false) {
        self.shouldBypassVpnCheck = shouldBypassVpnCheck
    }

    // MARK: Public

    // MARK: - Public Methods

    /// Checks if a VPN connection is currently active
    /// - Returns: True if a VPN connection is detected, false otherwise
    ///
    /// This method checks system proxy settings for known VPN interfaces.
    /// It's designed to be lightweight and can be called frequently.
    ///
    /// Example:
    /// ```swift
    /// let checker = VPNChecker()
    /// if checker.isVPNActive() {
    ///     print("VPN is active")
    /// }
    /// ```
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

    /// Determines whether VPN checking should be bypassed
    private let shouldBypassVpnCheck: Bool

    /// Set of known VPN interface prefixes
    private let vpnInterfaces = Set([
        "tap",
        "tun",
        "ppp",
        "ipsec",
        "ipsec0",
        "utun",
    ])

    // MARK: - Private Methods

#if !os(watchOS)
        /// Performs the actual VPN connection check
    private func checkVPNConnection() -> Bool {
        guard let proxySettings = fetchSystemProxySettings() else {
            return false
        }
        return hasVPNInterface(in: proxySettings)
    }

    /// Fetches system proxy settings safely
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

    /// Checks if any VPN interfaces are present in the settings
    private func hasVPNInterface(in settings: [String: Any]) -> Bool {
        settings.keys.contains { interfaceName in
            vpnInterfaces.contains { prefix in
                interfaceName.lowercased().starts(with: prefix)
            }
        }
    }
#endif
}
