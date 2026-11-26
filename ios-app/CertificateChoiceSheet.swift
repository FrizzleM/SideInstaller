import SwiftUI

/// F-1/F-2 (0.9.179): the certificate choice shared by the self-update
/// and the share-in install — one component, not two. The sheet asks
/// which certificate signs the IPA before anything installs, and the
/// choice itself says what each one does to the Bundle ID, so the
/// duplicate-icon surprise (personal-ID signing rewrites the ID to
/// "original ID.team ID") is visible before the tap, not after.
/// The renewal iron rule is untouched: this only picks how an install
/// is signed, never which team a renewal touches.
struct SigningChoiceRequest: Identifiable {
    let id = UUID()
    /// The staged IPA to hand to the enterprise signing page.
    let ipaURL: URL
}

/// The choice sheet itself: two signing rows with their Bundle ID
/// consequences, plus Cancel. No state of its own — the caller owns
/// what happens on a choice.
struct CertificateChoiceSheet: View {
    var onChoose: (CZFSignIdentity) -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("Choose how to sign"))
                .font(.headline)
            choiceRow(
                identity: .enterprise,
                systemImage: "checkmark.seal",
                title: L("企业证书"),
                detail: L("Enterprise signing keeps the Bundle ID unchanged."))
            choiceRow(
                identity: .appleID,
                systemImage: "person.crop.circle",
                title: L("Apple ID"),
                detail: L("Apple ID signing changes the Bundle ID to “original ID.team ID”, so it installs as a second icon."))
            Button(L("Cancel"), role: .cancel) { onCancel() }
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(20)
    }

    private func choiceRow(identity: CZFSignIdentity, systemImage: String, title: String, detail: String) -> some View {
        Button { onChoose(identity) } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(12)
            .background(Theme.control)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

/// F-1 (0.9.179): the self-update choice shared by AboutView's version
/// pill and the Install banner — one handler, not two. The identity is
/// remembered (B-2) either way; Apple ID runs the existing pipeline,
/// enterprise downloads the verified IPA and hands it to the signing
/// page via `CertWorkspace`.
@MainActor
func chooseSelfUpdateIdentity(
    _ identity: CZFSignIdentity,
    updateChecker: UpdateChecker,
    certWorkspace: CertWorkspace
) {
    identity.store()
    switch identity {
    case .appleID:
        updateChecker.startSelfUpdate()
    case .enterprise:
        updateChecker.startSelfUpdateEnterprise { url in
            certWorkspace.selectedIPA = url
            certWorkspace.openEnterpriseSign = true
        }
    }
}

/// F-2 (0.9.179): hosts the share-in certificate choice sheet on
/// RootView — a separate modifier (SourcesBadgeRecountModifier 同款)
/// so `RootView.body` doesn't grow another long chain for the
/// compiler to type-check.
struct SigningChoiceSheetModifier: ViewModifier {
    @Environment(Engine.self) private var engine
    @EnvironmentObject private var certWorkspace: CertWorkspace

    func body(content: Content) -> some View {
        content.sheet(item: Bindable(engine).pendingSigningChoice) { request in
            CertificateChoiceSheet(
                onChoose: { choose($0, request: request) },
                onCancel: { engine.pendingSigningChoice = nil }
            )
        }
    }

    /// F-2 (0.9.179): the share-in choice. Apple ID runs the existing
    /// one-click pipeline on the staged import; enterprise hands the
    /// staged IPA to the signing page. The identity is remembered
    /// (B-2) either way; the request is cleared first, so the sheet
    /// is gone before the Install sheet / signing page comes forward.
    private func choose(_ identity: CZFSignIdentity, request: SigningChoiceRequest) {
        engine.pendingSigningChoice = nil
        identity.store()
        switch identity {
        case .appleID:
            engine.installSource = .custom
            engine.sharedIPAReady = true
            engine.runOneClick()
        case .enterprise:
            certWorkspace.selectedIPA = request.ipaURL
            certWorkspace.openEnterpriseSign = true
        }
    }
}
