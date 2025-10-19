## What's New

- Updated default URLSession configuration and cache policy
- Default request cache policy is now `.useProtocolCachePolicy`
- Support for per-request cache policy overrides via `NetworkRouter`
- Logging now includes the effective cache policy and configuration snapshot
- Thread-safe propagation of configuration updates across client instances
- Tests updated to cover configuration and cache policy behavior

# SRNetworkManager

A comprehensive, thread-safe networking library for Swift applications with support for both Combine and async/await programming models.

## Features

- **🔄 Dual Programming Models**: Support for both Combine and async/await
- **🛡️ Thread Safety**: All operations are thread-safe with proper synchronization
- **🔄 Retry Logic**: Configurable retry strategies for failed requests
- **📤 Upload Support**: File upload with progress tracking
- **🌊 Streaming**: Support for streaming responses
- **📡 Network Monitoring**: Real-time network connectivity and VPN detection
- **🔧 Error Handling**: Rich error types with proper mapping
- **📝 Logging**: Comprehensive request/response logging with multiple levels
- **🔐 Authentication**: Built-in support for various authentication methods
- **📦 Parameter Encoding**: Support for JSON, URL-encoded, and multipart form data

## Requirements

- iOS 13.0+
- macOS 13.0+
- tvOS 13.0+
- watchOS 7.0+
- Swift 5.9+

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/SRNetworkManager.git", from: "1.0.0")
]
```

Or add it directly in Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select the version you want to use

## Quick Start

### Basic Setup

```swift
import SRNetworkManager

// Create a client with default configuration
let client = APIClient()

// Define your endpoint
struct GetUsersEndpoint: NetworkRouter {
    var baseURLString: String { "https://api.example.com" }
    var path: String { "/users" }
    var method: RequestMethod? { .get }
}

// Make a request
client.request(GetUsersEndpoint())
    .sink(
        receiveCompletion: { completion in
            if case .failure(let error) = completion {
                print("Error: \(error)")
            }
        },
        receiveValue: { (users: [User]) in
            print("Received \(users.count) users")
        }
    )
    .store(in: &cancellables)
```

### Async/Await Usage

```swift
// Using async/await
do {
    let users: [User] = try await client.request(GetUsersEndpoint())
    print("Received \(users.count) users")
} catch {
    print("Error: \(error)")
}
```

## Core Components

### APIClient

The main client for making network requests.

```swift
let client = APIClient(
    configuration: .default,
    qos: .userInitiated,
    logLevel: .standard,
    decoder: JSONDecoder(),
    retryHandler: DefaultRetryHandler(numberOfRetries: 3)
)
```

### NetworkRouter

Define your API endpoints with type safety.

```swift
struct CreateUserEndpoint: NetworkRouter {
    struct Parameters: Codable {
        let name: String
        let email: String
    }
    
    var baseURLString: String { "https://api.example.com" }
    var path: String { "/users" }
    var method: RequestMethod? { .post }
    var params: Parameters? { parameters }
    
    private let parameters: Parameters
    init(name: String, email: String) {
        self.parameters = Parameters(name: name, email: email)
    }
}
```

### Network Monitoring

Monitor network connectivity changes in real-time.

```swift
let monitor = NetworkMonitor()
monitor.startMonitoring()

monitor.status
    .sink { connectivity in
        switch connectivity {
        case .disconnected:
            print("Network disconnected")
        case .connected(let networkType):
            print("Connected via \(networkType)")
        }
    }
    .store(in: &cancellables)
```

## Advanced Usage

### File Upload with Progress

```swift
let endpoint = UploadEndpoint()
let imageData = UIImage().jpegData(compressionQuality: 0.8)

client.uploadRequest(endpoint, withName: "image", data: imageData) { progress in
    print("Upload progress: \(Int(progress * 100))%")
}
.sink(
    receiveCompletion: { completion in
        print("Upload completed")
    },
    receiveValue: { (response: UploadResponse) in
        print("Upload successful: \(response.url)")
    }
)
.store(in: &cancellables)
```

### Streaming Responses

```swift
client.streamRequest(StreamingEndpoint())
    .sink(
        receiveCompletion: { completion in
            print("Stream completed")
        },
        receiveValue: { (chunk: DataChunk) in
            print("Received chunk: \(chunk)")
        }
    )
    .store(in: &cancellables)
```

### Custom Retry Logic

```swift
struct CustomRetryHandler: RetryHandler {
    let numberOfRetries: Int
    
    func shouldRetry(request: URLRequest, error: NetworkError) -> Bool {
        switch error {
        case .urlError(let urlError):
            return urlError.code == .notConnectedToInternet ||
                   urlError.code == .timedOut
        case .customError(let statusCode, _):
            return statusCode >= 500
        default:
            return false
        }
    }
    
    func modifyRequestForRetry(client: APIClient, request: URLRequest, error: NetworkError) -> (URLRequest, NetworkError?) {
        var newRequest = request
        newRequest.setValue("retry", forHTTPHeaderField: "X-Retry-Attempt")
        return (newRequest, nil)
    }
    
    // Implement async methods...
}

