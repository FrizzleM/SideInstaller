import Foundation
import Network

/// 局域网传输：一个极简 HTTP 服务，把 App 的 Documents 目录
/// 开给同 Wi-Fi 的浏览器——列表、下载、上传、删除。只在本机
/// 点了「开启」才跑，关掉即停。
final class LANTransferServer: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var port: Int = 0
    @Published var lastError: String?

    private var listener: NWListener?
    /// 正在尝试/运行的端口（失败回调靠它判断要不要试下一个，
    /// 避免回调闭包持有 listener 造成循环引用）。
    private var activeCandidate = 0
    private let queue = DispatchQueue(label: "czf.lan.transfer")

    /// C-7：在途连接登记表——stop() 与 60 秒空闲超时靠它掐断僵尸连接。
    /// 全部在 lan 串行队列上读写（handle/receive/send 全走这条队列），不用加锁。
    private struct LiveConnection {
        let connection: NWConnection
        var lastActivity: Date
        var idleCheck: DispatchWorkItem?
    }
    private var liveConnections: [ObjectIdentifier: LiveConnection] = [:]
    private static let connectionIdleTimeout: TimeInterval = 60

    /// 登记一条在途连接并排上它的空闲检查。只在 lan 串行队列上调。
    private func registerConnection(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        liveConnections[id] = LiveConnection(connection: connection, lastActivity: Date(), idleCheck: nil)
        scheduleIdleCheck(for: id, after: Self.connectionIdleTimeout)
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
    private func scheduleIdleCheck(for id: ObjectIdentifier, after delay: TimeInterval) {
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

    /// N1(C)：单次上传 body 上限——min(8GB, 空闲 − 1GB)，每请求现算；
    /// 与 WebDAV 侧同数。空闲 ≤ 1GB 时返回 0（全部上传拒掉）。
    /// 字节数一律走 int64Value——intValue 在 2GB 以上会截断。
    private static func uploadBodyLimit() -> Int {
        let maxLimit: Int64 = 8 * 1024 * 1024 * 1024
        let reserve: Int64 = 1 * 1024 * 1024 * 1024
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath:
                FileManager.default.temporaryDirectory.path),
              let free = attrs[.systemFreeSize] as? NSNumber else {
            return Int(maxLimit)
        }
        let freeBytes = free.int64Value
        guard freeBytes > reserve else { return 0 }
        return Int(min(maxLimit, freeBytes - reserve))
    }

    /// S19：列表扫盘的短 TTL 缓存——GET / 每次都全量递归扫盘，上传/
    /// 删除后 303 再扫一次；电脑端列表最多滞后 TTL。只在 lan 串行
    /// 队列上读写（respond 全走这条队列），不用加锁；上传/删除后
    /// 的 redirect 会清掉缓存，所以刚传完的文件立刻能看到。
    private var lanListCache: (items: [LocalFileItem], at: Date)?
    private static let lanListCacheTTL: TimeInterval = 5

    /// 5 秒内的重复列表请求直接用缓存；过期重扫。
    private func cachedLANListItems() -> [LocalFileItem] {
        if let cache = lanListCache, Date().timeIntervalSince(cache.at) < Self.lanListCacheTTL {
            return cache.items
        }
        let items = AppFileLibrary.scan().filter { !$0.isDirectory }
        lanListCache = (items, Date())
        return items
    }

    private var root: URL { IPALibrary.documentsDir }

    var addressText: String {
        "http://\(Self.wifiIPAddress() ?? "127.0.0.1"):\(port)"
    }

    func start() {
        guard !isRunning else { return }
        lastError = nil
        tryPort(8088)
    }

    func stop() {
        activeCandidate = 0
        listener?.cancel()
        listener = nil
        isRunning = false
        port = 0
        // C-7：停 listener 只拦新连接——在途的也得掐断，否则传一半的文件
        // 还会完整落盘。登记表在 lan 队列上，异步清掉（串行队列保证
        // 先于之后新登记的连接执行，不会误掐新连接）。
        queue.async { [weak self] in
            guard let self else { return }
            for entry in self.liveConnections.values {
                entry.idleCheck?.cancel()
                entry.connection.cancel()
            }
            self.liveConnections.removeAll()
        }
    }

    private func tryPort(_ candidate: Int) {
        guard candidate <= 8098 else {
            DispatchQueue.main.async { self.lastError = L("端口 8088-8098 都被占用了") }
            return
        }
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let listener = try NWListener(
                using: params, on: NWEndpoint.Port(rawValue: UInt16(candidate))!)
            activeCandidate = candidate
            listener.stateUpdateHandler = { [weak self] state in
                guard let self, self.activeCandidate == candidate else { return }
                switch state {
                case .ready:
                    DispatchQueue.main.async {
                        self.isRunning = true
                        self.port = candidate
                    }
                case .failed:
                    self.listener = nil
                    self.tryPort(candidate + 1)
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
            tryPort(candidate + 1)
        }
    }

    // MARK: 连接与请求解析

    private struct Request {
        let method: String
        let path: String
        let query: [String: String]
        let headers: [String: String]
        let body: Data
    }

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
            if let (head, bodyStart) = Self.parseHead(buf) {
                // S20：POST /upload 走流式落盘，body 不再整条攒进内存；
                // 没 boundary 的畸形上传仍走老路（攒满后 saveUpload 回 400）。
                if head.method == "POST", head.path == "/upload",
                   head.contentLength > 0,
                   let boundary = Self.uploadBoundary(contentType: head.headers["content-type"]) {
                    self.receiveUploadHead(connection, head: head, boundary: boundary,
                                           body: Data(buf[bodyStart...].prefix(head.contentLength)),
                                           received: min(buf.count - bodyStart, head.contentLength))
                    return
                }
                // 非流式上传：body 超 1MB 直接 400，不攒 buf。
                // 合法非流式 body 在此服务上不存在（只有 POST /upload 收 body，
                // 且有 boundary 的已走流式路）；未知路由的大 body 同样是垃圾请求。
                if head.contentLength > (1 << 20) {
                    sendText(connection, status: "400 Bad Request", text: L("Couldn't parse the upload"))
                    return
                }
                if let request = Self.parse(buf) {
                    self.respond(connection, request: request)
                } else if isComplete || error != nil || buf.count > (256 << 20) {
                    self.unregisterConnection(connection)
                    connection.cancel()
                } else {
                    self.receive(connection, buffer: buf)
                }
            } else if isComplete || error != nil || buf.count > (256 << 20) {
                self.unregisterConnection(connection)
                connection.cancel()
            } else {
                self.receive(connection, buffer: buf)
            }
        }
    }

    /// 请求行 + 请求头（不含 body）；没齐返回 nil（继续收）。
    private struct RequestHead {
        let method: String
        let path: String
        let query: [String: String]
        let headers: [String: String]
        let contentLength: Int
    }

    private static func parseHead(_ buf: Data) -> (RequestHead, Int)? {
        let headerEnd = Data("\r\n\r\n".utf8)
        guard let range = buf.range(of: headerEnd) else { return nil }
        let headText = String(decoding: buf[..<range.lowerBound], as: UTF8.self)
        let lines = headText.components(separatedBy: "\r\n")
        guard let first = lines.first else { return nil }
        let parts = first.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if let colon = line.firstIndex(of: ":") {
                let key = line[..<colon].lowercased()
                let value = line[line.index(after: colon)...]
                    .trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }
        // S22：负 Content-Length 会让 parse 切出倒置 range、Data 下标 trap
        // 撞崩整个 App，夹到 0（畸形请求随后走老路回 400）。
        let contentLength = max(0, Int(headers["content-length"] ?? "") ?? 0)
        let rawPath = String(parts[1])
        let pathPart = rawPath.split(separator: "?", maxSplits: 1).first.map(String.init) ?? "/"
        var query: [String: String] = [:]
        if let q = rawPath.split(separator: "?", maxSplits: 1).last, rawPath.contains("?") {
            for pair in q.split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1)
                if kv.count == 2 {
                    query[String(kv[0])] = String(kv[1]).removingPercentEncoding ?? String(kv[1])
                }
            }
        }
        return (RequestHead(method: String(parts[0]), path: pathPart, query: query,
                            headers: headers, contentLength: contentLength),
                range.upperBound)
    }

    /// 数据齐了才返回请求；没齐返回 nil（继续收）。
    private static func parse(_ buf: Data) -> Request? {
        guard let (head, bodyStart) = parseHead(buf) else { return nil }
        guard buf.count - bodyStart >= head.contentLength else { return nil }
        let body = buf[bodyStart..<(bodyStart + head.contentLength)]
        return Request(method: head.method, path: head.path, query: head.query,
                       headers: head.headers, body: Data(body))
    }

    // MARK: 流式上传（S20）

    /// multipart 的 boundary（`Content-Type: multipart/form-data; boundary=…`）；
    /// 没有或为空就是非法上传。
    private static func uploadBoundary(contentType: String?) -> String? {
        guard let contentType,
              let boundaryRange = contentType.range(of: "boundary=", options: .caseInsensitive) else { return nil }
        let boundary = String(contentType[boundaryRange.upperBound...])
            .trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
        return boundary.isEmpty ? nil : boundary
    }

    /// part 头里的 filename="…"，只要 basename（与 saveUpload 同款）。
    private static func uploadFileName(partHead: String) -> String? {
        guard let nameRange = partHead.range(of: "filename=\"") else { return nil }
        let afterName = partHead[nameRange.upperBound...]
        guard let quoteEnd = afterName.firstIndex(of: "\"") else { return nil }
        let rawName = String(afterName[..<quoteEnd])
        let fileName = rawName.split(separator: "/").last.map(String.init) ?? "upload.bin"
        // N2(C)：. 开头的名字文件页看不到（.skipsHiddenFiles）——直接拒掉，
        // 流式路与老路共用本函数，两路同治。
        guard !fileName.hasPrefix(".") else { return nil }
        return fileName.isEmpty ? nil : fileName
    }

    /// 重名改名规则（与 saveUpload 同款）：已有同名文件时在后面加 " 2"、" 3"……。
    private static func uniqueDest(fileName: String, root: URL) -> URL {
        var dest = root.appendingPathComponent(fileName)
        let stem = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        var counter = 2
        while FileManager.default.fileExists(atPath: dest.path) {
            let name = ext.isEmpty ? "\(stem) \(counter)" : "\(stem) \(counter).\(ext)"
            dest = root.appendingPathComponent(name)
            counter += 1
        }
        return dest
    }

    /// 流式上传的接收状态：body 边收边写临时文件，内存里只留一个待写窗口。
    /// 临时文件里就是文件本身（part 头之后、收尾 marker 之前的内容）；收满后
    /// 按重名规则挪到 Documents，失败/取消/断开都删临时文件。
    private final class UploadSink {
        let tailMarker: Data
        let tempURL: URL
        let handle: FileHandle
        let fileName: String
        let contentLength: Int
        let limit: Int
        var received: Int
        var pending = Data()
        var markerFound = false

        init(boundary: String, tempURL: URL, handle: FileHandle,
             fileName: String, contentLength: Int, limit: Int, received: Int) {
            self.tailMarker = Data("\r\n--\(boundary)".utf8)
            self.tempURL = tempURL
            self.handle = handle
            self.fileName = fileName
            self.contentLength = contentLength
            self.limit = limit
            self.received = received
        }
    }

    /// 上传第一阶段：攒 body 直到 part 头齐（`\r\n\r\n`），取文件名、建临时
    /// 文件，进内容流。part 头本身很小，超 64KB 就是非法请求。
    private func receiveUploadHead(_ connection: NWConnection, head: RequestHead,
                                   boundary: String, body: Data, received: Int) {
        // N1(C)：先看声明总量再建 sink——超限直接 400，不建临时文件。
        let limit = Self.uploadBodyLimit()
        if head.contentLength > limit {
            sendText(connection, status: "400 Bad Request", text: L("Couldn't parse the upload"))
            return
        }
        let headEnd = Data("\r\n\r\n".utf8)
        if let range = body.range(of: headEnd) {
            let partHead = String(decoding: body[..<range.lowerBound], as: UTF8.self)
            guard let fileName = Self.uploadFileName(partHead: partHead) else {
                sendText(connection, status: "400 Bad Request", text: L("Couldn't parse the upload"))
                return
            }
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("lan-upload-\(UUID().uuidString).tmp")
            guard FileManager.default.createFile(atPath: tempURL.path, contents: nil),
                  let handle = try? FileHandle(forWritingTo: tempURL) else {
                sendText(connection, status: "400 Bad Request", text: L("Couldn't parse the upload"))
                return
            }
            let sink = UploadSink(boundary: boundary, tempURL: tempURL, handle: handle,
                                  fileName: fileName, contentLength: head.contentLength, limit: limit,
                                  // R-1：received 初值只算 part 头那段——首块内容马上要当
                                  // chunk 传给 receiveUploadBody 再加一次，初值里不能再算它，
                                  // 否则 received 虚高、收尾 marker 没到就提前 finishUpload 回 400。
                                  received: received - body[range.upperBound...].count)
            receiveUploadBody(connection, sink: sink,
                              chunk: Data(body[range.upperBound...]))
            return
        }
        guard received < head.contentLength else {
            sendText(connection, status: "400 Bad Request", text: L("Couldn't parse the upload"))
            return
        }
        guard body.count <= (64 << 10) else {
            sendText(connection, status: "400 Bad Request", text: L("Couldn't parse the upload"))
            return
        }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 16) {
            [weak self] data, _, isComplete, error in
            guard let self else { connection.cancel(); return }
            if let data {
                self.touchConnection(connection)
                var next = body
                let take = min(data.count, head.contentLength - received)
                next.append(data.prefix(take))
                self.receiveUploadHead(connection, head: head, boundary: boundary,
                                       body: next, received: received + take)
            } else if isComplete || error != nil {
                connection.cancel()
            } else {
                self.receiveUploadHead(connection, head: head, boundary: boundary,
                                       body: body, received: received)
            }
        }
    }

    /// 上传第二阶段：内容边收边写临时文件。收尾 marker（`\r\n--boundary`）
    /// 可能跨块，先扫整段待写窗口再落盘，留尾部（marker 长 − 1）字节不写，
    /// 见到 marker 才算收完——与 saveUpload“截在第一个 marker 处”同款。
    private func receiveUploadBody(_ connection: NWConnection, sink: UploadSink, chunk: Data) {
        if !sink.markerFound, !chunk.isEmpty {
            sink.pending.append(chunk)
            if let at = sink.pending.range(of: sink.tailMarker) {
                do {
                    try sink.handle.write(contentsOf: Data(sink.pending[..<at.lowerBound]))
                } catch {
                    failUpload(connection, sink: sink)
                    return
                }
                sink.pending.removeAll()
                sink.markerFound = true
            } else {
                let keep = sink.tailMarker.count - 1
                if sink.pending.count > keep {
                    let flush = Data(sink.pending[..<(sink.pending.count - keep)])
                    do {
                        try sink.handle.write(contentsOf: flush)
                    } catch {
                        failUpload(connection, sink: sink)
                        return
                    }
                    sink.pending.removeFirst(sink.pending.count - keep)
                }
            }
        }
        sink.received += chunk.count
        // N1(C)：流式上传总量上限——received 记的是整个 multipart body
        // （R-1 语义），比落盘字节只多不少，拿它当上限是保守的。
        if sink.received > sink.limit {
            failUpload(connection, sink: sink)
            return
        }
        if sink.received >= sink.contentLength {
            finishUpload(connection, sink: sink)
            return
        }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 16) {
            [weak self] data, _, isComplete, error in
            guard let self else {
                // 服务已释放：连接照旧掐掉，临时文件也不能留。
                try? sink.handle.close()
                try? FileManager.default.removeItem(at: sink.tempURL)
                connection.cancel()
                return
            }
            if let data {
                self.touchConnection(connection)
                let take = min(data.count, sink.contentLength - sink.received)
                self.receiveUploadBody(connection, sink: sink, chunk: Data(data.prefix(take)))
            } else if isComplete || error != nil {
                self.failUpload(connection, sink: sink)
            } else {
                self.receiveUploadBody(connection, sink: sink, chunk: Data())
            }
        }
    }

    /// 收满：没见到收尾 marker 就是非法 body，删临时文件回 400；见到了就
    /// 按重名规则把临时文件挪到 Documents，回 303。
    private func finishUpload(_ connection: NWConnection, sink: UploadSink) {
        try? sink.handle.close()
        guard sink.markerFound else {
            try? FileManager.default.removeItem(at: sink.tempURL)
            sendText(connection, status: "400 Bad Request", text: L("Couldn't parse the upload"))
            return
        }
        let dest = Self.uniqueDest(fileName: sink.fileName, root: root)
        do {
            try FileManager.default.moveItem(at: sink.tempURL, to: dest)
        } catch {
            try? FileManager.default.removeItem(at: sink.tempURL)
            sendText(connection, status: "400 Bad Request", text: L("Couldn't parse the upload"))
            return
        }
        redirect(connection)
    }

    /// 上传失败/取消/断开：关句柄、删临时文件、断连接，Documents 里不留半截文件。
    private func failUpload(_ connection: NWConnection, sink: UploadSink) {
        try? sink.handle.close()
        try? FileManager.default.removeItem(at: sink.tempURL)
        unregisterConnection(connection)
        connection.cancel()
    }

    // MARK: 路由

    private func respond(_ connection: NWConnection, request: Request) {
        switch (request.method, request.path) {
        case ("GET", "/"):
            send(connection, status: "200 OK", contentType: "text/html; charset=utf-8",
                 body: Data(indexHTML().utf8))
        case ("GET", "/dl"):
            guard let rel = request.query["path"], let file = resolve(rel),
                  FileManager.default.fileExists(atPath: file.path) else {
                sendText(connection, status: "404 Not Found", text: L("File not found"))
                return
            }
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: file.path, isDirectory: &isDir),
               isDir.boolValue {
                sendText(connection, status: "400 Bad Request", text: L("Invalid path"))
                return
            }
            sendFile(connection, file: file)
        case ("GET", "/del"):
            guard let rel = request.query["path"], let file = resolve(rel),
                  deleteFile(at: file) else {
                sendText(connection, status: "400 Bad Request", text: L("Invalid path"))
                return
            }
            redirect(connection)
        case ("POST", "/upload"):
            guard let contentType = request.headers["content-type"],
                  let saved = Self.saveUpload(body: request.body, contentType: contentType, root: root)
            else {
                sendText(connection, status: "400 Bad Request", text: L("Couldn't parse the upload"))
                return
            }
            _ = saved
            redirect(connection)
        default:
            sendText(connection, status: "404 Not Found", text: L("No such page"))
        }
    }

    /// 把相对路径钉回 Documents 里，逃不出去。
    /// C28：空串 split 得 0 分量会原样返回 Documents 根目录，
    /// /del?path= 能删整个 Documents——空 rel 直接拒掉。
    private func resolve(_ rel: String) -> URL? {
        guard !rel.isEmpty else { return nil }
        let decoded = rel.removingPercentEncoding ?? rel
        var url = root
        for component in decoded.split(separator: "/") {
            if component == ".." || component == "." { return nil }
            url.appendPathComponent(String(component))
        }
        let path = url.standardizedFileURL.path
        guard path == root.path || path.hasPrefix(root.path + "/") else { return nil }
        return url
    }

    /// C28：目录不删——/del?path=Signed 会删整个已签名目录。只拦目录：
    /// 不存在的文件沿用老路（try? 空操作，照旧 303），不扩大改动面。
    /// 返回 false 只表示“目录，拒绝”，调用方回 400。
    private func deleteFile(at file: URL) -> Bool {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: file.path, isDirectory: &isDir),
           isDir.boolValue {
            return false
        }
        let relDir = file.deletingLastPathComponent().path
            .replacingOccurrences(of: root.path, with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if relDir == "Signed",
           let record = SignedIPAStore.load().first(where: { $0.fileName == file.lastPathComponent }) {
            SignedIPAStore.remove(record)
            return true
        } else {
            try? FileManager.default.removeItem(at: file)
            return true
        }
    }

    // MARK: 响应发送

    private func send(_ connection: NWConnection, status: String, contentType: String,
                      body: Data, extraHeaders: [String] = []) {
        var head = "HTTP/1.1 \(status)\r\nContent-Type: \(contentType)\r\n"
        head += "Content-Length: \(body.count)\r\nConnection: close\r\n"
        for header in extraHeaders {
            head += "\(header)\r\n"
        }
        head += "\r\n"
        var data = Data(head.utf8)
        data.append(body)
        connection.send(content: data, completion: .contentProcessed { [weak self] _ in
            self?.unregisterConnection(connection)
            connection.cancel()
        })
    }

    private func sendText(_ connection: NWConnection, status: String, text: String) {
        send(connection, status: status, contentType: "text/plain; charset=utf-8",
             body: Data(text.utf8))
    }

    private func redirect(_ connection: NWConnection) {
        lanListCache = nil
        send(connection, status: "303 See Other", contentType: "text/plain",
             body: Data(), extraHeaders: ["Location: /"])
    }

    private func sendFile(_ connection: NWConnection, file: URL) {
        let size = (try? FileManager.default.attributesOfItem(atPath: file.path))?[.size] as? Int ?? 0
        let name = file.lastPathComponent
        let encoded = name.addingPercentEncoding(
            withAllowedCharacters: CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")) ?? "file"
        var head = "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\n"
        head += "Content-Length: \(size)\r\nConnection: close\r\n"
        head += "Content-Disposition: attachment; filename*=UTF-8''\(encoded)\r\n\r\n"
        connection.send(content: Data(head.utf8), completion: .contentProcessed { [weak self] _ in
            guard let self else {
                connection.cancel()
                return
            }
            self.touchConnection(connection)
            self.streamFile(connection, file: file, offset: 0)
        })
    }

    private func streamFile(_ connection: NWConnection, file: URL, offset: Int) {
        guard let handle = try? FileHandle(forReadingFrom: file) else {
            unregisterConnection(connection)
            connection.cancel()
            return
        }
        defer { try? handle.close() }
        do {
            try handle.seek(toOffset: UInt64(offset))
            let chunk = try handle.read(upToCount: 1 << 20) ?? Data()
            if chunk.isEmpty {
                let expected = (try? FileManager.default.attributesOfItem(atPath: file.path))?[.size] as? Int ?? -1
                // 正常到 EOF 时 offset == expected，不记；只有真短（删/换文件）才记。
                if expected < 0 || offset != expected {
                    LogStore.shared.append("⚠️ Download truncated: \(file.lastPathComponent) stopped at \(offset)/\(expected) bytes.")
                }
                unregisterConnection(connection)
                connection.cancel()
                return
            }
            connection.send(content: chunk, completion: .contentProcessed { [weak self] _ in
                self?.touchConnection(connection)
                self?.streamFile(connection, file: file, offset: offset + chunk.count)
            })
        } catch {
            unregisterConnection(connection)
            connection.cancel()
        }
    }

    // MARK: 页面与上传解析

    private func indexHTML() -> String {
        // 文件页改成连文件夹一起列之后，这里仍只列文件：
        // 局域网传输的下载链接对文件夹没有意义，别让它出现在列表里。
        let lang = Localizer.locale.language.languageCode?.identifier ?? "en"
        let items = cachedLANListItems()
        var rows = ""
        for item in items {
            let rel = item.relativeDir.isEmpty ? item.name : "\(item.relativeDir)/\(item.name)"
            let enc = rel.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&"))) ?? rel
            let size = ByteCountFormatter.string(fromByteCount: Int64(item.size), countStyle: .file)
            rows += "<tr><td>\(Self.htmlEscape(rel))</td><td>\(size)</td>" +
                "<td><a href=\"/dl?path=\(enc)\">\(L("Download"))</a></td>" +
                "<td><a href=\"/del?path=\(enc)\" onclick=\"return confirm('\(Self.jsConfirmEscape(L("Delete this file?")))')\">\(L("Delete"))</a></td></tr>"
        }
        if items.isEmpty {
            rows = "<tr><td colspan=\"4\">\(L("This directory is empty"))</td></tr>"
        }
        return """
        <!DOCTYPE html><html lang="\(lang)"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(L("SideInstaller LAN Transfer"))</title>
        <style>body{font-family:-apple-system,sans-serif;margin:24px;color:#222}
        table{border-collapse:collapse;width:100%}td,th{border-bottom:1px solid #ddd;padding:8px;text-align:left}
        a{color:#06c;text-decoration:none}</style></head><body>
        <h2>\(L("SideInstaller File Transfer"))</h2>
        <form method="post" action="/upload" enctype="multipart/form-data">
        <input type="file" name="file"> <button type="submit">\(L("Upload"))</button></form>
        <table><tr><th>\(L("File"))</th><th>\(L("Size"))</th><th></th><th></th></tr>\(rows)</table>
        </body></html>
        """
    }

    private static func htmlEscape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// 转义一段要放进 `onclick="…confirm('…')"` 的译文：译文里的撇号会截断
    /// JS 字符串、反斜杠会吃掉后一个字符，双引号会截断外层 HTML 属性。
    /// 顺序不能换：先反斜杠，再 &（免得把 &quot; 里的 & 再转一次），再引号。
    private static func jsConfirmEscape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "\\'")
    }

    /// 从 multipart/form-data 里取出文件存进目录，返回落点。
    private static func saveUpload(body: Data, contentType: String, root: URL) -> URL? {
        guard let boundary = uploadBoundary(contentType: contentType) else { return nil }
        let marker = Data("--\(boundary)".utf8)
        guard let first = body.range(of: marker) else { return nil }
        let afterMarker = body[first.upperBound...]
        guard let headEnd = afterMarker.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let partHead = String(decoding: afterMarker[..<headEnd.lowerBound], as: UTF8.self)
        guard let fileName = uploadFileName(partHead: partHead) else { return nil }
        let contentStart = headEnd.upperBound
        let tail = Data("\r\n--\(boundary)".utf8)
        guard let endRange = body.range(of: tail, options: [], in: contentStart..<body.count)
        else { return nil }
        let content = body[contentStart..<endRange.lowerBound]
        let dest = uniqueDest(fileName: fileName, root: root)
        do {
            try Data(content).write(to: dest, options: .atomic)
            return dest
        } catch {
            return nil
        }
    }

    // MARK: Wi-Fi 地址

    static func wifiIPAddress() -> String? {
        var address: String?
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else { return nil }
        defer { freeifaddrs(interfaces) }
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let ifa = ptr.pointee
            guard let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            if String(cString: ifa.ifa_name) == "en0" {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host,
                            socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                address = String(cString: host)
            }
        }
        return address
    }
}
