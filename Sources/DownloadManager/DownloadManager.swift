//
//  DownloadManager.swift
//  SRNetworkManager
//
//  Created by Siamak Rostami on 12/20/24.
//


import Foundation
import Combine
import Network

/// A robust download manager supporting multiple concurrent downloads,
/// background transfers, and progress tracking.
///
/// DownloadManager provides comprehensive download management features including:
/// - Multiple concurrent downloads with prioritization
/// - Progress tracking and speed calculation
/// - Background download support
/// - Pause/Resume/Cancel functionality
/// - Persistent state management
/// - Network reachability monitoring
public final class DownloadManager: @unchecked Sendable {
    // MARK: - Properties
    
    /// Configuration for the download manager
    let config: DownloadManagerConfig
    
    /// Queue for managing download tasks
    private let queue: DownloadQueue
    
    /// Storage for persisting download states
    let storage: DownloadStorage
    
    /// Events manager for handling download events
    let eventsManager: DownloadEventsManager
    
    /// Background URLSession for download tasks
    private let session: URLSession
    
    /// Currently active download tasks
    var activeDownloads: [UUID: URLSessionDownloadTask] = [:]
    
    /// Network path monitor for handling connectivity changes
    private let networkMonitor = NWPathMonitor()
    
    /// Set of cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    private let sessionDelegate: SessionDelegate?
    private let useBackgroundSession: Bool
    
    // MARK: - Public Interface
    
    /// Progress handler type for download progress updates
    public typealias ProgressHandler = @Sendable (Double, Double) -> Void
    
    // MARK: - Initialization
    
    /// Creates a new download manager instance.
    /// - Parameter configuration: Custom configuration for the download manager
    /// - Throws: Error if initialization fails
    public init(configuration: DownloadManagerConfig = .default, useBackgroundSession: Bool = false) async throws {
        self.useBackgroundSession = useBackgroundSession
        self.config = configuration
        self.queue = DownloadQueue(maxQueueSize: configuration.maxQueueSize)
        self.storage = try await DownloadStorage()
        self.eventsManager = DownloadEventsManager()
        self.sessionDelegate = SessionDelegate()
        // Configure background session
        let sessionConfig: URLSessionConfiguration
        if useBackgroundSession {
            sessionConfig = URLSessionConfiguration.background(withIdentifier: "com.SRNetworkManager.downloadmanager.background")
            sessionConfig.isDiscretionary = false
            sessionConfig.sessionSendsLaunchEvents = true
        } else {
            sessionConfig = URLSessionConfiguration.default
        }
        
        sessionConfig.allowsCellularAccess = configuration.allowsCellularAccess
        sessionConfig.timeoutIntervalForRequest = configuration.timeoutInterval
        sessionConfig.timeoutIntervalForResource = configuration.timeoutInterval
        
        self.session = URLSession(
            configuration: sessionConfig,
            delegate: sessionDelegate,
            delegateQueue: nil
        )
        
        self.sessionDelegate?.setManager(self)
        
        // Start network monitoring
        setupNetworkMonitoring()
        
        // Start queue processing
        await startQueueProcessing()
        
        // Restore previous session
        try await restoreSession()
    }
    
    // MARK: - Download Operations
    
    /// Starts a new download task.
    /// - Parameters:
    ///   - url: The URL to download from
    ///   - fileName: Optional custom filename for the downloaded file
    ///   - priority: Priority level for the download
    ///   - progress: Optional closure to receive progress updates
    /// - Returns: The created download task
    /// - Throws: DownloadError if the download cannot be started
    @discardableResult
    public func download(
        url: URL,
        fileName: String? = nil,
        priority: DownloadPriority = .normal,
        progress: ProgressHandler? = nil
    ) async throws -> DownloadTask {
        // Validate download
        guard await validateDownload(url: url) else {
            throw DownloadError.invalidURL
        }
        
        // Create task
        let task = DownloadTask(url: url, fileName: fileName, priority: priority)
        
        // Save and queue task
        try await storage.createDirectory(for: task)
        await queue.enqueue(task)
        await eventsManager.updateTask(task)
        
        // Set up progress tracking if provided
        if let progress = progress {
            self.downloadProgress(for: task.id)
                .sink { progressValue, speed in
                    progress(progressValue, speed)
                }
                .store(in: &cancellables)
        }
        
        return task
    }
    
