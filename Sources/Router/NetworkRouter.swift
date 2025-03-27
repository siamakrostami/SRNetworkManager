import Foundation

// MARK: - RequestMethod

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

public enum NetworkRouterError: Error, Sendable {
    case invalidURL
    case encodingFailed
}

// MARK: - EmptyParameters

public struct EmptyParameters: Codable {}

// MARK: - NetworkRouter

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
