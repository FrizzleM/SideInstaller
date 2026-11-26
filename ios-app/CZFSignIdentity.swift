import Foundation

/// 签名流程两种去向：仅签名存已签名，或签名后走配对安装。
/// SIDE-53：签名方式——企业证书（现有行为）或 Apple ID（一键安装）。
/// B-2 (0.9.179): was `private` in EnterpriseCertView — the self-update
/// and share-in certificate choice sheets (F-1/F-2) use the same type
/// and the same persisted last choice, so it lives here now.
enum CZFSignIdentity: String {
    case enterprise
    case appleID

    /// B-2 (0.9.179): the last signing method used, kept across pages
    /// and launches. Default is enterprise — the pre-B-2 behaviour.
    static let defaultsKey = "CZFSignIdentity"

    static var stored: CZFSignIdentity {
        guard let raw = UserDefaults.standard.string(forKey: defaultsKey),
              let value = CZFSignIdentity(rawValue: raw) else { return .enterprise }
        return value
    }

    func store() {
        UserDefaults.standard.set(rawValue, forKey: Self.defaultsKey)
    }
}
