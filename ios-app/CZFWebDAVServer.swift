import Foundation
import UIKit

/// WebDAV 文件服务（0.9.88）：局域网内用 WebDAV 访问 SideInstaller 的
/// Documents 目录。最小可用，只支持 PROPFIND / GET / PUT / DELETE /
/// MKCOL 五个动词，不做 LOCK/UNLOCK、COPY/MOVE、PROPPATCH。
///
/// 实现用已 vendored 的 GCDWebServer（ios-app/GCDWebServer，桥接头
/// 已 import），不自己写 NWListener：OTAInstallServer 那套只够回环
/// 直装，不够通用；GCDWebServer 的 default handler 正好按动词接管
/// 全部路径。服务默认关闭，开启时局域网内无密码可访问（UI 上有
/// 提示），传完请关闭；切后台时用 background task 续一会儿命，
/// 系统收回后服务即不可达（iOS 限制，非 bug）。
final class CZFWebDAVServer: ObservableObject {
    /// 全局唯一：工具页切 tab 重建视图也不能把跑着的服务连同视图
    /// 一起释放掉（OTAInstallServer.shared 同款）。
    static let shared = CZFWebDAVServer()
    private init() {}

    /// 首选端口；被占时往后顺延到 defaultPort + 10。
    static let defaultPort = 8080

    @Published private(set) var isRunning = false
    /// 开启后显示的局域网地址，如 http://192.168.1.5:8080；没连 Wi-Fi 时为 nil。
    @Published private(set) var address: String?
    /// 启动失败时的原因（端口全被占等），UI 直接展示。
    @Published private(set) var errorMessage: String?

    private var server: GCDWebServer?
    private var port = defaultPort
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    /// 本次服务的根目录：SideInstaller 自己的 Documents。
    private var root: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// 启动服务。已在跑时直接返回；端口被占自动顺延。
    func start() {
        guard !isRunning else { return }
        DispatchQueue.main.async { self.errorMessage = nil }
        let root = root
        let server = GCDWebServer()
        server.addDefaultHandler(forMethod: "PROPFIND", request: GCDWebServerRequest.self) { [weak self] request in
            self?.handlePropfind(request, root: root)
        }
        server.addDefaultHandler(forMethod: "GET", request: GCDWebServerRequest.self) { [weak self] request in
            self?.handleGet(request, root: root)
        }
        server.addDefaultHandler(forMethod: "PUT", request: GCDWebServerFileRequest.self) { [weak self] request in
            self?.handlePut(request, root: root)
        }
        server.addDefaultHandler(forMethod: "DELETE", request: GCDWebServerRequest.self) { [weak self] request in
            self?.handleDelete(request, root: root)
        }
        server.addDefaultHandler(forMethod: "MKCOL", request: GCDWebServerRequest.self) { [weak self] request in
            self?.handleMkcol(request, root: root)
        }
        var port = Self.defaultPort
        var started = false
        while port <= Self.defaultPort + 10 {
            if server.start(withPort: UInt(port), bonjourName: nil) {
                started = true
                break
            }
            port += 1
        }
        guard started else {
            DispatchQueue.main.async {
                self.errorMessage = L("WebDAV failed to start")
            }
            return
        }
        self.server = server
        self.port = port
        beginBackgroundTask()
        let address: String?
        if let ip = LANTransferServer.wifiIPAddress() {
            address = "http://\(ip):\(port)"
        } else {
            address = nil
        }
        DispatchQueue.main.async {
            self.isRunning = true
            self.address = address
        }
    }

    /// 停止服务并收掉后台任务。
    func stop() {
        server?.stop()
        server = nil
        endBackgroundTask()
        DispatchQueue.main.async {
            self.isRunning = false
            self.address = nil
            self.errorMessage = nil
        }
    }

    // MARK: - 路径

    /// 把请求路径解码并拼到根目录下。`..` 只在根目录内消化，
    /// 想逃出根目录的返回 nil（403），不让客户端读到别处。
    private func resolve(_ path: String, under root: URL) -> URL? {
        let decoded = (path as NSString).removingPercentEncoding ?? path
        var parts: [String] = []
        for seg in decoded.split(separator: "/") {
            if seg == "." || seg.isEmpty { continue }
            if seg == ".." {
                guard !parts.isEmpty else { return nil }
                parts.removeLast()
            } else {
                parts.append(String(seg))
            }
        }
        var url = root
        for part in parts { url.appendPathComponent(part) }
        return url
    }

