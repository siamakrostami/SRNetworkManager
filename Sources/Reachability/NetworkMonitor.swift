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
    // MARK: Lifecycle

    // MARK: - Init/Deinit

    public init(
        shouldDetectVpnAutomatically: Bool = true,
        queue: DispatchQueue? = nil
    ) {
        self.monitor = NWPathMonitor()
        self.monitorQueue =
            queue
            ?? DispatchQueue(
                label: "com.srnetworkmanager.networkmonitor.queue",
                qos: .userInitiated
            )
        self.vpnChecker = shouldDetectVpnAutomatically ? VPNChecker() : nil
    }

    deinit {
        stopMonitoring()
    }

    // MARK: Public

    /// A Combine publisher that emits changes to the network status.
    public var status: AnyPublisher<Connectivity, Never> {
        $_status.eraseToAnyPublisher()
    }

    // MARK: - Public Methods

    /// Start monitoring network changes.
    public func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else {
                return
            }
            self.updateStatus(with: path)
        }
        monitor.start(queue: monitorQueue)
    }

    /// Stop monitoring network changes.
    public func stopMonitoring() {
        monitor.cancel()
        asyncContinuation?.finish()
        asyncContinuation = nil
    }

    /// Returns an AsyncStream emitting NetworkStatus updates whenever
    /// the NWPathMonitor sees a change. This example only allows one concurrent
    /// stream at a time, for demonstration.
    public func statusStream() -> AsyncStream<Connectivity> {
        AsyncStream { continuation in
            // If there's already a continuation, finish the old one.
            if let existing = asyncContinuation {
                existing.finish()
            }
            asyncContinuation = continuation

            // Immediately send the current status
            continuation.yield(self._status)
        }
    }

    // MARK: Private

    /// Current computed network status (WiFi, cellular, VPN, etc.).
    @Published private var _status: Connectivity = .disconnected

    // MARK: - Private Properties

    private let monitor: NWPathMonitor
    private let monitorQueue: DispatchQueue
    private let vpnChecker: VPNChecking?

    /// For AsyncStream usage, we keep track of a single continuation for demonstration.
    /// For multiple concurrent consumers, you’d store multiple continuations.
    private var asyncContinuation: AsyncStream<Connectivity>.Continuation?

    // MARK: - Internal Update

    private func updateStatus(with path: NWPath) {
        var newStatus: Connectivity

        // If there's no connection or requires a connection (inactive)
        guard path.status == .satisfied else {
            newStatus = .disconnected
            DispatchQueue.main.async {
                self.setStatus(newStatus)
            }
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

        // Dispatch to main to publish changes
        DispatchQueue.main.async {
            self.setStatus(newStatus)
        }
    }

    /// Use a helper to set status (updates @Published, sends to async continuation, etc.)
    private func setStatus(_ newStatus: Connectivity) {
        debugPrint("altered status \(newStatus)")
        _status = newStatus
        asyncContinuation?.yield(newStatus)
    }
}
