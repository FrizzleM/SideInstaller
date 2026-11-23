import Foundation
import Network
import Security
import UIKit

/// 本机直装：App 内起一个本地明文 HTTP 服务（http://localhost），
/// 生成 OTA 清单，用 itms-services 拉起系统安装——不走配对、
/// 不走隧道、不要 WiFi。路子就是轻松签那套「本机安装」：
/// 签好的包只在本机回环上走一圈，系统安装器直接把它装进桌面。
/// 旧版走 https://127.0.0.1 + 企业证书 TLS：TLS 身份就是用户
/// 导入的这张企业证书，系统安装器建不起这个连接——8 代安装
/// 弹窗失败的实证病根；本版起一律明文，不再挂证书。
/// 限制先说明白：
/// - 只能装企业证书签好的包（个人 ID 签的包走这条路装不上，
///   系统安装器验签名那关就过不了，仍走配对安装）。
/// - 服务只在安装期间跑，装完自动停；路径带随机 ID，不猜到。
/// - 回环起不来时不静默回落：unavailableMessage 置位，证书页
///   弹兜底，用户点了“改用配对安装”才走 Engine。
/// - itms-services 接不接受明文 localhost 清单、以及安装器
///   半路失败时 App 内能不能感知，没有真机可测，CI 也验不出，
///   必须上真机验证。
final class OTAInstallServer: ObservableObject {
    /// 全局唯一：证书页切 tab 重建视图也不能把跑着的回环服务
    /// 连同视图一起释放掉（LocalHTTPInstallServer.shared 同款）。
    static let shared = OTAInstallServer()
    private init() {}

    @Published private(set) var isRunning = false
    @Published private(set) var status: String?
    /// 回环失败时置位（证书页 onChange 弹兜底用）；正常结束
    /// （发完包停、600 秒硬停）绝不置位，见 failLoopback。
    @Published private(set) var unavailableMessage: String?

    private var listener: NWListener?
    private var activeCandidate = 0
    private let queue = DispatchQueue(label: "czf.ota.install")
    private var installID = ""
    private var ipaURL: URL?
    private var manifestData = Data()
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var stopWork: DispatchWorkItem?
    private var hardStopWork: DispatchWorkItem?
    private var unavailableReported = false

    /// C-7：在途连接登记表——stop() 与 60 秒空闲超时靠它掐断僵尸连接。
    /// 全部在 ota 串行队列上读写（handle/receive/send 全走这条队列），不用加锁。
    private struct LiveConnection {
        let connection: NWConnection
        var lastActivity: Date
        var idleCheck: DispatchWorkItem?
    }
    private var liveConnections: [ObjectIdentifier: LiveConnection] = [:]
    private static let connectionIdleTimeout: TimeInterval = 60
    /// C-7：服务世代——stop() 加一；上一轮的 sendFile 完成分支看到世代
    /// 已换就不再重立 stopWork，免得新一轮安装被旧轮的 20 秒停掐掉。
    private var serveGeneration = 0

    /// 登记一条在途连接并排上它的空闲检查。只在 ota 串行队列上调。
    private func registerConnection(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        liveConnections[id] = LiveConnection(connection: connection, lastActivity: Date(), idleCheck: nil)
        scheduleIdleCheck(for: id)
    }

    /// 摘除一条连接（终结/取消/响应发完时调），并取消它待跑的空闲检查。
    private func unregisterConnection(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        liveConnections[id]?.idleCheck?.cancel()
        liveConnections.removeValue(forKey: id)
    }

    /// 有数据/发完就摸一下，空闲计时从此刻重算。
    private func touchConnection(_ connection: NWConnection) {
        liveConnections[ObjectIdentifier(connection)]?.lastActivity = Date()
    }

    /// 到期检查：已摘除就什么都不做；空闲满 60 秒就掐断，否则按剩余时间重排。
    private func scheduleIdleCheck(for id: ObjectIdentifier, after delay: TimeInterval = Self.connectionIdleTimeout) {
        liveConnections[id]?.idleCheck?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard let entry = self.liveConnections[id] else { return }
            let idle = Date().timeIntervalSince(entry.lastActivity)
            if idle >= Self.connectionIdleTimeout {
                self.liveConnections.removeValue(forKey: id)
                entry.connection.cancel()
            } else {
                self.scheduleIdleCheck(for: id, after: Self.connectionIdleTimeout - idle)
            }
        }
        liveConnections[id]?.idleCheck = work
        queue.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// 对一个已签好的 IPA 拉起本机安装。
    func install(record: SignedIPARecord) {
        guard !record.bundleID.isEmpty else {
            setStatus(L("这个已签名记录没有 Bundle ID，装不了，先重签一次。"))
            return
        }
        install(ipaURL: SignedIPAStore.url(for: record), appName: record.appName,
                bundleID: record.bundleID, version: record.version ?? "1.0")
    }

