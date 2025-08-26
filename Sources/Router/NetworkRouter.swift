import Foundation

// MARK: - RequestMethod

/// HTTP request methods supported by the network router.
///
/// This enum defines all standard HTTP methods that can be used in network requests.
/// Each method corresponds to a specific HTTP verb with its intended semantics.
///
/// ## Usage
/// ```swift
/// struct MyEndpoint: NetworkRouter {
///     var method: RequestMethod? { .post }
///     // ... other properties
/// }
/// ```
///
/// ## HTTP Method Semantics
/// - **GET**: Retrieve data from the server
/// - **POST**: Submit data to be processed
/// - **PUT**: Replace or create a resource
/// - **PATCH**: Partially update a resource
/// - **DELETE**: Remove a resource
/// - **HEAD**: Get headers only (no body)
/// - **TRACE**: Diagnostic information about the request
public enum RequestMethod: String, Sendable {
    case get
    case post
    case put
    case patch
    case trace
    case delete
    case head
}

// MARK: - NetworkRouterError

/// Errors that can occur during network routing operations.
///
/// This enum defines specific errors that may occur when creating or processing
/// network requests through the router.
///
/// ## Error Types
/// - **invalidURL**: The constructed URL is invalid
/// - **encodingFailed**: Parameter encoding failed
///
/// ## Usage
/// ```swift
/// do {
///     let request = try endpoint.asURLRequest()
/// } catch NetworkRouterError.invalidURL {
///     // Handle invalid URL
/// } catch NetworkRouterError.encodingFailed {
///     // Handle encoding failure
/// }
/// ```
public enum NetworkRouterError: Error, Sendable {
    case invalidURL
    case encodingFailed
}

// MARK: - EmptyParameters

/// A placeholder struct for endpoints that don't require parameters.
///
/// This struct is used as the default associated type for `Parameters` and `QueryParameters`
/// in the `NetworkRouter` protocol when an endpoint doesn't need to send any data.
///
/// ## Usage
/// ```swift
/// struct GetUserEndpoint: NetworkRouter {
///     // Uses EmptyParameters by default for both params and queryParams
///     var path: String { "/users/123" }
///     var method: RequestMethod? { .get }
/// }
/// ```
public struct EmptyParameters: Codable {}

// MARK: - NetworkRouter

/// A protocol that defines the structure for network endpoints.
///
/// `NetworkRouter` provides a type-safe way to define API endpoints with associated
/// parameters, query parameters, headers, and other request configuration. It automatically
/// handles URL construction, parameter encoding, and request creation.
///
/// ## Overview
/// The protocol uses associated types to ensure type safety:
/// - `Parameters`: The body parameters for the request (POST, PUT, PATCH)
/// - `QueryParameters`: The query string parameters (GET, DELETE)
///
/// ## Key Features
/// - **Type Safety**: Associated types ensure parameter type safety
/// - **Automatic Encoding**: Parameters are automatically encoded based on HTTP method
/// - **Flexible Configuration**: Support for custom headers, API versions, and base URLs
/// - **Default Implementations**: Sensible defaults for common use cases
///
/// ## Usage Examples
///
/// ### Simple GET Request
/// ```swift
/// struct GetUsersEndpoint: NetworkRouter {
///     var baseURLString: String { "https://api.example.com" }
///     var path: String { "/users" }
///     var method: RequestMethod? { .get }
/// }
/// ```
///
/// ### POST Request with Parameters
/// ```swift
/// struct CreateUserEndpoint: NetworkRouter {
///     struct Parameters: Codable {
///         let name: String
///         let email: String
///     }
///     
///     var baseURLString: String { "https://api.example.com" }
///     var path: String { "/users" }
///     var method: RequestMethod? { .post }
///     var params: Parameters? { parameters }
///     
///     private let parameters: Parameters
///     init(name: String, email: String) {
///         self.parameters = Parameters(name: name, email: email)
///     }
/// }
/// ```
///
/// ### GET Request with Query Parameters
/// ```swift
/// struct SearchUsersEndpoint: NetworkRouter {
///     struct QueryParameters: Codable {
///         let query: String
///         let limit: Int
///     }
///     
///     var baseURLString: String { "https://api.example.com" }
///     var path: String { "/users/search" }
///     var method: RequestMethod? { .get }
///     var queryParams: QueryParameters? { queryParameters }
///     
///     private let queryParameters: QueryParameters
///     init(query: String, limit: Int = 10) {
///         self.queryParameters = QueryParameters(query: query, limit: limit)
///     }
/// }
/// ```
///
/// ### Request with Custom Headers
/// ```swift
/// struct AuthenticatedEndpoint: NetworkRouter {
///     var baseURLString: String { "https://api.example.com" }
///     var path: String { "/protected" }
///     var method: RequestMethod? { .get }
///     var headers: [String: String]? {
///         ["Authorization": "Bearer \(token)"]
///     }
///     
///     private let token: String
///     init(token: String) {
///         self.token = token
///     }
/// }
/// ```
///
/// ## Parameter Encoding
/// The router automatically handles parameter encoding based on the HTTP method:
/// - **GET/DELETE/HEAD**: Query parameters are encoded in the URL
/// - **POST/PUT/PATCH**: Body parameters are encoded as JSON (default) or form data
/// - **Form Data**: Use `ContentTypeHeaders.formData.value` in headers for form encoding
///
/// ## API Versioning
/// Support for API versioning through the `version` property:
/// ```swift
/// var version: APIVersion? { .v2 }
/// ```
public protocol NetworkRouter: Sendable {
    associatedtype Parameters: Codable = EmptyParameters
    associatedtype QueryParameters: Codable = EmptyParameters

