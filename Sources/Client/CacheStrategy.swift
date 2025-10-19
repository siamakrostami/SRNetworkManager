//
//  CacheStrategy.swift
//  SRNetworkManager
//
//  Created by Siamak Rostami on 10/19/25.
//

import Foundation

/// A high-level description of how network responses should be cached.
///
/// `CacheStrategy` mirrors `URLRequest.CachePolicy` and is used to express
/// caching intent at the API level without directly depending on Foundation
/// policy values. Use the associated `requestPolicy` to apply the strategy
/// to a `URLRequest`.
///
/// Typical usage:
/// ```swift
/// var request = URLRequest(url: url)
/// request.cachePolicy = CacheStrategy.returnCacheDataElseLoad.requestPolicy
/// ```
public enum CacheStrategy: Sendable {
    /// Use the protocol-specified caching behavior (the system default).
    case useProtocolCachePolicy
    /// Ignore local cache and load from the origin server.
    case reloadIgnoringLocalCacheData
    /// Return cached data if available; otherwise load from the network.
    case returnCacheDataElseLoad
    /// Return cached data only; do not hit the network if no cache exists.
    case returnCacheDataDontLoad
    /// Revalidate cached data with the server before using it when possible.
    case reloadRevalidatingCacheData

    /// The corresponding Foundation `URLRequest.CachePolicy` for this strategy.
    public var requestPolicy: URLRequest.CachePolicy {
        switch self {
        case .useProtocolCachePolicy: return .useProtocolCachePolicy
        case .reloadIgnoringLocalCacheData: return .reloadIgnoringLocalCacheData
        case .returnCacheDataElseLoad: return .returnCacheDataElseLoad
        case .returnCacheDataDontLoad: return .returnCacheDataDontLoad
        case .reloadRevalidatingCacheData: return .reloadRevalidatingCacheData
        }
    }
}

/// Describes the shared `URLCache` capacities to install for networking.
///
/// Capacities are specified in bytes. Reasonable defaults are provided for
/// most apps (20 MB memory, 100 MB disk). Adjust these based on the size and
/// frequency of the responses your app handles.
public struct CacheConfiguration: Sendable {
    /// In-memory cache capacity, in bytes (e.g., 20 * 1024 * 1024 = 20 MB).
    public let memoryCapacity: Int
    /// On-disk cache capacity, in bytes (e.g., 100 * 1024 * 1024 = 100 MB).
    public let diskCapacity: Int
    /// Optional custom disk path for the cache. Pass `nil` to use the default.
    public let diskPath: String?

    /// Creates a cache configuration.
    /// - Parameters:
    ///   - memoryCapacity: In-memory capacity in bytes. The default `20 * 1024 * 1024` equals 20 MB.
    ///   - diskCapacity: On-disk capacity in bytes. The default `100 * 1024 * 1024` equals 100 MB.
    ///   - diskPath: Optional disk path. Use `nil` for the system default location.
    public init(
        memoryCapacity: Int = 20 * 1024 * 1024,
        diskCapacity: Int = 100 * 1024 * 1024,
        diskPath: String? = nil
    ) {
        self.memoryCapacity = memoryCapacity
        self.diskCapacity = diskCapacity
        self.diskPath = diskPath
    }

    /// A recommended default cache configuration (20 MB memory, 100 MB disk).
    public static let `default` = CacheConfiguration()

    /// Builds a `URLCache` instance using the configured capacities and path.
    func buildCache() -> URLCache {
        URLCache(
            memoryCapacity: memoryCapacity,
            diskCapacity: diskCapacity,
            diskPath: diskPath)
    }
}
