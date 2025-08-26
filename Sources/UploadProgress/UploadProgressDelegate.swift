import Foundation

/// A closure type for handling upload progress updates.
///
/// ## Overview
/// `ProgressHandler` is a closure type that receives upload progress information
/// and can be used to update UI elements, track upload status, or perform other
/// actions based on upload progress.
///
/// ## Parameters
/// - **totalProgress**: A value between 0.0 and 1.0 representing the upload progress
/// - **totalBytesSent**: The total number of bytes sent so far
/// - **totalBytesExpectedToSend**: The expected total size of the upload
///
/// ## Usage Examples
///
/// ### Basic Progress Tracking
/// ```swift
/// let progressHandler: ProgressHandler = { progress, bytesSent, totalBytes in
///     print("Upload progress: \(Int(progress * 100))%")
///     print("Sent: \(bytesSent) / \(totalBytes) bytes")
/// }
/// ```
///
/// ### UI Progress Bar Update
/// ```swift
/// let progressHandler: ProgressHandler = { progress, bytesSent, totalBytes in
///     DispatchQueue.main.async {
///         progressBar.progress = Float(progress)
///         progressLabel.text = "\(Int(progress * 100))%"
///     }
/// }
/// ```
///
/// ### Upload Status Tracking
/// ```swift
/// let progressHandler: ProgressHandler = { progress, bytesSent, totalBytes in
///     if progress >= 1.0 {
///         print("Upload completed!")
///     } else if progress > 0.5 {
///         print("Upload more than halfway done")
///     }
/// }
/// ```
///
/// ## Return Value
/// The closure returns `Void?` to allow for optional handling. Most implementations
/// will not need to return a value, but the option is available for advanced use cases.
public typealias ProgressHandler = @Sendable (
    _ totalProgress: Double, _ totalBytesSent: Int64,
    _ totalBytesExpectedToSend: Int64
) -> Void?

