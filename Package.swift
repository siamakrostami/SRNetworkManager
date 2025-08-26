// swift-tools-version: 6.0
import PackageDescription

/// SRNetworkManager - A comprehensive networking library for Swift applications
/// 
/// This package provides a robust, thread-safe networking solution with support for:
/// - Combine and async/await programming models
/// - Automatic retry mechanisms with customizable strategies
/// - Request/response logging with configurable levels
/// - File upload with progress tracking
/// - Streaming responses
/// - Network reachability monitoring
/// - VPN detection
/// - Multipart form data handling
/// - Custom error handling and mapping
/// - Thread-safe operations with proper synchronization
///
/// ## Supported Platforms
/// - iOS 13.0+
/// - macOS 13.0+
/// - tvOS 13.0+
/// - watchOS 7.0+
///
/// ## Key Features
/// - **Dual Programming Models**: Support for both Combine and async/await
/// - **Thread Safety**: All operations are thread-safe with proper synchronization
/// - **Retry Logic**: Configurable retry strategies for failed requests
/// - **Logging**: Comprehensive request/response logging with multiple levels
/// - **Upload Support**: File upload with progress tracking
/// - **Streaming**: Support for streaming responses
/// - **Network Monitoring**: Real-time network connectivity and VPN detection
/// - **Error Handling**: Rich error types with proper mapping
/// - **Parameter Encoding**: Support for JSON, URL-encoded, and multipart form data
let package = Package(
    name: "SRNetworkManager",
    platforms: [
        .iOS(.v13),
        .macOS(.v13),
        .tvOS(.v13),
        .watchOS(.v7)
    ],
    products: [
        .library(
            name: "SRNetworkManager",
            targets: ["SRNetworkManager"]
        ),
    ],
    targets: [
        .target(
            name: "SRNetworkManager",
            path: "Sources",
            sources: [
                "SRNetworkManager",      // Main network manager interface
                "HeaderHandler",         // HTTP header management
                "Encoding",              // Parameter encoding (JSON, URL, multipart)
                "Log",                   // Request/response logging
                "Mime",                  // MIME type detection
                "Error",                 // Network error definitions
                "Client",                // Core API client implementation
                "UploadProgress",        // Upload progress tracking
                "Router",                // Network routing and URL construction
                "Data",                  // Data extensions and utilities
                "Reachability"           // Network connectivity monitoring
            ],
            swiftSettings: [
                .define("SPM_SWIFT_6"),  // Swift 6 compatibility flag
                .define("SWIFT_PACKAGE") // Package manager flag
            ]
        ),
        .testTarget(
            name: "SRNetworkManagerTests",
            dependencies: ["SRNetworkManager"],
            path: "Tests/SRNetworkManagerTests"
        ),
    ],
    swiftLanguageModes: [.v6,.v5]  // Support for both Swift 5 and 6
)