let client = APIClient(retryHandler: CustomRetryHandler(numberOfRetries: 3))
```

### Authentication

```swift
// Bearer token authentication
let headers = HeaderHandler.shared
    .addAuthorizationHeader(type: .bearer(token: "your-token"))
    .addAcceptHeaders(type: .applicationJson)
    .build()

struct AuthenticatedEndpoint: NetworkRouter {
    var baseURLString: String { "https://api.example.com" }
    var path: String { "/protected" }
    var method: RequestMethod? { .get }
    var headers: [String: String]? { headers }
}
```

### Network-Aware Operations

```swift
class NetworkAwareService {
    private let client = APIClient()
    private let monitor = NetworkMonitor()
    private var pendingRequests: [() -> Void] = []
    
    init() {
        monitor.startMonitoring()
        setupNetworkHandling()
    }
    
    private func setupNetworkHandling() {
        monitor.status
            .sink { [weak self] connectivity in
                if case .connected = connectivity {
                    self?.processPendingRequests()
                }
            }
            .store(in: &cancellables)
    }
    
    func makeRequest<T: Codable>(_ endpoint: NetworkRouter) -> AnyPublisher<T, NetworkError> {
        if case .connected = monitor.currentStatus {
            return client.request(endpoint)
        } else {
            return Future { promise in
                self.pendingRequests.append {
                    self.client.request(endpoint)
                        .sink(receiveCompletion: { promise($0) }, receiveValue: { promise(.success($0)) })
                        .store(in: &self.cancellables)
                }
            }
            .eraseToAnyPublisher()
        }
    }
}
```

## Configuration

### Log Levels

```swift
let client = APIClient(logLevel: .verbose) // .none, .minimal, .standard, .verbose
```

### Custom Headers

```swift
let headers = HeaderHandler.shared
    .addContentTypeHeader(type: .applicationJson)
    .addAcceptHeaders(type: .applicationJson)
    .addAcceptLanguageHeaders(type: .en)
    .addAcceptEncodingHeaders(type: .gzip)
    .addCustomHeader(name: "X-API-Key", value: "your-api-key")
    .build()
```

### VPN Detection

```swift
let vpnChecker = VPNChecker()
if vpnChecker.isVPNActive() {
    print("VPN is connected")
    // Handle VPN-specific logic
}
```

## Error Handling

The library provides comprehensive error handling with specific error types:

```swift
switch networkError {
case .urlError(let urlError):
    print("Network error: \(urlError.localizedDescription)")
case .decodingError(let decodingError):
    print("Decoding error: \(decodingError)")
case .customError(let statusCode, let data):
    print("Server error: \(statusCode)")
case .responseError(let error):
    print("Response error: \(error)")
case .unknown:
    print("Unknown error occurred")
}
```

## Thread Safety

All operations in SRNetworkManager are thread-safe:

- **APIClient**: Uses dedicated dispatch queues for synchronization
- **NetworkMonitor**: Thread-safe status updates and continuation management
- **HeaderHandler**: Synchronized header operations
- **UploadProgressDelegate**: Thread-safe progress handling

## Performance Considerations

- **Efficient Monitoring**: Uses system-level network monitoring
- **Minimal Overhead**: Low CPU and memory usage
- **Background Operation**: Can operate in background queues
- **Battery Impact**: Minimal battery impact from monitoring

## Best Practices

### Production Configuration

```swift
#if DEBUG
let logLevel: LogLevel = .verbose
let retryHandler = DefaultRetryHandler(numberOfRetries: 3)
#else
let logLevel: LogLevel = .none
let retryHandler = DefaultRetryHandler(numberOfRetries: 1)
#endif

let client = APIClient(
    logLevel: logLevel,
    retryHandler: retryHandler
)
```

### Error Handling

```swift
client.request(endpoint)
    .sink(
        receiveCompletion: { completion in
            if case .failure(let error) = completion {
                switch error {
                case .urlError(let urlError):
                    if urlError.code == .notConnectedToInternet {
                        showOfflineMessage()
                    }
                case .customError(let statusCode, _):
                    if statusCode == 401 {
                        handleUnauthorized()
                    }
                default:
                    showGenericError()
                }
            }
        },
        receiveValue: { response in
            handleSuccess(response)
        }
    )
    .store(in: &cancellables)
```

### Memory Management

```swift
class NetworkService {
    private var cancellables = Set<AnyCancellable>()
    private let client = APIClient()
    
    func makeRequest() {
        client.request(endpoint)
            .sink(receiveCompletion: { ... }, receiveValue: { ... })
            .store(in: &cancellables) // Store to prevent cancellation
    }
}
```

## API Reference

### Core Types

- `APIClient`: Main client for network requests
- `NetworkRouter`: Protocol for defining API endpoints
- `NetworkError`: Comprehensive error types
- `RetryHandler`: Protocol for custom retry logic
- `NetworkMonitor`: Real-time network monitoring
- `VPNChecker`: VPN connection detection

### Request Methods

- `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `TRACE`

### Network Types

- `wifi`, `cellular`, `ethernet`, `vpn`, `other`

### Log Levels

- `none`, `minimal`, `standard`, `verbose`

### Content Types

- `applicationJson`, `urlEncoded`, `formData`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with Apple's Network framework
- Inspired by modern networking patterns
- Designed for performance and reliability

