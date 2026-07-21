import SwiftUI

/// Certificate manager: list and revoke the iOS development certificates on the
/// signed-in Apple ID. Apple caps a free account at 3 signing certificates, so
/// revoking a stale one here frees a slot when "Install" hits that limit.
struct CertsView: View {
    @EnvironmentObject private var engine: Engine
    /// Declared so every label on this screen redraws when the language changes.
    @EnvironmentObject private var loc: Localizer
    @ObservedObject var manager: CertManager

    @State private var showSettings = false
    /// The certificate the user tapped "Revoke" on, pending confirmation.
    @State private var pendingRevoke: DevCert?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header.cascadeItem(0)
                    appleIDCard.cascadeItem(1)
                    loadButton.cascadeItem(2)
                    if let error = manager.lastError {
                        errorCallout(error).transition(.cardAppear)
                    }
                    certList
                }
                .padding(20)
                .animation(.smooth(duration: 0.35), value: manager.lastError)
                .animation(.smooth(duration: 0.35), value: manager.certs)
                .animation(.smooth(duration: 0.3), value: manager.isWorking)
                .animation(.smooth(duration: 0.35), value: manager.teamSummary)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppBackground())
            .toolbar { settingsToolbarItem(isPresented: $showSettings) }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
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

    // MARK: Apple ID (shared with the Install tab)

    private var appleIDCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Apple ID", systemImage: "person.crop.circle.fill")
                TextField(L("Email"), text: $engine.appleID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .textFieldStyle(.plain)
                    .fieldBackground()
                SecureField(L("Password"), text: $engine.applePassword)
                    .textContentType(.password)
                    .textFieldStyle(.plain)
                    .fieldBackground()
            }
        }
        .disabled(manager.isWorking || manager.revokingID != nil)
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
        .disabled(manager.isWorking || manager.revokingID != nil)
    }

    // MARK: Certificate list

    @ViewBuilder
    private var certList: some View {
        if manager.hasLoaded && manager.certs.isEmpty && !manager.isWorking {
            emptyState.transition(.cardAppear)
        } else if !manager.certs.isEmpty {
            VStack(spacing: 14) {
                HStack {
                    Text(L("%d of 3 certificates", manager.certs.count))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .cascadeItem(3)
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
        let revoking = manager.revokingID == cert.id
        return PanelCard {
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

                Button(role: .destructive) {
                    pendingRevoke = cert
                } label: {
                    HStack(spacing: 6) {
                        if revoking {
                            ProgressView().controlSize(.small)
                            Text(L("Revoking"))
                        } else {
                            Image(systemName: "trash")
                            Text(L("Revoke"))
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.regular)
                .disabled(revoking || manager.isWorking || manager.revokingID != nil)
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
                    Text(L("Something went wrong"))
                        .font(.subheadline.weight(.semibold))
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Helpers

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        Label {
            Text(title).font(.headline)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Theme.brand)
        }
    }
}
