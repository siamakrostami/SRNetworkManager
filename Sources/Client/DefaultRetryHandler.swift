//
//  BasicRetryHandler.swift
//  SRGenericNetworkLayer
//
//  Created by Siamak on 12/16/24.
//

// MARK: - DefaultRetryHandler.swift

import Foundation

/// A basic implementation of RetryHandler that provides simple retry functionality.
///
/// ## Overview
/// `DefaultRetryHandler` is a straightforward implementation of the `RetryHandler` protocol
/// that retries requests up to a specified number of times without any complex logic.
/// It serves as a simple fallback option when custom retry logic is not needed.
///
/// ## Behavior
/// - **Retry Decision**: Always retries if `numberOfRetries > 0`, regardless of error type
/// - **Request Modification**: No modification to the original request
/// - **Error Handling**: No additional error processing
/// - **Async Support**: Same behavior for both sync and async methods
///
/// ## Usage Examples
///
/// ### Basic Usage
/// ```swift
/// let retryHandler = DefaultRetryHandler(numberOfRetries: 3)
/// let client = APIClient(retryHandler: retryHandler)
/// 
/// client.request(endpoint)
///     .sink(receiveCompletion: { ... }, receiveValue: { ... })
///     .store(in: &cancellables)
/// ```
///
/// ### Zero Retries (No Retry)
/// ```swift
/// let retryHandler = DefaultRetryHandler(numberOfRetries: 0)
/// let client = APIClient(retryHandler: retryHandler)
/// // Requests will not be retried
/// ```
///
/// ### Multiple Retries
/// ```swift
/// let retryHandler = DefaultRetryHandler(numberOfRetries: 5)
/// let client = APIClient(retryHandler: retryHandler)
/// // Requests will be retried up to 5 times
/// ```
///
/// ## When to Use
/// - **Simple Applications**: When basic retry functionality is sufficient
/// - **Prototyping**: During development when complex retry logic isn't needed
/// - **Testing**: As a baseline for testing retry functionality
/// - **Fallback**: When custom retry handlers are not available
///
/// ## Limitations
/// - **No Error Filtering**: Retries on all errors, including client errors (4xx)
/// - **No Request Modification**: Original request is used without changes
/// - **No Backoff Strategy**: No delays between retry attempts
/// - **No Smart Logic**: Doesn't consider error types or request context
///
/// ## Customization
/// For more sophisticated retry behavior, consider implementing a custom `RetryHandler`:
/// - Filter retries based on error types
/// - Add exponential backoff delays
/// - Modify requests for retries (e.g., add headers)
/// - Handle authentication token refresh
///
/// ## Thread Safety
/// This implementation is thread-safe as it only contains immutable properties
/// and doesn't maintain any state between retry attempts.
public struct DefaultRetryHandler: RetryHandler {
    
    /// Determines whether a request should be retried.
    /// - Parameters:
    ///   - request: The original request that failed
    ///   - error: The error that occurred
    /// - Returns: `true` if `numberOfRetries > 0`, `false` otherwise
    public func shouldRetry(request: URLRequest, error: NetworkError) -> Bool {
        return numberOfRetries > 0
    }
    
    /// Modifies a request for retry.
    /// - Parameters:
    ///   - client: The APIClient instance
    ///   - request: The original request that failed
    ///   - error: The error that occurred
    /// - Returns: A tuple containing the original request and `nil` for the error
    public func modifyRequestForRetry(client: APIClient, request: URLRequest, error: NetworkError) -> (URLRequest, NetworkError?) {
        return (request, nil)
    }
    
    /// Asynchronous version of `shouldRetry`.
    /// - Parameters:
    ///   - request: The original request that failed
    ///   - error: The error that occurred
    /// - Returns: `true` if `numberOfRetries > 0`, `false` otherwise
    public func shouldRetryAsync(request: URLRequest, error: NetworkError) async -> Bool {
        return numberOfRetries > 0
    }
    
    /// Asynchronous version of `modifyRequestForRetry`.
    /// - Parameters:
    ///   - client: The APIClient instance
    ///   - request: The original request that failed
    ///   - error: The error that occurred
    /// - Returns: The original request without modifications
    public func modifyRequestForRetryAsync(client: APIClient, request: URLRequest, error: NetworkError) async throws -> URLRequest {
        return request
    }
    
    // MARK: Lifecycle

    /// Initializes a new DefaultRetryHandler with the specified number of retries.
    /// - Parameter numberOfRetries: The maximum number of retry attempts (0 for no retries)
    public init(numberOfRetries: Int) {
        self.numberOfRetries = numberOfRetries
    }

    // MARK: Public

    /// The maximum number of retry attempts.
    public let numberOfRetries: Int
}
