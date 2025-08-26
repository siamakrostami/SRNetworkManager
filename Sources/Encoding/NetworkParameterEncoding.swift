import Foundation

// MARK: - EncodingError

/// Errors that can occur during parameter encoding operations.
///
/// ## Error Types
/// - **missingURL**: The URLRequest has no URL to encode parameters into
/// - **jsonEncodingFailed**: JSON encoding of parameters failed
///
/// ## Usage
/// ```swift
/// do {
///     try encoder.encode(&request, with: parameters)
/// } catch EncodingError.missingURL {
///     // Handle missing URL
/// } catch EncodingError.jsonEncodingFailed(let error) {
///     // Handle JSON encoding failure
/// }
/// ```
public enum EncodingError: Error, Sendable {
    /// The URLRequest has no URL to encode parameters into
    case missingURL
    /// JSON encoding of parameters failed
    case jsonEncodingFailed(error: Error)
}

// MARK: - NetworkParameterEncoding

/// A protocol defining the interface for encoding parameters in network requests.
///
/// ## Overview
/// `NetworkParameterEncoding` provides a unified interface for different parameter
/// encoding strategies. It supports encoding parameters into query strings, HTTP bodies,
/// or other request components based on the specific encoding implementation.
///
/// ## Key Features
/// - **Generic Support**: Works with any `Codable` type
/// - **Flexible Encoding**: Support for different encoding strategies
/// - **Error Handling**: Comprehensive error reporting
/// - **Thread Safety**: All implementations are thread-safe
///
/// ## Usage Examples
///
/// ### Basic Usage
/// ```swift
/// let encoder = JSONEncoding()
/// try encoder.encode(&request, with: userParameters)
/// ```
///
/// ### URL Encoding
/// ```swift
/// let encoder = URLEncoding(destination: .queryString)
/// try encoder.encode(&request, with: queryParameters)
/// ```
///
/// ## Implementation Requirements
/// - **encode**: Encode parameters into the URLRequest
/// - **Error Handling**: Throw appropriate EncodingError cases
/// - **Thread Safety**: Safe for concurrent access
public protocol NetworkParameterEncoding: Sendable {
    /// Encodes parameters into a URLRequest.
    /// - Parameters:
    ///   - urlRequest: The URLRequest to encode parameters into (modified in place)
    ///   - parameters: The parameters to encode (optional)
    /// - Throws: EncodingError if encoding fails
    func encode<T: Codable>(_ urlRequest: inout URLRequest, with parameters: T?)
        throws
}

// MARK: - URLEncoding

/// URL encoding implementation for query strings and form data.
///
/// ## Overview
/// `URLEncoding` provides flexible URL parameter encoding with support for
/// different destinations (query string, HTTP body, or method-dependent).
///
/// ## Key Features
/// - **Multiple Destinations**: Query string, HTTP body, or method-dependent
/// - **Automatic Method Detection**: Chooses encoding based on HTTP method
/// - **Nested Parameter Support**: Handles dictionaries and arrays
/// - **Proper Escaping**: URL-safe parameter encoding
///
/// ## Usage Examples
///
/// ### Query String Encoding
/// ```swift
/// let encoder = URLEncoding(destination: .queryString)
/// var request = URLRequest(url: URL(string: "https://api.example.com/users")!)
/// 
/// let params = ["name": "John", "age": 30]
/// try encoder.encode(&request, with: params)
/// // Results in: https://api.example.com/users?name=John&age=30
/// ```
///
/// ### Method-Dependent Encoding
/// ```swift
/// let encoder = URLEncoding(destination: .methodDependent)
/// var request = URLRequest(url: URL(string: "https://api.example.com/users")!)
/// 
/// // GET request - parameters in query string
/// request.httpMethod = "GET"
/// try encoder.encode(&request, with: params)
/// 
/// // POST request - parameters in HTTP body
/// request.httpMethod = "POST"
/// try encoder.encode(&request, with: params)
/// ```
///
/// ### Nested Parameters
/// ```swift
/// let nestedParams = [
///     "user": [
///         "name": "John",
///         "preferences": ["theme": "dark", "language": "en"]
///     ],
///     "filters": ["active", "verified"]
/// ]
/// 
/// try encoder.encode(&request, with: nestedParams)
/// // Results in: user[name]=John&user[preferences][theme]=dark&user[preferences][language]=en&filters[]=active&filters[]=verified
/// ```
///
/// ## Destination Types
/// - **methodDependent**: Automatically chooses based on HTTP method
/// - **queryString**: Always encodes in URL query string
/// - **httpBody**: Always encodes in HTTP body
public struct URLEncoding: NetworkParameterEncoding, Sendable {
    /// Defines where parameters should be encoded in the request.
    public enum Destination: Sendable {
        /// Automatically chooses encoding based on HTTP method
        case methodDependent
        /// Always encodes in URL query string
        case queryString
        /// Always encodes in HTTP body
        case httpBody
    }

