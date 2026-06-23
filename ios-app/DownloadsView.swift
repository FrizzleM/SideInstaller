import SwiftUI

/// Downloads manager: lists the SideStore / SS + LiveContainer IPAs the app has
/// fetched into Documents and lets the user delete them to reclaim space. The
/// install flow re-downloads on demand, so removing a file here is non-destructive.
struct DownloadsView: View {
    @ObservedObject var manager: DownloadsManager

    @State private var showSettings = false
    /// The IPA the user tapped "Delete" on, pending confirmation.
    @State private var pendingDelete: DownloadedIPA?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header.cascadeItem(0)
                    if let error = manager.lastError {
                        errorCallout(error).transition(.cardAppear)
                    }
                    downloadList
                }
                .padding(20)
                .animation(.smooth(duration: 0.35), value: manager.lastError)
                .animation(.smooth(duration: 0.35), value: manager.downloads)
                .animation(.smooth(duration: 0.3), value: manager.deletingID)
            }
            .background(AppBackground())
            .toolbar { settingsToolbarItem(isPresented: $showSettings) }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
        .onAppear { manager.refresh() }
        .alert("Delete this download?",
               isPresented: Binding(get: { pendingDelete != nil },
                                    set: { if !$0 { pendingDelete = nil } })) {
            Button("Delete", role: .destructive) {
                if let item = pendingDelete { manager.delete(item) }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            if let item = pendingDelete {
                Text("“\(item.fileName)” (\(item.sizeText)) will be removed. You can download it again any time from the Install tab.")
            }
        }
    }

    // MARK: Header

    private var header: some View {
        BrandHeader(icon: "arrow.down.circle.fill", image: "DownloadsLogo", title: "Downloads") {
            if !manager.downloads.isEmpty {
                StatusPill(text: "\(manager.totalSizeText) used",
                           systemImage: "internaldrive.fill", color: .green)
                    .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .top)))
            }
        }
    }

    // MARK: List

    @ViewBuilder
    private var downloadList: some View {
        if manager.hasLoaded && manager.downloads.isEmpty {
            emptyState.cascadeItem(1)
        } else if !manager.downloads.isEmpty {
            VStack(spacing: 14) {
                HStack {
                    Text("\(manager.downloads.count) downloaded \(manager.downloads.count == 1 ? "file" : "files")")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .cascadeItem(1)
                ForEach(Array(manager.downloads.enumerated()), id: \.element.id) { idx, item in
                    downloadRow(item).cascadeItem(2 + idx)
                }
            }
        }
    }

    private var emptyState: some View {
        PanelCard {
            VStack(spacing: 8) {
                Image(systemName: "arrow.down.circle")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.brand)
                Text("No downloads")
                    .font(.headline)
                Text("IPAs you download from the Install tab show up here so you can delete them later.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private func downloadRow(_ item: DownloadedIPA) -> some View {
        let deleting = manager.deletingID == item.id
        return PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "shippingbox.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.brand)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.displayName)
                            .font(.subheadline.weight(.semibold))
                        Text(item.fileName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Text(item.sizeText)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.accent2)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.accent.opacity(0.16)))
                }

                if let modified = item.modified {
                    Label("Downloaded \(modified.formatted(date: .abbreviated, time: .shortened))",
                          systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button(role: .destructive) {
                    pendingDelete = item
                } label: {
                    HStack(spacing: 6) {
                        if deleting {
                            ProgressView().controlSize(.small)
                            Text("Deleting")
                        } else {
                            Image(systemName: "trash")
                            Text("Delete")
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.regular)
                .disabled(deleting || manager.deletingID != nil)
            }
        }
    }

    // MARK: Error

    private func errorCallout(_ message: String) -> some View {
        CalloutCard(tint: .red) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Something went wrong")
                        .font(.subheadline.weight(.semibold))
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
