//
//  APIVersion.swift
//  SRGenericNetworkLayer
//
//  Created by Siamak on 11/30/24.
//

// MARK: - APIVersion

/// Represents numeric API versions for versioning control.
///
/// ## Overview
/// `NumericVersion` provides a type-safe way to represent API versions,
/// supporting both predefined versions and custom numeric versions.
///
/// ## Usage Examples
///
/// ### Predefined Versions
/// ```swift
/// let version1 = NumericVersion.v1  // Represents version 1
/// let version2 = NumericVersion.v2  // Represents version 2
/// ```
///
/// ### Custom Versions
/// ```swift
/// let customVersion = NumericVersion.custom(version: 3)  // Represents version 3
/// let betaVersion = NumericVersion.custom(version: 99)   // Represents version 99
/// ```
///
/// ## Integration with APIVersion
/// ```swift
/// let apiVersion = APIVersion.custom(path: "api", version: .v2)
/// // Results in: "api/v2"
/// ```
public enum NumericVersion: Sendable {
    /// Version 1 of the API
    case v1
    /// Version 2 of the API
    case v2
    /// Custom numeric version
    case custom(version: Int)
}

/// Represents API versioning information for network requests.
///
/// ## Overview
/// `APIVersion` provides a flexible way to specify API versions in network requests.
/// It supports custom path prefixes and numeric versioning to accommodate different
/// API versioning strategies.
///
/// ## Key Features
/// - **Custom Paths**: Support for custom path prefixes (e.g., "api", "rest")
/// - **Numeric Versions**: Support for both predefined and custom version numbers
/// - **Flexible Formatting**: Automatic path construction with proper separators
/// - **Sendable Conformance**: Safe for concurrent usage
///
/// ## Usage Examples
///
/// ### Basic Versioning
/// ```swift
/// struct MyEndpoint: NetworkRouter {
///     var version: APIVersion? { .custom(path: "api", version: .v1) }
///     var path: String { "/users" }
///     // Results in: "https://example.com/api/v1/users"
/// }
/// ```
///
/// ### Version Only (No Path Prefix)
/// ```swift
/// struct MyEndpoint: NetworkRouter {
///     var version: APIVersion? { .custom(path: nil, version: .v2) }
///     var path: String { "/users" }
///     // Results in: "https://example.com/v2/users"
/// }
/// ```
///
/// ### Custom Version Number
/// ```swift
/// struct MyEndpoint: NetworkRouter {
///     var version: APIVersion? { .custom(path: "api", version: .custom(version: 3)) }
///     var path: String { "/users" }
///     // Results in: "https://example.com/api/3/users"
/// }
/// ```
///
/// ### No Versioning
/// ```swift
/// struct MyEndpoint: NetworkRouter {
///     var version: APIVersion? { nil }  // No versioning
///     var path: String { "/users" }
///     // Results in: "https://example.com/users"
/// }
/// ```
///
/// ## Common API Versioning Patterns
///
/// ### URL Path Versioning
/// ```swift
/// // https://api.example.com/v1/users
/// let version = APIVersion.custom(path: nil, version: .v1)
/// ```
///
/// ### Subdomain Versioning
/// ```swift
/// // https://v1.api.example.com/users
/// // (Handled by baseURLString, not APIVersion)
/// let baseURL = "https://v1.api.example.com"
/// ```
///
/// ### Header Versioning
/// ```swift
/// // https://api.example.com/users with Accept-Version header
/// let version = APIVersion.custom(path: nil, version: .v2)
/// let headers = ["Accept-Version": "2"]
/// ```
///
/// ## Path Construction
/// The `path` property automatically constructs the version path:
/// - If both path and version are provided: `"{path}/{version}"`
/// - If only version is provided: `"{version}"`
/// - If neither is provided: `""`
///
/// ## Best Practices
/// - **Consistent Versioning**: Use the same versioning strategy across your API
/// - **Backward Compatibility**: Consider maintaining multiple versions during transitions
/// - **Documentation**: Clearly document versioning strategy for API consumers
/// - **Deprecation**: Plan for version deprecation and migration strategies
public enum APIVersion: Sendable {
    /// Custom API version with optional path prefix and numeric version
    case custom(path: String?, version: NumericVersion)

    // MARK: Public

    /// The constructed version path string.
    ///
    /// This property returns the formatted version path that will be appended
    /// to the base URL in network requests.
    ///
    /// ## Examples
    /// ```swift
    /// APIVersion.custom(path: "api", version: .v1).path  // "api/v1"
    /// APIVersion.custom(path: nil, version: .v2).path    // "v2"
    /// ```
    public var path: String {
        rawValue
    }

    // MARK: Internal

    /// The raw string value of the version path.
    ///
    /// Constructs the version path based on the provided path prefix and version.
    /// - If path is provided: `"{path}/{version}"`
    /// - If path is nil: `"{version}"`
    var rawValue: String {
        switch self {
        case .custom(let path, let version):
            if let path {
                return "\(path)/\(version)"
            } else {
                return "\(version)"
            }
        }
    }
}
