import Foundation

// MARK: - ConnectionHeaders

/// HTTP Connection header values for controlling connection behavior.
///
/// ## Overview
/// `ConnectionHeaders` provides type-safe values for the HTTP Connection header,
/// which controls whether the connection should be kept alive or closed.
///
/// ## Usage Examples
///
/// ### Keep-Alive Connection
/// ```swift
/// let header = ConnectionHeaders.keepAlive
/// // Results in: "Connection: keep-alive"
/// ```
///
/// ### Close Connection
/// ```swift
/// let header = ConnectionHeaders.close
/// // Results in: "Connection: close"
/// ```
///
/// ### Custom Connection Value
/// ```swift
/// let header = ConnectionHeaders.custom("upgrade")
/// // Results in: "Connection: upgrade"
/// ```
///
/// ## Common Use Cases
/// - **keep-alive**: Maintain persistent connections for better performance
/// - **close**: Close connection after request completion
/// - **upgrade**: Upgrade connection (e.g., for WebSocket)
public enum ConnectionHeaders: Sendable {
    /// Keep the connection alive for subsequent requests
    case keepAlive
    /// Close the connection after the request
    case close
    /// Custom connection value
    case custom(String)

    /// The string value for the Connection header.
    public var value: String {
        switch self {
        case .keepAlive:
            return "keep-alive"
        case .close:
            return "close"
        case .custom(let customValue):
            return customValue
        }
    }

    /// The header name: "connection"
    public static var name: String {
        return "connection"
    }
}

// MARK: - AcceptHeaders

/// HTTP Accept header values for specifying acceptable response content types.
///
/// ## Overview
/// `AcceptHeaders` provides type-safe values for the HTTP Accept header,
/// which tells the server what content types the client can handle.
///
/// ## Usage Examples
///
/// ### Accept All Content Types
/// ```swift
/// let header = AcceptHeaders.all
/// // Results in: "Accept: */*"
/// ```
///
/// ### Accept JSON Only
/// ```swift
/// let header = AcceptHeaders.applicationJson
/// // Results in: "Accept: application/json"
/// ```
///
/// ### Accept JSON with UTF-8 Encoding
/// ```swift
/// let header = AcceptHeaders.applicationJsonUTF8
/// // Results in: "Accept: application/json; charset=utf-8"
/// ```
///
/// ### Accept Multiple Types
/// ```swift
/// let header = AcceptHeaders.combinedAll
/// // Results in: "Accept: application/json, text/plain, */*"
/// ```
///
/// ### Custom Accept Value
/// ```swift
/// let header = AcceptHeaders.custom("application/xml")
/// // Results in: "Accept: application/xml"
/// ```
public enum AcceptHeaders: Sendable {
    /// Accept all content types
    case all
    /// Accept JSON content
    case applicationJson
    /// Accept JSON content with UTF-8 encoding
    case applicationJsonUTF8
    /// Accept plain text content
    case text
    /// Accept multiple content types
    case combinedAll
    /// Custom accept value
    case custom(String)

    /// The string value for the Accept header.
    public var value: String {
        switch self {
        case .all:
            return "*/*"
        case .applicationJson:
            return "application/json"
        case .applicationJsonUTF8:
            return "application/json; charset=utf-8"
        case .text:
            return "text/plain"
        case .combinedAll:
            return "application/json, text/plain, */*"
        case .custom(let customValue):
            return customValue
        }
    }

    /// The header name: "accept"
    public static var name: String {
        return "accept"
    }
}

// MARK: - ContentTypeHeaders

