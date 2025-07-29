// MARK: - RetryHandler.swift

import Combine
import Foundation

// MARK: - RetryHandler

/// A protocol defining the retry handling behavior for network requests.
public protocol RetryHandler: Sendable {
    /// The maximum number of retry attempts.
    var numberOfRetries: Int { get }
    func shouldRetry(request: URLRequest, error: NetworkError) -> Bool
    func modifyRequestForRetry(client: APIClient, request: URLRequest, error: NetworkError) -> (URLRequest, NetworkError?)
    func shouldRetryAsync(request: URLRequest, error: NetworkError) async -> Bool
    func modifyRequestForRetryAsync(client: APIClient, request: URLRequest, error: NetworkError) async throws -> URLRequest
    
}
