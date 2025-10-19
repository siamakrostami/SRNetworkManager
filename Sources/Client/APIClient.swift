import Combine
import Foundation

// MARK: - APIClient



/// A comprehensive, thread-safe API client for handling network requests with support for
/// both Combine and async/await programming models.
///
/// ## Overview
/// `APIClient` is the core component of SRNetworkManager that provides a unified interface
/// for making HTTP requests, handling responses, managing uploads, and implementing retry logic.
/// It's designed to be thread-safe and can handle concurrent requests efficiently.
///
/// ## Key Features
/// - **Dual Programming Models**: Support for both Combine and async/await
/// - **Thread Safety**: All operations are thread-safe with proper synchronization
/// - **Retry Logic**: Configurable retry strategies for failed requests
/// - **Upload Support**: File upload with progress tracking
/// - **Streaming**: Support for streaming responses
/// - **Logging**: Comprehensive request/response logging
/// - **Error Handling**: Rich error types with proper mapping
/// - **Session Management**: Automatic session lifecycle management
///
/// ## Thread Safety
/// The client uses a dedicated dispatch queue (`apiQueue`) for all operations to ensure
/// thread safety. All properties are accessed through thread-safe getters and setters,
/// and operations that modify shared state use barrier flags for proper synchronization.
///
/// ## Usage Examples
///
/// ### Basic Configuration
/// ```swift
/// let client = APIClient(
///     configuration: .default,
///     qos: .userInitiated,
///     logLevel: .verbose,
///     decoder: JSONDecoder(),
///     retryHandler: DefaultRetryHandler(numberOfRetries: 3)
/// )
/// ```
///
/// ### Making Requests
/// ```swift
/// // Combine
/// client.request(endpoint)
///     .sink(receiveCompletion: { ... }, receiveValue: { ... })
///     .store(in: &cancellables)
///
/// // Async/await
/// let response = try await client.request(endpoint)
/// ```
///
/// ### File Upload
/// ```swift
/// client.uploadRequest(endpoint, withName: "file", data: fileData) { progress in
///     print("Upload progress: \(progress)")
/// }
/// .sink(receiveCompletion: { ... }, receiveValue: { ... })
/// .store(in: &cancellables)
/// ```
///
/// ### Streaming
/// ```swift
/// client.streamRequest(endpoint)
///     .sink(receiveCompletion: { ... }, receiveValue: { chunk in
///         // Handle each chunk
///     })
///     .store(in: &cancellables)
/// ```
///
/// ## Error Handling
/// The client provides comprehensive error handling with automatic mapping of:
/// - Network errors (URLError)
/// - Decoding errors (DecodingError)
/// - Custom server errors
/// - Response errors
///
/// ## Retry Logic
/// Failed requests can be automatically retried based on configurable strategies:
/// - Number of retries
/// - Retry conditions
/// - Request modification for retries
///
/// ## Logging
/// Request and response logging can be configured with different levels:
/// - `.none`: No logging
/// - `.basic`: Basic request/response info
/// - `.verbose`: Detailed logging with headers and body
///
/// ## Session Management
/// The client automatically manages URLSession instances and provides methods to:
/// - Track active sessions
/// - Cancel all ongoing requests
/// - Invalidate sessions properly
public final class APIClient: @unchecked Sendable
{
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Initializes a new APIClient instance.
    /// - Parameters:
    ///   - configuration: An optional `URLSessionConfiguration` to use for sessions. Pass `nil` to use a default configuration.
    ///   - configurationDelegate: An optional `URLSessionDelegate` used when creating sessions.
    ///   - qos: The quality of service for the API queue. Default is `.background`.
    ///   - logLevel: The initial log level for request/response logging. Default is `.none`.
    ///   - defaultCacheStrategy: The default cache strategy applied to requests when no explicit policy is provided. Default is `.useProtocolCachePolicy`.
    ///   - decoder: The JSONDecoder used for decoding responses. Defaults to a new `JSONDecoder()`.
    ///   - retryHandler: The retry handler controlling retry behavior. Defaults to `DefaultRetryHandler(numberOfRetries: 0)`.
    public init(
        configuration: URLSessionConfiguration? = nil,
        configurationDelegate: URLSessionDelegate? = nil,
        qos: DispatchQoS = .background,
        logLevel: LogLevel = .none,
        defaultCacheStrategy: CacheStrategy = .useProtocolCachePolicy,
        decoder: JSONDecoder? = nil,
        retryHandler: RetryHandler? = nil
    ) {
        self._logLevel = logLevel
        self._defaultCacheStrategy = defaultCacheStrategy
        self.apiQueue = DispatchQueue(label: "com.apiQueue", qos: qos)
        self._decoder = decoder ?? JSONDecoder()
        self._retryHandler = retryHandler ?? DefaultRetryHandler(numberOfRetries: 0)
        self._configuration = configuration
        self._configurationDelegate = configurationDelegate
        self._requestsToRetry = []
        self._activeSessions = Set()
    }