/// HTTP Content-Type header values for specifying request content types.
///
/// ## Overview
/// `ContentTypeHeaders` provides type-safe values for the HTTP Content-Type header,
/// which tells the server what type of content is being sent in the request body.
///
/// ## Usage Examples
///
/// ### JSON Content
/// ```swift
/// let header = ContentTypeHeaders.applicationJson
/// // Results in: "Content-Type: application/json"
/// ```
///
/// ### JSON with UTF-8 Encoding
/// ```swift
/// let header = ContentTypeHeaders.applicationJsonUTF8
/// // Results in: "Content-Type: application/json; charset=utf-8"
/// ```
///
/// ### URL-Encoded Form Data
/// ```swift
/// let header = ContentTypeHeaders.urlEncoded
/// // Results in: "Content-Type: application/x-www-form-urlencoded"
/// ```
///
/// ### Multipart Form Data
/// ```swift
/// let header = ContentTypeHeaders.formData
/// // Results in: "Content-Type: multipart/form-data"
/// ```
///
/// ### Custom Content Type
/// ```swift
/// let header = ContentTypeHeaders.custom("application/xml")
/// // Results in: "Content-Type: application/xml"
/// ```
public enum ContentTypeHeaders: Sendable {
    /// JSON content type
    case applicationJson
    /// JSON content type with UTF-8 encoding
    case applicationJsonUTF8
    /// URL-encoded form data
    case urlEncoded
    /// Multipart form data
    case formData
    /// Custom content type
    case custom(String)

    /// The string value for the Content-Type header.
    public var value: String {
        switch self {
        case .applicationJson:
            return "application/json"
        case .applicationJsonUTF8:
            return "application/json; charset=utf-8"
        case .urlEncoded:
            return "application/x-www-form-urlencoded"
        case .formData:
            return "multipart/form-data"
        case .custom(let customValue):
            return customValue
        }
    }

    /// The header name: "content-type"
    public static var name: String {
        return "content-type"
    }
}

// MARK: - AcceptEncodingHeaders

/// HTTP Accept-Encoding header values for specifying acceptable content encodings.
///
/// ## Overview
/// `AcceptEncodingHeaders` provides type-safe values for the HTTP Accept-Encoding header,
/// which tells the server what content encodings the client can handle.
///
/// ## Usage Examples
///
/// ### Accept Gzip Compression
/// ```swift
/// let header = AcceptEncodingHeaders.gzip
/// // Results in: "Accept-Encoding: gzip"
/// ```
///
/// ### Accept All Encodings
/// ```swift
/// let header = AcceptEncodingHeaders.all
/// // Results in: "Accept-Encoding: *"
/// ```
///
/// ### Accept No Compression
/// ```swift
/// let header = AcceptEncodingHeaders.identity
/// // Results in: "Accept-Encoding: identity"
/// ```
///
/// ### Custom Encoding
/// ```swift
/// let header = AcceptEncodingHeaders.custom("gzip, deflate")
/// // Results in: "Accept-Encoding: gzip, deflate"
/// ```
///
/// ## Common Encodings
/// - **gzip**: GNU zip compression
/// - **compress**: Unix compress
/// - **deflate**: Deflate compression
/// - **br**: Brotli compression
/// - **identity**: No compression
public enum AcceptEncodingHeaders: Sendable {
    /// Accept gzip compression
    case gzip
    /// Accept compress compression
    case compress
    /// Accept deflate compression
    case deflate
    /// Accept Brotli compression
    case br
    /// Accept no compression (identity)
    case identity
    /// Accept all encodings
    case all
    /// Custom encoding value
    case custom(String)

    /// The string value for the Accept-Encoding header.
    public var value: String {
        switch self {
        case .gzip:
            return "gzip"
        case .compress:
            return "compress"
        case .deflate:
            return "deflate"
        case .br:
            return "br"
        case .identity:
            return "identity"
        case .all:
            return "*"
        case .custom(let customValue):
            return customValue
        }
    }

    /// The header name: "accept-encoding"
    public static var name: String {
        return "accept-encoding"
    }
}

// MARK: - AcceptLanguageHeaders

/// HTTP Accept-Language header values for specifying preferred languages.
///
/// ## Overview
/// `AcceptLanguageHeaders` provides type-safe values for the HTTP Accept-Language header,
/// which tells the server what languages the client prefers for responses.
///
/// ## Usage Examples
///
/// ### Accept English
/// ```swift
/// let header = AcceptLanguageHeaders.en
/// // Results in: "Accept-Language: en"
/// ```
///
/// ### Accept Persian/Farsi
/// ```swift
/// let header = AcceptLanguageHeaders.fa
/// // Results in: "Accept-Language: fa"
/// ```
///
/// ### Accept All Languages
/// ```swift
/// let header = AcceptLanguageHeaders.all
/// // Results in: "Accept-Language: *"
/// ```
///
/// ### Custom Language
/// ```swift
/// let header = AcceptLanguageHeaders.custom("en-US,en;q=0.9")
/// // Results in: "Accept-Language: en-US,en;q=0.9"
/// ```
public enum AcceptLanguageHeaders: Sendable {
    /// Accept English language
    case en
    /// Accept Persian/Farsi language
    case fa
    /// Accept all languages
    case all
    /// Custom language value
    case custom(String)

