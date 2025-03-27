import Combine
import Foundation

/// A struct that wraps a promise to make it Sendable.
struct SendablePromise<T> {
    // MARK: Lifecycle

    /// Initializes a new SendablePromise.
    /// - Parameter promise: A closure that takes a Result and returns Void.
    init(_ promise: @escaping (Result<T, NetworkError>) -> Void) {
        _promise = promise
    }

    // MARK: Internal

    /// Resolves the promise with a result.
    /// - Parameter result: The Result to resolve the promise with.
    func resolve(_ result: Result<T, NetworkError>) {
        promise(result)
    }

    // MARK: Private

    /// The underlying promise closure.
    private var _promise: (Result<T, NetworkError>) -> Void
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
    private let queue = DispatchQueue(label: "com.SendablePromise.queue")
}

// MARK: Sendable

extension SendablePromise: @unchecked Sendable {}
