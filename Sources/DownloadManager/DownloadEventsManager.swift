import Foundation
import Combine

/// Protocol defining the interface for download event management
public protocol DownloadEventManaging: Sendable {
    var eventsPublisher: AnyPublisher<DownloadEvent, Never> { get }
    var tasksPublisher: AnyPublisher<[DownloadTask], Never> { get }
    
    func emitProgress(taskId: UUID, progress: Double, speed: Double) async
    func emitStateChange(taskId: UUID, state: DownloadState) async
    func emitError(taskId: UUID, error: String) async
    func updateTask(_ task: DownloadTask) async
    func removeTask(_ taskId: UUID) async
    func getAllTasks() async -> [DownloadTask]
}

/// Manages download-related events and state updates.
///
/// This actor provides thread-safe event emission and state tracking
/// for all download operations, supporting both individual task
/// monitoring and global event observation.
import Foundation
import Combine

public final class DownloadEventsManager: DownloadEventManaging, @unchecked Sendable {
        // MARK: - Properties
    
    private let eventSubject: PassthroughSubject<DownloadEvent, Never>
    private let taskSubject: CurrentValueSubject<[DownloadTask], Never>
    private var tasks: [UUID: DownloadTask]
    
        // Serial queue for synchronization
    private let queue: DispatchQueue
    
        // MARK: - Initialization
    
    public init() {
        self.eventSubject = PassthroughSubject<DownloadEvent, Never>()
        self.taskSubject = CurrentValueSubject<[DownloadTask], Never>([])
        self.tasks = [:]
        self.queue = DispatchQueue(label: "com.SRNetworkManager.eventsManager")
    }
    
        // MARK: - Public Interface
    
    public var eventsPublisher: AnyPublisher<DownloadEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    public var tasksPublisher: AnyPublisher<[DownloadTask], Never> {
        taskSubject.eraseToAnyPublisher()
    }
    
    public func emitProgress(taskId: UUID, progress: Double, speed: Double) async {
        queue.async { [weak self] in
            self?.eventSubject.send(.progress(taskId, progress, speed))
        }
    }
    
    public func emitStateChange(taskId: UUID, state: DownloadState) async {
        queue.async { [weak self] in
            self?.eventSubject.send(.stateChange(taskId, state))
        }
    }
    
    public func emitError(taskId: UUID, error: String) async {
        queue.async { [weak self] in
            self?.eventSubject.send(.error(taskId, error))
        }
    }
    
    public func updateTask(_ task: DownloadTask) async {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                self.tasks[task.id] = task
                self.taskSubject.send(Array(self.tasks.values))
                continuation.resume()
            }
        }
    }
    
    public func removeTask(_ taskId: UUID) async {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                self.tasks.removeValue(forKey: taskId)
                self.taskSubject.send(Array(self.tasks.values))
                continuation.resume()
            }
        }
    }
    
    public func getAllTasks() async -> [DownloadTask] {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(returning: Array(self.tasks.values))
            }
        }
    }
    
    public func getAllTasks() -> [DownloadTask] {
        queue.sync {
            return Array(self.tasks.values)
        }
    }
    
        // MARK: - Helper Methods
    
    public func updateTasks(_ tasks: [DownloadTask]) async {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                for task in tasks {
                    self.tasks[task.id] = task
                }
                self.taskSubject.send(Array(self.tasks.values))
                continuation.resume()
            }
        }
    }
    
    public func removeTasks(_ taskIds: [UUID]) async {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                for id in taskIds {
                    self.tasks.removeValue(forKey: id)
                }
                self.taskSubject.send(Array(self.tasks.values))
                continuation.resume()
            }
        }
    }
    
    public func clearAllTasks() async {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                self.tasks.removeAll()
                self.taskSubject.send([])
                continuation.resume()
            }
        }
    }
}

    // MARK: - Helper Extensions

extension DownloadEventsManager {
    public func getTasks(inState state: DownloadState) async -> [DownloadTask] {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }
                let filteredTasks = self.tasks.values.filter { $0.state == state }
                continuation.resume(returning: Array(filteredTasks))
            }
        }
    }
    
    public func getTask(withId id: UUID) async -> DownloadTask? {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: self.tasks[id])
            }
        }
    }
    
    public func hasTask(withId id: UUID) async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }
                continuation.resume(returning: self.tasks[id] != nil)
            }
        }
    }
}
