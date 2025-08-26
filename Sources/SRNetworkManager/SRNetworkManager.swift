// The Swift Programming Language
// https://docs.swift.org/swift-book

/// SRNetworkManager - Main Interface
///
/// This file serves as the main entry point for the SRNetworkManager library.
/// It provides a high-level interface for network operations with support for
/// both Combine and async/await programming models.
///
/// ## Overview
/// SRNetworkManager is a comprehensive networking library designed to simplify
/// network operations in Swift applications. It provides a unified interface
/// for making HTTP requests, handling responses, managing uploads, and monitoring
/// network connectivity.
///
/// ## Key Components
/// - **APIClient**: Core client for making network requests
/// - **NetworkRouter**: Protocol for defining API endpoints
/// - **NetworkError**: Comprehensive error handling
/// - **RetryHandler**: Configurable retry strategies
/// - **UploadProgressDelegate**: Upload progress tracking
/// - **NetworkMonitor**: Network connectivity monitoring
///
/// ## Usage Examples
///
/// ### Basic Request with Combine
/// ```swift
/// let client = APIClient()
/// let endpoint = MyAPIEndpoint()
/// 
/// client.request(endpoint)
///     .sink(
///         receiveCompletion: { completion in
///             // Handle completion
///         },
///         receiveValue: { response in
///             // Handle response
///         }
///     )
///     .store(in: &cancellables)
/// ```
///
/// ### Basic Request with async/await
/// ```swift
/// let client = APIClient()
/// let endpoint = MyAPIEndpoint()
/// 
/// do {
///     let response = try await client.request(endpoint)
///     // Handle response
/// } catch {
///     // Handle error
/// }
/// ```
///
/// ### File Upload
/// ```swift
/// let client = APIClient()
/// let endpoint = UploadEndpoint()
/// let imageData = UIImage().jpegData(compressionQuality: 0.8)
/// 
/// client.uploadRequest(endpoint, withName: "image", data: imageData) { progress in
///     print("Upload progress: \(progress)")
/// }
/// .sink(
///     receiveCompletion: { completion in
///         // Handle completion
///     },
///     receiveValue: { response in
///         // Handle response
///     }
/// )
/// .store(in: &cancellables)
/// ```
///
/// ### Streaming Response
/// ```swift
/// let client = APIClient()
/// let endpoint = StreamingEndpoint()
/// 
/// client.streamRequest(endpoint)
///     .sink(
///         receiveCompletion: { completion in
///             // Handle completion
///         },
///         receiveValue: { chunk in
///             // Handle each chunk
///         }
///     )
///     .store(in: &cancellables)
/// ```
///
/// ## Configuration
/// The library supports various configuration options:
/// - Custom URLSessionConfiguration
/// - Quality of service settings
/// - Log levels for debugging
/// - Custom JSON decoders
/// - Retry strategies
///
/// ## Thread Safety
/// All operations are thread-safe and can be called from any queue.
/// The library uses proper synchronization mechanisms to ensure
/// data consistency across multiple threads.
///
/// ## Error Handling
/// The library provides comprehensive error handling with:
/// - Network-specific errors
/// - Decoding errors
/// - Custom error responses
/// - Retry mechanisms
///
/// ## Network Monitoring
/// Built-in network monitoring capabilities:
/// - Real-time connectivity status
/// - VPN detection
/// - Network type identification
/// - Automatic retry on network restoration
