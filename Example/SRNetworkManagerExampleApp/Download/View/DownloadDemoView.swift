//
//  DownloadDemoView.swift
//  SRNetworkManagerExampleApp
//
//  Created by Siamak on 12/21/24.
//


import SwiftUI
import Combine
import SRNetworkManager

struct DownloadDemoView: View {
    @StateObject private var viewModel = DownloadViewModel()
    
    var body: some View {
        NavigationView {
            List {
                // Single Download Section
                Section(header: Text("Single Downloads")) {
                    ForEach(viewModel.singleDownloads) { download in
                        DownloadItemView(download: download) { action in
                            Task {
                                await viewModel.handleDownloadAction(action, for: download)
                            }
                        }
                    }
                }
                
                // Batch Download Section
                Section(header: Text("Batch Downloads")) {
                    Button(action: {
                        Task {
                            await viewModel.startBatchDownload()
                        }
                    }) {
                        Text("Start Batch Download")
                            .disabled(viewModel.isBatchDownloading)
                    }
                    
                    if !viewModel.batchDownloads.isEmpty {
                        ForEach(viewModel.batchDownloads) { download in
                            DownloadItemView(download: download) { action in
                                Task {
                                    await viewModel.handleDownloadAction(action, for: download)
                                }
                            }
                        }
                    }
                }
                
                // Controls Section
                Section {
                    Button(role: .destructive, action: {
                        Task {
                            await viewModel.cancelAllDownloads()
                        }
                    }) {
                        Text("Cancel All Downloads")
                    }
                    
                    Button(action: {
                        Task {
                            await viewModel.removeCompletedDownloads()
                        }
                    }) {
                        Text("Remove Completed")
                    }
                }
            }
            .navigationTitle("Download Manager Demo")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.addNewDownload()
                        }
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

struct DownloadItemView: View {
    let download: DownloadItem
    let onAction: (DownloadAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(download.fileName)
                    .font(.headline)
                Spacer()
                downloadStatusView
            }
            
            if download.state == .downloading {
                ProgressView(value: download.progress) {
                    HStack {
                        Text("\(Int(download.progress * 100))%")
                        Spacer()
                        Text(formatSpeed(download.speed))
                    }
                    .font(.caption)
                }
            }
            
            HStack {
                Spacer()
                downloadActionButton
            }
        }
        .padding(.vertical, 4)
    }
    
    private var downloadStatusView: some View {
        HStack {
            switch download.state {
            case .queued:
                Image(systemName: "clock")
                    .foregroundColor(.orange)
            case .downloading:
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.blue)
            case .paused:
                Image(systemName: "pause.circle")
                    .foregroundColor(.yellow)
            case .completed:
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.green)
            case .failed:
                Image(systemName: "xmark.circle")
                    .foregroundColor(.red)
            case .cancelled:
                Image(systemName: "slash.circle")
                    .foregroundColor(.gray)
            }
            Text(download.state.rawValue.capitalized)
                .font(.caption)
        }
    }
    
    private var downloadActionButton: some View {
        HStack {
            switch download.state {
                case .queued, .downloading:
                    HStack {
                        Button("Pause") {
                            onAction(.pause)
                        }
                        Button(role: .destructive) {
                            onAction(.cancel)
                        } label: {
                            Text("Cancel")
                        }
                    }
                    
                case .paused:
                    Button("Resume") {
                        onAction(.resume)
                    }
                    
                case .completed:
                    Button("Remove") {
                        onAction(.remove)
                    }
                    
                case .failed:
                    Button("Retry") {
                        onAction(.retry)
                    }
                    
                case .cancelled:
                    Button("Remove") {
                        onAction(.remove)
                    }
            }
        }
    }
    
    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        let mbps = bytesPerSecond / 1_048_576 // Convert to MB/s
        return String(format: "%.1f MB/s", mbps)
    }
}


