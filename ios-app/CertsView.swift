import SwiftUI

/// Certificate manager tab: list and revoke the iOS development certificates on
/// the signed-in Apple ID. Apple caps a free account at 3 signing certificates,
/// so revoking a stale one here frees a slot when "Install" hits that limit.
struct CertsView: View {
    @EnvironmentObject private var engine: Engine
    @ObservedObject var manager: CertManager

    /// The certificate the user tapped "Revoke" on, pending confirmation.
    @State private var pendingRevoke: DevCert?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                credentials
                actionButton
                if let error = manager.lastError {
                    errorCard(error).transition(.cardAppear)
                }
                certList
            }
            .padding(16)
            .animation(.smooth(duration: 0.35), value: manager.lastError)
            .animation(.smooth(duration: 0.35), value: manager.certs)
            .animation(.smooth(duration: 0.3), value: manager.isWorking)
        }
        .alert("Revoke this certificate?",
               isPresented: Binding(get: { pendingRevoke != nil },
                                    set: { if !$0 { pendingRevoke = nil } })) {
            Button("Revoke", role: .destructive) {
                if let cert = pendingRevoke { manager.revoke(cert) }
                pendingRevoke = nil
            }
            Button("Cancel", role: .cancel) { pendingRevoke = nil }
        } message: {
            if let cert = pendingRevoke {
                Text("“\(cert.displayName)” will be revoked. Apps already signed with this certificate will stop launching on every device. This can't be undone.")
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            Text("Certificates")
                .font(.largeTitle.bold())
            if let team = manager.teamSummary {
                Label(team, systemImage: "person.2")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: Credentials (shared with the Install tab)

    private var credentials: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Apple ID", systemImage: "person.crop.circle")
                    .font(.headline)
                TextField("Apple ID email", text: $engine.appleID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .textFieldStyle(.roundedBorder)
                SecureField("Apple ID password", text: $engine.applePassword)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .disabled(manager.isWorking || manager.revokingID != nil)
    }

    // MARK: Primary action

    private var actionButton: some View {
        Button {
            manager.loadCerts()
        } label: {
            HStack {
                if manager.isWorking {
                    ProgressView().tint(.white)
                    Text(manager.isSignedIn ? "Refreshing…" : "Signing in…")
                } else {
                    Image(systemName: manager.hasLoaded ? "arrow.clockwise" : "list.bullet.rectangle")
                        .contentTransition(.symbolEffect(.replace))
                    Text(manager.hasLoaded ? "Refresh" : "Load certificates")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(manager.isWorking || manager.revokingID != nil)
    }

    // MARK: Certificate list

    @ViewBuilder
    private var certList: some View {
        if manager.hasLoaded && manager.certs.isEmpty && !manager.isWorking {
            card {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.seal")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No development certificates")
                        .font(.subheadline.bold())
                    Text("This Apple ID has no iOS development certificates to revoke.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
            .transition(.cardAppear)
        } else if !manager.certs.isEmpty {
            VStack(spacing: 12) {
                HStack {
                    Text("\(manager.certs.count) of 3 certificates")
                        .font(.subheadline.bold())
                    Spacer()
                }
                ForEach(manager.certs) { cert in
                    certRow(cert)
                }
            }
        }
    }

    private func certRow(_ cert: DevCert) -> some View {
        let revoking = manager.revokingID == cert.id
        return card(tint: cert.isExpired ? .orange : .secondary) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cert.displayName)
                            .font(.subheadline.bold())
                        if let machine = cert.machineLabel {
                            Label(machine, systemImage: "desktopcomputer")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if cert.isExpired {
                        Text("expired")
                            .font(.caption2.bold())
                            .foregroundStyle(.orange)
                    }
                }
                if let expiry = cert.expiresAt {
                    Label("Expires \(expiry.formatted(date: .abbreviated, time: .omitted))",
                          systemImage: "calendar")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if !cert.serialNumber.isEmpty {
                    Text("Serial \(cert.serialNumber)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Button(role: .destructive) {
                    pendingRevoke = cert
                } label: {
                    HStack {
                        if revoking {
                            ProgressView().controlSize(.small)
                            Text("Revoking…")
                        } else {
                            Image(systemName: "trash")
                            Text("Revoke")
                        }
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.small)
                .disabled(revoking || manager.isWorking || manager.revokingID != nil)
            }
        }
    }

    // MARK: Error

    private func errorCard(_ message: String) -> some View {
        card(tint: .red) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Couldn't complete that", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Card helper (mirrors ContentView's)

    private func card<Content: View>(tint: Color = .secondary,
                                     @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(tint.opacity(0.25), lineWidth: 1)
            )
    }
}
