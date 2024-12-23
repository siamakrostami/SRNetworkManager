//
//  DownloadViewModel.swift
//  SRNetworkManagerExampleApp
//
//  Created by Siamak on 12/21/24.
//
import SwiftUI
import Combine
import SRNetworkManager

class DownloadViewModel: ObservableObject {
    private var downloadManager: DownloadManager?
    private var cancellables = Set<AnyCancellable>()
    
    @Published private(set) var singleDownloads: [DownloadItem] = []
    @Published private(set) var batchDownloads: [DownloadItem] = []
    @Published private(set) var isBatchDownloading = false
    
    // Real-world sample files for downloading
    private let sampleFiles = [
        (
            url: URL(string: "https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_10mb.mp4")!,
            name: "100MB Test File"
        ),
        (
            url: URL(string: "https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_20mb.mp4")!,
            name: "Linux Kernel"
        ),
        (
            url: URL(string: "https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_30mb.mp4")!,
            name: "Big Buck Bunny"
        ),
        (
            url: URL(string: "https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_40mb.mp4")!,
            name: "Firefox Browser"
        )
    ]
    
    init() {
        setupDownloadManager()
    }
    
    private func setupDownloadManager() {
        Task {
            do {
                let config = DownloadManagerConfig(
                    maxConcurrentDownloads: 3,
                    maxQueueSize: 10,
                    maxRetryAttempts: 3,
                    allowsCellularAccess: true
                )
                
                downloadManager = try await DownloadManager(configuration: config)
                setupSubscriptions()
            } catch {
                print("Failed to initialize DownloadManager: \(error)")
            }
        }
    }
    
    private func setupSubscriptions() {
        guard let downloadManager = downloadManager else { return }
        
        // Subscribe to download events
        downloadManager.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleDownloadEvent(event)
            }
            .store(in: &cancellables)
    }
    
    func addNewDownload() async {
        guard let downloadManager = downloadManager else { return }
        guard let sample = sampleFiles.randomElement() else { return }
        
        do {
            let task = try await downloadManager.download(
                url: sample.url,
                fileName: sample.name,
                priority: .normal
            ) { progress, speed in
                print("Progress: \(progress), Speed: \(speed)")
            }
            
            await MainActor.run {
                singleDownloads.append(DownloadItem(task: task))
            }
        } catch {
            print("Failed to start download: \(error)")
        }
    }
    
    func startBatchDownload() async {
        guard let downloadManager = downloadManager else { return }
        
        let downloads = sampleFiles.map { (
            url: $0.url,
            fileName: $0.name,
            priority: DownloadPriority.normal
        )}
        
        await MainActor.run {
            isBatchDownloading = true
        }
        
        do {
            let tasks = try await downloadManager.downloadMultiple(urls: downloads)
            await MainActor.run {
                batchDownloads = tasks.map { DownloadItem(task: $0) }
                isBatchDownloading = false
            }
        } catch {
            print("Batch download failed: \(error)")
            await MainActor.run {
                isBatchDownloading = false
            }
        }
    }
    
    func handleDownloadAction(_ action: DownloadAction, for download: DownloadItem) async {
        guard let downloadManager = downloadManager else { return }
        
        do {
            switch action {
            case .pause:
                try await downloadManager.pauseDownload(id: download.id)
            case .resume:
                try await downloadManager.resumeDownload(id: download.id)
            case .cancel:
                try await downloadManager.cancelDownload(id: download.id)
            case .retry:
                // Re-create the download
                try await downloadManager.download(
                    url: download.url,
                    fileName: download.fileName,
                    priority: .normal
                )
            case .remove:
                await MainActor.run {
                    singleDownloads.removeAll { $0.id == download.id }
                    batchDownloads.removeAll { $0.id == download.id }
                }
            }
        } catch {
            print("Download action failed: \(error)")
        }
    }
    
    func cancelAllDownloads() async {
        let allDownloads = singleDownloads + batchDownloads
        for download in allDownloads {
            await handleDownloadAction(.cancel, for: download)
        }
    }
    
    func removeCompletedDownloads() async {
        guard let downloadManager = downloadManager else { return }
        
        do {
            try await downloadManager.removeCompletedDownloads()
            await MainActor.run {
                singleDownloads.removeAll { $0.state == .completed }
                batchDownloads.removeAll { $0.state == .completed }
            }
        } catch {
            print("Failed to remove completed downloads: \(error)")
        }
    }
    
    private func handleDownloadEvent(_ event: DownloadEvent) {
        switch event {
        case .progress(let id, let progress, let speed):
            updateDownloadProgress(id: id, progress: progress, speed: speed)
        case .stateChange(let id, let state):
            updateDownloadState(id: id, state: state)
        case .error(let id, let error):
            print("Download error for \(id): \(error)")
        case .queueUpdated:
            break
        }
    }
    
    private func updateDownloadProgress(id: UUID, progress: Double, speed: Double) {
        if let index = singleDownloads.firstIndex(where: { $0.id == id }) {
            singleDownloads[index].progress = progress
            singleDownloads[index].speed = speed
        }
        if let index = batchDownloads.firstIndex(where: { $0.id == id }) {
            batchDownloads[index].progress = progress
            batchDownloads[index].speed = speed
        }
    }
    
    private func updateDownloadState(id: UUID, state: DownloadState) {
        if let index = singleDownloads.firstIndex(where: { $0.id == id }) {
            singleDownloads[index].state = state
        }
        if let index = batchDownloads.firstIndex(where: { $0.id == id }) {
            batchDownloads[index].state = state
        }
    }
}

struct DownloadItem: Identifiable {
    let id: UUID
    let url: URL
    let fileName: String
    var state: DownloadState
    var progress: Double
    var speed: Double
    
    init(task: DownloadTask) {
        self.id = task.id
        self.url = task.url
        self.fileName = task.fileName
        self.state = task.state
        self.progress = task.progress
        self.speed = task.speed
    }
}

enum DownloadAction {
    case pause
    case resume
    case cancel
    case retry
    case remove
}
