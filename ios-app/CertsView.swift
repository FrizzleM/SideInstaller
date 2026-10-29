import SwiftUI

/// Lists and revokes the Apple ID's development certificates (e.g. to fix error
/// 7460), exports the one SideInstaller signs with, or signs with SideStore's
/// instead. Pushed from Tools (relies on its `NavigationStack`).
struct CertsView: View {
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer
    @ObservedObject var manager: CertManager

    @State private var showSettings = false
    /// The certificate the user tapped "Revoke" on, pending confirmation.
    @State private var pendingRevoke: DevCert?
    /// The certificate the user tapped "Export" on, pending a password.
    @State private var pendingExport: DevCert?
    @State private var exportPassword = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header.cascadeItem(0)
                loadButton.cascadeItem(1)
                if manager.sideStoreInstalled {
                    sideStoreCard.cascadeItem(2)
                }
                // Errors show as a popup, which `RootView` lays over the app.
                certList
            }
            // Here rather than beside the revoke alert: one view, one alert.
            .alert(L("Export certificate"),
                   isPresented: Binding(get: { pendingExport != nil },
                                        set: { if !$0 { endExport() } })) {
                SecureField(L("Password (optional)"), text: $exportPassword)
                Button(L("Export")) {
                    if let cert = pendingExport {
                        manager.export(cert, password: exportPassword, share: share)
                    }
                    endExport()
                }
                Button(L("Cancel"), role: .cancel) { endExport() }
            } message: {
                Text(L("Saves this certificate and its private key as a .p12 file, for another signing app or a computer to sign with. Leave the password empty for no protection, or choose one — you'll need it later to import the file. Keep the file to yourself."))
            }
            .padding(20)
            .pageColumn()
            .animation(.smooth(duration: 0.35), value: manager.certs)
            .animation(.smooth(duration: 0.3), value: manager.isWorking)
            .animation(.smooth(duration: 0.3), value: manager.isImporting)
            .animation(.smooth(duration: 0.35), value: manager.teamSummary)
        }
        .background(AppBackground())
        .toolbar { settingsToolbarItem(isPresented: $showSettings) }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .onAppear { manager.autoLoad() }
        .alert(L("Revoke this certificate?"),
               isPresented: Binding(get: { pendingRevoke != nil },
                                    set: { if !$0 { pendingRevoke = nil } })) {
            Button(L("Revoke"), role: .destructive) {
                if let cert = pendingRevoke { manager.revoke(cert) }
                pendingRevoke = nil
            }
            Button(L("Cancel"), role: .cancel) { pendingRevoke = nil }
        } message: {
            if let cert = pendingRevoke {
                Text(L("“%@” will be revoked. Apps already signed with it will stop launching on every device. This can't be undone.",
                       cert.displayName))
            }
        }
    }

    // MARK: Header

    private var header: some View {
        BrandHeader(icon: "checkmark.seal.fill", image: "CertsLogo", title: L("Certificates")) {
            if let team = manager.teamSummary {
                StatusPill(text: team, systemImage: "person.2.fill", color: .green)
                    .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .top)))
            }
        }
    }

    // MARK: Primary action

    private var loadButton: some View {
        Button {
            manager.loadCerts()
        } label: {
            HStack(spacing: 10) {
                if manager.isWorking {
                    ProgressView().tint(.white)
                    Text(manager.isSignedIn ? L("Refreshing") : L("Signing in"))
                } else {
                    Image(systemName: manager.hasLoaded ? "arrow.clockwise" : "list.bullet.rectangle.fill")
                        .contentTransition(.symbolEffect(.replace))
                    Text(manager.hasLoaded ? L("Refresh") : L("Load certificates"))
                }
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(manager.isBusy)
    }

    // MARK: SideStore's certificate

    /// Signs with SideStore's certificate instead of a certificate of its own,
    /// which a free Apple ID can't have alongside SideStore's.
    private var sideStoreCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(L("SideStore opens and sends back its certificate. SideInstaller then signs with it too, so on a free Apple ID neither app has to revoke the other's."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    manager.requestSideStoreCertificate(retryInstall: false)
                } label: {
                    HStack(spacing: 6) {
                        if manager.isImporting {
                            ProgressView().controlSize(.small)
                            Text(L("Checking the certificate"))
                        } else {
                            Image(systemName: "checkmark.seal")
                            Text(L("Use SideStore's certificate"))
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered, sound: .tap)
                .tint(Theme.accent)
                .disabled(manager.isBusy)
            }
        }
    }

    // MARK: Certificate list

    @ViewBuilder
    private var certList: some View {
        if manager.hasLoaded && manager.certs.isEmpty && !manager.isWorking {
            emptyState.transition(.cardAppear)
        } else if !manager.certs.isEmpty {
            VStack(spacing: 14) {
                HStack {
                    // Count only; Apple doesn't report the account's limit.
                    Text(L("%d certificate(s)", manager.certs.count))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .cascadeItem(3)
                if manager.hasLoaded {
                    Text(L("Pick any certificate and tap Export. Only the one SideInstaller signs with has its private key on this iPhone — others will show an error because the key stays on the device that asked Apple for it."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .cascadeItem(3)
                }
                ForEach(Array(manager.certs.enumerated()), id: \.element.id) { idx, cert in
                    certRow(cert).cascadeItem(4 + idx)
                }
            }
        }
    }

    private var emptyState: some View {
        PanelCard {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.brand)
                Text(L("No certificates"))
                    .font(.headline)
                Text(L("This Apple ID has no development certificates to revoke."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private func certRow(_ cert: DevCert) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "seal.fill")
                        .font(.title3)
                        .foregroundStyle(cert.isExpired ? Theme.gradient(.orange) : Theme.brand)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(cert.displayName)
                            .font(.subheadline.weight(.semibold))
                        if let machine = cert.machineLabel {
                            Label(machine, systemImage: "desktopcomputer")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if cert.isSigning {
                            Label(L("SideInstaller signs with this one"), systemImage: "checkmark.seal.fill")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.green)
                        }
                    }
                    Spacer()
                    if cert.isExpired {
                        Text(L("Expired"))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.orange.opacity(0.16)))
                    }
                }

                if cert.expiresAt != nil || !cert.serialNumber.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        if let expiry = cert.expiresAt {
                            Label(L("Expires %@", expiry.formatted(
                                       Date.FormatStyle(date: .abbreviated, time: .omitted)
                                           .locale(Localizer.locale))),
                                  systemImage: "calendar")
                        }
                        if !cert.serialNumber.isEmpty {
                            Label(cert.serialNumber, systemImage: "number")
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    exportButton(cert)
                    revokeButton(cert)
                }
            }
        }
    }

    private func exportButton(_ cert: DevCert) -> some View {
        Button {
            exportPassword = ""
            pendingExport = cert
        } label: {
            HStack(spacing: 6) {
                if manager.exportingID == cert.id {
                    ProgressView().controlSize(.small)
                    Text(L("Exporting"))
                } else {
                    Image(systemName: "square.and.arrow.up")
                    Text(L("Export"))
                }
            }
            .font(.subheadline.weight(.medium))
            // Two side by side leave little room for "Exporting" in some languages.
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered, sound: .tap)
        .tint(Theme.accent)
        .controlSize(.regular)
        .disabled(manager.isBusy)
    }

    private func revokeButton(_ cert: DevCert) -> some View {
        Button(role: .destructive) {
            pendingRevoke = cert
        } label: {
            HStack(spacing: 6) {
                if manager.revokingID == cert.id {
                    ProgressView().controlSize(.small)
                    Text(L("Revoking"))
                } else {
                    Image(systemName: "trash")
                    Text(L("Revoke"))
                }
            }
            .font(.subheadline.weight(.medium))
            // Two side by side leave little room for "Exporting" in some languages.
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered, sound: .tap)
        .tint(.red)
        .controlSize(.regular)
        .disabled(manager.isBusy)
    }

    // MARK: Export

    private func endExport() {
        pendingExport = nil
        exportPassword = ""
    }

    /// Offers the exported .p12 to Files, AirDrop or a signing app, then deletes
    /// it and its folder: it holds the private key.
    private func share(_ file: URL) {
        let folder = file.deletingLastPathComponent()
        // The password prompt may still be animating away.
        var top = UIApplication.shared.topViewController
        while let leaving = top, leaving.isBeingDismissed { top = leaving.presentingViewController }
        guard let top else {
            try? FileManager.default.removeItem(at: folder)
            return
        }
        let sheet = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        sheet.completionWithItemsHandler = { _, _, _, _ in
            try? FileManager.default.removeItem(at: folder)
        }
        // On iPad the share sheet is a popover and needs an anchor.
        sheet.popoverPresentationController?.sourceView = top.view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY,
                                                                 width: 0, height: 0)
        top.present(sheet, animated: true)
    }
}
