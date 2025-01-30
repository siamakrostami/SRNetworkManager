//
//  Connectivity.swift
//  SRNetworkManager
//
//  Created by Siamak Rostami on 1/30/25.
//


// MARK: - Connectivity

/// Represents the high-level connectivity state:
/// - `.disconnected` for no network.
/// - `.connected(NetworkStatus)` for a network connection of a specific type.
public enum Connectivity: Equatable, Sendable {
    case disconnected
    case connected(NetworkType)
}

// MARK: - NetworkStatus

/// Represents the underlying network interface type (WiFi, cellular, etc.).
public enum NetworkType: Equatable, Sendable {
    case wifi
    case cellular
    case ethernet
    case other
    case vpn
}
