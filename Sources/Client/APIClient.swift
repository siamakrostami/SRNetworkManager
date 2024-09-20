import Combine
import Foundation

// MARK: - APIClient

/// A generic client for handling API requests with both Combine and async/await support.
public final class APIClient<ErrorType: CustomErrorProtocol>: @unchecked Sendable {
    // MARK: - Properties
    
    /// Queue for handling API operations
    private let apiQueue: DispatchQueue
    
    /// Current log level for request/response logging
    private var logLevel: LogLevel
    
    private var configuration: URLSessionConfiguration?
    
    /// Retry handler for failed requests
    private var _retryHandler: Interceptor<ErrorType> = Interceptor<ErrorType>(numberOfRetries: 0)
    
    /// Array to store requests that are to be retried
    private var requestsToRetry: [URLRequest] = []
    
    /// Thread-safe access to the retry handler
    private var retryHandler: Interceptor<ErrorType> {
        get {
            return apiQueue.sync { _retryHandler }
        }
        set {
            apiQueue.sync { _retryHandler = newValue }
        }
    }
    
    // MARK: - Initialization
    
    /// Initializes a new APIClient instance.
    /// - Parameters:
    ///   - qos: The quality of service for the API queue. Default is .background.
    ///   - logLevel: The initial log level for request/response logging. Default is .none.
    public init(configuration: URLSessionConfiguration? = nil,qos: DispatchQoS = .background, logLevel: LogLevel = .none) {
        self.logLevel = logLevel
        apiQueue = DispatchQueue(label: "com.apiQueue", qos: qos)
    }
    
    // MARK: - Configuration Methods
    
    /// Sets the retry handler for the API client.
    /// - Parameter interceptor: The interceptor to handle retries.
    /// - Returns: The APIClient instance for method chaining.
    @discardableResult
    public func set(interceptor: Interceptor<ErrorType>) -> Self {
        retryHandler = interceptor
        return self
    }
    
    /// Sets the log level for request/response logging.
    /// - Parameter level: The desired log level.
    /// - Returns: The APIClient instance for method chaining.
    @discardableResult
    public func setLog(level: LogLevel) -> Self {
        self.logLevel = level
        return self
    }
}


// MARK: - APIClient+CombineRequest

extension APIClient {
    // MARK: - Combine Network Request
    
    /// Performs a network request using Combine.
    /// - Parameter endpoint: The NetworkRouter defining the request.
    /// - Returns: A publisher that emits the decoded response or an error.
    public func request<T: Codable>(_ endpoint: any NetworkRouter) -> AnyPublisher<T, NetworkError<ErrorType>> {
        guard let urlRequest = try? endpoint.asURLRequest() else {
            return Fail(error: .unknown).eraseToAnyPublisher()
        }
        
        return makeRequest(urlRequest: urlRequest, retryCount: 3)
    }
    
