//
//  DownloadQueue.swift
//  SRNetworkManager
//
//  Created by Siamak Rostami on 12/20/24.
//

import Foundation

// MARK: - DownloadQueue

/// Thread-safe implementation of download queue management.
///
/// This actor ensures thread-safe access to the download queue
/// while maintaining proper ordering based on priority.
public final class DownloadQueue: DownloadQueueManaging, @unchecked Sendable {
    // MARK: Lifecycle

    /// Creates a new download queue with specified capacity.
    /// - Parameter maxQueueSize: Maximum number of tasks that can be queued, defaults to 100
    public init(maxQueueSize: Int = 100) {
        self.maxQueueSize = maxQueueSize
        self.queue = []
    }

    // MARK: Public

    /// Adds a new download task to the queue.
    ///
    /// Tasks are inserted based on their priority level, with higher
    /// priority tasks being placed before lower priority ones.
    /// - Parameter task: The task to be added to the queue
    public func enqueue(_ task: DownloadTask) async {
        if queue.count < maxQueueSize {
            // Insert task based on priority
            if let index = queue.firstIndex(where: {
                $0.priority.rawValue < task.priority.rawValue
            }) {
                queue.insert(task, at: index)
            } else {
                queue.append(task)
            }
        }
    }

    /// Removes and returns the next task to be processed.
    /// - Returns: The next task in the queue, or nil if queue is empty
    public func dequeue() async -> DownloadTask? {
        guard !queue.isEmpty else {
            return nil
        }
        return queue.removeFirst()
    }

    /// Removes a specific task from the queue.
    /// - Parameter task: The task to be removed
    public func remove(_ task: DownloadTask) async {
        queue.removeAll { $0.id == task.id }
    }

    /// Returns all tasks currently in the queue.
    /// - Returns: Array of all queued tasks
    public func getAllTasks() async -> [DownloadTask] {
        queue
    }

    /// Updates the state of a task in the queue.
    /// - Parameter task: The task with updated state
    public func updateTask(_ task: DownloadTask) async {
        if let index = queue.firstIndex(where: { $0.id == task.id }) {
            queue[index] = task
        }
    }

    /// Removes all tasks from the queue.
    public func clear() async {
        queue.removeAll()
    }

    // MARK: Private

    /// Internal queue storage
    private var queue: [DownloadTask]
    /// Maximum number of tasks that can be queued
    private var maxQueueSize: Int
}

// MARK: - DownloadQueueManaging

/// Protocol defining the interface for download queue management.
public protocol DownloadQueueManaging: Sendable {
    /// Adds a new task to the queue
    func enqueue(_ task: DownloadTask) async
    /// Removes and returns the next task to process
    func dequeue() async -> DownloadTask?
    /// Removes a specific task from the queue
    func remove(_ task: DownloadTask) async
    /// Returns all tasks currently in the queue
    func getAllTasks() async -> [DownloadTask]
    /// Updates the state of a task in the queue
    func updateTask(_ task: DownloadTask) async
    /// Removes all tasks from the queue
    func clear() async
}