    /// 对一个刚签好的文件拉起本机安装（签名页「签名并安装」用）。
    func install(ipaURL: URL, appName: String, bundleID: String, version: String) {
        stop()
        // 失败上报复位：上一轮的失败文案先清掉，不然同一句失败
        // 再来一次时 onChange 认不出变化、兜底弹不出来。
        unavailableReported = false
        DispatchQueue.main.async { self.unavailableMessage = nil }
        guard FileManager.default.fileExists(atPath: ipaURL.path) else {
            setStatus(L("签好的文件找不到了，先重签一次。"))
            return
        }
        setStatus(L("正在启动本机安装服务…"))
        beginBackgroundTask()
        installID = UUID().uuidString
        self.ipaURL = ipaURL
        // 清单等端口定下来再生成（里面要写 127.0.0.1:端口）。
        pendingMeta = (appName: appName, bundleID: bundleID, version: version)
        hardStopWork = DispatchWorkItem { [weak self] in self?.stop() }
        if let hardStopWork {
            queue.asyncAfter(deadline: .now() + 600, execute: hardStopWork)
        }
        tryPort(18080)
    }

    // MARK: - 公网 OTA（企业证书 + R2 托管，0.9.104，v1 手动上传）

    /// R2 公开直链前缀（用户自己的桶 xiaofang-ipa；manifest 与 IPA 都放这里）。
    static let r2BaseURL = "https://pub-c948069b1c9743189b263b39ecce2ca7.r2.dev/"

    /// manifest 文件名：同名 .ipa 换 .plist 后缀。
    static func publicManifestFileName(for ipaFileName: String) -> String {
        (ipaFileName as NSString).deletingPathExtension + ".plist"
    }

    /// R2 上的 manifest 直链（文件名按路径段编码）。
    static func publicManifestR2URL(for ipaFileName: String) -> String {
        let name = publicManifestFileName(for: ipaFileName)
        return r2BaseURL + (name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name)
    }

    /// R2 上的 IPA 直链。
    static func publicIPAR2URL(for ipaFileName: String) -> String {
        r2BaseURL + (ipaFileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ipaFileName)
    }

    /// 按标准 itms-services 格式生成 manifest（与回环 onReady 同款 items 结构，
    /// 基址换 R2 https 地址；补 subtitle；不起本地服务、不走回环）。
    static func publicManifestData(ipaFileName: String, appName: String, bundleID: String, version: String) -> Data? {
        let item: [String: Any] = [
            "assets": [
                ["kind": "software-package", "url": publicIPAR2URL(for: ipaFileName)],
            ],
            "metadata": [
                "bundle-identifier": bundleID,
                "bundle-version": version,
                "kind": "software",
                "subtitle": appName,
                "title": appName,
            ],
        ]
        return try? PropertyListSerialization.data(
            fromPropertyList: ["items": [item]], format: .xml, options: 0)
    }