    /// Internal method to make the actual network request.
    private func makeRequest<T: Codable>(urlRequest: URLRequest, retryCount: Int) -> AnyPublisher<T, NetworkError<ErrorType>> {
        URLSessionLogger.shared.logRequest(urlRequest, logLevel: logLevel)
        
        let session = configuredSession(configuration: configuration)
        
        return session.dataTaskPublisher(for: urlRequest)
            .subscribe(on: apiQueue)
            .tryMap { [weak self] output in
                URLSessionLogger.shared.logResponse(output.response, data: output.data, error: nil, logLevel: self?.logLevel)
                guard let httpResponse = output.response as? HTTPURLResponse else {
                    throw NetworkError<ErrorType>.unknown
                }
                if 200 ..< 300 ~= httpResponse.statusCode {
                    return output.data
                } else {
                    guard let error = self?.mapErrorResponse(output.data, statusCode: httpResponse.statusCode) else {
                        throw NetworkError<ErrorType>.unknown
                    }
                    URLSessionLogger.shared.logResponse(output.response, data: output.data, error: error, logLevel: self?.logLevel)
                    throw error
                }
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { [weak self] error -> NetworkError<ErrorType> in
                URLSessionLogger.shared.logResponse(nil, data: nil, error: error, logLevel: self?.logLevel)
                return self?.mapErrorToNetworkError(error) ?? .unknown
            }
            .catch { [weak self] error -> AnyPublisher<T, NetworkError<ErrorType>> in
                guard let self = self else {
                    return Fail(error: .unknown).eraseToAnyPublisher()
                }
                return self.handleRetry(urlRequest: urlRequest, retryCount: retryCount, error: error)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    /// Handles retry logic for failed requests.
    private func handleRetry<T: Codable>(urlRequest: URLRequest, retryCount: Int, error: NetworkError<ErrorType>) -> AnyPublisher<T, NetworkError<ErrorType>> {
        if retryCount > 0 && retryHandler.shouldRetry(request: urlRequest, error: error) {
            apiQueue.sync(flags: .barrier) {
                requestsToRetry.append(urlRequest)
            }
            let (newUrlRequest, newError) = retryHandler.modifyRequestForRetry(client: self, request: requestsToRetry.last ?? urlRequest, error: error)
            if let newError = newError {
                return Fail(error: newError).eraseToAnyPublisher()
            }
            apiQueue.sync(flags: .barrier) {
                requestsToRetry.removeAll()
            }
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
    public func uploadRequest<T: Codable>(_ endpoint: any NetworkRouter, withName: String, data: Data?, progressCompletion: @escaping ProgressHandler) -> AnyPublisher<T, NetworkError<ErrorType>> {
        guard let urlRequest = try? endpoint.asURLRequest(), let file = data else {
            return Fail(error: NetworkError<ErrorType>.unknown).eraseToAnyPublisher()
        }
        
        return makeUploadRequest(urlRequest: urlRequest, params: endpoint.params, withName: withName, data: file, progressCompletion: progressCompletion, retryCount: 3)
            .subscribe(on: apiQueue)
            .eraseToAnyPublisher()
    }
    
    /// Internal method to make the actual upload request.
    private func makeUploadRequest<T: Codable>(urlRequest: URLRequest, params: Codable?, withName: String, data: Data, progressCompletion: @escaping ProgressHandler, retryCount: Int) -> AnyPublisher<T, NetworkError<ErrorType>> {
        URLSessionLogger.shared.logRequest(urlRequest, logLevel: logLevel)
        let (newUrlRequest, bodyData) = createBody(urlRequest: urlRequest, parameters: params, data: data, filename: withName)
        
        return Future<Data, NetworkError<ErrorType>> { [weak self] (promise) in
            guard let self = self else { return }
            
            let sendablePromise = SendablePromise(promise)
            let progressDelegate = UploadProgressDelegate()
            progressDelegate.progressHandler = progressCompletion
            let session = self.configuredSession(delegate: progressDelegate,configuration: configuration)
            
            let task = session.uploadTask(with: newUrlRequest, from: bodyData) { (data, response, error) in
                URLSessionLogger.shared.logResponse(response, data: data, error: error, logLevel: self.logLevel)
                
                // Ensure that this part is Sendable-safe
                if let error = error {
                    sendablePromise.resolve(.failure(self.mapErrorToNetworkError(error)))
                } else if let httpResponse = response as? HTTPURLResponse, let responseData = data {
                    if 200..<300 ~= httpResponse.statusCode {
                        sendablePromise.resolve(.success(responseData))
                    } else {
                        URLSessionLogger.shared.logResponse(response, data: data, error: error, logLevel: self.logLevel)
                        sendablePromise.resolve(.failure(self.mapErrorResponse(responseData, statusCode: httpResponse.statusCode)))
                    }
                } else {
                    URLSessionLogger.shared.logResponse(response, data: data, error: error, logLevel: self.logLevel)
                    sendablePromise.resolve(.failure(.unknown))
                }
            }
            
            task.resume()
        }
        .flatMap { [weak self] data -> AnyPublisher<T, NetworkError<ErrorType>> in
            guard let self = self else {
                return Fail(error: .unknown).eraseToAnyPublisher()
            }
            return Just(data)
                .decode(type: T.self, decoder: JSONDecoder())
                .mapError { self.mapErrorToNetworkError($0) }
                .catch { error -> AnyPublisher<T, NetworkError<ErrorType>> in
                    self.handleRetry(urlRequest: urlRequest, retryCount: retryCount, error: error)
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
    public func asyncRequest<T: Codable>(_ endpoint: any NetworkRouter) async throws -> T {
        guard let urlRequest = try? endpoint.asURLRequest() else {
            throw NetworkError<ErrorType>.unknown
        }
        
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(throwing: NetworkError<ErrorType>.unknown)
                return
            }
            apiQueue.async {
                Task {
                    do {
                        let result: T = try await self.makeAsyncRequest(urlRequest: urlRequest, retryCount: 3)
                        continuation.resume(returning: result)
                    } catch let error as NetworkError<ErrorType> {
                        continuation.resume(throwing: error)
                    } catch {
                        continuation.resume(throwing: NetworkError<ErrorType>.unknown)
                    }
                }
            }
        }
    }
    
    /// Internal method to make the actual async network request.
    private func makeAsyncRequest<T: Codable>(urlRequest: URLRequest, retryCount: Int) async throws -> T {
        URLSessionLogger.shared.logRequest(urlRequest, logLevel: logLevel)
        
        let session = configuredSession(configuration: configuration)
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError<ErrorType>.unknown
            }
            
            URLSessionLogger.shared.logResponse(response, data: data, error: nil, logLevel: logLevel)
            
            if 200 ..< 300 ~= httpResponse.statusCode {
                do {
                    let decodedResponse = try JSONDecoder().decode(T.self, from: data)
                    return decodedResponse
                } catch {
                    throw mapErrorToNetworkError(error)
                }
            } else {
                let error = mapErrorResponse(data, statusCode: httpResponse.statusCode)
                throw error
            }
        } catch {
            return try await handleAsyncRetry(urlRequest: urlRequest, retryCount: retryCount, error: error)
        }
    }
    
    /// Handles retry logic for failed async requests.
    private func handleAsyncRetry<T: Codable>(urlRequest: URLRequest, retryCount: Int, error: Error) async throws -> T {
        let networkError = error as? NetworkError<ErrorType> ?? mapErrorToNetworkError(error)
        
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let shouldRetry = await retryHandler.shouldRetryAsync(request: urlRequest, error: networkError)
                    
                    if retryCount > 0 && shouldRetry {
                        apiQueue.sync(flags: .barrier) {
                            requestsToRetry.append(urlRequest)
                        }
                        
                        let newUrlRequest = try await retryHandler.modifyRequestForRetryAsync(client: self, request: requestsToRetry.last ?? urlRequest, error: networkError)
                        
                        apiQueue.sync(flags: .barrier) {
                            requestsToRetry.removeAll()
                        }
                        
                        do {
                            let result: T = try await makeAsyncRequest(urlRequest: newUrlRequest, retryCount: retryCount - 1)
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
    public func asyncUploadRequest<T: Codable>(_ endpoint: any NetworkRouter, withName: String, data: Data?, progressCompletion: @escaping ProgressHandler) async throws -> T {
        guard let urlRequest = try? endpoint.asURLRequest(), let file = data else {
            throw NetworkError<ErrorType>.unknown
        }
        
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(throwing: NetworkError<ErrorType>.unknown)
                return
            }
            apiQueue.async {
                Task {
                    do {
                        let result: T = try await self.makeAsyncUploadRequest(urlRequest: urlRequest, params: endpoint.params, withName: withName, data: file, progressCompletion: progressCompletion, retryCount: 3)
                        continuation.resume(returning: result)
                    } catch let error as NetworkError<ErrorType> {
                        continuation.resume(throwing: error)
                    } catch {
                        continuation.resume(throwing: NetworkError<ErrorType>.unknown)
                    }
                }
            }
        }
    }
    
    /// Internal method to make the actual async upload request.
    private func makeAsyncUploadRequest<T: Codable>(urlRequest: URLRequest, params: Codable?, withName: String, data: Data, progressCompletion: @escaping ProgressHandler, retryCount: Int) async throws -> T {
        URLSessionLogger.shared.logRequest(urlRequest, logLevel: logLevel)
        let (newUrlRequest, bodyData) = createBody(urlRequest: urlRequest, parameters: params, data: data, filename: withName)
        
        let progressDelegate = UploadProgressDelegate()
        progressDelegate.progressHandler = progressCompletion
        let session = configuredSession(delegate: progressDelegate,configuration: configuration)
        
        do {
            let (data, response) = try await session.upload(for: newUrlRequest, from: bodyData)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError<ErrorType>.unknown
            }
            
            URLSessionLogger.shared.logResponse(response, data: data, error: nil, logLevel: logLevel)
            
            if 200 ..< 300 ~= httpResponse.statusCode {
                do {
                    let decodedResponse = try JSONDecoder().decode(T.self, from: data)
                    return decodedResponse
                } catch {
                    throw mapErrorToNetworkError(error)
                }
            } else {
                let error = mapErrorResponse(data, statusCode: httpResponse.statusCode)
                throw error
            }
        } catch {
            return try await handleAsyncRetry(urlRequest: urlRequest, retryCount: retryCount, error: error)
        }
    }
    
}

// MARK: - APIClient+ErrorHandling

extension APIClient {
    // MARK: - Error Handling
    
    /// Maps a general Error to a NetworkError.
    private func mapErrorToNetworkError(_ error: Error) -> NetworkError<ErrorType> {
        if let networkError = error as? NetworkError<ErrorType> {
            return networkError
        }
        switch error {
        case let urlError as URLError:
            return .urlError(urlError)
        case let decodingError as DecodingError:
            return .decodingError(decodingError)
        default:
            return .unknown
        }
    }
    
    /// Maps an error response to a NetworkError.
    private func mapErrorResponse(_ data: Data, statusCode: Int) -> NetworkError<ErrorType> {
        do {
            let errorResponse = try JSONDecoder().decode(ErrorType.self, from: data)
            return .customError(errorResponse)
        } catch {
            // If we can't decode the custom error type, we'll create a default ErrorResponse
            let defaultError = GeneralErrorResponse(
                code: statusCode,
                details: String(data: data, encoding: .utf8) ?? "No details available",
                message: HTTPURLResponse.localizedString(forStatusCode: statusCode),
                path: "",
                timestamp: ISO8601DateFormatter().string(from: Date())
            )
            return .customError(defaultError as! ErrorType)
        }
    }
    
}

extension APIClient {
    // MARK: - Helper Methods
    
    /// Configures and returns a URLSession.
    private func configuredSession(delegate: URLSessionDelegate? = nil, configuration: URLSessionConfiguration? = nil) -> URLSession {
        guard let configuration else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 120
            configuration.timeoutIntervalForResource = 120
            configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        }
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }
    
    /// Creates the body for a multipart form data request.
    private func createBody(urlRequest: URLRequest, parameters: Codable?, data: Data, filename: String) -> (URLRequest, Data) {
        var newUrlRequest = urlRequest
        let boundary = "Boundary-\(UUID().uuidString)"
        let mime = MimeTypeDetector.detectMimeType(from: data)
        newUrlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        if let parameters = parameters {
            do {
                let jsonData = try JSONEncoder().encode(parameters)
                if let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    for (key, value) in jsonObject {
                        body.appendString("--\(boundary)\r\n")
                        body.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
                        body.appendString("\(value)\r\n")
                    }
                }
            } catch {
                print("Error encoding parameters: \(error)")
            }
        }
        
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename).\(mime?.ext ?? "")\"\r\n")
        body.appendString("Content-Type: \(mime?.mime ?? "")\r\n\r\n")
        body.append(data)
        body.appendString("\r\n")
        body.appendString("--\(boundary)--\r\n")
        
        return (newUrlRequest, body)
    }
}
