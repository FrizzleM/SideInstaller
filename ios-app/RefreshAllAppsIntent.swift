import AppIntents
import UIKit
import Foundation

extension Notification.Name {
    static let refreshAllApps = Notification.Name("sideinstaller.refreshAllApps")
}

/// Shortcuts action: Resign all sideloaded apps.
/// Runs in background; posts notification that the app handles.
struct RefreshAllAppsIntent: AppIntent {
    static var title: LocalizedStringResource = "全部续签"
    static var description = IntentDescription("重新签名所有侧载应用，延长7天有效期")
    
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // SIDE-2 C2：以前先 post 通知、再直调 refreshAllFromShortcut，应用页
        // 在前台时通知同步跑 refreshAll() 抢掉 isRefreshing，直调的 LocalDevVPN
        // 交接分支永远走不到。只留直调一个入口（与界面共用同一个 manager，
        // 靠 isRefreshing 互斥不会重复跑）。
        await SideloadedAppsManager.shared.refreshAllFromShortcut()
        return .result()
    }
}

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case message(String)
    
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .message(let msg):
            return LocalizedStringResource(stringLiteral: msg)
        }
    }
}