    // MARK: Private

    // MARK: - Properties

    /// Queue for handling API operations
    private let apiQueue: DispatchQueue

    /// Current log level for request/response logging
       private var _logLevel: LogLevel
       
       /// Thread-safe access to log level
       private var logLevel: LogLevel {
           get { return apiQueue.sync { _logLevel } }
           set { apiQueue.sync { _logLevel = newValue } }
       }
       
    /// Backing storage for the session configuration used to build new URLSession instances.
    /// - Note: Access this via the thread-safe `configuration` computed property. Use
    ///   `updateConfiguration(_:delegate:)` to change it at runtime.
    private var _configuration: URLSessionConfiguration?
    
    /// Backing storage for the URLSession delegate used when creating sessions.
    /// - Note: Access this via the thread-safe `configurationDelegate` computed property.
    private var _configurationDelegate: URLSessionDelegate?
       
    /// Thread-safe access to the current URLSessionConfiguration used when building
    /// new sessions. If `nil`, a default configuration is used.
    private var configuration: URLSessionConfiguration? {
        get { return apiQueue.sync { _configuration } }
        set { apiQueue.sync { _configuration = newValue } }
    }
    
    /// Thread-safe access to the current URLSessionDelegate used for newly created sessions.
    private var configurationDelegate: URLSessionDelegate? {
        get { return apiQueue.sync { _configurationDelegate } }
        set { apiQueue.sync { _configurationDelegate = newValue } }
    }
       
    /// Backing storage for the retry handler which determines retry policy and request
    /// mutation across failures.
    private var _retryHandler: RetryHandler?
       
    /// Thread-safe access to the retry handler. Defaults to `DefaultRetryHandler(numberOfRetries: 0)`
    /// when not explicitly provided.
    private var retryHandler: RetryHandler {
        get { return apiQueue.sync { _retryHandler ?? DefaultRetryHandler(numberOfRetries: 0) } }
        set { apiQueue.sync { _retryHandler = newValue } }
    }
       
    /// Backing storage for requests queued for retry. Access only through thread-safe helpers.
    private var _requestsToRetry: [URLRequest]
       
    /// Thread-safe access to the queue of requests pending retry.
    private var requestsToRetry: [URLRequest] {
        get { return apiQueue.sync { _requestsToRetry } }
        set { apiQueue.sync(flags: .barrier) { _requestsToRetry = newValue } }
    }
       
    /// Appends a request to the retry queue in a thread-safe manner.
    private func appendRequestToRetry(_ request: URLRequest) {
        apiQueue.sync(flags: .barrier) {
            _requestsToRetry.append(request)
        }
    }
       
    /// Clears all requests from the retry queue in a thread-safe manner.
    private func clearRequestsToRetry() {
        apiQueue.sync(flags: .barrier) {
            _requestsToRetry.removeAll()
        }
    }
       
    /// Backing storage for the JSON decoder used for response decoding.
    private var _decoder: JSONDecoder
       
    /// Thread-safe access to the JSON decoder used for decoding server responses.
    private var decoder: JSONDecoder {
        get { return apiQueue.sync { _decoder } }
        set { apiQueue.sync { _decoder = newValue } }
    }
       
    /// Backing storage for currently active URLSession instances managed by the client.
    private var _activeSessions: Set<URLSession>
       
    /// Thread-safe access to the set of active URLSession instances.
    private var activeSessions: Set<URLSession> {
        get { return apiQueue.sync { _activeSessions } }
        set { apiQueue.sync(flags: .barrier) { _activeSessions = newValue } }
    }
       
    /// Tracks a newly created session in a thread-safe manner.
    private func addSession(_ session: URLSession) {
        apiQueue.async {
            self._activeSessions.insert(session)
        }
    }
       
