import SwiftUI
import UIKit
import SafariServices

/// The "Report a problem" sheet: asks what happened, shows what goes along
/// (details, log, crash logs), saves the report file and opens a prefilled
/// GitHub issue. A log too long for the link is copied for the user to paste
/// into it. See `ProblemReport`.
struct ReportProblemView: View {
    @EnvironmentObject private var engine: Engine
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer
    @ObservedObject private var ownCrashes = CrashDiagnostics.shared
    @Environment(\.dismiss) private var dismiss

    @State private var description = ""
    /// Crash logs read from this iPhone; nil until it's been asked.
    @State private var deviceCrashes: [DeviceCrashLog]?
    @State private var lookingForCrashes = false
    @State private var crashLookError: String?
    /// Crash logs unticked, by id.
    @State private var leftOut: Set<String> = []
    /// The report text the preview shows, set when it's opened.
    @State private var previewText: String?
    @State private var saveError: String?
    /// An issue whose log was copied, waiting while the user reads how to
    /// paste it.
    @State private var issueToOpen: ProblemReport.IssueDraft?
    /// True for a moment after “Copy the full log”.
    @State private var copiedLog = false

    /// An issue with nothing in it can't be acted on (#27, #37, #67), so a few
    /// words are asked for first.
    private var canSend: Bool {
        description.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
    }