    /// 把 manifest 写到已签名 IPA 旁边（SignedIPAStore.dir），返回文件地址；
    /// 生成或写盘失败返回 nil（调用方显示“安装清单生成失败”并留配对入口）。
    static func writePublicManifest(for record: SignedIPARecord) -> URL? {
        guard !record.bundleID.isEmpty,
              let data = publicManifestData(ipaFileName: record.fileName, appName: record.appName,
                                            bundleID: record.bundleID, version: record.version ?? "1.0") else {
            return nil
        }
        let url = SignedIPAStore.dir.appendingPathComponent(publicManifestFileName(for: record.fileName))
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            return nil
        }
        return url
    }

    /// itms-services 安装链接（manifest 直链按 query 编码，onReady 同款写法）。
    static func publicInstallURL(manifestR2URL: String) -> URL? {
        let encoded = manifestR2URL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&"))) ?? manifestR2URL
        return URL(string: "itms-services://?action=download-manifest&url=\(encoded)")
    }

    func stop() {
        stopWork?.cancel()
        stopWork = nil
        hardStopWork?.cancel()
        hardStopWork = nil
        activeCandidate = 0
        listener?.cancel()
        listener = nil
        ipaURL = nil
        pendingMeta = nil
        manifestData = Data()
        endBackgroundTask()
        DispatchQueue.main.async {
            self.isRunning = false
        }
        // C-7：停 listener 只拦新连接——在途的 installd 下载也得掐断，
        // 世代加一，上一轮 sendFile 的完成分支不再重立 stopWork。
        // 登记表在 ota 队列上，异步清掉（串行队列保证先于之后新登记
        // 的连接执行，不会误掐新连接）。
        serveGeneration += 1
        queue.async { [weak self] in
            guard let self else { return }
            for entry in self.liveConnections.values {
                entry.idleCheck?.cancel()
                entry.connection.cancel()
            }
            self.liveConnections.removeAll()
        }
    }

    // MARK: - 服务

    private var pendingMeta: (appName: String, bundleID: String, version: String)?

    /// 回环失败统一出口：只报一次，stop() 本身不报——600 秒硬停、
    /// 发完包 20 秒停这些正常结束绝不能被当成失败弹兜底。
    /// 失败只由这几处进：端口全占、清单/链接生成失败、清单已发出
    /// 后服务断掉；文件找不着那档不进这里（配对安装同样装不了）。
    private func failLoopback(_ message: String) {
        setStatus(message)
        if !unavailableReported {
            unavailableReported = true
            DispatchQueue.main.async { self.unavailableMessage = message }
        }
        stop()
    }

    private func tryPort(_ candidate: Int) {
        guard candidate <= 18090 else {
            failLoopback(L("本机端口 18080-18090 都被占用了，本机安装起不来，改用配对安装。"))
            return
        }
        // 明文 TCP，不再挂企业证书 TLS：TLS 身份就是用户导入的
        // 这张企业证书，系统安装器建不起这个连接——8 代安装
        // 弹窗失败的实证病根。轻松签同款是明文 http://localhost。
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        do {
            let listener = try NWListener(
                using: params, on: NWEndpoint.Port(rawValue: UInt16(candidate))!)
            activeCandidate = candidate
            listener.stateUpdateHandler = { [weak self] state in
                guard let self, self.activeCandidate == candidate else { return }
                switch state {
                case .ready:
                    self.onReady(port: candidate)
                case .failed:
                    self.listener = nil
                    if self.manifestData.isEmpty {
                        // 还没对外公布清单：换个端口再试。
                        self.tryPort(candidate + 1)
                    } else {
                        // 清单已发出、安装进行中，服务挂了就明说，
                        // 别悄悄换端口（安装器手里的旧地址就失效了）。
                        self.failLoopback(L("本机安装服务断了，改用配对安装。"))
                    }
                default:
                    break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }
            self.listener = listener
            listener.start(queue: queue)
        } catch {
            // 监听器建不起来（端口被占）就换下一个端口，不要
            // 直接停掉——旧代码这里直接停，端口被占一次就全失败。
            tryPort(candidate + 1)
        }
    }

    private func onReady(port: Int) {
        guard let meta = pendingMeta else { return }
        let base = "http://localhost:\(port)/\(installID)"
        let manifestURL = "\(base)/manifest.plist"
        let item: [String: Any] = [
            "assets": [
                ["kind": "software-package", "url": "\(base)/app.ipa"],
            ],
            "metadata": [
                "bundle-identifier": meta.bundleID,
                "bundle-version": meta.version,
                "kind": "software",
                "title": meta.appName,
            ],
        ]
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: ["items": [item]], format: .xml, options: 0) else {
            failLoopback(L("安装清单生成失败，改用配对安装。"))
            return
        }
        manifestData = data
        DispatchQueue.main.async { self.isRunning = true }
        // 每次安装换一个随机路径，系统安装器不会吃到上次缓存的旧清单。
        let encoded = manifestURL.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed) ?? manifestURL
        guard let link = URL(string: "itms-services://?action=download-manifest&url=\(encoded)") else {
            failLoopback(L("安装链接生成失败，改用配对安装。"))
            return
        }
        setStatus(L("已拉起系统安装：点「安装」后服务保持到下载完成，装完自动停。"))
        DispatchQueue.main.async {
            UIApplication.shared.open(link)
        }
    }

    // MARK: - HTTP（只认 GET，两条路由）

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        registerConnection(connection)
        receive(connection, buffer: Data())
    }

    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 16) {
            [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }
            var buf = buffer
            if let data {
                buf.append(data)
                self.touchConnection(connection)
            }
            if let path = Self.requestPath(buf) {
                self.respond(connection, path: path)
            } else if isComplete || error != nil || buf.count > (1 << 20) {
                self.unregisterConnection(connection)
                connection.cancel()
            } else {
                self.receive(connection, buffer: buf)
            }
        }
    }

    private static func requestPath(_ buf: Data) -> String? {
        let headerEnd = Data("\r\n\r\n".utf8)
        guard let range = buf.range(of: headerEnd) else { return nil }
        let headText = String(decoding: buf[..<range.lowerBound], as: UTF8.self)
        guard let first = headText.components(separatedBy: "\r\n").first else { return nil }
        let parts = first.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" else { return nil }
        return String(parts[1])
    }

    private func respond(_ connection: NWConnection, path: String) {
        if path == "/\(installID)/manifest.plist" {
            send(connection, status: "200 OK", contentType: "text/xml",
                 length: manifestData.count, body: manifestData) { [weak self] in
                self?.unregisterConnection(connection)
                connection.cancel()
            }
            return
        }
        if path == "/\(installID)/app.ipa", let ipaURL {
            guard let size = (try? FileManager.default.attributesOfItem(atPath: ipaURL.path))?[.size] as? Int,
                  let handle = try? FileHandle(forReadingFrom: ipaURL) else {
                send(connection, status: "404 Not Found", contentType: "text/plain",
                     length: 0, body: Data()) { [weak self] in
                    self?.unregisterConnection(connection)
                    connection.cancel()
                }
                // A4：文件没了，安装器拿 404 也装不成——别空转到 600 秒硬停。
                setStatus(L("签好的文件找不到了，先重签一次。"))
                stop()
                return
            }
            // 安装器下载包时 App 已退到后台，分片发、发完再停，
            // 别把 17MB 一次塞进内存。
            // C-7：记下当前世代——发完包时世代已换（新一轮 install 调过
            // stop()），就不再重立 stopWork，免得掐掉新安装。
            let generation = serveGeneration
            send(connection, status: "200 OK", contentType: "application/octet-stream",
                 length: size, body: nil) { [weak self] in
                self?.sendFile(connection, handle: handle, remaining: size, generation: generation)
            }
            return
        }
        send(connection, status: "404 Not Found", contentType: "text/plain",
             length: 0, body: Data()) { [weak self] in
            self?.unregisterConnection(connection)
            connection.cancel()
        }
    }

    private func send(_ connection: NWConnection, status: String, contentType: String,
                      length: Int, body: Data?, done: @escaping () -> Void) {
        var head = "HTTP/1.1 \(status)\r\n"
        head += "Content-Type: \(contentType)\r\n"
        head += "Content-Length: \(length)\r\n"
        head += "Connection: close\r\n\r\n"
        var payload = Data(head.utf8)
        if let body { payload.append(body) }
        connection.send(content: payload, completion: .contentProcessed { _ in done() })
    }

    private func sendFile(_ connection: NWConnection, handle: FileHandle, remaining: Int, generation: Int) {
        // C-7：连接已不在登记表（被 stop() 掐断）就别再发——stop() 之后
        // 在途的 send completion 仍会跑进来，靠登记表拦住它。
        guard liveConnections[ObjectIdentifier(connection)] != nil else {
            try? handle.close()
            connection.cancel()
            return
        }
        guard remaining > 0 else {
            try? handle.close()
            connection.cancel()
            unregisterConnection(connection)
            // 包发完了：留 20 秒给安装器重试，之后停服务——但只在
            // 仍是同一轮安装时；世代已换说明新一轮开始了，别掐它。
            guard generation == serveGeneration else { return }
            stopWork?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.stop() }
            stopWork = work
            queue.asyncAfter(deadline: .now() + 20, execute: work)
            return
        }
        let chunk = handle.readData(ofLength: min(remaining, 64 * 1024))
        guard !chunk.isEmpty else {
            LogStore.shared.append("⚠️ Install truncated: \(ipaURL?.lastPathComponent ?? "?") stopped with \(remaining) bytes left.")
            try? handle.close()
            unregisterConnection(connection)
            connection.cancel()
            // A4：包发一半文件没了——别静默空转，停服务并告诉用户重签。
            setStatus(L("签好的文件找不到了，先重签一次。"))
            stop()
            return
        }
        connection.send(content: chunk, completion: .contentProcessed { [weak self] _ in
            self?.touchConnection(connection)
            self?.sendFile(connection, handle: handle, remaining: remaining - chunk.count, generation: generation)
        })
    }

    // MARK: - 后台与状态

    private func beginBackgroundTask() {
        endBackgroundTask()
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "OTAInstall") {
            [weak self] in self?.stop()
        }
    }

    private func endBackgroundTask() {
        let task = backgroundTask
        backgroundTask = .invalid
        guard task != .invalid else { return }
        DispatchQueue.main.async {
            UIApplication.shared.endBackgroundTask(task)
        }
    }

    private func setStatus(_ text: String) {
        DispatchQueue.main.async { self.status = text }
    }
}