    /// Removes a session from tracking in a thread-safe manner.
    private func removeSession(_ session: URLSession) {
        apiQueue.async {
            self._activeSessions.remove(session)
        }
    }
    
    /// Backing storage for the default cache strategy applied to requests that do not specify a policy.
    private var _defaultCacheStrategy: CacheStrategy = .useProtocolCachePolicy

    /// Backing storage for the shared URLCache configuration applied to newly created sessions.
    private var _cacheConfiguration: CacheConfiguration?

    /// Thread-safe access to the default cache strategy.
    private var defaultCacheStrategy: CacheStrategy {
        get { return apiQueue.sync { _defaultCacheStrategy } }
        set { apiQueue.sync { _defaultCacheStrategy = newValue } }
    }

    /// Thread-safe access to the cache configuration used to build a URLCache for new sessions.
    private var cacheConfiguration: CacheConfiguration? {
        get { return apiQueue.sync { _cacheConfiguration } }
        set { apiQueue.sync { _cacheConfiguration = newValue } }
    }
}

// MARK: - APIClient+CombineRequest

extension APIClient {
    // MARK: - Combine Network Request

    /// Performs a network request using Combine.
    /// - Parameter endpoint: The NetworkRouter defining the request.
    /// - Returns: A publisher that emits the decoded response or an error.
    public func request<T: Codable & Sendable>(_ endpoint: any NetworkRouter)
        -> AnyPublisher<T, NetworkError>
    {
        guard let urlRequest = try? endpoint.asURLRequest() else {
            return Fail(error: .unknown).eraseToAnyPublisher()
        }

        return makeRequest(urlRequest: urlRequest, retryCount: self.retryHandler.numberOfRetries)
    }