    /// Pauses a download task.
    /// - Parameter id: ID of the task to pause
    /// - Throws: Error if pausing fails
    public func pauseDownload(id: UUID) async throws {
        guard let downloadTask = activeDownloads[id] else { return }
        
        var task = await eventsManager.getAllTasks().first { $0.id == id }
        task?.state = .paused
        
        if let task = task {
            await eventsManager.updateTask(task)
            await eventsManager.emitStateChange(taskId: id, state: .paused)
        }
        
        downloadTask.suspend()
    }
    
    /// Resumes a paused download task.
    /// - Parameter id: ID of the task to resume
    /// - Throws: Error if resuming fails
    public func resumeDownload(id: UUID) async throws {
        if let task = await eventsManager.getAllTasks().first(where: { $0.id == id }),
           task.state == .paused {
            var updatedTask = task
            updatedTask.state = .queued
            await queue.enqueue(updatedTask)
            await eventsManager.updateTask(updatedTask)
            await eventsManager.emitStateChange(taskId: id, state: .queued)
        }
    }
    
    /// Cancels a download task.
    /// - Parameter id: ID of the task to cancel
    /// - Throws: Error if cancellation fails
    public func cancelDownload(id: UUID) async throws {
        if let downloadTask = activeDownloads[id] {
            downloadTask.cancel()
            activeDownloads.removeValue(forKey: id)
        }
        
        if var task = await eventsManager.getAllTasks().first(where: { $0.id == id }) {
            task.state = .cancelled
            try await storage.removeTask(task.id)
            await eventsManager.updateTask(task)
            await eventsManager.emitStateChange(taskId: id, state: .cancelled)
        }
    }
    
    /// Removes completed download tasks.
    /// - Throws: Error if removal fails
    public func removeCompletedDownloads() async throws {
        let tasks = await eventsManager.getAllTasks()
        for task in tasks where task.state == .completed {
            try await storage.removeTask(task.id)
            await eventsManager.removeTask(task.id)
        }
    }
    
    // MARK: - Private Methods
    