    var body: some View {
        let report = ProblemReport.current(engine)
        NavigationStack {
            Form {
                descriptionSection
                includedSection(report)
                crashSection
                sendSection(report)
            }
            .navigationTitle(L("Report a problem"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("Cancel")) { dismiss() }
                }
            }
            .navigationDestination(item: $previewText) { ReportPreview(text: $0) }
            .alert(L("Paste the log into the issue"),
                   isPresented: Binding(get: { issueToOpen != nil },
                                        set: { if !$0 { issueToOpen = nil } }),
                   presenting: issueToOpen) { issue in
                Button(L("Open GitHub")) { present(issue.url) }
                Button(L("Cancel"), role: .cancel) {}
            } message: { _ in
                Text(L("The full log is too long to fill in, so SideInstaller copied it. On GitHub, tap the end of the text, choose Paste, then submit the issue."))
            }
        }
        .task {
            // Only while the tunnel is already up: opening LocalDevVPN unasked
            // would be a surprise.
            if engine.vpnConnected && engine.hasPairingFile && !engine.isRunning {
                await lookForCrashes()
            }
        }
    }

    // MARK: What happened

    private var descriptionSection: some View {
        Section {
            TextField(L("What were you doing, and what went wrong?"), text: $description, axis: .vertical)
                .lineLimit(4...12)
        } header: {
            Text(L("What happened?"))
        } footer: {
            Text(L("Say what you tapped, what you expected and what happened instead. English is best, but any language is fine."))
        }
    }

    // MARK: What goes along

    private func includedSection(_ report: ProblemReport) -> some View {
        Section {
            ForEach(report.details) { detail in
                LabeledContent(L(detail.label), value: detail.shown ?? detail.value)
            }
            if let error = report.error {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Error"))
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            LabeledContent(L("Activity log"), value: L("%d lines", report.logLines.count))
        } header: {
            Text(L("Included"))
        } footer: {
            Text(L("Your Apple ID, device name, serial numbers and keys are taken out of the log first."))
        }
    }

    // MARK: Crash logs

    private var crashSection: some View {
        Section {
            ForEach(ownCrashes.crashes) { crash in
                crashToggle(id: crash.id, title: "SideInstaller",
                            detail: "\(Self.dateText(crash.date)) · \(crash.summary)")
            }
            ForEach(deviceCrashes ?? []) { crash in
                crashToggle(id: crash.id, title: crash.app,
                            detail: crash.date.map(Self.dateText) ?? crash.name)
            }
            if lookingForCrashes {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(L("Looking for crash logs …"))
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    Task { await lookForCrashes() }
                } label: {
                    Label(deviceCrashes == nil ? L("Look for crash logs on this iPhone") : L("Look again"),
                          systemImage: "magnifyingglass")
                }
                .disabled(engine.isRunning)
            }
            if let crashLookError {
                Text(crashLookError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else if deviceCrashes?.isEmpty == true {
                Text(L("No crash logs from SideStore, LiveContainer or Madeira in the last %d days.",
                       DeviceCrashLog.maxAgeDays))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(L("Crash logs"))
        } footer: {
            Text(L("iOS hands SideInstaller its own crashes the next time it opens. Crash logs from SideStore, LiveContainer and Madeira are read from this iPhone through LocalDevVPN."))
        }
    }

    private func crashToggle(id: String, title: String, detail: String) -> some View {
        Toggle(isOn: Binding(get: { !leftOut.contains(id) },
                             set: { if $0 { leftOut.remove(id) } else { leftOut.insert(id) } })) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private static func dateText(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(Localizer.locale))
    }

    @MainActor
    private func lookForCrashes() async {
        guard !lookingForCrashes else { return }
        lookingForCrashes = true
        crashLookError = nil
        defer { lookingForCrashes = false }
        do {
            deviceCrashes = try await engine.deviceCrashLogs()
        } catch {
            crashLookError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    private var pickedDeviceCrashes: [DeviceCrashLog] {
        (deviceCrashes ?? []).filter { !leftOut.contains($0.id) }
    }

    private var pickedOwnCrashes: [CrashDiagnostics.Crash] {
        ownCrashes.crashes.filter { !leftOut.contains($0.id) }
    }

    // MARK: Send

    private func sendSection(_ report: ProblemReport) -> some View {
        Section {
            Button {
                openIssue(report)
            } label: {
                Label(L("Open a GitHub issue"), systemImage: "arrow.up.right.square")
                    .font(.body.weight(.semibold))
            }
            .disabled(!canSend)
            Button {
                copyLog(report)
            } label: {
                Label(copiedLog ? L("Copied") : L("Copy the full log"),
                      systemImage: copiedLog ? "checkmark" : "doc.on.doc")
            }
            .disabled(!canSend)
            Button {
                share(report)
            } label: {
                Label(L("Share the report"), systemImage: "square.and.arrow.up")
            }
            .disabled(!canSend)
            Button {
                previewText = fileText(report)
            } label: {
                Label(L("Preview the report"), systemImage: "doc.text.magnifyingglass")
            }
            if let saveError {
                Text(saveError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } footer: {
            Text(canSend
                 ? L("The issue opens filled in. When the log is too long for that, SideInstaller copies it for you to paste at the end of the issue. The whole report is also saved in %@.",
                     ProblemReport.reportsFolder(onMyIPhone: L("Files › On My iPhone")))
                 : L("Describe the problem above first."))
        }
    }

    private func fileText(_ report: ProblemReport) -> String {
        report.fileText(description: description, deviceCrashes: pickedDeviceCrashes,
                        ownCrashes: pickedOwnCrashes)
    }

    private func issueDraft(_ report: ProblemReport) -> ProblemReport.IssueDraft {
        report.issueDraft(description: description, deviceCrashes: pickedDeviceCrashes,
                          ownCrashes: pickedOwnCrashes)
    }

    /// Saves the file, then opens the issue. When the link can't carry the
    /// whole log, the log is copied first and an alert says where it goes.
    private func openIssue(_ report: ProblemReport) {
        guard let file = save(report) else { return }
        let issue = issueDraft(report)
        engine.log("Report a problem: saved \(file.lastPathComponent), opening a GitHub issue.")
        guard let paste = issue.pasteText else { return present(issue.url) }
        UIPasteboard.general.string = paste
        engine.log("Report a problem: the log is too long for the link, so it's copied for pasting (\(paste.count) characters).")
        issueToOpen = issue
    }

    /// Copies what the issue needs pasted, or the whole log when the link
    /// carries everything: for when the clipboard has been used since, or the
    /// issue is written somewhere else.
    private func copyLog(_ report: ProblemReport) {
        let issue = issueDraft(report)
        UIPasteboard.general.string = issue.pasteText ?? report.fileText(
            description: description, deviceCrashes: pickedDeviceCrashes, ownCrashes: pickedOwnCrashes)
        copiedLog = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            copiedLog = false
        }
    }

    /// Opens `url` in Safari inside the app: GitHub's own app would take the
    /// link and drop what's filled in.
    private func present(_ url: URL) {
        let safari = SFSafariViewController(url: url)
        safari.dismissButtonStyle = .close
        UIApplication.shared.topViewController?.present(safari, animated: true)
    }

    /// For those without GitHub: the file, to send on Discord or by mail.
    private func share(_ report: ProblemReport) {
        guard let file = save(report) else { return }
        let sheet = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        guard let top = UIApplication.shared.topViewController else { return }
        // On iPad the share sheet is a popover and needs an anchor.
        sheet.popoverPresentationController?.sourceView = top.view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY,
                                                                 width: 0, height: 0)
        top.present(sheet, animated: true)
    }

    private func save(_ report: ProblemReport) -> URL? {
        saveError = nil
        do {
            return try report.save(fileText(report))
        } catch {
            saveError = L("Couldn't save the report: %@", error.localizedDescription)
            engine.log("⛔️ Report a problem: \(saveError ?? "")")
            return nil
        }
    }
}

/// The whole report as it will be saved.
private struct ReportPreview: View {
    let text: String

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(Array(text.split(separator: "\n", omittingEmptySubsequences: false).enumerated()),
                        id: \.offset) { _, line in
                    Text(line)
                        .font(.system(.caption2, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .textSelection(.enabled)
            .padding()
        }
        .navigationTitle(L("Report"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension UIApplication {
    /// The view controller on top, which a UIKit sheet is presented from.
    var topViewController: UIViewController? {
        let window = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        var top = window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
