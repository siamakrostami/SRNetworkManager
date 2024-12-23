//
//  DownloadState.swift
//  SRNetworkManager
//
//  Created by Siamak Rostami on 12/20/24.
//


import Foundation
import Combine

/// Represents the current state of a download task.
///
/// The state transitions typically follow this pattern:
/// queued -> downloading -> completed/failed/cancelled
/// with possible paused state in between.
public enum DownloadState: String, Codable, Sendable {
    /// Task is waiting in queue to be processed
    case queued
    /// Task is actively downloading
    case downloading
    /// Task is temporarily suspended
    case paused
    /// Task has successfully completed
    case completed
    /// Task failed due to an error
    case failed
    /// Task was manually cancelled
    case cancelled
}

/// Defines priority levels for download tasks.
///
/// Higher priority tasks are processed before lower priority ones
/// when multiple tasks are in the queue.
public enum DownloadPriority: Int, Codable, Sendable {
    /// Lowest priority, these tasks are processed last
    case low = 0
    /// Default priority level
    case normal = 1
    /// Higher priority than normal
    case high = 2
    /// Highest priority, these tasks are processed first
    case critical = 3
    
    /// Maps priority levels to URLSession task priority values
    var urlSessionPriority: Float {
        switch self {
        case .low: return 0.25
        case .normal: return 0.5
        case .high: return 0.75
        case .critical: return 1.0
        }
    }
}

/// Represents a single download task with its associated metadata and state.
///
/// This structure contains all the information needed to track and manage
/// a download throughout its lifecycle.
public struct DownloadTask: Identifiable, Codable, Sendable {
    /// Unique identifier for the download task
    public let id: UUID
    /// Source URL for the download
    public let url: URL
    /// Target filename for the downloaded file
    public var fileName: String
    /// Priority level for queue processing
    public let priority: DownloadPriority
    /// Current state of the download
    public var state: DownloadState
    /// Download progress from 0.0 to 1.0
    public var progress: Double
    /// Expected total bytes to download
    public var expectedBytes: Int64
    /// Currently downloaded bytes
    public var downloadedBytes: Int64
    /// Current download speed in bytes per second
    public var speed: Double
    /// Timestamp when the task was created
    public var createdAt: Date
    /// Error message if the task failed
    public var error: String?
    
    /// Creates a new download task.
    /// - Parameters:
    ///   - url: The source URL to download from
    ///   - fileName: Optional custom filename, defaults to URL's last path component
    ///   - priority: Priority level for the download, defaults to .normal
    public init(
        url: URL,
        fileName: String? = nil,
        priority: DownloadPriority = .normal
    ) {
        self.id = UUID()
        self.url = url
        self.fileName = fileName ?? url.lastPathComponent
        self.priority = priority
        self.state = .queued
        self.progress = 0
        self.expectedBytes = 0
        self.downloadedBytes = 0
        self.speed = 0
        self.createdAt = Date()
    }
}

/// Represents events that can occur during the download process.
///
/// These events are used to notify observers about changes in
/// download status, progress, and queue updates.
public enum DownloadEvent: Equatable, Sendable {
    /// Progress update event with task ID, progress percentage, and current speed
    case progress(UUID, Double, Double)
    /// State change event with task ID and new state
    case stateChange(UUID, DownloadState)
    /// Error event with task ID and error message
    case error(UUID, String)
    /// Queue update event with current list of tasks
    case queueUpdated([DownloadTask])
    
    public static func == (lhs: DownloadEvent, rhs: DownloadEvent) -> Bool {
        switch (lhs, rhs) {
        case let (.progress(id1, prog1, speed1), .progress(id2, prog2, speed2)):
            return id1 == id2 && prog1 == prog2 && speed1 == speed2
            
        case let (.stateChange(id1, state1), .stateChange(id2, state2)):
            return id1 == id2 && state1 == state2
            
        case let (.error(id1, error1), .error(id2, error2)):
            return id1 == id2 && error1 == error2
            
        case let (.queueUpdated(tasks1), .queueUpdated(tasks2)):
            return tasks1.map { $0.id } == tasks2.map { $0.id }
            
        default:
            return false
        }
    }
}

/// Represents possible errors that can occur during download operations.
public enum DownloadError: Error {
    /// The provided URL is invalid or malformed
    case invalidURL
    /// Not enough storage space available for download
    case insufficientStorage
    /// Network-related error occurred
    case networkError
    /// File system operation error
    case fileError
    /// Download was cancelled by user or system
    case cancelled
    /// Attempted to download already downloading file
    case alreadyDownloading
    /// Download queue is at capacity
    case queueFull
    /// Error related to persistent storage operations
    case storageError(String)
    /// Unspecified error occurred
    case unknown
}