    /// 目录/文件在 PROPFIND 里的 href：根目录是 /，其余拼路径并编码。
    private func href(for url: URL, root: URL) -> String {
        if url == root { return "/" }
        let rel = url.path.replacingOccurrences(of: root.path, with: "")
        return (rel as NSString).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? rel
    }

    // MARK: - PROPFIND（列目录）

    private func handlePropfind(_ request: GCDWebServerRequest, root: URL) -> GCDWebServerResponse? {
        guard let url = resolve(request.path, under: root) else {
            return GCDWebServerResponse(statusCode: 403)
        }
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return GCDWebServerResponse(statusCode: 404)
        }
        // Depth: 0 只列自身，1（默认）再列一层子项。
        let depth = request.headers["Depth"] ?? request.headers["depth"] ?? "1"
        var urls: [URL] = [url]
        // A-37-4：子项一次取齐 isDirectory/size/mdate（readdir 时预取，
        // 循环里读缓存值，不再每条目 stat 两次）；depth 0 只有自身，
        // 仍走下面单条目的 attributesOfItem（一次 stat）。
        let propKeys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        if depth != "0", isDir.boolValue,
           let children = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: propKeys) {
            urls += children.sorted { $0.lastPathComponent < $1.lastPathComponent }
        }
        var xml = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<D:multistatus xmlns:D=\"DAV:\">\n"
        for item in urls {
            let isRootItem = item == url
            // 根条目用入口 fileExists 的 isDir + 一次 attributesOfItem；
            // 子项用 contentsOfDirectory 预取的 resourceValues（不 stat）。
            let values = isRootItem ? nil : try? item.resourceValues(forKeys: Set(propKeys))
            let itemIsDir = isRootItem ? isDir.boolValue : (values?.isDirectory ?? false)
            let name = item == root ? "" : item.lastPathComponent
            xml += "  <D:response>\n"
            xml += "    <D:href>\(xmlEscape(href(for: item, root: root)))</D:href>\n"
            xml += "    <D:propstat>\n      <D:prop>\n"
            xml += "        <D:displayname>\(xmlEscape(name))</D:displayname>\n"
            // S8：size 与 mdate 一次取字典两项同读——原来每个条目调两次
            // attributesOfItem（stat 两次）；子项现在读预取值。
            let attrs = isRootItem ? try? fm.attributesOfItem(atPath: item.path) : nil
            let size = isRootItem ? attrs?[.size] as? NSNumber : values?.fileSize.map { NSNumber(value: $0) }
            let mdate = isRootItem ? attrs?[.modificationDate] as? Date : values?.contentModificationDate
            if itemIsDir {
                xml += "        <D:resourcetype><D:collection/></D:resourcetype>\n"
            } else {
                xml += "        <D:resourcetype/>\n"
                if let size {
                    xml += "        <D:getcontentlength>\(size.intValue)</D:getcontentlength>\n"
                }
            }
            if let mdate {
                xml += "        <D:getlastmodified>\(Self.rfc1123.string(from: mdate))</D:getlastmodified>\n"
            }
            xml += "      </D:prop>\n      <D:status>HTTP/1.1 200 OK</D:status>\n    </D:propstat>\n  </D:response>\n"
        }
        xml += "</D:multistatus>\n"
        let response = GCDWebServerDataResponse(data: Data(xml.utf8), contentType: "application/xml; charset=utf-8")
        response.statusCode = 207
        response.setValue("1", forAdditionalHeader: "DAV")
        return response
    }

    // MARK: - GET（下载）

    private func handleGet(_ request: GCDWebServerRequest, root: URL) -> GCDWebServerResponse? {
        guard let url = resolve(request.path, under: root) else {
            return GCDWebServerResponse(statusCode: 403)
        }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else {
            return GCDWebServerResponse(statusCode: 404)
        }
        return GCDWebServerFileResponse(file: url.path)
    }

    // MARK: - PUT（上传）

    private func handlePut(_ request: GCDWebServerRequest, root: URL) -> GCDWebServerResponse? {
        guard let url = resolve(request.path, under: root) else {
            return GCDWebServerResponse(statusCode: 403)
        }
        // C-2 同款：. 开头的名字文件页看不到（FilesTabView 用 .skipsHiddenFiles
        // 枚举）；守卫放在 resolve 之后，%2E 编码的点解码后同样拦住。
        // url != root 顺手拦 PUT /（否则拿文件替换整个 Documents 目录）。
        guard url != root, !url.lastPathComponent.hasPrefix(".") else {
            return GCDWebServerResponse(statusCode: 400)
        }
        let parent = url.deletingLastPathComponent()
        var parentIsDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: parent.path, isDirectory: &parentIsDir),
              parentIsDir.boolValue else {
            return GCDWebServerResponse(statusCode: 409)
        }
        let existed = FileManager.default.fileExists(atPath: url.path)
        // B7：正在安装的源文件不覆盖——body 已由框架流到临时文件（C21-1），
        // 这里只拦“落盘”这一步，不拦收 body；回 423 Locked 并记一笔。
        if Engine.shared.isInstallingSource(path: url.path) {
            Engine.shared.log("⛔️ WebDAV PUT refused: \(url.lastPathComponent) is being installed.")
            return GCDWebServerResponse(statusCode: 423)
        }
        // C21-1：PUT 走流式 FileRequest，body 落临时文件不进内存；
        // 临时文件在 request 释放时自动删，移走后 unlink 空操作。
        // 覆盖用 replaceItemAt（失败保旧文件），新建用 moveItem。
        guard let tmpPath = (request as? GCDWebServerFileRequest)?.temporaryPath else {
            return GCDWebServerResponse(statusCode: 500)
        }
        let tmpURL = URL(fileURLWithPath: tmpPath)
        do {
            if existed {
                _ = try FileManager.default.replaceItem(at: url, withItemAt: tmpURL, backupItemName: nil, resultingItemURL: nil)
            } else {
                try FileManager.default.moveItem(at: tmpURL, to: url)
            }
        } catch {
            return GCDWebServerResponse(statusCode: 500)
        }
        // 201 新建，204 覆盖。
        return GCDWebServerResponse(statusCode: existed ? 204 : 201)
    }

    // MARK: - DELETE（删除）

    private func handleDelete(_ request: GCDWebServerRequest, root: URL) -> GCDWebServerResponse? {
        guard let url = resolve(request.path, under: root) else {
            return GCDWebServerResponse(statusCode: 403)
        }
        // C32：C28 同款——目录（含 Documents 根本身）不删，回 400；
        // 不存在的文件仍回 404（不改原有语义）。
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            return GCDWebServerResponse(statusCode: 400)
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            return GCDWebServerResponse(statusCode: 404)
        }
        // B7：正在安装的源文件不删——删了签名步读不到文件；回 423 Locked 并记一笔。
        if Engine.shared.isInstallingSource(path: url.path) {
            Engine.shared.log("⛔️ WebDAV DELETE refused: \(url.lastPathComponent) is being installed.")
            return GCDWebServerResponse(statusCode: 423)
        }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            return GCDWebServerResponse(statusCode: 500)
        }
        return GCDWebServerResponse(statusCode: 204)
    }

    // MARK: - MKCOL（建目录）

    private func handleMkcol(_ request: GCDWebServerRequest, root: URL) -> GCDWebServerResponse? {
        guard let url = resolve(request.path, under: root) else {
            return GCDWebServerResponse(statusCode: 403)
        }
        // C-2 同款：见 handlePut（. 开头的名字文件页看不到；守卫在
        // resolve 之后，%2E 编码同样拦住；根目录也不许建）。
        guard url != root, !url.lastPathComponent.hasPrefix(".") else {
            return GCDWebServerResponse(statusCode: 400)
        }
        if FileManager.default.fileExists(atPath: url.path) {
            return GCDWebServerResponse(statusCode: 405)
        }
        let parent = url.deletingLastPathComponent()
        var parentIsDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: parent.path, isDirectory: &parentIsDir),
              parentIsDir.boolValue else {
            return GCDWebServerResponse(statusCode: 409)
        }
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        } catch {
            return GCDWebServerResponse(statusCode: 500)
        }
        return GCDWebServerResponse(statusCode: 201)
    }

    // MARK: - 小工具

    private func xmlEscape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    /// getlastmodified 的 RFC 1123（GMT）格式。
    private static let rfc1123: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        return formatter
    }()

    // MARK: - 后台续命（OTAInstallServer 同款）

    private func beginBackgroundTask() {
        endBackgroundTask()
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "CZFWebDAV") { [weak self] in
            self?.stop()
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
}