    var baseURLString: String { get }
    var method: RequestMethod? { get }
    var path: String { get }
    var headers: [String: String]? { get }
    var params: Parameters? { get }
    var queryParams: QueryParameters? { get }
    var version: APIVersion? { get }
    func asURLRequest() throws -> URLRequest
}

// MARK: - Network Router Protocol Default Implementation

extension NetworkRouter {
    public var baseURLString: String {
        return ""
    }

    public var method: RequestMethod? {
        return .none
    }

    public var path: String {
        return ""
    }

    public var headers: [String: String]? {
        return nil
    }

    public var params: Parameters? {
        return nil
    }

    public var queryParams: QueryParameters? {
        return nil
    }

    public var version: APIVersion? {
        return nil
    }

    // MARK: URLRequestConvertible

    public func asURLRequest() throws -> URLRequest {
        let fullPath = baseURLString + (version?.path ?? "") + path
        guard let url = URL(string: fullPath) else {
            throw NetworkRouterError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method?.rawValue.uppercased()
        urlRequest.allHTTPHeaderFields = headers

        // Determine the encoding based on the HTTP method and headers
        switch method {
        case .delete, .get, .head:
            // For GET, DELETE, and HEAD, encode parameters in the query string if any
            if let queryParams = queryParams {
                let urlEncoding = URLEncoding(destination: .queryString)
                try urlEncoding.encode(&urlRequest, with: queryParams)
            }
        default:
            // For POST, PUT, PATCH, etc., check the content type to decide encoding
            if let contentType = headers?[ContentTypeHeaders.name],
                contentType == ContentTypeHeaders.formData.value
            {
                // Use URLEncoding for form-urlencoded content
                if let params = params {
                    let urlEncoding = URLEncoding(destination: .httpBody)
                    try urlEncoding.encode(&urlRequest, with: params)
                    urlRequest.setValue(
                        "application/x-www-form-urlencoded; charset=utf-8",
                        forHTTPHeaderField: "Content-Type")
                }
            } else {
                // Default to JSON encoding
                if let queryParams = queryParams {
                    try URLEncoding(destination: .queryString).encode(
                        &urlRequest, with: queryParams)
                }
                if let params = params {
                    try JSONEncoding().encode(&urlRequest, with: params)
                }
            }
        }

        return urlRequest
    }
}
