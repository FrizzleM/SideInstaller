import Combine
import Foundation

/// 步骤/诊断日志存放（0.9.21 起）：v68 回退到 Engine 配对路后，
/// 本地 HTTP 安装传输（install/stop/webServer/静音保活）全仓
/// 已无调用方，传输代码随之删除；证书页与文件页的诊断日志 UI
/// 仍读这一个单例。不复活 localhost 路线，不再起任何服务。
final class LocalHTTPInstallServer: ObservableObject {
    /// 全局唯一：证书页与文件页共用同一实例，日志不两边分裂。
    static let shared = LocalHTTPInstallServer()
    private init() {}

    /// 接线诊断日志（页内可直接读这个数组展示，只留最近 100 行）。
    @Published private(set) var diagnosticLog: [String] = []

    /// 企业页/文件页步骤日志：签名/安装阶段行也进同一份
    /// diagnosticLog（不另起一套日志系统）。
    /// 只追加一行，不动安装流程；log() 本身走主队列追加，任何
    /// 线程调都安全。
    func appendStepLog(_ message: String) {
        log(message)
    }

    /// 接线诊断日志：Console 可见（NSLog 自带时间），同时进
    /// diagnosticLog 数组（页内可读）。数组追加走主队列
    /// （@Published 须主线程改）；时间格式每次现建
    /// （DateFormatter 非线程安全，不能共用静态实例）。
    private func log(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let line = "[\(formatter.string(from: Date()))] \(message)"
        NSLog("[LocalHTTPInstall] %@", line)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.diagnosticLog.append(line)
            if self.diagnosticLog.count > 100 {
                self.diagnosticLog.removeFirst(self.diagnosticLog.count - 100)
            }
        }
    }
}
