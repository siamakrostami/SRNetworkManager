// MARK: - RetryHandler.swift

import Combine
import Foundation

// MARK: - RetryHandler

/// A protocol defining the retry handling behavior for network requests.
///
/// ## Overview
/// `RetryHandler` provides a flexible and extensible way to implement retry logic
/// for failed network requests. It allows customizing when to retry requests and
/// how to modify them for retry attempts.
///
/// ## Key Features
/// - **Configurable Retry Count**: Set maximum number of retry attempts
/// - **Conditional Retrying**: Define custom logic for when to retry
/// - **Request Modification**: Modify requests before retry (e.g., add headers, change parameters)
/// - **Async Support**: Both synchronous and asynchronous retry handling
/// - **Error-Based Decisions**: Make retry decisions based on specific error types
///
/// ## Usage Examples
///
/// ### Basic Retry Handler
/// ```swift
/// struct BasicRetryHandler: RetryHandler {
///     let numberOfRetries: Int
///     
///     func shouldRetry(request: URLRequest, error: NetworkError) -> Bool {
///         switch error {
///         case .urlError(let urlError):
///             return urlError.code == .notConnectedToInternet ||
///                    urlError.code == .timedOut
///         case .customError(let statusCode, _):
///             return statusCode >= 500 // Retry server errors
///         default:
///             return false
///         }
///     }
///     
///     func modifyRequestForRetry(client: APIClient, request: URLRequest, error: NetworkError) -> (URLRequest, NetworkError?) {
///         var newRequest = request
///         // Add retry header
///         newRequest.setValue("retry", forHTTPHeaderField: "X-Retry-Attempt")
///         return (newRequest, nil)
///     }
///     
///     func shouldRetryAsync(request: URLRequest, error: NetworkError) async -> Bool {
///         return shouldRetry(request: request, error: error)
///     }
///     
///     func modifyRequestForRetryAsync(client: APIClient, request: URLRequest, error: NetworkError) async throws -> URLRequest {
///         let (newRequest, _) = modifyRequestForRetry(client: client, request: request, error: error)
///         return newRequest
///     }
/// }
/// ```
///
/// ### Exponential Backoff Retry Handler
/// ```swift
/// struct ExponentialBackoffRetryHandler: RetryHandler {
///     let numberOfRetries: Int
///     private var retryCount = 0
///     
///     func shouldRetry(request: URLRequest, error: NetworkError) -> Bool {
///         guard retryCount < numberOfRetries else { return false }
///         
///         switch error {
///         case .urlError(let urlError):
///             return urlError.code == .timedOut ||
///                    urlError.code == .networkConnectionLost
///         case .customError(let statusCode, _):
///             return statusCode >= 500
///         default:
///             return false
///         }
///     }
///     
///     func modifyRequestForRetry(client: APIClient, request: URLRequest, error: NetworkError) -> (URLRequest, NetworkError?) {
///         retryCount += 1
///         var newRequest = request
///         
///         // Add exponential backoff delay
///         let delay = pow(2.0, Double(retryCount))
///         newRequest.setValue("\(delay)", forHTTPHeaderField: "X-Retry-Delay")
///         
///         return (newRequest, nil)
///     }
///     
///     func shouldRetryAsync(request: URLRequest, error: NetworkError) async -> Bool {
///         return shouldRetry(request: request, error: error)
///     }
///     
///     func modifyRequestForRetryAsync(client: APIClient, request: URLRequest, error: NetworkError) async throws -> URLRequest {
///         let (newRequest, _) = modifyRequestForRetry(client: client, request: request, error: error)
///         return newRequest
///     }
/// }
/// ```
///
/// ### Authentication Retry Handler
/// ```swift
/// struct AuthRetryHandler: RetryHandler {
///     let numberOfRetries: Int
///     private let authService: AuthenticationService
///     
///     func shouldRetry(request: URLRequest, error: NetworkError) -> Bool {
///         switch error {
///         case .customError(let statusCode, _):
///             return statusCode == 401 // Unauthorized
///         default:
///             return false
///         }
///     }
///     
///     func modifyRequestForRetry(client: APIClient, request: URLRequest, error: NetworkError) -> (URLRequest, NetworkError?) {
///         var newRequest = request
///         
///         // Refresh token and update authorization header
///         if let newToken = authService.refreshToken() {
///             newRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
///             return (newRequest, nil)
///         } else {
///             return (newRequest, NetworkError.customError(401, Data()))
///         }
///     }
///     
///     func shouldRetryAsync(request: URLRequest, error: NetworkError) async -> Bool {
///         return shouldRetry(request: request, error: error)
///     }
///     
///     func modifyRequestForRetryAsync(client: APIClient, request: URLRequest, error: NetworkError) async throws -> URLRequest {
///         let (newRequest, error) = modifyRequestForRetry(client: client, request: request, error: error)
///         if let error = error {
///             throw error
///         }
///         return newRequest
///     }
/// }
/// ```
///
/// ## Integration with APIClient
/// ```swift
/// let retryHandler = BasicRetryHandler(numberOfRetries: 3)
/// let client = APIClient(retryHandler: retryHandler)
/// 
/// client.request(endpoint)
///     .sink(receiveCompletion: { ... }, receiveValue: { ... })
///     .store(in: &cancellables)
/// ```
///
/// ## Best Practices
/// - **Limit Retry Attempts**: Avoid infinite retry loops
/// - **Exponential Backoff**: Implement delays between retries
/// - **Error-Specific Logic**: Only retry on appropriate errors
/// - **Request Modification**: Update requests appropriately for retries
/// - **Async Considerations**: Handle async operations properly in async methods
public protocol RetryHandler: Sendable {
    /// The maximum number of retry attempts.
    var numberOfRetries: Int { get }
    
    /// Determines whether a request should be retried based on the error.
    /// - Parameters:
    ///   - request: The original request that failed
    ///   - error: The error that occurred
    /// - Returns: `true` if the request should be retried, `false` otherwise
    func shouldRetry(request: URLRequest, error: NetworkError) -> Bool
    
    /// Modifies a request for retry and returns any error that should prevent retry.
    /// - Parameters:
    ///   - client: The APIClient instance
    ///   - request: The original request that failed
    ///   - error: The error that occurred
    /// - Returns: A tuple containing the modified request and an optional error
    func modifyRequestForRetry(client: APIClient, request: URLRequest, error: NetworkError) -> (URLRequest, NetworkError?)
    
    /// Asynchronous version of `shouldRetry`.
    /// - Parameters:
    ///   - request: The original request that failed
    ///   - error: The error that occurred
    /// - Returns: `true` if the request should be retried, `false` otherwise
    func shouldRetryAsync(request: URLRequest, error: NetworkError) async -> Bool
    
    /// Asynchronous version of `modifyRequestForRetry`.
    /// - Parameters:
    ///   - client: The APIClient instance
    ///   - request: The original request that failed
    ///   - error: The error that occurred
    /// - Returns: The modified request for retry
    /// - Throws: An error if the request should not be retried
    func modifyRequestForRetryAsync(client: APIClient, request: URLRequest, error: NetworkError) async throws -> URLRequest
}
