# SRNetworkManager

## What's New

- Updated default URLSession configuration and cache policy
- Default request cache policy is now `.useProtocolCachePolicy`
- Support for per-request cache policy overrides via `NetworkRouter`
- Logging now includes the effective cache policy and configuration snapshot
- Thread-safe propagation of configuration updates across client instances
- Tests updated to cover configuration and cache policy behavior

## Features

- **🔄 Dual Programming Models**: Support for both Combine and async/await
- **🛡️ Thread Safety**: All operations are thread-safe with proper synchronization
- **🔄 Retry Logic**: Configurable retry strategies for failed requests
- **📤 Upload Support**: File upload with progress tracking
- **🌊 Streaming**: Support for streaming responses
- **📡 Network Monitoring**: Real-time network connectivity and VPN detection
- **🗃️ Cache Policy Control**: Default `.useProtocolCachePolicy` with per-request overrides
- **🔧 Error Handling**: Rich error types with proper mapping
- **📝 Logging**: Comprehensive request/response logging with multiple levels
- **🔐 Authentication**: Built-in support for various authentication methods
- **📦 Parameter Encoding**: Support for JSON, URL-encoded, and multipart form data

## Requirements

- iOS 13.0+
- macOS 13.0+
- tvOS 13.0+
- watchOS 7.0+
- Swift 5.9+ (Swift 5 and 6 supported)

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/SRNetworkManager.git", from: "1.0.0")
]
