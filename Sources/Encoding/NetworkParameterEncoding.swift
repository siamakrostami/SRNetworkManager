import Foundation

// MARK: - EncodingError

/// Error Handling
public enum EncodingError: Error, Sendable {
    case missingURL
    case jsonEncodingFailed(error: Error)
}

// MARK: - NetworkParameterEncoding

/// Protocol for encoding parameters in network requests
public protocol NetworkParameterEncoding: Sendable {
    func encode<T: Codable>(_ urlRequest: inout URLRequest, with parameters: T?)
        throws
}

// MARK: - URLEncoding

/// URL encoding implementation
public struct URLEncoding: NetworkParameterEncoding, Sendable {
    public enum Destination: Sendable {
        case methodDependent
        case queryString
        case httpBody
    }

    public var destination: Destination

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

    private func encodeQueryString<T: Codable>(
        _ urlRequest: inout URLRequest, with parameters: T
    ) throws {
        guard let url = urlRequest.url else {
            throw EncodingError.missingURL
        }

        let queryItems = try URLQueryEncoder().encode(parameters)  // Encode the parameters into query string
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

    private func encodeHttpBody<T: Codable>(
        _ urlRequest: inout URLRequest, with parameters: T
    ) throws {
        let jsonData = try JSONEncoder().encode(parameters)
        urlRequest.httpBody = jsonData
    }
}

// MARK: - JSONEncoding

/// JSON encoding implementation
public struct JSONEncoding: NetworkParameterEncoding, Sendable {
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

/// Encoder for URL query parameters
public struct URLQueryEncoder {
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

    private func query(from parameters: [String: Any]) -> String {
        var components: [(String, String)] = []

        for key in parameters.keys.sorted(by: <) {
            let value = parameters[key]!
            components += queryComponents(fromKey: key, value: value)
        }
        return components.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
    }

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

    private func escape(_ string: String) -> String {
        return string.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed) ?? string
    }
}
