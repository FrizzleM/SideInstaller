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

    @Environment(Engine.self) private var engine
    /// P1-2 (0.9.186): the signing account picker, same store as the
    /// install page — the Apple ID choice below signs as the account
    /// picked here, not whatever Settings last had active.
    @EnvironmentObject private var accounts: AccountStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // U-2 (0.9.190): new shell — the section title, not a
            // hand-written headline.
            SectionTitle(title: L("Choose how to sign"), systemImage: "signature")
            if !accounts.accounts.isEmpty {
                HStack(spacing: 10) {
                    Text(L("签名账号"))
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    Menu {
                        ForEach(accounts.accounts) { account in
                            Button { Task { await pickSigningAccount(account) } } label: {
                                Label {
                                    Text(account.appleID)
                                } icon: {
                                    if accounts.isActive(account) { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        Text(accounts.active?.appleID ?? L("Add Apple ID"))
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Theme.accent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .buttonStyle(.plain)
                }
                if let team = accounts.team(for: engine.normalizedAppleID) {
                    HStack(spacing: 10) {
                        Text(L("Team"))
                            .font(.subheadline.weight(.semibold))
                        Spacer(minLength: 8)
                        Text(team.label)
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                    }
                }
            }
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
            // U-2 (0.9.190): new shell — the quiet secondary button,
            // full width (AccountViews 同款 label 内 maxWidth).
            Button(role: .cancel) { onCancel() } label: {
                Text(L("Cancel"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(20)
    }

    /// ContentView.pickInstallAccount 同款：切账号并等旧会话释放完，
    /// 再让下面的 Apple ID 选择去跑管线，否则管线可能沿用旧会话、
    /// 用错账号签名。企业证书路不用 Apple ID，不受影响。
    @MainActor
    private func pickSigningAccount(_ account: SavedAccount) async {
        guard !accounts.isActive(account) else { return }
        accounts.activate(account)
        await engine.dropSignSession()
        engine.log("Signing choice: signing account switched to \(account.normalized).")
    }

    private func choiceRow(identity: CZFSignIdentity, systemImage: String, title: String, detail: String) -> some View {
        Button { onChoose(identity) } label: {
            // U-2 (0.9.190): new shell — the row is a PanelCard; the
            // Theme.control background and the 12pt corner are the
            // card's now, the icon/title/detail layout is untouched.
            PanelCard(padding: 12) {
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
                    // F-1 (0.9.190): mark the last-used signing method —
                    // the choice is already persisted in
                    // CZFSignIdentity.stored; the sheet re-reads it every
                    // time it opens, so the mark is always current.
                    if identity == CZFSignIdentity.stored {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
        }
        // 0.9.193: plain 样式没有按压反馈，点下去像没点——下次再崩
        // 视频里看不出点了哪一行；复用仓内现成的 CZFPressButtonStyle
        //（按下整行变淡 + 微缩），只改观感，不改点击行为。
        .buttonStyle(CZFPressButtonStyle())
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

    /// 0.9.193: 点下的选择先存这里，等 sheet 真正消失后
    /// （onDismiss）再跑后续动作，见 `choose`。
    @State private var deferredChoice: DeferredSigningChoice?

    func body(content: Content) -> some View {
        content.sheet(item: Bindable(engine).pendingSigningChoice, onDismiss: { runDeferredChoice() }) { request in
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
    ///
    /// 0.9.193: "cleared first" was not enough — the follow-up ran in
    /// the same transaction as the dismiss (enterprise: dismiss + 切
    /// 设置 tab + NavigationLink 推入；Apple ID: dismiss + 全屏
    /// cover present)，present/push 与 dismiss 撞在同一个事务里，
    /// UIKit 直接 trap，闪退回主屏幕，下一屏永远画不出来。整条链
    /// 无强制解包，崩的就是这个竞态。所以 `choose` 现在只记下选择
    /// 并清掉请求，后续动作推迟到 sheet 真正消失后的 onDismiss
    /// （`runDeferredChoice`）再跑；两条路都串行化，视频看不出
    /// 点了哪个，不能只修一条。语义不变。
    private func choose(_ identity: CZFSignIdentity, request: SigningChoiceRequest) {
        deferredChoice = DeferredSigningChoice(identity: identity, ipaURL: request.ipaURL)
        engine.pendingSigningChoice = nil
        identity.store()
    }

    /// 0.9.193: `choose` 的后半段，从 sheet 的 onDismiss 跑——这时
    /// sheet 已真正消失，后面的 present/push 不再与 dismiss 同事务。
    /// 取消（onCancel / 下滑）时没有攒下的选择，直接 no-op。
    /// 语义与修前逐行一致：Apple ID 开安装页跑一键管线，企业路把
    /// 暂存 IPA 交给签名页；只换了时机，不改签名逻辑本身。
    private func runDeferredChoice() {
        guard let deferred = deferredChoice else { return }
        deferredChoice = nil
        switch deferred.identity {
        case .appleID:
            engine.installSource = .custom
            engine.sharedIPAReady = true
            engine.runOneClick()
        case .enterprise:
            certWorkspace.selectedIPA = deferred.ipaURL
            certWorkspace.openEnterpriseSign = true
        }
    }
}

/// 0.9.193: 点下时攒着、sheet 消失后才跑的选择（见上）。
private struct DeferredSigningChoice {
    let identity: CZFSignIdentity
    let ipaURL: URL
}