    /// Internal method to make the actual network request.
    private func makeRequest<T: Codable & Sendable>(
        urlRequest: URLRequest, retryCount: Int
    ) -> AnyPublisher<T, NetworkError> {
        URLSessionLogger.shared.logRequest(urlRequest, logLevel: logLevel)
        
        let session = configuredSession(delegate: configurationDelegate, configuration: configuration)
        
        return session.dataTaskPublisher(for: urlRequest)
            .subscribe(on: apiQueue)
            .tryMap { output in
                URLSessionLogger.shared.logResponse(
                    output.response, data: output.data, error: nil,
                    logLevel: self.logLevel)
                guard let httpResponse = output.response as? HTTPURLResponse
                else {
                    throw NetworkError.unknown
                }
                if 200..<300 ~= httpResponse.statusCode {
                    return output.data
                } else {
                    let error = self.mapErrorResponseToCustomErrorData(
                        output.data, statusCode: httpResponse.statusCode)
                    
                    URLSessionLogger.shared.logResponse(
                        output.response, data: output.data, error: error,
                        logLevel: self.logLevel)
                    throw error
                }
            }
            .decode(type: T.self, decoder: self.decoder)
            .mapError { error -> NetworkError in
                URLSessionLogger.shared.logResponse(
                    nil, data: nil, error: error, logLevel: self.logLevel)
                return self.mapErrorToNetworkError(error)
            }
            .catch { error -> AnyPublisher<T, NetworkError> in
                return self.handleRetry(
                    urlRequest: urlRequest, retryCount: retryCount, error: error
                )
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    /// Handles retry logic for failed requests.
    private func handleRetry<T: Codable & Sendable>(
        urlRequest: URLRequest, retryCount: Int, error: NetworkError
    ) -> AnyPublisher<T, NetworkError> {
        if retryCount > 0 && retryHandler.shouldRetry(request: urlRequest, error: error) {
            // Safely append to requestsToRetry
            appendRequestToRetry(urlRequest)
            
            // Safely get the last request
            let lastRequest = apiQueue.sync { _requestsToRetry.last ?? urlRequest }
            
            let (newUrlRequest, newError) = retryHandler.modifyRequestForRetry(
                client: self, request: lastRequest, error: error)
                
            if let newError = newError {
                return Fail(error: newError).eraseToAnyPublisher()
            }
            
            // Safely clear the requests
            clearRequestsToRetry()
            
            return makeRequest(urlRequest: newUrlRequest, retryCount: retryCount - 1)
        } else {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
}

extension APIClient {
    // MARK: - Combine Upload Request

    /// Performs a file upload request using Combine.
    /// - Parameters:
    ///   - endpoint: The NetworkRouter defining the request.
    ///   - withName: The name to be used for the file in the multipart form data.
    ///   - data: The file data to be uploaded.
    ///   - progressCompletion: A closure to handle upload progress updates.
    /// - Returns: A publisher that emits the decoded response or an error.
    public func uploadRequest<T: Codable & Sendable>(
        _ endpoint: any NetworkRouter, withName: String, data: Data?,
        progressCompletion: @escaping ProgressHandler
    ) -> AnyPublisher<T, NetworkError> {
        guard let urlRequest = try? endpoint.asURLRequest(), let file = data
        else {
            return Fail(error: NetworkError.unknown)
                .eraseToAnyPublisher()
        }

        return makeUploadRequest(
            urlRequest: urlRequest, params: endpoint.params, withName: withName,
            data: file, progressCompletion: progressCompletion, retryCount: self.retryHandler.numberOfRetries
        )
        .subscribe(on: apiQueue)
        .eraseToAnyPublisher()
    }

    /// Internal method to make the actual upload request.
    private func makeUploadRequest<T: Codable & Sendable>(
        urlRequest: URLRequest, params: Codable?, withName: String, data: Data,
        progressCompletion: @escaping ProgressHandler, retryCount: Int
    ) -> AnyPublisher<T, NetworkError> {
        URLSessionLogger.shared.logRequest(urlRequest, logLevel: logLevel)
        let (newUrlRequest, bodyData) = createBody(
            urlRequest: urlRequest, parameters: params, data: data,
            filename: withName)

        return Future<Data, NetworkError> { [weak self] promise in
            guard let self = self else {
                return
            }

            let sendablePromise = SendablePromise(promise)
            let progressDelegate = UploadProgressDelegate()
            progressDelegate.progressHandler = progressCompletion
            let session = self.configuredSession(
                delegate: configurationDelegate == nil ? progressDelegate : configurationDelegate, configuration: self.configuration)

            let task = session.uploadTask(with: newUrlRequest, from: bodyData) {
                data, response, error in
                URLSessionLogger.shared.logResponse(
                    response, data: data, error: error, logLevel: self.logLevel)

                if let error = error {
                    sendablePromise.resolve(
                        .failure(self.mapErrorToNetworkError(error)))
                } else if let httpResponse = response as? HTTPURLResponse,
                    let responseData = data
                {
                    if 200..<300 ~= httpResponse.statusCode {
                        sendablePromise.resolve(.success(responseData))
                    } else {
                        URLSessionLogger.shared.logResponse(
                            response, data: data, error: error,
                            logLevel: self.logLevel)
                        sendablePromise.resolve(
                            .failure(
                                self.mapErrorResponseToCustomErrorData(
                                    responseData,
                                    statusCode: httpResponse.statusCode)))
                    }
                } else {
                    URLSessionLogger.shared.logResponse(
                        response, data: data, error: error,
                        logLevel: self.logLevel)
                    sendablePromise.resolve(.failure(.unknown))
                }
            }

            task.resume()
        }
        .flatMap { [weak self] data -> AnyPublisher<T, NetworkError> in
            guard let self = self else {
                return Fail(error: .unknown).eraseToAnyPublisher()
            }
            return Just(data)
                .decode(type: T.self, decoder: self.decoder)
                .mapError { self.mapErrorToNetworkError($0) }
                .catch { error -> AnyPublisher<T, NetworkError> in
                    self.handleRetry(
                        urlRequest: urlRequest, retryCount: retryCount,
                        error: error)
                }
                .eraseToAnyPublisher()
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
}

extension APIClient {
    // MARK: - Async/Await Network Request

    /// Performs a network request using async/await.
    /// - Parameter endpoint: The NetworkRouter defining the request.
    /// - Returns: The decoded response.
    /// - Throws: A NetworkError if the request fails.
    public func request<T: Codable & Sendable>(_ endpoint: any NetworkRouter)
        async throws -> T
    {
        guard let urlRequest = try? endpoint.asURLRequest() else {
            throw NetworkError.unknown
        }

        return try await withCheckedThrowingContinuation {
            [weak self] continuation in
            guard let self = self else {
                continuation.resume(throwing: NetworkError.unknown)
                return
            }
            apiQueue.async {
                Task {
                    do {
                        let result: T = try await self.makeAsyncRequest(
                            urlRequest: urlRequest, retryCount: self.retryHandler.numberOfRetries)
                        continuation.resume(returning: result)
                    } catch let error as NetworkError {
                        continuation.resume(throwing: error)
                    } catch {
                        continuation.resume(
                            throwing: NetworkError.unknown)
                    }
                }
            }
        }
    }

    /// Internal method to make the actual async network request.
    private func makeAsyncRequest<T: Codable & Sendable>(
        urlRequest: URLRequest, retryCount: Int
    ) async throws -> T {
        URLSessionLogger.shared.logRequest(urlRequest, logLevel: logLevel)

        let session = configuredSession(delegate: configurationDelegate,configuration: configuration)

        do {
            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.unknown
            }

            URLSessionLogger.shared.logResponse(
                response, data: data, error: nil, logLevel: logLevel)

            if 200..<300 ~= httpResponse.statusCode {
                do {
                    // Use thread-safe decoder
                    let decodedResponse = try self.decoder.decode(T.self, from: data)
                    return decodedResponse
                } catch {
                    throw mapErrorToNetworkError(error)
                }
            } else {
                let error = mapErrorResponseToCustomErrorData(
                    data, statusCode: httpResponse.statusCode)
                throw error
            }
        } catch {
            return try await handleAsyncRetry(
                urlRequest: urlRequest, retryCount: retryCount, error: error)
        }
    }

    /// Handles retry logic for failed async requests.
    private func handleAsyncRetry<T: Codable & Sendable>(
        urlRequest: URLRequest, retryCount: Int, error: Error
    ) async throws -> T {
        let networkError = error as? NetworkError ?? mapErrorToNetworkError(error)

        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let shouldRetry = await retryHandler.shouldRetryAsync(
                        request: urlRequest, error: networkError)

                    if retryCount > 0 && shouldRetry {
                        // Use thread-safe method
                        appendRequestToRetry(urlRequest)
                        
                        // Safely access last request
                        let lastRequest = apiQueue.sync { _requestsToRetry.last ?? urlRequest }
                        
                        let newUrlRequest = try await retryHandler.modifyRequestForRetryAsync(
                            client: self,
                            request: lastRequest,
                            error: networkError)

                        // Use thread-safe method
                        clearRequestsToRetry()

                        do {
                            let result: T = try await makeAsyncRequest(
                                urlRequest: newUrlRequest, retryCount: retryCount - 1)
                            continuation.resume(returning: result)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    } else {
                        continuation.resume(throwing: networkError)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

extension APIClient {
    // MARK: - Async/Await Upload Request

    /// Performs a file upload request using async/await.
    /// - Parameters:
    ///   - endpoint: The NetworkRouter defining the request.
    ///   - withName: The name to be used for the file in the multipart form data.
    ///   - data: The file data to be uploaded.
    ///   - progressCompletion: A closure to handle upload progress updates.
    /// - Returns: The decoded response.
    /// - Throws: A NetworkError if the request fails.
    public func uploadRequest<T: Codable & Sendable>(
        _ endpoint: any NetworkRouter, withName: String, data: Data?,
        progressCompletion: @escaping ProgressHandler
    ) async throws -> T {
        guard let urlRequest = try? endpoint.asURLRequest(), let file = data
        else {
            throw NetworkError.unknown
        }

        return try await withCheckedThrowingContinuation {
            [weak self] continuation in
            guard let self = self else {
                continuation.resume(throwing: NetworkError.unknown)
                return
            }
            apiQueue.async {
                Task {
                    do {
                        let result: T = try await self.makeAsyncUploadRequest(
                            urlRequest: urlRequest, params: endpoint.params,
                            withName: withName, data: file,
                            progressCompletion: progressCompletion,
                            retryCount: self.retryHandler.numberOfRetries)
                        continuation.resume(returning: result)
                    } catch let error as NetworkError {
                        continuation.resume(throwing: error)
                    } catch {
                        continuation.resume(
                            throwing: NetworkError.unknown)
                    }
                }
            }
        }
    }

    /// Internal method to make the actual async upload request.
    private func makeAsyncUploadRequest<T: Codable & Sendable>(
        urlRequest: URLRequest, params: Codable?, withName: String, data: Data,
        progressCompletion: @escaping ProgressHandler, retryCount: Int
    ) async throws -> T {
        URLSessionLogger.shared.logRequest(urlRequest, logLevel: logLevel)
        let (newUrlRequest, bodyData) = createBody(
            urlRequest: urlRequest, parameters: params, data: data,
            filename: withName)

        let progressDelegate = UploadProgressDelegate()
        progressDelegate.progressHandler = progressCompletion
        let session = self.configuredSession(
            delegate: configurationDelegate == nil ? progressDelegate : configurationDelegate, configuration: self.configuration)

        do {
            let (data, response) = try await session.upload(
                for: newUrlRequest, from: bodyData)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.unknown
            }

            URLSessionLogger.shared.logResponse(
                response, data: data, error: nil, logLevel: logLevel)

            if 200..<300 ~= httpResponse.statusCode {
                do {
                    // Use thread-safe decoder
                    let decodedResponse = try self.decoder.decode(T.self, from: data)
                    return decodedResponse
                } catch {
                    throw mapErrorToNetworkError(error)
                }
            } else {
                let error = mapErrorResponseToCustomErrorData(
                    data, statusCode: httpResponse.statusCode)
                throw error
            }
        } catch {
            return try await handleAsyncRetry(
                urlRequest: urlRequest, retryCount: retryCount, error: error)
        }
    }
}

// MARK: - APIClient+CombineStreamRequest

extension APIClient {
    // MARK: - Combine Stream Request

    /// Performs a streaming network request using Combine.
    /// - Parameter endpoint: The NetworkRouter defining the request.
    /// - Returns: A publisher that emits decoded responses as they arrive or an error.
    public func streamRequest<T: Codable & Sendable>(_ endpoint: any NetworkRouter)
        -> AnyPublisher<T, NetworkError>
    {
        guard let urlRequest = try? endpoint.asURLRequest() else {
            return Fail(error: .unknown).eraseToAnyPublisher()
        }

        return makeStreamRequest(urlRequest: urlRequest)
    }

    /// Internal method to make the actual streaming network request.
    private func makeStreamRequest<T: Codable & Sendable>(urlRequest: URLRequest)
        -> AnyPublisher<T, NetworkError>
    {
        let sessionDelegate = StreamingSessionDelegate<T>()
        sessionDelegate.logLevel = logLevel
        let session = configuredSession(
            delegate: configurationDelegate == nil ? sessionDelegate: configurationDelegate, configuration: configuration)

        sessionDelegate.startRequest(session: session, urlRequest: urlRequest)

        return sessionDelegate.subject
            .mapError { [weak self] error in
                self?.mapErrorToNetworkError(error) ?? .unknown
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - StreamingSessionDelegate

private class StreamingSessionDelegate<T: Codable>: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    let subject = PassthroughSubject<T, Error>()
    private let queue = DispatchQueue(label: "com.streamingSessionDelegate.queue")
    private var _dataBuffer = Data()
    private var _logLevel: LogLevel = .none
    
    var dataBuffer: Data {
        get { queue.sync { _dataBuffer } }
        set { queue.sync { _dataBuffer = newValue } }
    }
    
    var logLevel: LogLevel {
        get { queue.sync { _logLevel } }
        set { queue.sync { _logLevel = newValue } }
    }
    
    func appendToBuffer(_ data: Data) {
        queue.sync { _dataBuffer.append(data) }
    }
    
    func removeFromBuffer(range: Range<Data.Index>) {
        queue.sync { _dataBuffer.removeSubrange(range) }
    }
    
    func startRequest(session: URLSession, urlRequest: URLRequest) {
        URLSessionLogger.shared.logRequest(urlRequest, logLevel: logLevel)
        let task = session.dataTask(with: urlRequest)
        task.resume()
    }

    func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        appendToBuffer(data)
        
        // Process buffer in a thread-safe way
        queue.sync {
            while let range = _dataBuffer.range(of: Data("\n".utf8)) {
                let lineData = _dataBuffer.subdata(
                    in: _dataBuffer.startIndex..<range.lowerBound)
                _dataBuffer.removeSubrange(_dataBuffer.startIndex..<range.upperBound)
                
                do {
                    let decoder = JSONDecoder()
                    let decodedObject = try decoder.decode(T.self, from: lineData)
                    subject.send(decodedObject)
                } catch {
                    subject.send(completion: .failure(error))
                    return
                }
            }
        }
    }
    
    func urlSession(
        _ session: URLSession, task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            URLSessionLogger.shared.logResponse(
                nil, data: nil, error: error, logLevel: logLevel)
            subject.send(completion: .failure(error))
        } else {
            // If there's any data left in buffer after the stream ends
            queue.sync {
                if !_dataBuffer.isEmpty {
                    do {
                        let decoder = JSONDecoder()
                        let decodedObject = try decoder.decode(
                            T.self, from: _dataBuffer)
                        subject.send(decodedObject)
                    } catch {
                        subject.send(completion: .failure(error))
                        return
                    }
                }
            }
            subject.send(completion: .finished)
        }
    }
}

// MARK: - APIClient+ErrorHandling

extension APIClient {
    // MARK: - Error Handling

    /// Maps a general Error to a NetworkError.
    private func mapErrorToNetworkError(_ error: Error) -> NetworkError {
        if let networkError = error as? NetworkError {
            return networkError
        }
        switch error {
        case let urlError as URLError:
            return .urlError(urlError)
        case let decodingError as DecodingError:
            return .decodingError(decodingError)
        default:
            return .responseError(error)
        }
    }

    /// Maps an error response to a NetworkError.
    private func mapErrorResponseToCustomErrorData(
        _ data: Data, statusCode: Int
    )
        -> NetworkError
    {
        return .customError(statusCode, data)
    }
}

// MARK: - APIClient+AsyncStreamRequest

extension APIClient {
    // MARK: - Async/Await Stream Request

    /// Performs a streaming network request using async/await.
    /// - Parameter endpoint: The NetworkRouter defining the request.
    /// - Returns: An AsyncThrowingStream that yields decoded responses as they arrive.
    @available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public func asyncStreamRequest<T: Codable & Sendable>(_ endpoint: any NetworkRouter)
        -> AsyncThrowingStream<T, Error>
    {
        guard let urlRequest = try? endpoint.asURLRequest() else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: NetworkError.unknown)
            }
        }

        return makeAsyncStreamRequest(urlRequest: urlRequest)
    }

    /// Internal method to make the actual async streaming network request.
    @available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    private func makeAsyncStreamRequest<T: Codable & Sendable>(urlRequest: URLRequest)
        -> AsyncThrowingStream<T, Error>
    {
        return AsyncThrowingStream { [weak self] continuation in
            guard let self = self else {
                continuation.finish(throwing: NetworkError.unknown)
                return
            }

            let session = self.configuredSession(delegate: configurationDelegate,
                configuration: self.configuration)

            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(
                        for: urlRequest)
                    URLSessionLogger.shared.logResponse(
                        response, data: nil, error: nil, logLevel: self.logLevel
                    )

                    var iterator = bytes.makeAsyncIterator()
                    var dataBuffer = Data()

                    while let chunk = try await iterator.next() {
                        dataBuffer.append(chunk)

                        while let range = dataBuffer.range(of: Data("\n".utf8))
                        {
                            let lineData = dataBuffer.subdata(
                                in: dataBuffer.startIndex..<range.lowerBound)
                            dataBuffer.removeSubrange(
                                dataBuffer.startIndex..<range.upperBound)

                            do {
                                let decoder = JSONDecoder()
                                let decodedObject = try decoder.decode(
                                    T.self, from: lineData)
                                continuation.yield(decodedObject)
                            } catch {
                                // Handle decoding error for this chunk
                                continuation.finish(throwing: error)
                                return
                            }
                        }
                    }

                    // If there's any data left in buffer after the stream ends
                    if !dataBuffer.isEmpty {
                        do {
                            let decoder = JSONDecoder()
                            let decodedObject = try decoder.decode(
                                T.self, from: dataBuffer)
                            continuation.yield(decodedObject)
                        } catch {
                            continuation.finish(throwing: error)
                            return
                        }
                    }

                    continuation.finish()
                } catch {
                    URLSessionLogger.shared.logResponse(
                        nil, data: nil, error: error, logLevel: self.logLevel)
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}

extension APIClient {
    // MARK: - Helper Methods

    /// Updates the client's URLSession configuration and optional delegate in a thread-safe manner.
    /// - Parameters:
    ///   - configuration: The new URLSessionConfiguration to apply. Pass `nil` to revert to default.
    ///   - delegate: An optional URLSessionDelegate to use for newly created sessions.
    ///   - invalidateExistingSessions: If true, invalidates and clears currently active sessions so
    ///     future requests use the new configuration immediately. Defaults to `true`.
    public func updateConfiguration(
        _ configuration: URLSessionConfiguration?,
        delegate: URLSessionDelegate? = nil,
        invalidateExistingSessions: Bool = true
    ) {
        apiQueue.sync(flags: .barrier) {
            self._configuration = configuration
            if let delegate = delegate {
                self._configurationDelegate = delegate
            }

            if invalidateExistingSessions {
                let sessions = self._activeSessions
                sessions.forEach { $0.invalidateAndCancel() }
                self._activeSessions.removeAll()
            }
        }
    }
    
    /// Updates the default cache strategy used for requests that don't specify a cache policy.
    /// - Parameter strategy: The new cache strategy to apply.
    public func updateDefaultCacheStrategy(_ strategy: CacheStrategy) {
        apiQueue.sync(flags: .barrier) {
            self._defaultCacheStrategy = strategy
        }
    }

    /// Updates the cache configuration. New sessions will install a URLCache built from this configuration.
    /// - Parameters:
    ///   - configuration: The cache configuration to use. Pass `nil` to remove a custom cache.
    ///   - invalidateExistingSessions: If true, invalidates and clears active sessions so that new sessions pick up the cache change immediately. Defaults to `false`.
    public func updateCacheConfiguration(_ configuration: CacheConfiguration?, invalidateExistingSessions: Bool = false) {
        apiQueue.sync(flags: .barrier) {
            self._cacheConfiguration = configuration
            if invalidateExistingSessions {
                let sessions = self._activeSessions
                sessions.forEach { $0.invalidateAndCancel() }
                self._activeSessions.removeAll()
            }
        }
    }

    /// Builds a URLSession using either the provided configuration/delegate or the client's
    /// current configuration/delegate. Tracks the session for later cancellation.
    private func configuredSession(
        delegate: URLSessionDelegate? = nil,
        configuration: URLSessionConfiguration? = nil
    ) -> URLSession {
        guard let configuration else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 120
            configuration.timeoutIntervalForResource = 120
            configuration.requestCachePolicy = defaultCacheStrategy.requestPolicy
            if let cacheConfig = cacheConfiguration {
                configuration.urlCache = cacheConfig.buildCache()
            }
            return URLSession(
                configuration: configuration, delegate: delegate,
                delegateQueue: nil)
        }
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        addSession(session)
        return session
    }

    /// Creates the body for a multipart form data request.
    private func createBody(
        urlRequest: URLRequest, parameters: Codable?, data: Data,
        filename: String
    ) -> (URLRequest, Data) {
        var newUrlRequest = urlRequest
        let boundary = "Boundary-\(UUID().uuidString)"
        let mime = MimeTypeDetector.detectMimeType(from: data)
        newUrlRequest.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type")

        var body = Data()

        if let parameters = parameters {
            do {
                let jsonData = try JSONEncoder().encode(parameters)
                if let jsonObject = try JSONSerialization.jsonObject(
                    with: jsonData) as? [String: Any]
                {
                    for (key, value) in jsonObject {
                        body.appendString("--\(boundary)\r\n")
                        body.appendString(
                            "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n"
                        )
                        body.appendString("\(value)\r\n")
                    }
                }
            } catch {
                print("Error encoding parameters: \(error)")
            }
        }

        body.appendString("--\(boundary)\r\n")
        body.appendString(
            "Content-Disposition: form-data; name=\"file\"; filename=\"\(filename).\(mime?.ext ?? "")\"\r\n"
        )
        body.appendString("Content-Type: \(mime?.mime ?? "")\r\n\r\n")
        body.append(data)
        body.appendString("\r\n")
        body.appendString("--\(boundary)--\r\n")

        return (newUrlRequest, body)
    }
}

// MARK: - Session Management

extension APIClient {
    private func trackSession(_ session: URLSession) {
        addSession(session)
    }

    /// Cancels all ongoing network requests
    func cancelAllRequests() {
        let sessionsToCancel = activeSessions
        apiQueue.sync(flags: .barrier) {
            sessionsToCancel.forEach { session in
                session.invalidateAndCancel()
            }
            _activeSessions.removeAll()
            _requestsToRetry.removeAll()
        }
    }
}

