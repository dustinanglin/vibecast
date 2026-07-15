import SwiftUI

/// Global download preferences + storage management. Presented as a sheet
/// from the masthead gear button.
struct DownloadSettingsView: View {
    @Environment(\.downloadManager) private var downloadManager
    @Environment(\.dismiss) private var dismiss

    @State private var autoEnabled = DownloadSettings.autoDownloadEnabled()
    @State private var keepLastN = DownloadSettings.keepLastN()
    @State private var deleteWhenPlayed = DownloadSettings.deleteWhenPlayed()
    @State private var wifiOnly = DownloadSettings.wifiOnly()
    @State private var storageBytes: Int64 = 0
    @State private var showDeleteAllConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Download new episodes", isOn: $autoEnabled)
                        .onChange(of: autoEnabled) { _, value in
                            DownloadSettings.setAutoDownloadEnabled(value)
                        }
                    Picker("Keep per show", selection: $keepLastN) {
                        Text("1").tag(1)
                        Text("3").tag(3)
                        Text("5").tag(5)
                        Text("10").tag(10)
                        Text("All").tag(0)
                    }
                    .onChange(of: keepLastN) { _, value in
                        DownloadSettings.setKeepLastN(value)
                        downloadManager?.pruneAll()
                        refreshStorage()
                    }
                } header: {
                    Text("Automatic downloads")
                } footer: {
                    Text("The newest episode of each show downloads when it appears. Episodes you download yourself are always kept.")
                }

                Section("Playback") {
                    Toggle("Delete when played", isOn: $deleteWhenPlayed)
                        .onChange(of: deleteWhenPlayed) { _, value in
                            DownloadSettings.setDeleteWhenPlayed(value)
                        }
                }

                Section("Network") {
                    Toggle("Download on Wi-Fi only", isOn: $wifiOnly)
                        .onChange(of: wifiOnly) { _, value in
                            DownloadSettings.setWifiOnly(value)
                        }
                }

                Section("Storage") {
                    LabeledContent("Storage used", value: formattedStorage)
                    Button("Delete All Downloads", role: .destructive) {
                        showDeleteAllConfirm = true
                    }
                    .disabled(storageBytes == 0)
                }
            }
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Delete all downloaded episodes?",
                isPresented: $showDeleteAllConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete All", role: .destructive) {
                    downloadManager?.deleteAllDownloads()
                    refreshStorage()
                }
            }
            .onAppear { refreshStorage() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var formattedStorage: String {
        ByteCountFormatter.string(fromByteCount: storageBytes, countStyle: .file)
    }

    private func refreshStorage() {
        storageBytes = downloadManager?.totalStorageBytes() ?? 0
    }
}

#Preview {
    DownloadSettingsView()
}