    /// The destination for parameter encoding
    public var destination: Destination

    /// Initializes a new URLEncoding instance.
    /// - Parameter destination: Where to encode the parameters
    public init(destination: Destination = .methodDependent) {
        self.destination = destination
    }

    /// Encodes parameters into the URLRequest based on the destination.
    /// - Parameters:
    ///   - urlRequest: The URLRequest to encode parameters into
    ///   - parameters: The parameters to encode
    /// - Throws: EncodingError if encoding fails
    public func encode<T: Codable>(
        _ urlRequest: inout URLRequest, with parameters: T?
    ) throws {
        guard let parameters = parameters else { return }

        switch destination {
        case .methodDependent:
            if let method = RequestMethod(
                rawValue: urlRequest.httpMethod?.lowercased() ?? "get"),
                [.get, .delete, .head].contains(method)
            {
                try encodeQueryString(&urlRequest, with: parameters)
            } else {
                try encodeHttpBody(&urlRequest, with: parameters)
            }
        case .queryString:
            try encodeQueryString(&urlRequest, with: parameters)
        case .httpBody:
            try encodeHttpBody(&urlRequest, with: parameters)
        }
    }

    // MARK: Private

    /// Encodes parameters into the URL query string.
    /// - Parameters:
    ///   - urlRequest: The URLRequest to modify
    ///   - parameters: The parameters to encode
    /// - Throws: EncodingError.missingURL if URL is missing
    private func encodeQueryString<T: Codable>(
        _ urlRequest: inout URLRequest, with parameters: T
    ) throws {
        guard let url = urlRequest.url else {
            throw EncodingError.missingURL
        }

        let queryItems = try URLQueryEncoder().encode(parameters) 
        if var urlComponents = URLComponents(
            url: url, resolvingAgainstBaseURL: false), !queryItems.isEmpty
        {
            let percentEncodedQuery =
                (urlComponents.percentEncodedQuery.map { $0 + "&" } ?? "")
                + queryItems
            urlComponents.percentEncodedQuery = percentEncodedQuery
            urlRequest.url = urlComponents.url
        }
    }

    /// Encodes parameters into the HTTP body as JSON.
    /// - Parameters:
    ///   - urlRequest: The URLRequest to modify
    ///   - parameters: The parameters to encode
    /// - Throws: EncodingError.jsonEncodingFailed if JSON encoding fails
    private func encodeHttpBody<T: Codable>(
        _ urlRequest: inout URLRequest, with parameters: T
    ) throws {
        let jsonData = try JSONEncoder().encode(parameters)
        urlRequest.httpBody = jsonData
    }
}

// MARK: - JSONEncoding

/// JSON encoding implementation for HTTP body parameters.
///
/// ## Overview
/// `JSONEncoding` provides JSON-based parameter encoding for HTTP requests.
/// It automatically sets the Content-Type header to "application/json".
///
/// ## Key Features
/// - **JSON Encoding**: Converts parameters to JSON format
/// - **Automatic Headers**: Sets Content-Type to application/json
/// - **Codable Support**: Works with any Codable type
/// - **Error Handling**: Comprehensive error reporting
///
/// ## Usage Examples
///
/// ### Basic JSON Encoding
/// ```swift
/// let encoder = JSONEncoding()
/// var request = URLRequest(url: URL(string: "https://api.example.com/users")!)
/// 
/// let userData = User(name: "John", email: "john@example.com")
/// try encoder.encode(&request, with: userData)
/// 
/// // Sets Content-Type: application/json
/// // HTTP body: {"name":"John","email":"john@example.com"}
/// ```
///
/// ### Complex Object Encoding
/// ```swift
/// struct CreateUserRequest: Codable {
///     let user: User
///     let preferences: [String: String]
///     let isActive: Bool
/// }
/// 
/// let request = CreateUserRequest(
///     user: User(name: "John", email: "john@example.com"),
///     preferences: ["theme": "dark", "language": "en"],
///     isActive: true
/// )
/// 
/// try encoder.encode(&urlRequest, with: request)
/// ```
///
/// ## Error Handling
/// ```swift
/// do {
///     try encoder.encode(&request, with: parameters)
/// } catch EncodingError.jsonEncodingFailed(let error) {
///     print("JSON encoding failed: \(error)")
///     // Handle encoding failure
/// }
/// ```
public struct JSONEncoding: NetworkParameterEncoding, Sendable {
    /// Initializes a new JSONEncoding instance.
    public init() {}
    
