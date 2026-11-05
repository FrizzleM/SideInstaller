import Foundation
import UIKit

/// Where SideInstaller should send the signing certificate after an export.
/// Each case builds the encoding / URL that app expects, or falls back to a .p12 share.
enum CertificateExportDestination: String, CaseIterable, Identifiable, Hashable {
    /// Use the exact `callback_template` from the `sideinstaller://exportCertificate` link.
    case linkCallback
    /// LiveContainer: `livecontainer://certificate?cert=&password=`
    case liveContainer
    /// SideStore-style: `sidestore://certificate?data=&password=`
    case sideStore
    /// Any other app: share a password-less `.p12` (Feather, manual import, Files, …).
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .linkCallback:  return L("App that opened the link")
        case .liveContainer: return L("LiveContainer")
        case .sideStore:     return L("SideStore")
        case .other:         return L("Other (share .p12)")
        }
    }

    var subtitle: String {
        switch self {
        case .linkCallback:
            return L("Send using the callback URL that app provided.")
        case .liveContainer:
            return L("Opens LiveContainer with the certificate in its import URL.")
        case .sideStore:
            return L("Opens SideStore with the certificate in its import URL.")
        case .other:
            return L("Share or save a .p12 file you can import in any app.")
        }
    }

    /// Prefer destinations whose app is installed; always include Other and linkCallback when relevant.
    static func options(hasLinkTemplate: Bool) -> [CertificateExportDestination] {
        var list: [CertificateExportDestination] = []
        if hasLinkTemplate { list.append(.linkCallback) }
        list.append(.liveContainer)
        list.append(.sideStore)
        list.append(.other)
        return list
    }

    /// Default selection when a link template is present: use that callback.
    static func preferred(hasLinkTemplate: Bool) -> CertificateExportDestination {
        hasLinkTemplate ? .linkCallback : .liveContainer
    }

    /// Build the callback URL for URL-based destinations. `template` is only used for `.linkCallback`.
    func callbackURL(base64Cert: String, password: String, linkTemplate: String?) -> URL? {
        switch self {
        case .linkCallback:
            guard let template = linkTemplate, !template.isEmpty else { return nil }
            let filled = template
                .replacingOccurrences(of: "$(BASE64_CERT)", with: base64Cert)
                .replacingOccurrences(of: "$(PASSWORD)", with: password)
            return URL(string: filled)
        case .liveContainer:
            // LiveContainer Settings import: cert + password query items.
            var components = URLComponents()
            components.scheme = "livecontainer"
            components.host = "certificate"
            components.queryItems = [
                URLQueryItem(name: "cert", value: base64Cert),
                URLQueryItem(name: "password", value: password),
            ]
            return components.url
        case .sideStore:
            var components = URLComponents()
            components.scheme = "sidestore"
            components.host = "certificate"
            components.queryItems = [
                URLQueryItem(name: "data", value: base64Cert),
                URLQueryItem(name: "password", value: password),
            ]
            return components.url
        case .other:
            return nil
        }
    }
}


/// Confirmed export: where to send the cert and the optional deep-link template.
struct CertificateExportRequest: Equatable {
    let destination: CertificateExportDestination
    let linkTemplate: String?
}

#if canImport(SwiftUI)
import SwiftUI

/// Popup: pick LiveContainer / SideStore / link callback / Other, then export.
struct ExportCertificatePopup: View {
    let linkTemplate: String
    let onClose: () -> Void
    let onConfirm: (CertificateExportDestination) -> Void
    let onCancel: () -> Void

    @State private var destination: CertificateExportDestination

    init(linkTemplate: String,
         onClose: @escaping () -> Void,
         onConfirm: @escaping (CertificateExportDestination) -> Void,
         onCancel: @escaping () -> Void) {
        self.linkTemplate = linkTemplate
        self.onClose = onClose
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        let has = !linkTemplate.isEmpty
        _destination = State(initialValue: CertificateExportDestination.preferred(hasLinkTemplate: has))
    }

    var body: some View {
        PopupCard(title: L("Export signing certificate?"), systemImage: "square.and.arrow.up.fill",
                  tint: Theme.accent, onClose: {
            onCancel()
            onClose()
        }) {
            VStack(alignment: .leading, spacing: 16) {
                Text(L("Choose which app should receive the signing certificate. SideInstaller encodes it the way that app expects. “Other” shares a .p12 file."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 0) {
                    ForEach(CertificateExportDestination.options(hasLinkTemplate: !linkTemplate.isEmpty)) { dest in
                        Button {
                            destination = dest
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: destination == dest ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(destination == dest ? Theme.accent : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dest.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(dest.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        if dest != CertificateExportDestination.options(hasLinkTemplate: !linkTemplate.isEmpty).last {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 4)

                VStack(spacing: 10) {
                    Button {
                        onConfirm(destination)
                        onClose()
                    } label: {
                        Label(L("Export and send"), systemImage: "square.and.arrow.up.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Button(role: .cancel) {
                        onCancel()
                        onClose()
                    } label: {
                        Text(L("Cancel"))
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }
            }
        }
    }
}
#endif