    /// The string value for the Accept-Language header.
    public var value: String {
        switch self {
        case .en:
            return "en"
        case .fa:
            return "fa"
        case .all:
            return "*"
        case .custom(let customValue):
            return customValue
        }
    }

    /// The header name: "accept-language"
    public static var name: String {
        return "accept-language"
    }
}

// MARK: - AuthorizationType

/// HTTP Authorization header values for authentication.
///
/// ## Overview
/// `AuthorizationType` provides type-safe values for the HTTP Authorization header,
/// supporting common authentication schemes like Bearer tokens and Basic auth.
///
/// ## Usage Examples
///
/// ### Bearer Token Authentication
/// ```swift
/// let header = AuthorizationType.bearer(token: "your-jwt-token")
/// // Results in: "Authorization: Bearer your-jwt-token"
/// ```
///
/// ### Basic Authentication
/// ```swift
/// let header = AuthorizationType.basic(username: "user", password: "pass")
/// // Results in: "Authorization: Basic dXNlcjpwYXNz" (base64 encoded)
/// ```
///
/// ### Custom Authorization
/// ```swift
/// let header = AuthorizationType.custom("Digest username=\"user\"")
/// // Results in: "Authorization: Digest username=\"user\""
/// ```
///
/// ## Security Considerations
/// - **Bearer Tokens**: Use HTTPS to protect tokens in transit
/// - **Basic Auth**: Credentials are base64 encoded but not encrypted
/// - **Token Storage**: Store tokens securely (Keychain, etc.)
/// - **Token Refresh**: Implement token refresh mechanisms
public enum AuthorizationType: Sendable {
    /// Bearer token authentication
    case bearer(token: String)
    /// Basic username/password authentication
    case basic(username: String, password: String)
    /// Custom authorization value
    case custom(String)

    /// The string value for the Authorization header.
    public var value: String {
        switch self {
        case .bearer(let token):
            return "Bearer \(token)"
        case .basic(let username, let password):
            let credentials = "\(username):\(password)"
            guard
                let encodedCredentials = credentials.data(using: .utf8)?
                    .base64EncodedString()
            else {
                return ""
            }
            return "Basic \(encodedCredentials)"
        case .custom(let customValue):
            return customValue
        }
    }

    /// The header name: "authorization"
    public static var name: String {
        return "authorization"
    }
}

// MARK: - HeaderHandler

/// A thread-safe builder for constructing HTTP headers.
///
/// ## Overview
/// `HeaderHandler` provides a fluent interface for building HTTP headers with
/// type-safe header values and thread-safe operations.
///
/// ## Key Features
/// - **Thread Safety**: All operations are synchronized
/// - **Fluent Interface**: Method chaining for easy header construction
/// - **Type Safety**: Type-safe header values prevent errors
/// - **Singleton Pattern**: Shared instance for global header management
/// - **Custom Headers**: Support for custom header names and values
///
/// ## Usage Examples
///
/// ### Basic Header Construction
/// ```swift
/// let headers = HeaderHandler.shared
///     .addContentTypeHeader(type: .applicationJson)
///     .addAcceptHeaders(type: .applicationJson)
///     .build()
/// ```
///
/// ### Authentication Headers
/// ```swift
/// let headers = HeaderHandler.shared
///     .addAuthorizationHeader(type: .bearer(token: "your-token"))
///     .addAcceptHeaders(type: .applicationJson)
///     .build()
/// ```
///
/// ### Complete Header Set
/// ```swift
/// let headers = HeaderHandler.shared
///     .addContentTypeHeader(type: .applicationJson)
///     .addAcceptHeaders(type: .applicationJson)
///     .addAcceptLanguageHeaders(type: .en)
///     .addAcceptEncodingHeaders(type: .gzip)
///     .addConnectionHeader(type: .keepAlive)
///     .addCustomHeader(name: "X-API-Key", value: "your-api-key")
///     .build()
/// ```
///
/// ### Custom Headers
/// ```swift
/// let headers = HeaderHandler.shared
///     .addCustomHeader(name: "X-Custom-Header", value: "custom-value")
///     .addCustomHeader(name: "X-Version", value: "1.0")
///     .build()
/// ```
///
/// ## Thread Safety
/// All header operations are thread-safe and can be called from any queue.
/// The handler uses a dedicated dispatch queue for synchronization.
///
/// ## Best Practices
/// - **Reuse Headers**: Use the shared instance for common headers
/// - **Type Safety**: Use provided enums instead of raw strings
/// - **Method Chaining**: Take advantage of the fluent interface
/// - **Custom Headers**: Use custom headers for API-specific requirements
public class HeaderHandler: @unchecked Sendable {
    // MARK: Lifecycle

