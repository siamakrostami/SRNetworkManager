import Foundation

// MARK: - Log Level

/// An enum representing different levels of logging.
public enum LogLevel: Sendable {
    case none
    case minimal // Only log the URL and method
    case standard // Log headers and status code
    case verbose // Log everything, including the body
}

/// A class for logging URL session requests and responses.
public final class URLSessionLogger: Sendable {
    
    // MARK: Lifecycle
    private init() {}

    // MARK: Internal
    public static let shared = URLSessionLogger() // Singleton instance
    
    // Serial queue for synchronized logging
    private let logQueue = DispatchQueue(label: "com.urlsessionlogger.queue")

    /// Logs a URL request.
    /// - Parameters:
    ///   - request: The URLRequest to log.
    ///   - logLevel: The desired log level.
    public func logRequest(_ request: URLRequest, logLevel: LogLevel?) {
        guard let logLevel = logLevel, logLevel != .none else { return }
        
        logQueue.async {
            print("\n🚀🚀🚀 REQUEST 🚀🚀🚀")
            print("🔈 \(request.httpMethod ?? "UNKNOWN") \(request.url?.absoluteString ?? "Invalid URL")")

            if logLevel != .minimal {
                print("Headers:")
                request.allHTTPHeaderFields?.forEach { print("💡 \($0.key): \($0.value)") }
            }

            if logLevel == .verbose, let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
                print("Body: {\n  \(bodyString)\n}")
            }

            print("🔼🔼🔼 END REQUEST 🔼🔼🔼")
        }
    }

    /// Logs a URL response.
    /// - Parameters:
    ///   - response: The URLResponse to log.
    ///   - data: The response data.
    ///   - error: Any error that occurred.
    ///   - logLevel: The desired log level.
    public func logResponse(_ response: URLResponse?, data: Data?, error: Error?, logLevel: LogLevel?) {
        guard let logLevel = logLevel, logLevel != .none else { return }
        
        logQueue.async {
            if let httpResponse = response as? HTTPURLResponse {
                if 200 ..< 300 ~= httpResponse.statusCode {
                    print("\n✅✅✅ SUCCESS RESPONSE ✅✅✅")
                } else {
                    print("\n🛑🛑🛑 REQUEST ERROR 🛑🛑🛑")
                }
                
                print("🔈 \(httpResponse.url?.absoluteString ?? "Invalid URL")")
                print("🔈 Status code: \(httpResponse.statusCode)")
                
                if logLevel != .minimal {
                    print("Headers:")
                    httpResponse.allHeaderFields.forEach { print("💡 \($0.key): \($0.value)") }
                }

                if logLevel == .verbose, let data = data, let responseBody = String(data: data, encoding: .utf8) {
                    print("Body: {\n  \(responseBody)\n}")
                }

                print("🔼🔼🔼 END RESPONSE 🔼🔼🔼")

            } else if let error = error {
                print("\n🛑🛑🛑 REQUEST ERROR 🛑🛑🛑")
                print("🔈 \(error.localizedDescription)")
                print("🔼🔼🔼 END ERROR 🔼🔼🔼")
            }
        }
    }
}