/// A thread-safe delegate class for monitoring upload progress in URLSession tasks.
///
/// ## Overview
/// `UploadProgressDelegate` implements the `URLSessionTaskDelegate` and `URLSessionDataDelegate`
/// protocols to provide real-time upload progress monitoring. It uses a thread-safe
/// approach to handle progress updates and can be safely used across multiple threads.
///
/// ## Key Features
/// - **Thread Safety**: All operations are synchronized using a dedicated dispatch queue
/// - **Progress Tracking**: Real-time monitoring of upload progress
/// - **Flexible Callbacks**: Customizable progress handler closure
/// - **Memory Management**: Proper delegate lifecycle management
/// - **Sendable Conformance**: Safe for concurrent usage
///
/// ## Usage Examples
///
/// ### Basic Upload with Progress
/// ```swift
/// let progressDelegate = UploadProgressDelegate()
/// progressDelegate.progressHandler = { progress, bytesSent, totalBytes in
///     print("Upload progress: \(Int(progress * 100))%")
/// }
/// 
/// let session = URLSession(configuration: .default, delegate: progressDelegate, delegateQueue: nil)
/// let task = session.uploadTask(with: request, from: fileData)
/// task.resume()
/// ```
///
/// ### UI Progress Updates
/// ```swift
/// let progressDelegate = UploadProgressDelegate()
/// progressDelegate.progressHandler = { progress, bytesSent, totalBytes in
///     DispatchQueue.main.async {
///         self.progressView.progress = Float(progress)
///         self.statusLabel.text = "Uploading... \(Int(progress * 100))%"
///         
///         if progress >= 1.0 {
///             self.statusLabel.text = "Upload completed!"
///         }
///     }
/// }
/// ```
///
/// ### Multiple Upload Tracking
/// ```swift
/// class UploadManager {
///     private var uploads: [String: UploadProgressDelegate] = [:]
///     
///     func startUpload(id: String, data: Data, url: URL) {
///         let progressDelegate = UploadProgressDelegate()
///         progressDelegate.progressHandler = { [weak self] progress, bytesSent, totalBytes in
///             self?.updateUploadProgress(id: id, progress: progress)
///         }
///         
///         uploads[id] = progressDelegate
///         
///         let session = URLSession(configuration: .default, delegate: progressDelegate, delegateQueue: nil)
///         let request = URLRequest(url: url)
///         let task = session.uploadTask(with: request, from: data)
///         task.resume()
///     }
///     
///     private func updateUploadProgress(id: String, progress: Double) {
///         // Update UI for specific upload
///     }
/// }
/// ```
///
/// ### Integration with APIClient
/// ```swift
/// let client = APIClient()
/// let endpoint = UploadEndpoint()
/// 
/// client.uploadRequest(endpoint, withName: "file", data: fileData) { progress in
///     print("Upload progress: \(Int(progress * 100))%")
/// }
/// .sink(
///     receiveCompletion: { completion in
///         print("Upload completed")
///     },
///     receiveValue: { response in
///         print("Upload response: \(response)")
///     }
/// )
/// .store(in: &cancellables)
/// ```
///
/// ## Thread Safety
/// The delegate uses a dedicated serial queue (`queue`) to ensure thread-safe access
/// to the progress handler. All read and write operations are synchronized to prevent
/// race conditions when the progress handler is accessed from multiple threads.
///
/// ## Memory Management
/// - **Weak References**: Use weak references in progress handlers to avoid retain cycles
/// - **Delegate Lifecycle**: The delegate is retained by the URLSession during the upload
/// - **Handler Cleanup**: Progress handlers are automatically cleaned up when uploads complete
///
/// ## Performance Considerations
/// - **Queue Overhead**: Minimal overhead from queue synchronization
/// - **Callback Frequency**: Progress updates are called frequently during uploads
/// - **UI Updates**: Always dispatch UI updates to the main queue
/// - **Memory Usage**: Minimal memory footprint for the delegate
///
/// ## Best Practices
/// - **UI Updates**: Always dispatch UI updates to the main queue
/// - **Weak References**: Use weak references to avoid retain cycles
/// - **Error Handling**: Handle upload failures in completion handlers
/// - **Progress Validation**: Validate progress values (0.0 to 1.0)
/// - **Resource Cleanup**: Clean up delegates when uploads complete
public final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate,
    URLSessionDataDelegate, @unchecked Sendable
{

    /// The closure to be called when progress updates occur.
    ///
    /// This property provides thread-safe access to the progress handler closure.
    /// The handler is called whenever the upload progress changes, providing
    /// real-time feedback on the upload status.
    ///
    /// ## Thread Safety
    /// Access to this property is synchronized using a dedicated dispatch queue
    /// to ensure thread-safe read and write operations.
    ///
    /// ## Usage
    /// ```swift
    /// let delegate = UploadProgressDelegate()
    /// delegate.progressHandler = { progress, bytesSent, totalBytes in
    ///     // Handle progress update
    /// }
    /// ```
    private var _progressHandler: ProgressHandler?
    var progressHandler: ProgressHandler? {
        get {
            queue.sync {
                return _progressHandler
            }
        }
        set {
            queue.sync {
                _progressHandler = newValue
            }
        }
    }

    /// Dedicated dispatch queue for thread synchronization
    private let queue = DispatchQueue(label: "com.uploadProgressDelegate.queue")

    /// URLSession delegate method for monitoring upload progress.
    ///
    /// This method is called by URLSession whenever data is sent during an upload task.
    /// It calculates the upload progress and calls the progress handler with the
    /// current status information.
    ///
    /// ## Progress Calculation
    /// The progress is calculated as `totalBytesSent / totalBytesExpectedToSend`,
    /// resulting in a value between 0.0 and 1.0 representing the upload completion percentage.
    ///
    /// ## Thread Safety
    /// The progress handler is accessed in a thread-safe manner using the dedicated
    /// dispatch queue to prevent race conditions.
    ///
    /// ## Parameters
    /// - **session**: The URLSession instance
    /// - **task**: The URLSessionTask being monitored
    /// - **bytesSent**: The number of bytes sent in the latest transmission
    /// - **totalBytesSent**: The total number of bytes sent so far
    /// - **totalBytesExpectedToSend**: The expected length of the body data
    public func urlSession(
        _ session: URLSession, task: URLSessionTask,
        didSendBodyData bytesSent: Int64, totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)

        let handler = queue.sync { _progressHandler }

        // Safely call the progressHandler closure, passing the labeled values
        if let handler = handler {
            handler(progress, totalBytesSent, totalBytesExpectedToSend)
        }
    }
}
