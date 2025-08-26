import Combine
import Foundation

/// A thread-safe wrapper for promises that makes them conform to the Sendable protocol.
///
/// ## Overview
/// `SendablePromise` is a utility struct that wraps promise closures to make them
/// thread-safe and conform to the `Sendable` protocol. This is particularly useful
/// in concurrent environments where promises need to be resolved from different threads.
///
/// ## Key Features
/// - **Thread Safety**: All operations are synchronized using a dedicated dispatch queue
/// - **Sendable Conformance**: Can be safely passed across thread boundaries
/// - **Promise Resolution**: Thread-safe promise resolution with Result type
/// - **Generic Support**: Works with any type that can be wrapped in a Result
///
/// ## Usage Examples
///
/// ### Basic Usage
/// ```swift
/// let promise = SendablePromise<MyResponse> { result in
///     switch result {
///     case .success(let response):
///         // Handle success
///     case .failure(let error):
///         // Handle error
///     }
/// }
///
/// // Resolve from any thread
/// DispatchQueue.global().async {
///     promise.resolve(.success(myResponse))
/// }
/// ```
///
/// ### In Network Operations
/// ```swift
/// let sendablePromise = SendablePromise(promise)
/// 
/// URLSession.shared.dataTask(with: request) { data, response, error in
///     if let error = error {
///         sendablePromise.resolve(.failure(.urlError(error)))
///     } else if let data = data {
///         do {
///             let decoded = try JSONDecoder().decode(T.self, from: data)
///             sendablePromise.resolve(.success(decoded))
///         } catch {
///             sendablePromise.resolve(.failure(.decodingError(error)))
///         }
///     }
/// }.resume()
/// ```
///
/// ### With Combine Publishers
/// ```swift
/// return Future<MyResponse, NetworkError> { promise in
///     let sendablePromise = SendablePromise(promise)
///     
///     // Start async operation
///     performAsyncOperation { result in
///         sendablePromise.resolve(result)
///     }
/// }
/// ```
///
/// ## Thread Safety
/// The struct uses a dedicated dispatch queue (`queue`) to ensure thread-safe access
/// to the underlying promise closure. All read and write operations are synchronized
/// to prevent race conditions.
///
/// ## Sendable Protocol
/// The struct conforms to `@unchecked Sendable`, meaning it's designed to be safe
/// for concurrent access, but the compiler doesn't verify this automatically.
/// The thread safety is implemented manually through proper synchronization.
///
/// ## Performance Considerations
/// - **Queue Overhead**: Each promise resolution involves queue synchronization
/// - **Memory Usage**: Minimal overhead for the wrapper and queue
/// - **Concurrent Access**: Safe for high-concurrency scenarios
///
/// ## Best Practices
/// - **Single Resolution**: Each promise should be resolved only once
/// - **Error Handling**: Always handle both success and failure cases
/// - **Thread Awareness**: Can be resolved from any thread safely
/// - **Memory Management**: Avoid strong reference cycles in promise closures
struct SendablePromise<T> {
    // MARK: Lifecycle

    /// Initializes a new SendablePromise with a promise closure.
    /// - Parameter promise: A closure that takes a Result and returns Void.
    ///   This closure will be called when the promise is resolved.
    init(_ promise: @escaping (Result<T, NetworkError>) -> Void) {
        _promise = promise
    }

    // MARK: Internal

    /// Resolves the promise with a result in a thread-safe manner.
    /// - Parameter result: The Result to resolve the promise with.
    ///   This can be called from any thread safely.
    func resolve(_ result: Result<T, NetworkError>) {
        promise(result)
    }

    // MARK: Private

    /// The underlying promise closure stored in a thread-safe manner.
    private var _promise: (Result<T, NetworkError>) -> Void
    
    /// Thread-safe access to the promise closure.
    private var promise: (Result<T, NetworkError>) -> Void {
        get {
            queue.sync {
                _promise
            }
        }
        set {
            queue.sync {
                _promise = newValue
            }
        }
    }
    
    /// Dedicated dispatch queue for thread synchronization.
    private let queue = DispatchQueue(label: "com.SendablePromise.queue")
}

// MARK: Sendable

/// Conformance to Sendable protocol for thread-safe usage.
/// The @unchecked modifier is used because thread safety is implemented manually.
extension SendablePromise: @unchecked Sendable {}