    /// Encodes parameters as JSON in the HTTP body.
    /// - Parameters:
    ///   - urlRequest: The URLRequest to encode parameters into
    ///   - parameters: The parameters to encode as JSON
    /// - Throws: EncodingError.jsonEncodingFailed if JSON encoding fails
    public func encode<T: Codable>(
        _ urlRequest: inout URLRequest, with parameters: T?
    ) throws {
        guard let parameters = parameters else { return }

        do {
            let data = try JSONEncoder().encode(parameters)
            urlRequest.httpBody = data
            urlRequest.setValue(
                "application/json", forHTTPHeaderField: "Content-Type")
        } catch {
            throw EncodingError.jsonEncodingFailed(error: error)
        }
    }
}

// MARK: - URLQueryEncoder

/// A utility for encoding Codable objects into URL query strings.
///
/// ## Overview
/// `URLQueryEncoder` provides functionality to convert Codable objects into
/// URL query string format, supporting nested structures and arrays.
///
/// ## Key Features
/// - **Nested Support**: Handles dictionaries and arrays
/// - **Type Safety**: Works with any Codable type
/// - **Proper Escaping**: URL-safe parameter encoding
/// - **Sorted Keys**: Consistent output ordering
///
/// ## Usage Examples
///
/// ### Basic Encoding
/// ```swift
/// let encoder = URLQueryEncoder()
/// let params = ["name": "John", "age": 30]
/// let queryString = try encoder.encode(params)
/// // Results in: "age=30&name=John"
/// ```
///
/// ### Nested Dictionary Encoding
/// ```swift
/// let nestedParams = [
///     "user": [
///         "name": "John",
///         "profile": ["age": 30, "city": "New York"]
///     ]
/// ]
/// 
/// let queryString = try encoder.encode(nestedParams)
/// // Results in: "user[name]=John&user[profile][age]=30&user[profile][city]=New%20York"
/// ```
///
/// ### Array Encoding
/// ```swift
/// let arrayParams = [
///     "tags": ["swift", "ios", "networking"],
///     "numbers": [1, 2, 3]
/// ]
/// 
/// let queryString = try encoder.encode(arrayParams)
/// // Results in: "numbers[]=1&numbers[]=2&numbers[]=3&tags[]=swift&tags[]=ios&tags[]=networking"
/// ```
///
/// ## Encoding Rules
/// - **Simple Values**: `key=value`
/// - **Nested Dictionaries**: `key[subkey]=value`
/// - **Arrays**: `key[]=value1&key[]=value2`
/// - **Boolean Values**: `true`/`false` strings
/// - **URL Escaping**: Automatic percent encoding
public struct URLQueryEncoder {
    /// Encodes a Codable value into a URL query string.
    /// - Parameter value: The value to encode
    /// - Returns: The encoded query string
    /// - Throws: EncodingError if encoding fails
    func encode<T: Codable>(_ value: T) throws -> String {
        let jsonData = try JSONEncoder().encode(value)
        guard
            let jsonObject = try JSONSerialization.jsonObject(
                with: jsonData, options: []) as? [String: Any]
        else {
            throw EncodingError.jsonEncodingFailed(
                error: NSError(domain: "Invalid JSON", code: 1))
        }

        return query(from: jsonObject)
    }

    /// Converts a dictionary to a query string.
    /// - Parameter parameters: The dictionary to convert
    /// - Returns: The query string representation
    private func query(from parameters: [String: Any]) -> String {
        var components: [(String, String)] = []

        for key in parameters.keys.sorted(by: <) {
            let value = parameters[key]!
            components += queryComponents(fromKey: key, value: value)
        }
        return components.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
    }

    /// Recursively converts key-value pairs to query components.
    /// - Parameters:
    ///   - key: The current key
    ///   - value: The current value
    /// - Returns: Array of (key, value) tuples
    private func queryComponents(fromKey key: String, value: Any) -> [(
        String, String
    )] {
        var components: [(String, String)] = []

        if let dictionary = value as? [String: Any] {
            for (nestedKey, value) in dictionary {
                components += queryComponents(
                    fromKey: "\(key)[\(nestedKey)]", value: value)
            }
        } else if let array = value as? [Any] {
            for value in array {
                components += queryComponents(fromKey: "\(key)[]", value: value)
            }
        } else if let bool = value as? Bool {
            components.append((escape(key), escape(bool ? "true" : "false")))
        } else {
            components.append((escape(key), escape("\(value)")))
        }

        return components
    }

    /// Escapes a string for URL safety.
    /// - Parameter string: The string to escape
    /// - Returns: The URL-safe escaped string
    private func escape(_ string: String) -> String {
        return string.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed) ?? string
    }
}
