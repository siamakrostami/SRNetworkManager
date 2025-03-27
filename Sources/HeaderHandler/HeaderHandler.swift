import Foundation

// MARK: - ConnectionHeaders

public enum ConnectionHeaders: Sendable {
    case keepAlive
    case close
    case custom(String)

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

    public static var name: String {
        return "connection"
    }
}

// MARK: - AcceptHeaders

public enum AcceptHeaders: Sendable {
    case all
    case applicationJson
    case applicationJsonUTF8
    case text
    case combinedAll
    case custom(String)

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

    public static var name: String {
        return "accept"
    }
}

// MARK: - ContentTypeHeaders

public enum ContentTypeHeaders: Sendable {
    case applicationJson
    case applicationJsonUTF8
    case urlEncoded
    case formData
    case custom(String)

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

    public static var name: String {
        return "content-type"
    }
}

// MARK: - AcceptEncodingHeaders

public enum AcceptEncodingHeaders: Sendable {
    case gzip
    case compress
    case deflate
    case br
    case identity
    case all
    case custom(String)

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

    public static var name: String {
        return "accept-encoding"
    }
}

// MARK: - AcceptLanguageHeaders

public enum AcceptLanguageHeaders: Sendable {
    case en
    case fa
    case all
    case custom(String)

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

    public static var name: String {
        return "accept-language"
    }
}

// MARK: - AuthorizationType

public enum AuthorizationType: Sendable {
    case bearer(token: String)
    case basic(username: String, password: String)
    case custom(String)

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

    public static var name: String {
        return "authorization"
    }
}

// MARK: - HeaderHandler

public class HeaderHandler: @unchecked Sendable {
    // MARK: Lifecycle

    private init() { _headers = [:] }

    // MARK: Internal

    public static let shared = HeaderHandler()

    private let queue = DispatchQueue(label: "com.headerHandler.queue")

    @discardableResult
    public func addContentTypeHeader(type: ContentTypeHeaders) -> HeaderHandler
    {
        queue.sync {
            _headers.updateValue(type.value, forKey: ContentTypeHeaders.name)
            return self
        }

    }

    @discardableResult
    public func addConnectionHeader(type: ConnectionHeaders) -> HeaderHandler {
        queue.sync {
            _headers.updateValue(type.value, forKey: ConnectionHeaders.name)
            return self
        }

    }

    @discardableResult
    public func addAcceptHeaders(type: AcceptHeaders) -> HeaderHandler {
        queue.sync {
            _headers.updateValue(type.value, forKey: AcceptHeaders.name)
            return self
        }

    }

    @discardableResult
    public func addAcceptLanguageHeaders(type: AcceptLanguageHeaders)
        -> HeaderHandler
    {
        queue.sync {
            _headers.updateValue(type.value, forKey: AcceptLanguageHeaders.name)
            return self
        }

    }

    @discardableResult
    public func addAcceptEncodingHeaders(type: AcceptEncodingHeaders)
        -> HeaderHandler
    {
        queue.sync {
            _headers.updateValue(type.value, forKey: AcceptEncodingHeaders.name)
            return self
        }

    }

    @discardableResult
    public func addAuthorizationHeader(type: AuthorizationType) -> HeaderHandler
    {
        queue.sync {
            _headers.updateValue(type.value, forKey: AuthorizationType.name)
            return self
        }

    }

    @discardableResult
    public func addCustomHeader(name: String, value: String) -> HeaderHandler {
        queue.sync {
            _headers.updateValue(value, forKey: name)
            return self
        }

    }

    public func build() -> [String: String] {
        return headers
    }

    // MARK: Private

    private var _headers: [String: String] = [:]
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