    private func startQueueProcessing() async {
        Task.detached { [weak self] in
            guard let self = self else { return }
            
            while true {
                let activeCount =  self.activeDownloads.count
                if activeCount < self.config.maxConcurrentDownloads {
                    if let task = await self.queue.dequeue() {
                        await self.startDownload(task)
                    }
                }
                
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
    }
    
    private func startDownload(_ task: DownloadTask) async {
        var updatedTask = task
        updatedTask.state = .downloading
        
        await eventsManager.updateTask(updatedTask)
        await eventsManager.emitStateChange(taskId: task.id, state: .downloading)
        
        
        let downloadTask = session.downloadTask(with: task.url)
        downloadTask.priority = task.priority.urlSessionPriority
        activeDownloads[task.id] = downloadTask
        downloadTask.resume()
    }
    
    private func validateDownload(url: URL) async -> Bool {
        guard url.scheme == "https" else { return false }
        
        do {
            let fileSystem = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            let freeSpace = (fileSystem[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
            return freeSpace > config.minFreeDiskSpace
        } catch {
            return false
        }
    }
    
    func handleDownloadError(task: DownloadTask, error: Error) async {
        var updatedTask = task
        updatedTask.state = .failed
        updatedTask.error = error.localizedDescription
        
        await eventsManager.updateTask(updatedTask)
        await eventsManager.emitError(taskId: task.id, error: error.localizedDescription)
        await eventsManager.emitStateChange(taskId: task.id, state: .failed)
    }
    

    
    private func cleanupTemporaryFiles(for task: DownloadTask) async {
        try? await storage.removeTask(task.id)
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            Task {
                if path.status == .satisfied {
                    // Resume downloads when network becomes available
                    let tasks = await self.eventsManager.getAllTasks()
                    for task in tasks where task.state == .paused {
                        try? await self.resumeDownload(id: task.id)
                    }
                } else {
                    // Pause downloads when network is lost
                    let tasks = await self.eventsManager.getAllTasks()
                    for task in tasks where task.state == .downloading {
                        try? await self.pauseDownload(id: task.id)
                    }
                }
            }
        }
        
        networkMonitor.start(queue: DispatchQueue(label: "com.downloadmanager.network"))
    }
    
    private func restoreSession() async throws {
            // Check existing directories
        let tasks = await eventsManager.getAllTasks()
        for var task in tasks {
            if try await storage.fileExists(for: task) {
                switch task.state {
                    case .downloading, .queued:
                        task.state = .queued
                        await queue.enqueue(task)
                        await eventsManager.updateTask(task)
                        
                    case .paused:
                        await queue.enqueue(task)
                        await eventsManager.updateTask(task)
                        
                    case .completed:
                        await eventsManager.updateTask(task)
                        
                    case .failed, .cancelled:
                        try await storage.removeTask(task.id)
                }
            } else {
                    // No file exists, reset state
                if task.state == .completed {
                    task.state = .queued
                    await queue.enqueue(task)
                    await eventsManager.updateTask(task)
                }
            }
        }
    }
}

// MARK: - URLSession Delegate

private final class SessionDelegate: NSObject, URLSessionDownloadDelegate, URLSessionDataDelegate, @unchecked Sendable {
    private weak var manager: DownloadManager?
    private var receivedData: [UUID: Data] = [:] // For non-background downloads
    
    func setManager(_ manager: DownloadManager) {
        self.manager = manager
    }
    
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let temporaryDirectory = FileManager.default.temporaryDirectory
        let temporaryCopyURL = temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        try? FileManager.default.copyItem(at: location, to: temporaryCopyURL)
        
        debugPrint("Downloaded file to \(temporaryCopyURL.path)")
        Task {
            guard let manager = manager,
                  let url = downloadTask.originalRequest?.url,
                  let task = await manager.eventsManager.getAllTasks().first(where: { $0.url == url })
            else { return }
            
            do {
                
                let fileData = try Data(contentsOf: location)
                let mimeType = MimeTypeDetector.detectMimeType(from: fileData) ??
                MimeTypeDetector.detectMimeType(fromExtension: url.pathExtension)
                
                let fileName = task.fileName + (task.fileName.contains(".") ? "" : ".\(mimeType?.ext ?? "download")")
                
                var updatedTask = task
                updatedTask.fileName = fileName
                
                try await manager.storage.saveFile(at: temporaryCopyURL, for: updatedTask)
                try? FileManager.default.removeItem(at: temporaryCopyURL)
                
                updatedTask.state = .completed
                await manager.eventsManager.updateTask(updatedTask)
                await manager.eventsManager.emitStateChange(taskId: task.id, state: .completed)
                
            } catch {
                print("File error: \(error)")
                await manager.handleDownloadError(task: task, error: error)
            }
        }
    }

    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didCompleteWithError error: Error?) {
        guard let url = dataTask.originalRequest?.url,
              let taskId = manager?.activeDownloads.first(where: { $0.value == dataTask })?.key else { return }
        
        Task {
            if let error = error {
                if let task = await manager?.eventsManager.getAllTasks().first(where: { $0.id == taskId }) {
                    await manager?.handleDownloadError(task: task, error: error)
                }
            } else if let receivedData = receivedData[taskId],
                      let task = await manager?.eventsManager.getAllTasks().first(where: { $0.id == taskId }) {
                do {
                    let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    try receivedData.write(to: temporaryURL)
                    
                    var updatedTask = task
                    let mimeType = MimeTypeDetector.detectMimeType(from: receivedData) ??
                    MimeTypeDetector.detectMimeType(fromExtension: url.pathExtension)
                    
                    updatedTask.fileName = task.fileName + (task.fileName.contains(".") ? "" : ".\(mimeType?.ext ?? "download")")
                    
                    try await manager?.storage.saveFile(at: temporaryURL, for: updatedTask)
                    try? FileManager.default.removeItem(at: temporaryURL)
                    
                    updatedTask.state = .completed
                    await manager?.eventsManager.updateTask(updatedTask)
                    await manager?.eventsManager.emitStateChange(taskId: taskId, state: .completed)
                } catch {
                    await manager?.handleDownloadError(task: task, error: error)
                }
            }
            self.receivedData.removeValue(forKey: taskId)
        }
    }
    
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task {
            guard let manager = manager,
                  let url = downloadTask.originalRequest?.url,
                  let task = await manager.eventsManager.getAllTasks().first(where: { $0.url == url })
            else { return }
            
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            let speed = Double(bytesWritten)
            await manager.eventsManager.emitProgress(taskId: task.id, progress: progress, speed: speed)
        }
    }
}


