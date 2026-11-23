import SwiftUI

/// Lists and revokes the Apple ID's development certificates (e.g. to fix error
/// 7460). Pushed from Tools (relies on its `NavigationStack`).
struct CertsView: View {
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer
    @ObservedObject var manager: CertManager

    @State private var showSettings = false
    /// The certificate the user tapped "Revoke" on, pending confirmation.
    @State private var pendingRevoke: DevCert?
    /// Exported p12 file URL for ShareLink.
    @State private var exportURL: URL?
    @State private var exportPassword: String?
    @State private var isExporting = false
    @State private var exportError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header.cascadeItem(0)
                expiryBanner
                loadButton.cascadeItem(1)
                exportButton.cascadeItem(2)
                if manager.canUseSideStoreCertificate {
                    sideStoreCard.cascadeItem(3)
                }
                // Errors show as a popup, which `RootView` lays over the app.
                certList
            }
            .padding(20)
            .animation(.smooth(duration: 0.35), value: manager.certs)
            .animation(.smooth(duration: 0.3), value: manager.isWorking)
            .animation(.smooth(duration: 0.35), value: manager.teamSummary)
        }
        .background(AppBackground())
        .toolbar { settingsToolbarItem(isPresented: $showSettings) }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .onAppear { manager.autoLoad() }
        .onDisappear { Self.deleteExportTempFiles() }
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
        BrandHeader(icon: "checkmark.seal", image: "CertsLogo", title: L("Certificates")) {
            if let team = manager.teamSummary {
                StatusDot(text: team, color: Theme.positive, textColor: Theme.muted)
                    .transition(.opacity)
            }
        }
    }

    // MARK: Expiry warning

    /// 7 天内到期（含已过期）的证书：跟 EnterpriseCertView.expirySoon
    /// 同一条规则（剩余天数 ≤7 天），只做展示。
    private var expiringCerts: [DevCert] {
        manager.certs.filter { cert in
            guard let expiry = cert.expiresAt else { return false }
            return (Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? 0) <= 7
        }
    }

    /// 企业页已有同款红条，个人证书页之前只有行内小字到期日：
    /// 7 天有效期的个人证书到期前毫无预警，App 打不开才发现。
    /// 任一证书 7 天内到期就出红条，写明证书名 + 到期日，下附一行
    /// 动作指引；只展示，不碰续签过滤、团队判定等任何逻辑。
    @ViewBuilder
    private var expiryBanner: some View {
        if !expiringCerts.isEmpty {
            CalloutCard(tint: Theme.negative) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("证书到期提醒"))
                        .font(.subheadline.weight(.semibold))
                    ForEach(expiringCerts, id: \.id) { cert in
                        HStack {
                            Text(cert.displayName)
                                .font(.subheadline)
                            Spacer()
                            if let expiry = cert.expiresAt {
                                Text(expiryLabel(expiry))
                                    .font(.footnote)
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                    }
                    Text(L("证书到期后请重新登录 Apple ID 获取新证书，再用全部续签重签 App。"))
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
            }
            .transition(.opacity)
        }
    }

    /// 到期日 + 剩余天数，跟 EnterpriseCertView.remainingText、已装 App 页
    /// AppsView.daysRemaining 同一套算法（自然日对齐，见 S7），
    /// 同一到期日在三页说法一致。只改日期显示，不动 ID 签名/
    /// 续签逻辑。
    private func expiryLabel(_ expiry: Date) -> String {
        let date = expiry.formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted)
                .locale(Localizer.locale))
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: expiry)).day ?? 0
        if days < 0 { return L("%@（已过期）", date) }
        if days == 0 { return L("%@（今天到期）", date) }
        return L("%@（剩 %d 天）", date, days)
    }

    // MARK: Primary action

    private var loadButton: some View {
        Button {
            manager.loadCerts()
        } label: {
            HStack(spacing: 8) {
                if manager.isWorking {
                    ProgressView()
                    Text(manager.isSignedIn ? L("Refreshing") : L("Signing in"))
                } else {
                    Image(systemName: manager.hasLoaded ? "arrow.clockwise" : "list.bullet.rectangle")
                        .contentTransition(.symbolEffect(.replace))
                    Text(manager.hasLoaded ? L("Refresh") : L("Load certificates"))
                }
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(manager.isWorking || manager.revokingID != nil)
    }

    /// Export certificate as p12 for LiveContainer import.
    private var exportButton: some View {
        VStack(spacing: 10) {
            if let url = exportURL {
                ShareLink(item: url) {
                    Label(L("Export certificate (p12)"), systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered, sound: .tap)
                .tint(Theme.accent)
                if let pwd = exportPassword {
                    VStack(spacing: 4) {
                        Text(L("Certificate password:"))
                            .font(.caption)
                            .foregroundColor(Theme.muted)
                        Text(pwd)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            } else {
                Button {
                    doExport()
                } label: {
                    HStack(spacing: 10) {
                        if isExporting {
                            ProgressView().tint(.white)
                            Text(L("Exporting"))
                        } else {
                            Image(systemName: "square.and.arrow.up")
                            Text(L("Export certificate (p12)"))
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(manager.isWorking || isExporting || !manager.isSignedIn)
            }
            if let err = exportError {
                Text(err).font(.caption).foregroundColor(Theme.negative)
            }
        }
    }

    // MARK: SideStore's certificate

    /// Signs with SideStore's certificate instead of a certificate of its own,
    /// which a free Apple ID can't have alongside SideStore's. Inside
    /// LiveContainer it's read from LiveContainer, as SideStore can't send it.
    private var sideStoreCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(Engine.runsInLiveContainer
                     ? L("SideInstaller takes SideStore's certificate from LiveContainer and signs with it too, so on a free Apple ID neither app has to revoke the other's.")
                     : L("SideStore opens and sends back its certificate. SideInstaller then signs with it too, so on a free Apple ID neither app has to revoke the other's."))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    manager.requestSideStoreCertificate(retryInstall: false)
                } label: {
                    HStack(spacing: 8) {
                        if manager.isImporting {
                            ProgressView().controlSize(.small)
                            Text(L("Checking the certificate"))
                        } else {
                            Image(systemName: "checkmark.seal")
                            Text(L("Use SideStore's certificate"))
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle(), sound: .tap)
                .disabled(manager.isBusy)
            }
        }
    }

    /// N4：证书导出把明文密码写进 tmp（certificate-password.txt），
    /// 分享完就删——导出开始时清上一份，页面离开时清最后一份；
    /// 固定名，下次导出直接覆盖，残留最多只剩最新的一组。
    private static func deleteExportTempFiles() {
        let tmp = FileManager.default.temporaryDirectory
        try? FileManager.default.removeItem(at: tmp.appendingPathComponent("certificate.p12"))
        try? FileManager.default.removeItem(at: tmp.appendingPathComponent("certificate-password.txt"))
    }

    private func doExport() {
        isExporting = true
        exportError = nil
        exportURL = nil
        Self.deleteExportTempFiles()
        Task {
            do {
                // 证书页导出同款：先自动登录再导出，否则刚启动没开过证书页
                // 之外的入口点进来也会报 Not signed in.（App 详情页同款已修）。
                try await manager.ensureSignedIn()
                let (p12Data, password) = try manager.exportP12()
                // Write to temp file
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("certificate.p12")
                try p12Data.write(to: tempURL)
                // Also save password to a txt file for convenience
                let pwdURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("certificate-password.txt")
                try password.write(to: pwdURL, atomically: true, encoding: .utf8)
                await MainActor.run {
                    isExporting = false
                    exportURL = tempURL
                    exportPassword = password
                }
            } catch is CancellationError {
                // A2：切账号后本次导出作废，不记错。
                await MainActor.run { isExporting = false }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportError = error.localizedDescription
                }
            }
        }
    }

    // MARK: Certificate list

    @ViewBuilder
    private var certList: some View {
        if manager.hasLoaded && manager.certs.isEmpty && !manager.isWorking {
            emptyState.transition(.cardAppear)
        } else if !manager.certs.isEmpty {
            VStack(spacing: 16) {
                HStack {
                    // Count only; Apple doesn't report the account's limit.
                    Text(L("%d certificate(s)", manager.certs.count))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.muted)
                    Spacer()
                }
                .cascadeItem(2)
                ForEach(Array(manager.certs.enumerated()), id: \.element.id) { idx, cert in
                    certRow(cert).cascadeItem(3 + idx)
                }
            }
        }
    }

    private var emptyState: some View {
        PanelCard {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.muted)
                Text(L("No certificates"))
                    .font(.headline)
                Text(L("This Apple ID has no development certificates to revoke."))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
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
                    Image(systemName: "seal")
                        .font(.title3)
                        .foregroundStyle(cert.isExpired ? Theme.warning : Theme.muted)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cert.displayName)
                            .font(.subheadline.weight(.medium))
                        if let machine = cert.machineLabel {
                            Label(machine, systemImage: "desktopcomputer")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    Spacer()
                    if cert.isExpired {
                        Text(L("Expired"))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.warning)
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
                    .foregroundStyle(Theme.muted)
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
                .tint(Theme.negative)
                .controlSize(.regular)
                .disabled(revoking || manager.isWorking || manager.revokingID != nil)
            }
        }
    }
}