    /// Private initializer for singleton pattern
    private init() { _headers = [:] }

    // MARK: Internal

    /// Shared instance for global header management
    public static let shared = HeaderHandler()

    /// Dedicated dispatch queue for thread synchronization
    private let queue = DispatchQueue(label: "com.headerHandler.queue")

    /// Adds a Content-Type header to the header collection.
    /// - Parameter type: The content type to add
    /// - Returns: Self for method chaining
    @discardableResult
    public func addContentTypeHeader(type: ContentTypeHeaders) -> HeaderHandler
    {
        queue.sync {
            _headers.updateValue(type.value, forKey: ContentTypeHeaders.name)
            return self
        }
    }

    /// Adds a Connection header to the header collection.
    /// - Parameter type: The connection type to add
    /// - Returns: Self for method chaining
    @discardableResult
    public func addConnectionHeader(type: ConnectionHeaders) -> HeaderHandler {
        queue.sync {
            _headers.updateValue(type.value, forKey: ConnectionHeaders.name)
            return self
        }
    }

    /// Adds an Accept header to the header collection.
    /// - Parameter type: The accept type to add
    /// - Returns: Self for method chaining
    @discardableResult
    public func addAcceptHeaders(type: AcceptHeaders) -> HeaderHandler {
        queue.sync {
            _headers.updateValue(type.value, forKey: AcceptHeaders.name)
            return self
        }
    }

    /// Adds an Accept-Language header to the header collection.
    /// - Parameter type: The language type to add
    /// - Returns: Self for method chaining
    @discardableResult
    public func addAcceptLanguageHeaders(type: AcceptLanguageHeaders)
        -> HeaderHandler
    {
        queue.sync {
            _headers.updateValue(type.value, forKey: AcceptLanguageHeaders.name)
            return self
        }
    }

    /// Adds an Accept-Encoding header to the header collection.
    /// - Parameter type: The encoding type to add
    /// - Returns: Self for method chaining
    @discardableResult
    public func addAcceptEncodingHeaders(type: AcceptEncodingHeaders)
        -> HeaderHandler
    {
        queue.sync {
            _headers.updateValue(type.value, forKey: AcceptEncodingHeaders.name)
            return self
        }
    }

    /// Adds an Authorization header to the header collection.
    /// - Parameter type: The authorization type to add
    /// - Returns: Self for method chaining
    @discardableResult
    public func addAuthorizationHeader(type: AuthorizationType) -> HeaderHandler
    {
        queue.sync {
            _headers.updateValue(type.value, forKey: AuthorizationType.name)
            return self
        }
    }

    /// Adds a custom header to the header collection.
    /// - Parameters:
    ///   - name: The header name
    ///   - value: The header value
    /// - Returns: Self for method chaining
    @discardableResult
    public func addCustomHeader(name: String, value: String) -> HeaderHandler {
        queue.sync {
            _headers.updateValue(value, forKey: name)
            return self
        }
    }

    /// Builds and returns the final header dictionary.
    /// - Returns: Dictionary of header name-value pairs
    public func build() -> [String: String] {
        return headers
    }

    // MARK: Private

    /// Internal storage for headers
    private var _headers: [String: String] = [:]
    
    /// Thread-safe access to headers
    private var headers: [String: String] {
        get {
            queue.sync {
                _headers
            }
        }
        set {
            queue.sync {
                _headers = newValue
            }
        }
    }
}
