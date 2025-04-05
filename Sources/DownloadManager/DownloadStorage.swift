//
//  DownloadStorage.swift
//  SRNetworkManager
//
//  Created by Siamak on 12/21/24.
//

import Foundation

// MARK: - DownloadStorageManaging

/// Implementation of persistent storage for download tasks.
///
/// This actor provides thread-safe access to persistent storage
/// operations for download tasks using JSON serialization.
public protocol DownloadStorageManaging: Sendable {
    func createDirectory(for task: DownloadTask) async throws
    func saveFile(at sourceURL: URL, for task: DownloadTask) async throws
    func removeTask(_ taskId: UUID) async throws
    func clearAll() async throws
    func fileExists(for task: DownloadTask) async throws -> Bool
    func getDirectoryFor(task: DownloadTask) -> URL
    func getFileURL(for task: DownloadTask) -> URL
}

// MARK: - DownloadStorage

public final class DownloadStorage: DownloadStorageManaging, @unchecked Sendable
{
    // MARK: Lifecycle

    public init() async throws {
        self.fileManager = FileManager.default
        self.ioQueue = DispatchQueue(
            label: "com.SRNetworkManager.storage.io", qos: .utility)

        // Get documents directory
        let documentsURL = fileManager.urls(
            for: .documentDirectory, in: .userDomainMask)[0]
        self.baseDirectory = documentsURL.appendingPathComponent(
            "Downloads", isDirectory: true)

        // Create base downloads directory if it doesn't exist
        try await createBaseDirectory()
    }

    // MARK: Public

    public func getDirectoryFor(task: DownloadTask) -> URL {
        baseDirectory.appendingPathComponent(
            task.id.uuidString, isDirectory: true)
    }

    public func getFileURL(for task: DownloadTask) -> URL {
        let directory = getDirectoryFor(task: task)
        return directory.appendingPathComponent(task.fileName)
    }

    public func createDirectory(for task: DownloadTask) async throws {
        try await withCheckedThrowingContinuation { continuation in
            ioQueue.async {
                do {
                    let directory = self.getDirectoryFor(task: task)
                    if !self.fileManager.fileExists(atPath: directory.path) {
                        try self.fileManager.createDirectory(
                            at: directory,
                            withIntermediateDirectories: true
                        )
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func saveFile(at sourceURL: URL, for task: DownloadTask) async throws
    {
        try await withCheckedThrowingContinuation { continuation in
            ioQueue.async {
                do {
                    let directory = self.getDirectoryFor(task: task)
                    let destinationURL = directory.appendingPathComponent(
                        task.fileName)

                    // Create directory if it doesn't exist
                    if !self.fileManager.fileExists(atPath: directory.path) {
                        try self.fileManager.createDirectory(
                            at: directory,
                            withIntermediateDirectories: true
                        )
                    }

                    // Remove existing file if it exists
                    if self.fileManager.fileExists(atPath: destinationURL.path)
                    {
                        try self.fileManager.removeItem(at: destinationURL)
                    }

                    // Copy the new file
                    try self.fileManager.copyItem(
                        at: sourceURL, to: destinationURL)

                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func removeTask(_ taskId: UUID) async throws {
        try await withCheckedThrowingContinuation { continuation in
            ioQueue.async {
                do {
                    let directory = self.baseDirectory.appendingPathComponent(
                        taskId.uuidString, isDirectory: true)
                    if self.fileManager.fileExists(atPath: directory.path) {
                        try self.fileManager.removeItem(at: directory)
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func clearAll() async throws {
        try await withCheckedThrowingContinuation { continuation in
            ioQueue.async {
                do {
                    if self.fileManager.fileExists(
                        atPath: self.baseDirectory.path)
                    {
                        try self.fileManager.removeItem(at: self.baseDirectory)
                        try self.fileManager.createDirectory(
                            at: self.baseDirectory,
                            withIntermediateDirectories: true
                        )
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func fileExists(for task: DownloadTask) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            ioQueue.async {
                let fileURL = self.getFileURL(for: task)
                continuation.resume(
                    returning: self.fileManager.fileExists(atPath: fileURL.path)
                )
            }
        }
    }

    // MARK: Private

    private let fileManager: FileManager
    private let baseDirectory: URL
    private let ioQueue: DispatchQueue

    private func createBaseDirectory() async throws {
        try await withCheckedThrowingContinuation { continuation in
            ioQueue.async {
                do {
                    if !self.fileManager.fileExists(
                        atPath: self.baseDirectory.path)
                    {
                        try self.fileManager.createDirectory(
                            at: self.baseDirectory,
                            withIntermediateDirectories: true
                        )
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