/// Combine extensions for DownloadManager providing reactive interfaces
extension DownloadManager {
    /// Publisher for all download events
    public var events: AnyPublisher<DownloadEvent, Never> {
        eventsManager.eventsPublisher
    }
    
    /// Publisher for current tasks state
    public var currentTasks: AnyPublisher<[DownloadTask], Never> {
        eventsManager.tasksPublisher
    }
    
    /// Creates a publisher for updates to a specific task
    /// - Parameter taskId: ID of the task to monitor
    /// - Returns: Publisher emitting task updates
    public func taskUpdates(for taskId: UUID) -> AnyPublisher<DownloadTask, Never> {
        eventsManager.tasksPublisher
            .compactMap { tasks in
                tasks.first { $0.id == taskId }
            }
            .eraseToAnyPublisher()
    }
    
    /// Creates a publisher for download progress of a specific task
    /// - Parameter taskId: ID of the task to monitor
    /// - Returns: Publisher emitting progress updates
    public func downloadProgress(for taskId: UUID) -> AnyPublisher<(progress: Double, speed: Double), Never> {
        eventsManager.eventsPublisher
            .compactMap { event in
                if case let .progress(id, progress, speed) = event, id == taskId {
                    return (progress, speed)
                }
                return nil
            }
            .eraseToAnyPublisher()
    }
    
    /// Creates a publisher for state changes of a specific task
    /// - Parameter taskId: ID of the task to monitor
    /// - Returns: Publisher emitting state changes
    public func stateChanges(for taskId: UUID) -> AnyPublisher<DownloadState, Never> {
        eventsManager.eventsPublisher
            .compactMap { event in
                if case let .stateChange(id, state) = event, id == taskId {
                    return state
                }
                return nil
            }
            .eraseToAnyPublisher()
    }
    
    /// Creates a publisher for error events of a specific task
    /// - Parameter taskId: ID of the task to monitor
    /// - Returns: Publisher emitting error messages
    public func errors(for taskId: UUID) -> AnyPublisher<String, Never> {
        eventsManager.eventsPublisher
            .compactMap { event in
                if case let .error(id, error) = event, id == taskId {
                    return error
                }
                return nil
            }
            .eraseToAnyPublisher()
    }
}

extension DownloadManager {
    
    /// Initiates multiple downloads concurrently using async/await
    /// - Parameter urls: Array of URLs with optional filenames and priorities
    /// - Returns: Array of created download tasks
    /// - Throws: Error if any download fails
    public func downloadMultiple(
        urls: [(url: URL, fileName: String?, priority: DownloadPriority)]
    ) async throws -> [DownloadTask] {
        try await withThrowingTaskGroup(of: DownloadTask.self) { group in
            // Add all downloads to the group
            for urlInfo in urls {
                group.addTask {
                    try await self.download(
                        url: urlInfo.url,
                        fileName: urlInfo.fileName,
                        priority: urlInfo.priority
                    )
                }
            }
            
            // Collect results
            var tasks: [DownloadTask] = []
            tasks.reserveCapacity(urls.count)
            
            for try await task in group {
                tasks.append(task)
            }
            
            return tasks
        }
    }
}
