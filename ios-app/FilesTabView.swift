import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Documents 里的一个文件或文件夹（递归，含子文件夹）。
struct LocalFileItem: Identifiable {
    let url: URL
    let name: String
    /// 相对 Documents 的目录（"" 是根目录，如 "Custom"、"Signed"）。
    let relativeDir: String
    let size: Int
    let modified: Date?
    /// 是不是文件夹：轻松签文件列表式，文件夹也是一行。
    let isDirectory: Bool
    /// 文件夹的直接子项数（不含隐藏项），文件恒为 0。
    let childCount: Int
    var id: String { url.path }
    var isIPA: Bool { name.lowercased().hasSuffix(".ipa") }
    var isZip: Bool { name.lowercased().hasSuffix(".zip") }
    var isInSignedDir: Bool { relativeDir == "Signed" }
    /// App 自己用的 DDI 支撑文件，不是用户文件：DDI 文件夹、以及根
    /// 目录或 DDI/ 里的 Image.dmg、trustcache、BuildManifest。文件页
    /// 默认不把它们混在用户文件里，收到系统文件组里，需要时再展开。
    var isSystem: Bool {
        if isDirectory { return name == "DDI" }
        let ddiNames: Set<String> = ["Image.dmg", "Image.dmg.trustcache", "BuildManifest.plist"]
        guard ddiNames.contains(name) else { return false }
        return relativeDir.isEmpty || relativeDir == "DDI" || relativeDir.hasPrefix("DDI/")
    }
}

/// App 自己 Documents 目录的文件扫描（下载/导入/已签名都在这）。
enum AppFileLibrary {
    static func scan() -> [LocalFileItem] {
        let root = IPALibrary.documentsDir
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]) else { return [] }
        var items: [LocalFileItem] = []
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(
                forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
            let isDirectory = values?.isDirectory == true
            let rel = url.path.replacingOccurrences(of: root.path + "/", with: "")
            let dir = (rel as NSString).deletingLastPathComponent
            // 文件夹数直接子项（不含隐藏项），文件恒为 0。
            let childCount: Int
            if isDirectory {
                let children = (try? fm.contentsOfDirectory(atPath: url.path)) ?? []
                childCount = children.filter { !$0.hasPrefix(".") }.count
            } else {
                childCount = 0
            }
            items.append(LocalFileItem(
                url: url,
                name: url.lastPathComponent,
                relativeDir: dir == "." ? "" : dir,
                size: values?.fileSize ?? 0,
                modified: values?.contentModificationDate,
                isDirectory: isDirectory,
                childCount: childCount))
        }
        return items.sorted { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) }
    }

    /// 把外部文件拷进 Documents 根目录，重名自动改名，返回落点。
    static func importIntoDocuments(_ source: URL) throws -> URL {
        let fm = FileManager.default
        let stem = source.deletingPathExtension().lastPathComponent
        let ext = source.pathExtension
        var candidate = IPALibrary.documentsDir.appendingPathComponent(source.lastPathComponent)
        var counter = 2
        while fm.fileExists(atPath: candidate.path) {
            let name = ext.isEmpty ? "\(stem) \(counter)" : "\(stem) \(counter).\(ext)"
            candidate = IPALibrary.documentsDir.appendingPathComponent(name)
            counter += 1
        }
        try fm.copyItem(at: source, to: candidate)
        return candidate
    }
}

/// 文件页：管理 App 沙盒 Documents 里的文件——导入、分享、删除，
/// IPA 可以直接去企业证书签名或（已签名的）直接安装。
struct FilesTabView: View {
    // 文件页企业安装走 Engine 配对链路（v68 回退，证书页同款）：
    // 这里重新观察 Engine（v63 曾拿掉，v68 拿回来，只为企业已
    // 签名安装；安装 tab 的 ID 线与文件页仍是各认各次安装的状
    // 态，不串台——结果判定只看 fileInstallInFlight 期间的变化）。
    @Environment(Engine.self) private var engine: Engine
    /// 步骤日志存放处（单例，与证书页共用同一份 diagnosticLog）：
    /// 文件页安装的传输不再走它的 install()，只用 appendStepLog
    /// 记配对安装开始/完成/失败，证书页的诊断日志里能看到。
    @ObservedObject private var localInstall = LocalHTTPInstallServer.shared
    /// IPA 文件行图标缓存（路径 → 图标数据）与已试集合（键 =
    /// 路径#大小#修改时间，文件换了就重取，不死循环重试）。
    @State private var fileIcons: [String: Data] = [:]
    @State private var fileIconsTried: Set<String> = []
    /// Declared so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer
    @EnvironmentObject private var workspace: CertWorkspace
    /// 切到证书页（RootView 给的）。
    var onGoCert: () -> Void

    /// First scan happens in onAppear; starting empty so the list isn't
    /// scanned twice on first appearance.
    @State private var files: [LocalFileItem] = []
    @State private var showImporter = false
    @State private var importError: String?
    // 多选 / 重命名 / 压缩解压
    @State private var selecting = false
    @State private var selection: Set<String> = []
    @State private var renameItem: LocalFileItem?
    @State private var renameText = ""
    @State private var opBusy = false
    @State private var opMessage: String?
    @State private var opFailed = false
    // Mach-O 查看 / 局域网传输
    @State private var machoItem: LocalFileItem?
    /// ⓘ 详情 sheet 正在看的行。
    @State private var detailItem: LocalFileItem?
    /// 文件页搜索（轻松签文件列表顶部搜索条同款）：按名字过滤当前视图。
    @State private var fileSearchText = ""
    /// 轻松签文件列表式切栏：未签名 = 不在 Signed 目录的 IPA，
    /// 已签名 tab 只显示已签名 IPA；未签名 tab 显示未签名 IPA +
    /// 其他文件 + 系统文件。
    @State private var fileTab = FileListTab.unsigned
    /// IPA 行信息缓存（路径 → Info.plist 解析结果）：行格式第二行
    /// 要版本/Bundle ID，文件页以前只取图标不解析，这里按行在后台
    /// 解析一次；键带大小 + 修改时间，文件换了就重解析。
    @State private var fileIPAInfo: [String: IPALibrary.AppInfo] = [:]
    @State private var fileIPAInfoTried: Set<String> = []
    /// 续签源清单缓存（路径/包名 → 续签用的 App）：行内「续签」角标
    /// 与详情页同认；进页时读一次，不每行读盘。删文件时的提示走
    /// RenewalSourceStore.source 现读，不用这份缓存。
    @State private var renewalSources: [RenewalSourceEntry] = []
    /// 点行弹出的底部动作菜单正在操作的行（nil = 不弹）。
    @State private var actionItem: LocalFileItem?
    /// 待确认删除的单个文件（行菜单/行内按钮/详情页点删除后先弹确认）。
    @State private var pendingDeleteItem: LocalFileItem?
    /// 批量删除待确认（工具栏“删除所选”点后先弹确认，带数量）。
    @State private var pendingDeleteSelection = false
    /// 当前进的文件夹（相对 Documents 的路径，"" = 根目录）：
    /// 点文件夹行就进，返回条回上级；删了当前文件夹就回根目录。
    @State private var currentDir = ""
    /// 新建文件夹：名字输入（alert 里填）+ 是否弹出。
    @State private var newFolderName = ""
    @State private var showNewFolderAlert = false
    /// 要移动的文件/文件夹（sheet 的 item，nil 就不弹）。
    @State private var moveItem: LocalFileItem?
    @StateObject private var lanServer = LANTransferServer()
    /// 文件页已签名安装：走 Engine 配对链路（v68 回退，证书页
    /// startEngineInstall 同款）。进行中标志 + 完成弹框（inFlight
    /// 隔离：结果判定只看 fileInstallInFlight 期间 engine.isRunning
    /// 的变化，ID 线的安装跑完不会误弹到这里）；重试用的记录/
    /// 文件地址（装时记下）；失败原因快照（证书页同款，不直接
    /// 读 engine 的全局 lastError，免得别的页的失败串到这里）。
    @State private var fileInstallInFlight = false
    @State private var showingFileInstallSuccessAlert = false
    @State private var fileInstallRecord: SignedIPARecord?
    @State private var fileInstallURL: URL?
    @State private var fileInstallErrorText: String?
    /// 局域网地址点按复制后的短暂「已复制」提示。
    @State private var lanCopied = false

    private var ipas: [LocalFileItem] { files.filter { $0.isIPA } }
    private var others: [LocalFileItem] { files.filter { !$0.isIPA && !$0.isSystem } }
    private var systemFiles: [LocalFileItem] { files.filter { $0.isSystem } }
    private var totalSize: Int { files.reduce(0) { $0 + $1.size } }

    /// 切栏计数：未签名/已签名 IPA 各多少（搜索不影响切栏总数）。
    private var unsignedCount: Int { ipas.filter { !$0.isInSignedDir }.count }
    private var signedCount: Int { ipas.filter { $0.isInSignedDir }.count }

    /// 文件列表排序：默认扫描顺序 / 名称 / 大小（大在前）/ 最新
    /// （修改时间晚在前）。只改显示顺序，不动磁盘顺序。
    private enum FileSort: String, CaseIterable {
        case `default`, name, size, newest
        var label: String {
            switch self {
            case .default: return L("默认")
            case .name: return L("名称")
            case .size: return L("大小")
            case .newest: return L("最新")
            }
        }
    }
    @AppStorage("CZFFileSort") private var fileSortRaw = FileSort.default.rawValue
    private var fileSort: FileSort { FileSort(rawValue: fileSortRaw) ?? .default }

    private func sortedFiles(_ items: [LocalFileItem]) -> [LocalFileItem] {
        switch fileSort {
        case .default: return items
        case .name: return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .size: return items.sorted { $0.size > $1.size }
        case .newest: return items.sorted { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) }
        }
    }

    /// 切栏是否命中这行 IPA：已签名的判定跟行内「安装」按钮同例
    ///（在 Signed 目录里），跟证书页已签名清单的落点一致。
    private func fileTabMatches(_ item: LocalFileItem) -> Bool {
        switch fileTab {
        case .unsigned: return !item.isInSignedDir
        case .signed: return item.isInSignedDir
        }
    }

    /// 切栏 + 搜索过滤后的 IPA 列表（根目录视图用，递归扫描的全量）。
    private var filteredIPAs: [LocalFileItem] {
        sortedFiles(matching(ipas).filter { fileTabMatches($0) })
    }

    /// 当前文件夹视图里切栏过滤后的可见项：未签名 tab 显示未签名 IPA
    /// + 其他文件 + 系统文件；已签名 tab 只显示已签名 IPA（其他文件、
    /// 系统文件与文件夹内的非 IPA 行一律不显示）。
    private var visibleDirItems: [LocalFileItem] {
        currentDirItems.filter { item in
            if fileTab == .signed {
                return item.isIPA && item.isInSignedDir
            }
            return !item.isIPA || !item.isInSignedDir
        }
    }

    /// IPA 行显示名：解析出的 App 名优先，解析不到回落文件名去后缀。
    private func ipaDisplayName(_ item: LocalFileItem) -> String {
        if let name = fileIPAInfo[item.url.path]?.name, !name.isEmpty {
            return name
        }
        return (item.name as NSString).deletingPathExtension
    }

    /// 这行 IPA 是不是某 App 续签用的源（行内角标 + 详情页同认）：
    /// 路径对上，或包名对上（改名/移过文件夹后路径变了，包名还能认）。
    /// 认进页时读的缓存清单，不每行读盘。
    private func renewalSource(for item: LocalFileItem) -> RenewalSourceEntry? {
        if let hit = renewalSources.first(where: { $0.ipaPath == item.url.path }) { return hit }
        guard item.isIPA else { return nil }
        guard let bundleID = fileIPAInfo[item.url.path]?.bundleID, !bundleID.isEmpty else { return nil }
        return renewalSources.first(where: { $0.bundleID == bundleID })
    }

    /// IPA 行第二行（轻松签文件列表同款）：V版本 | 大小 | Bundle ID；
    /// 版本缺了就省掉 V 那段，解析失败只显示大小，不造假。
    private func ipaSecondLine(_ item: LocalFileItem) -> String {
        let size = ByteCountFormatter.string(fromByteCount: Int64(item.size), countStyle: .file)
        guard let info = fileIPAInfo[item.url.path] else { return size }
        var parts: [String] = []
        if let version = info.version, !version.isEmpty {
            parts.append("V\(version)")
        }
        parts.append(size)
        if !info.bundleID.isEmpty {
            parts.append(info.bundleID)
        }
        return parts.joined(separator: " | ")
    }

    /// IPA 行信息解析（只取可见行，行 .task 触发）：键里带大小 +
    /// 修改时间，文件被覆盖换了就重解析；解析失败也记已尝试，
    /// 不重复读盘。跟证书页未签名栏同例，只解析 Info.plist。
    private func loadFileIPAInfo(for item: LocalFileItem) {
        guard item.isIPA else { return }
        let key = "\(item.url.path)#\(item.size)#\(item.modified?.timeIntervalSince1970 ?? 0)"
        guard !fileIPAInfoTried.contains(key) else { return }
        fileIPAInfoTried.insert(key)
        // 显式捕获（loadFileIcon 同例）：不把整个 item 隐式带进
        // detached 任务，免得 Swift 6 并发检查找麻烦。
        Task.detached(priority: .userInitiated) { [url = item.url, path = item.url.path] in
            guard let info = IPALibrary.appInfo(at: url) else { return }
            await MainActor.run { self.fileIPAInfo[path] = info }
        }
    }

    /// 动作菜单里的分享：系统分享面板（ReportProblemView 同例，
    /// UIActivityViewController + topViewController，iPad 锚点居中）。
    /// present 包一层 main.async：菜单按钮点按时菜单本身正在收起，
    /// 下一轮再 present，免得两个 presented 控制器抢窗口层级。
    private func shareFile(_ item: LocalFileItem) {
        DispatchQueue.main.async {
            let sheet = UIActivityViewController(activityItems: [item.url], applicationActivities: nil)
            guard let top = UIApplication.shared.topViewController else { return }
            sheet.popoverPresentationController?.sourceView = top.view
            sheet.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY,
                                                                     width: 0, height: 0)
            top.present(sheet, animated: true)
        }
    }

    /// 动作菜单里的查看文件位置：切到这行 IPA 所在的切栏 + 文件夹，
    /// 清掉搜索，让这一行在当前视图里直接可见；位置在操作提示里明说。
    /// 触感不另加：切栏变化会触发上面的 fileTab onChange 震一次 .light。
    private func locateFile(_ item: LocalFileItem) {
        fileTab = item.isInSignedDir ? .signed : .unsigned
        currentDir = item.relativeDir
        fileSearchText = ""
        opMessage = L("已定位到：%@", item.relativeDir.isEmpty ? L("根目录") : item.relativeDir)
        opFailed = false
    }

    /// 文件行统一动作集：点行底部菜单与长按菜单共用同一批按钮，
    /// 适用性按行类型裁剪——IPA 全套；非 IPA 文件除签名/安装/提取库
    /// 外都有；文件夹只留重命名/移动/复制/删除。提取库映射到现有的
    /// Mach-O 依赖查看；查看文件位置不另震（切栏变化会震一次）。
    /// useIcons 为真时用 Label + 图标（长按菜单），否则纯文字（底部菜单）。
    @ViewBuilder
    private func fileActionButtons(for item: LocalFileItem, useIcons: Bool) -> some View {
        if item.isIPA {
            Button {
                CZFHaptics.impact(.light)
                workspace.selectedIPA = item.url
                onGoCert()
                actionItem = nil
            } label: {
                if useIcons { Label(L("签名"), systemImage: "checkmark.seal") } else { Text(L("签名")) }
            }
            if item.isInSignedDir {
                Button {
                    CZFHaptics.impact(.light)
                    installSignedFile(item)
                    actionItem = nil
                } label: {
                    if useIcons { Label(L("安装"), systemImage: "square.and.arrow.down") } else { Text(L("安装")) }
                }
            }
            Button {
                CZFHaptics.impact(.light)
                machoItem = item
                actionItem = nil
            } label: {
                if useIcons { Label(L("提取库"), systemImage: "list.bullet.rectangle") } else { Text(L("提取库")) }
            }
        }
        if !item.isDirectory {
            Button {
                CZFHaptics.impact(.light)
                detailItem = item
                actionItem = nil
            } label: {
                if useIcons { Label(L("详情"), systemImage: "info.circle") } else { Text(L("详情")) }
            }
            Button {
                CZFHaptics.impact(.light)
                shareFile(item)
                actionItem = nil
            } label: {
                if useIcons { Label(L("分享"), systemImage: "square.and.arrow.up") } else { Text(L("分享")) }
            }
            Button {
                locateFile(item)
                actionItem = nil
            } label: {
                if useIcons { Label(L("查看文件位置"), systemImage: "magnifyingglass") } else { Text(L("查看文件位置")) }
            }
        }
        Button {
            renameText = item.name
            renameItem = item
            actionItem = nil
        } label: {
            if useIcons { Label(L("重命名"), systemImage: "pencil") } else { Text(L("重命名")) }
        }
        Button {
            moveItem = item
            actionItem = nil
        } label: {
            if useIcons { Label(L("移动"), systemImage: "folder") } else { Text(L("移动")) }
        }
        Button {
            duplicate(item)
            actionItem = nil
        } label: {
            if useIcons { Label(L("复制"), systemImage: "doc.on.doc") } else { Text(L("复制")) }
        }
        if !item.isDirectory {
            Button {
                zipSingle(item)
                actionItem = nil
            } label: {
                if useIcons { Label(L("压缩成 ZIP"), systemImage: "archivebox") } else { Text(L("压缩成 ZIP")) }
            }
            if item.isZip {
                Button {
                    unzip(item)
                    actionItem = nil
                } label: {
                    if useIcons { Label(L("解压"), systemImage: "tray.and.arrow.up") } else { Text(L("解压")) }
                }
            }
        }
        Button(role: .destructive) {
            CZFHaptics.impact(.light)
            pendingDeleteItem = item
            actionItem = nil
        } label: {
            if useIcons { Label(L("删除"), systemImage: "trash") } else { Text(L("删除")) }
        }
    }

    /// 搜索过滤（当前视图）：名字或行上显示的 Bundle ID 含查询串就算，不区分大小写。
    private func matching(_ items: [LocalFileItem]) -> [LocalFileItem] {
        guard !fileSearchText.isEmpty else { return items }
        let query = fileSearchText.lowercased()
        return items.filter {
            $0.name.lowercased().contains(query)
                || (fileIPAInfo[$0.url.path]?.bundleID.lowercased().contains(query) == true)
        }
    }

    /// 当前文件夹的直接子项（文件夹 + 文件同一列表，扫描顺序）。
    private var currentDirItems: [LocalFileItem] {
        sortedFiles(matching(files.filter { $0.relativeDir == currentDir }))
    }

    /// 文件夹的相对路径（进文件夹用）：根目录下的文件夹就是名字，
    /// 深层的就是“父目录/名字”。
    private func folderPath(_ item: LocalFileItem) -> String {
        item.relativeDir.isEmpty ? item.name : "\(item.relativeDir)/\(item.name)"
    }

    /// 当前文件夹的显示名（返回条用）。
    private var currentDirName: String {
        (currentDir as NSString).lastPathComponent
    }

    /// 文件页已签名 IPA 安装：只走轻松签式本地安装（v63 起），
    /// 不碰 Engine/共享「安装」页；记录找得到就用记录里的
    /// 包名/Bundle ID/版本，找不到（手动拷进已签名目录的）就
    /// 现解析 Info.plist（只读 central directory + 单条目，不整
    /// 包解压，主线程也快）——解析不到 Bundle ID 就明说装不了，
    /// 不静默失败、不拿空 Bundle ID 去拼清单。
    private func installSignedFile(_ item: LocalFileItem) {
        if let record = SignedIPAStore.load().first(where: { SignedIPAStore.url(for: $0) == item.url }) {
            startEnterpriseInstall(ipaURL: item.url, record: record)
            return
        }
        startEnterpriseInstall(ipaURL: item.url, record: nil)
    }

    /// 文件页安装日志用的 App 名：记录名优先，现解析次之，文件名兜底；
    /// startEnterpriseInstall 里步骤日志用同款推导。
    private var fileInstallAppName: String? {
        fileInstallRecord?.appName
            ?? fileInstallURL.flatMap { IPALibrary.appInfo(at: $0)?.name }
            ?? fileInstallURL?.deletingPathExtension().lastPathComponent
    }

    /// 文件页安装统一入口（证书页 startEngineInstall 同款）：
    /// 调 Engine 的 runInstallSignedIPA（配对设备链路，v45 那套），
    /// 全程只在文件页内反馈——进行中显示 Engine 进度 +“取消安装”，
    /// 跑完成功弹框，失败快照原因 +“重试安装”。前置检查（配对文件、
    /// 隧道、设备 IP）不过时 Engine 直接返回、isRunning 根本没置位，
    /// 这时就别留着进行中标志，并把原因快照到页内（证书页同款：
    /// 优先用 Engine 的前置向导，向导没变或是上一次跑剩的旧向导时
    /// 给通用提示，不读 lastError——前置失败不置它）。名字只用于
    /// 步骤日志：有记录用记录名，没记录现解析，解析不到就用文件名，
    /// Engine 安装本身不需要 Bundle ID，不再因解析不到而拒装。
    /// 文件页安装跑完写一条「仅安装」日志（kind 有 installOnly 后
    /// 不再会说成“签名并安装”）；前置失败不进日志（与此前一致）。
    private func startEnterpriseInstall(ipaURL: URL, record: SignedIPARecord?) {
        fileInstallRecord = record
        fileInstallURL = ipaURL
        fileInstallErrorText = nil
        let appName = record?.appName
            ?? IPALibrary.appInfo(at: ipaURL)?.name
            ?? ipaURL.deletingPathExtension().lastPathComponent
        // 别的 tab 的安装在跑时不新起（Engine 单管线）：只显错误
        // 文本，不进 runInstallSignedIPA、不记失败。
        guard !engine.isRunning else {
            fileInstallErrorText = L("已有安装在进行，先等当前安装完成再试。")
            return
        }
        let guideBefore = engine.guide
        fileInstallInFlight = true
        localInstall.appendStepLog(L("配对安装开始：%@", appName))
        engine.runInstallSignedIPA(ipaURL: ipaURL)
        if !engine.isRunning {
            fileInstallInFlight = false
            if let guide = engine.guide,
               guide != guideBefore
               || guide == Guides.importPairing || guide == Guides.vpn
               || guide == Guides.deviceIPMismatch {
                fileInstallErrorText = ([guide.title] + guide.steps).joined(separator: "\n")
            } else {
                fileInstallErrorText = L("配对安装没能启动：请检查配对文件与隧道是否就绪，或去「安装」页看日志。")
            }
            localInstall.appendStepLog(L("配对安装失败：%@", fileInstallErrorText ?? ""))
        }
    }

    /// 文件页配对安装状态：只在文件页内显示，不碰共享「安装」页。
    /// 进行中显示 Engine 进度 +“取消安装”（调 Engine 的
    /// cancelOneClick，中止 pipelineTask；取消后 isRunning 落下触发
    /// onChange 清 inFlight，取消不算成功也不记失败）；失败时显示
    /// 快照的原因 +“重试安装”（原因来自 startEnterpriseInstall /
    /// onChange 的快照，不直接读 engine 的全局 lastError，免得别的
    /// 页的失败串到这里）。进行中只认 fileInstallInFlight（ID 线
    /// 的安装跑起来时这里不跟着亮，免得串台）。
    @ViewBuilder
    private var fileInstallStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            if fileInstallInFlight {
                HStack(spacing: 8) {
                    if engine.installProgress > 0 {
                        Text(L("配对安装进行中（%d%%）", Int(engine.installProgress * 100)))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(L("配对安装进行中"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(L("取消安装")) { CZFHaptics.impact(.light); engine.cancelOneClick() }
                    .font(.footnote)
                }
            } else if let error = fileInstallErrorText {
                HStack(spacing: 8) {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                    Spacer()
                    if let record = fileInstallRecord {
                        Button(L("重试安装")) { CZFHaptics.impact(.light); startEnterpriseInstall(ipaURL: SignedIPAStore.url(for: record), record: record) }
                            .font(.footnote)
                    } else if let url = fileInstallURL {
                        Button(L("重试安装")) { CZFHaptics.impact(.light); startEnterpriseInstall(ipaURL: url, record: nil) }
                            .font(.footnote)
                    }
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header.cascadeItem(0)
                    if selecting {
                        selectionBar.cascadeItem(2)
                    }
                    // 轻松签文件列表式切栏（只过滤 IPA 行）：放搜索框上面，
                    // 跟证书页应用库切栏同例，segmented 样式。
                    Picker("", selection: $fileTab) {
                        Text(L("未签名 (%d)", unsignedCount)).tag(FileListTab.unsigned)
                        Text(L("已签名 (%d)", signedCount)).tag(FileListTab.signed)
                    }
                    .pickerStyle(.segmented)
                    // 切栏触感：点切栏、或菜单“查看文件位置”切栏变化时
                    // 各震一次 .light；后者菜单按钮本身不另震，免得一次点按震两次。
                    .onChange(of: fileTab) { _, _ in CZFHaptics.impact(.light) }
                    fileSearchBar
                    // 排序：只改显示顺序（IPA 列表、文件夹内列表、其他文件
                    // 组都按同一规则排）；默认保持扫描顺序，不动老习惯。
                    HStack {
                        Menu {
                            ForEach(FileSort.allCases, id: \.self) { option in
                                Button {
                                    fileSortRaw = option.rawValue
                                } label: {
                                    if fileSort == option {
                                        Label(option.label, systemImage: "checkmark")
                                    } else {
                                        Text(option.label)
                                    }
                                }
                            }
                        } label: {
                            Label(L("排序：%@", fileSort.label), systemImage: "arrow.up.arrow.down")
                                .font(.footnote.weight(.semibold))
                        }
                        Spacer()
                    }
                    if !currentDir.isEmpty {
                        currentDirBar
                        if currentDirItems.isEmpty {
                            emptyCard.cascadeItem(2)
                        } else if visibleDirItems.isEmpty {
                            Text(L("没有匹配的 IPA。"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            folderSection(items: visibleDirItems).cascadeItem(2)
                        }
                    } else if files.isEmpty {
                        emptyCard.cascadeItem(2)
                    } else {
                        // IPA 行不再单开「IPA 文件」组：切栏 + 搜索过滤
                        // 后的 ipaList 就是全部 IPA（轻松签文件列表式，
                        // 无卡片头）；其他文件、系统文件不再分组头，合并为
                        // 扁平列表（过滤逻辑不动）。
                        ipaList.cascadeItem(2)
                        if fileTab == .unsigned {
                            let flatFiles = sortedFiles(matching(others) + matching(systemFiles))
                            if !flatFiles.isEmpty {
                                PanelCard {
                                    VStack(alignment: .leading, spacing: 12) {
                                        ForEach(flatFiles) { item in
                                            fileRow(item)
                                            if item.id != flatFiles.last?.id {
                                                Divider()
                                            }
                                        }
                                    }
                                }
                                .cascadeItem(3)
                            }
                        }
                    }
                    // 页尾（原来顶栏区的安装状态、导入卡、计数都到这里）：
                    // 安装状态平时不显示，安装进行中/失败时才出现。
                    fileInstallStatus
                    importCard.cascadeItem(5)
                    Text(L("%d 个文件 · %@", files.count,
                           ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding([.horizontal, .top], 20)
                .padding(.bottom, 20)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(AppBackground())
        }
        .onAppear {
            files = AppFileLibrary.scan()
            renewalSources = RenewalSourceStore.load()
        }
        // 配对安装跑完：finished 置位才算成功（取消不算）。只认
        // fileInstallInFlight 期间的变化，ID 线的安装跑完不会误弹
        // 到这里；失败原因快照到页内本地量，不直接绑 engine 的
        // 全局量。文件页安装跑完写一条「仅安装」日志（见 startEnterpriseInstall）。
        .onChange(of: engine.isRunning) { old, new in
            if old && !new && fileInstallInFlight {
                fileInstallInFlight = false
                if engine.finished {
                    showingFileInstallSuccessAlert = true
                    localInstall.appendStepLog(L("配对安装完成"))
                    CZFHaptics.notification(.success)
                    if let appName = fileInstallAppName {
                        CertSignLogStore.append(CertSignLogEntry(id: UUID(), date: Date(),
                            appName: appName, kind: .installOnly, success: true,
                            detail: L("配对安装完成。")))
                    }
                } else if let error = engine.lastError {
                    fileInstallErrorText = error
                    localInstall.appendStepLog(L("配对安装失败：%@", error))
                    CZFHaptics.notification(.error)
                    if let appName = fileInstallAppName {
                        CertSignLogStore.append(CertSignLogEntry(id: UUID(), date: Date(),
                            appName: appName, kind: .installOnly, success: false,
                            detail: error))
                    }
                }
            }
        }
        .alert(L("安装完成"), isPresented: $showingFileInstallSuccessAlert) {
            Button(L("知道了"), role: .cancel) {}
        } message: {
            Text(L("装好了，可以回桌面查看安装进度。"))
        }
        // 单删确认：沙盒删除不进废纸篓，IPA 很可能是唯一一份。
        .alert(L("删除“%@”？", pendingDeleteItem?.name ?? ""), isPresented: Binding(
            get: { pendingDeleteItem != nil },
            set: { if !$0 { pendingDeleteItem = nil } }
        )) {
            Button(L("删除"), role: .destructive) {
                if let item = pendingDeleteItem { delete(item) }
                pendingDeleteItem = nil
            }
            Button(L("取消"), role: .cancel) { pendingDeleteItem = nil }
        } message: {
            if let item = pendingDeleteItem, let warning = renewalDeleteWarning(for: item) {
                Text(warning)
            } else {
                Text(L("删除后无法恢复"))
            }
        }
        // 批量删确认，带数量。
        .alert(L("删除所选 %d 个？", selection.count), isPresented: $pendingDeleteSelection) {
            Button(L("删除"), role: .destructive) {
                pendingDeleteSelection = false
                deleteSelection()
            }
            Button(L("取消"), role: .cancel) { pendingDeleteSelection = false }
        } message: {
            if let warning = renewalDeleteWarning(forSelection: selection) {
                Text(warning)
            } else {
                Text(L("删除后无法恢复"))
            }
        }
        // 点行弹出的底部动作菜单：与长按菜单同一动作集（见 fileActionButtons），
        // 适用性按行类型裁剪；查看文件位置切到该行所在的切栏 + 文件夹
        // 并清搜索，让行直接可见。
        .confirmationDialog("", isPresented: Binding(
            get: { actionItem != nil },
            set: { if !$0 { actionItem = nil } }
        )) {
            if let item = actionItem {
                fileActionButtons(for: item, useIcons: false)
            }
            Button(L("取消"), role: .cancel) {
                actionItem = nil
            }
        }
        .alert(L("重命名"), isPresented: Binding(
            get: { renameItem != nil },
            set: { if !$0 { renameItem = nil } }
        )) {
            TextField(L("文件名"), text: $renameText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button(L("取消"), role: .cancel) { renameItem = nil }
            Button(L("保存")) { performRename() }
        } message: {
            Text(L("扩展名别改错，不然文件可能打不开。"))
        }
        .alert(L("新建文件夹"), isPresented: $showNewFolderAlert) {
            TextField(L("请输入文件夹名字"), text: $newFolderName)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button(L("取消"), role: .cancel) { showNewFolderAlert = false }
            Button(L("创建")) {
                showNewFolderAlert = false
                createFolder()
            }
        }
        .sheet(item: $machoItem) { item in
            MachOView(url: item.url, fileName: item.name)
        }
        .sheet(item: $detailItem) { item in
            FileDetailSheet(item: item, renewalAppName: renewalSource(for: item)?.appName, onDelete: {
                detailItem = nil
                pendingDeleteItem = item
            }, onRename: {
                detailItem = nil
                renameText = item.name
                renameItem = item
            }, onMove: {
                detailItem = nil
                moveItem = item
            }, onDuplicate: {
                detailItem = nil
                duplicate(item)
            })
        }
        .sheet(item: $moveItem) { item in
            moveSheetContent(item: item)
        }
        .sheet(isPresented: $showImporter) {
            FileImporterRepresentableView(
                allowedContentTypes: [.item],
                allowsMultipleSelection: true
            ) { urls in
                for url in urls {
                    do {
                        _ = try AppFileLibrary.importIntoDocuments(url)
                        importError = nil
                    } catch {
                        importError = L("导入失败：%@", error.localizedDescription)
                    }
                }
                files = AppFileLibrary.scan()
            }
        }
    }

    /// 文件页顶栏：只留标题 + 切栏 + 搜索（轻松签文件列表式紧凑顶栏）；
    /// 原来的大标题计数、导入卡、安装状态、操作行都移到页尾或 ••• 菜单里。
    private var header: some View {
        HStack(alignment: .top) {
            Text(L("文件"))
                .font(.largeTitle.weight(.bold))
            Spacer()
            Menu {
                Button { showImporter = true } label: {
                    Label(L("导入文件"), systemImage: "square.and.arrow.down")
                }
                Button {
                    newFolderName = ""
                    showNewFolderAlert = true
                } label: {
                    Label(L("新建文件夹"), systemImage: "folder.badge.plus")
                }
                Button {
                    files = AppFileLibrary.scan()
                    resetCurrentDirIfNeeded()
                } label: {
                    Label(L("刷新"), systemImage: "arrow.clockwise")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            if !files.isEmpty {
                Button {
                    selecting.toggle()
                    selection = []
                } label: {
                    Text(selecting ? L("完成") : L("选择"))
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    /// 多选时的操作条：压缩成一个 zip / 批量删除。
    private var selectionBar: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(L("已选 %d 个", selection.count))
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 10) {
                    Button {
                        zipSelection()
                    } label: {
                        HStack {
                            if opBusy { ProgressView() }
                            Text(L("压缩成 ZIP"))
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(selection.isEmpty || opBusy)
                    Button(role: .destructive) {
                        pendingDeleteSelection = true
                    } label: {
                        Text(L("删除所选"))
                    }
                    .buttonStyle(.bordered)
                    .disabled(selection.isEmpty || opBusy)
                }
            }
        }
    }

    private var importCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .foregroundStyle(.secondary)
                    Text(L("文件管理"))
                        .font(.headline)
                }
                Text(L("这里是 App 自己的文件目录：下载的、导入的、已签名的 IPA 都在这。也可以在「文件」App 里往 SideInstaller 的目录放文件，回到这里就能看到。"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    showImporter = true
                } label: {
                    Text(L("导入文件"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                if let importError {
                    Text(importError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                if opBusy {
                    HStack(spacing: 6) {
                        ProgressView()
                        Text(L("处理中…"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if let opMessage {
                    Text(opMessage)
                        .font(.footnote)
                        .foregroundStyle(opFailed ? .red : .green)
                }
                Divider()
                lanSection
            }
        }
    }

    /// 局域网传输开关：开着时同 Wi-Fi 的浏览器能管理这个目录。
    private var lanSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "wifi")
                    .foregroundStyle(.secondary)
                Text(L("局域网传输"))
                    .font(.headline)
            }
            if lanServer.isRunning {
                Text(L("电脑和手机连同一个 Wi-Fi，浏览器打开这个地址就能上传、下载、删除这里的文件："))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    UIPasteboard.general.string = lanServer.addressText
                    withAnimation { lanCopied = true }
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        withAnimation { lanCopied = false }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(lanServer.addressText)
                            .font(.footnote.monospaced().weight(.semibold))
                        Image(systemName: lanCopied ? "checkmark" : "doc.on.doc")
                            .font(.footnote)
                            .foregroundStyle(lanCopied ? Color.green : Color.secondary)
                        if lanCopied {
                            Text(L("已复制"))
                                .font(.footnote)
                                .foregroundStyle(.green)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button(role: .destructive) {
                    lanServer.stop()
                } label: {
                    Text(L("关闭局域网传输"))
                        .font(.footnote)
                }
            } else {
                Text(L("开启后，同一 Wi-Fi 下的电脑打开网页就能往这里传文件，不用数据线。关掉就停，只在本机开着时有效。"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    lanServer.start()
                } label: {
                    Text(L("开启局域网传输"))
                        .font(.footnote)
                }
                if let error = lanServer.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var emptyCard: some View {
        PanelCard {
            Text(L("还没有文件。点上面「导入文件」放 IPA 进来，或在安装页下载/导入后这里会出现。"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    /// 文件页顶部搜索条（轻松签文件列表同款浅灰搜索框）：
    /// 按名字过滤当前视图（根目录各组、或当前文件夹内）。
    private var fileSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(L("搜索"), text: $fileSearchText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .multilineTextAlignment(.center)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.12))
        .cornerRadius(8)
    }

    /// 当前文件夹返回条：点回上级（根目录就回文件组）。
    private var currentDirBar: some View {
        PanelCard {
            HStack(spacing: 8) {
                Button {
                    currentDir = (currentDir as NSString).deletingLastPathComponent
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text(L("返回"))
                    }
                    .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.plain)
                Text(currentDirName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(L("%d 项", currentDirItems.count))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 当前文件夹内的直接子项（文件夹 + 文件同一列表，轻松签式）：
    /// 行格式跟根目录 fileRow 一模一样，不另起一套。
    private func folderSection(items: [LocalFileItem]) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(items) { item in
                    fileRow(item)
                    if item.id != items.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    /// 轻松签文件列表式 IPA 列表（切栏 + 搜索过滤后）：行格式见
    /// fileRow 的 IPA 分支（图标 + 名 + 版本|大小|Bundle ID + 文件名），
    /// 点行弹底部动作菜单；空态按切栏/搜索区分文案，不空白。
    /// 无卡片头（参考图里列表就是平铺的），跟其他文件组区分开。
    private var ipaList: some View {
        VStack(alignment: .leading, spacing: 12) {
            if filteredIPAs.isEmpty {
                Text(fileSearchText.isEmpty
                     ? (fileTab == .unsigned ? L("还没有未签名的 IPA。") : L("还没有已签名的 IPA。"))
                     : L("没有匹配的 IPA。"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filteredIPAs) { item in
                    fileRow(item)
                    if item.id != filteredIPAs.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    /// 轻松签文件列表式第二行：文件夹是“n 项”，文件是“大小  时间”。
    private func fileSecondLine(_ item: LocalFileItem) -> String {
        if item.isDirectory {
            return L("%d 项", item.childCount)
        }
        let size = ByteCountFormatter.string(fromByteCount: Int64(item.size), countStyle: .file)
        guard let modified = item.modified else { return size }
        return "\(size)  \(fileTimeText(modified))"
    }

    /// 今天显示时间（14:38:19），以前的显示日期（2026/10/27），轻松签同款。
    private func fileTimeText(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .standard)
        }
        return date.formatted(date: .numeric, time: .omitted)
    }

    /// 文件行图标：IPA 真图 / 文件夹蓝标 / 其他灰标，三路不同
    /// View 类型，函数前必须加 @ViewBuilder（AGENTS.md 血泪）。
    /// 真图 52×52 圆角填满；系统标放 52×52 框里居中，行高对齐。
    @ViewBuilder
    private func fileIcon(for item: LocalFileItem) -> some View {
        if item.isDirectory {
            Image(systemName: "folder.fill")
                .foregroundStyle(.blue)
                .font(.title3)
                .frame(width: 52, height: 52)
        } else if item.isIPA,
                  let data = fileIcons[item.id],
                  let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            // IPA 还没取到图、取图失败、非 IPA 文件：一律中性占位，
            // 不造假图、不空框（IPA 占位与应用库同款灰色文档标）。
            Image(systemName: "doc")
                .foregroundStyle(.secondary)
                .font(.title3)
                .frame(width: 52, height: 52)
        }
    }

    /// 图标取图键：路径 + 大小 + 修改时间——文件被覆盖换了就重取。
    private func fileIconKey(_ item: LocalFileItem) -> String {
        "\(item.id)#\(item.size)#\(item.modified?.timeIntervalSince1970 ?? 0)"
    }

    /// IPA 行图标解析：复用应用库那套 IPALibrary.iconData（只读
    /// central directory + 单个图标条目，不整包解压），不为文件页
    /// 单开一套；耗时放 Task.detached，取到回主线程写缓存；
    /// Assets.car 独占图标时 iconData 返回 nil，行里显示中性占位。
    private func loadFileIcon(for item: LocalFileItem) {
        guard item.isIPA else { return }
        let key = fileIconKey(item)
        guard !fileIconsTried.contains(key) else { return }
        fileIconsTried.insert(key)
        Task.detached { [url = item.url, id = item.id] in
            guard let data = IPALibrary.iconData(at: url) else { return }
            await MainActor.run { fileIcons[id] = data }
        }
    }

    private func fileRow(_ item: LocalFileItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if selecting {
                    Image(systemName: selection.contains(item.id)
                          ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selection.contains(item.id) ? Color.accentColor : .secondary)
                }
                // 轻松签文件列表式：IPA 有真实图标就显示真图（应用库
                // 同款解析，见 loadFileIcon），没取到就中性占位；
                // 文件夹蓝色、其他文件灰色文档图标。图标区统一
                // 52×52 框，行高对齐，不晃。
                fileIcon(for: item)
                if item.isIPA {
                    // IPA 行三行格式（轻松签文件列表同款）：解析出的
                    // App 名 / V版本 | 大小 | Bundle ID / 文件名。
                    // 行内不再放分享/去签名/安装/删除按钮——点行弹
                    // 底部动作菜单，菜单里全有；右侧ⓘ 点开详情
                    // （与非 IPA 行一致）。
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ipaDisplayName(item))
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(ipaSecondLine(item))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(item.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(2)
                        Text(fileSecondLine(item))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if let source = renewalSource(for: item) {
                    // 续签用的源文件：行内一眼认出，删之前先想想。
                    Text(L("续签"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green, in: Capsule())
                        .accessibilityLabel(L("续签用的文件：%@", source.appName))
                }
                // ⓘ 详情：所有行都有（IPA 行也补上，与非 IPA 行一致）；
                // 文件夹不再另放 chevron，点行就进文件夹。
                Button {
                    detailItem = item
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        // IPA 行图标：行出现时触发一次取图（文件换了就重取，
        // 键里带大小 + 修改时间；取不到也记 tried，不死循环）。
        .task(id: fileIconKey(item)) { loadFileIcon(for: item) }
        // IPA 行信息：行出现时触发一次解析（版本/Bundle ID 用），
        // 非 IPA 行直接跳过（loadFileIPAInfo 里 guard）。
        .task(id: "\(item.url.path)#\(item.size)#\(item.modified?.timeIntervalSince1970 ?? 0)") { loadFileIPAInfo(for: item) }
        .onTapGesture {
            if selecting {
                if selection.contains(item.id) {
                    selection.remove(item.id)
                } else {
                    selection.insert(item.id)
                }
            } else if item.isDirectory {
                // 点文件夹行就进文件夹（轻松签文件列表同款入口，
                // 不藏在详情或长按里）。
                currentDir = folderPath(item)
            } else if item.isIPA {
                // 点 IPA 行弹底部动作菜单（轻松签文件列表同款）。
                actionItem = item
            } else {
                // 非 IPA 文件行点按同样弹底部动作菜单（按文件类型
                // 裁剪后的子集），不再点着没事；长按菜单仍在。
                actionItem = item
            }
        }
        .contextMenu {
            // 与点行底部菜单同一动作集（见 fileActionButtons），
            // 适用性按行类型裁剪；文件夹只留重命名/移动/复制/删除。
            fileActionButtons(for: item, useIcons: true)
        }
    }

    /// 当前文件夹不存在了就回根目录（删/改名/移走当前文件夹后都调，
    /// 免得停在一个不存在的目录里）。
    private func resetCurrentDirIfNeeded() {
        if !currentDir.isEmpty,
           !files.contains(where: { $0.isDirectory && folderPath($0) == currentDir }) {
            currentDir = ""
        }
    }

    /// 从磁盘删掉一项，返回磁盘上是不是真没了（已签名行同时清 Signed 清单记录，
    /// SignedIPAStore.remove 里本来就连文件一起删）。删不掉返回 false，
    /// 调用方写提示，别静默重扫了事。
    private func removeFileFromDisk(_ item: LocalFileItem) -> Bool {
        if item.isInSignedDir,
           let record = SignedIPAStore.load().first(where: { $0.fileName == item.name }) {
            SignedIPAStore.remove(record)
        } else if FileManager.default.fileExists(atPath: item.url.path) {
            do {
                try FileManager.default.removeItem(at: item.url)
            } catch {
                return false
            }
        }
        return !FileManager.default.fileExists(atPath: item.url.path)
    }

    /// 删文件时的续签源提示：这文件是某 App 续签用过的 IPA，删了它
    /// 下次就续不了。按路径认，改名/移过文件夹后按包名认（行上已解
    /// 析的 Bundle ID 优先，取不到就现解析，只读 central directory）。
    private func renewalDeleteWarning(for item: LocalFileItem) -> String? {
        guard item.isIPA else { return nil }
        let info = fileIPAInfo[item.url.path] ?? IPALibrary.appInfo(at: item.url)
        guard let entry = RenewalSourceStore.source(forFileURL: item.url, bundleID: info?.bundleID) else { return nil }
        return L("这是 %@ 续签用的文件，删了它下次就续不了，要重新导入 IPA 才能续。删除后无法恢复", entry.appName)
    }

    /// 批量删里的续签源提示：选中的文件里有续签用过的，就把 App 名列出来。
    private func renewalDeleteWarning(forSelection selected: Set<String>) -> String? {
        let names = files.filter { selected.contains($0.id) && $0.isIPA }
            .compactMap { item -> String? in
                let info = fileIPAInfo[item.url.path] ?? IPALibrary.appInfo(at: item.url)
                return RenewalSourceStore.source(forFileURL: item.url, bundleID: info?.bundleID)?.appName
            }
        guard !names.isEmpty else { return nil }
        return L("其中 %@ 是续签用的文件，删了它们下次就续不了，要重新导入 IPA 才能续。删除后无法恢复", names.joined(separator: "、"))
    }

    /// 单删：磁盘上确认没了才从数组里去掉它（含文件夹子项），
    /// 不用整树重扫；删除没成功（文件还在）就重扫恢复真相，
    /// 别把还在的文件藏掉。
    private func delete(_ item: LocalFileItem) {
        if removeFileFromDisk(item) {
            files.removeAll {
                $0.url.path == item.url.path || $0.url.path.hasPrefix(item.url.path + "/")
            }
            resetCurrentDirIfNeeded()
        } else {
            files = AppFileLibrary.scan()
            resetCurrentDirIfNeeded()
            opMessage = L("删除失败，文件仍在")
            opFailed = true
        }
    }

    /// 在当前目录（根目录或进的文件夹里）新建文件夹（轻松签
    /// 新建文件夹同款）：重名就拒，不覆盖。
    private func createFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !name.contains("/") else { return }
        let root = IPALibrary.documentsDir
        let parent = currentDir.isEmpty ? root : root.appendingPathComponent(currentDir)
        let dest = parent.appendingPathComponent(name)
        guard !FileManager.default.fileExists(atPath: dest.path) else {
            opMessage = L("已有同名文件")
            opFailed = true
            return
        }
        do {
            try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: false)
            files = AppFileLibrary.scan()
            opMessage = L("已创建文件夹 %@", name)
            opFailed = false
        } catch {
            opMessage = error.localizedDescription
            opFailed = true
        }
    }

    /// “移动到” sheet 内容：从 body 抽出来——body 的修饰链太大，
    /// 编译器在 ForEach 那行报 type-check timeout；内容一字未动，
    /// 只是换了个地方放。
    @ViewBuilder
    private func moveSheetContent(item: LocalFileItem) -> some View {
        NavigationStack {
            List {
                if moveDestinations(for: item).isEmpty {
                    Text(L("没有可移动到的文件夹，先新建一个。"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(moveDestinations(for: item), id: \.dir) { dest in
                    Button {
                        moveItem = nil
                        moveItemToFolder(item, dest.dir)
                    } label: {
                        HStack {
                            Image(systemName: dest.dir.isEmpty ? "house" : "folder")
                            Text(dest.name)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(L("移动到"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("取消")) { moveItem = nil }
                }
            }
        }
    }

    /// 移动的目的地（根目录 + 全部文件夹，排除三类：自己当前所在
    /// 目录（移了等于没移）、自己、自己的子文件夹（移进去就丢了）。
    private func moveDestinations(for item: LocalFileItem) -> [(dir: String, name: String)] {
        var out: [(dir: String, name: String)] = []
        if !item.relativeDir.isEmpty {
            out.append(("", L("根目录")))
        }
        let selfPath = item.isDirectory ? folderPath(item) : nil
        for folder in files.filter({ $0.isDirectory }) {
            let path = folderPath(folder)
            if path == item.relativeDir { continue }
            if let selfPath, (path == selfPath || path.hasPrefix(selfPath + "/")) { continue }
            out.append((path, path))
        }
        return out
    }

    /// 把文件/文件夹移到目标目录（轻松签移动文件同款）：同名就拒，
    /// 移完重扫 + 当前目录复位；已签名 IPA 移出 Signed 目录时，
    /// 清单下次 load 会自动滤掉无文件记录，不用这里手动删。
    private func moveItemToFolder(_ item: LocalFileItem, _ destDir: String) {
        let root = IPALibrary.documentsDir
        let parent = destDir.isEmpty ? root : root.appendingPathComponent(destDir)
        let dest = parent.appendingPathComponent(item.name)
        guard !FileManager.default.fileExists(atPath: dest.path) else {
            opMessage = L("目标文件夹里已有同名文件")
            opFailed = true
            return
        }
        do {
            try FileManager.default.moveItem(at: item.url, to: dest)
            files = AppFileLibrary.scan()
            resetCurrentDirIfNeeded()
            opMessage = L("已移动到 %@", destDir.isEmpty ? L("根目录") : destDir)
            opFailed = false
        } catch {
            opMessage = error.localizedDescription
            opFailed = true
        }
    }

    /// 复制文件/文件夹（轻松签复制同款）：同目录下起不重名的新名字，
    /// 文件夹整目录拷；已签名 IPA 的副本只是文件，不自动进已签名
    /// 清单（清单是记录制，跟手动拷进 Signed 目录同例）。
    private func duplicate(_ item: LocalFileItem) {
        let stem = item.url.deletingPathExtension().lastPathComponent
        let dest = uniqueSibling(of: item, stem: stem, ext: item.url.pathExtension)
        do {
            try FileManager.default.copyItem(at: item.url, to: dest)
            files = AppFileLibrary.scan()
            opMessage = L("已复制为 %@", dest.lastPathComponent)
            opFailed = false
        } catch {
            opMessage = error.localizedDescription
            opFailed = true
        }
    }

    /// 批量删：先删完所有项，最后只扫一次（原来每项各扫一次，
    /// 删 N 个就是 N 次整树枚举，全在主线程）。
    private func deleteSelection() {
        var failed = 0
        for item in files where selection.contains(item.id) {
            if !removeFileFromDisk(item) { failed += 1 }
        }
        selection = []
        selecting = false
        files = AppFileLibrary.scan()
        resetCurrentDirIfNeeded()
        if failed > 0 {
            opMessage = L("有 %d 个文件删除失败", failed)
            opFailed = true
        }
    }

    /// 在同目录里找一个不重名的目标 URL。
    private func uniqueSibling(of item: LocalFileItem, stem: String, ext: String) -> URL {
        let dir = item.url.deletingLastPathComponent()
        var candidate = dir.appendingPathComponent(ext.isEmpty ? stem : "\(stem).\(ext)")
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            let name = ext.isEmpty ? "\(stem) \(counter)" : "\(stem) \(counter).\(ext)"
            candidate = dir.appendingPathComponent(name)
            counter += 1
        }
        return candidate
    }

    private func performRename() {
        guard let item = renameItem else { return }
        renameItem = nil
        var newName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != item.name,
              !newName.contains("/") else { return }
        // 已签 IPA 改名去后缀后，证书页清单仍留一条幽灵记录
        // （点安装必失败）：IPA 文件改名没写 .ipa 就补上。
        if !item.isDirectory, item.url.pathExtension.lowercased() == "ipa",
           !newName.lowercased().hasSuffix(".ipa") {
            newName += ".ipa"
        }
        // 补后缀后跟原名相同（“X.ipa”改“X”）就是没改，直接返回。
        guard newName != item.name else { return }
        let dest = item.url.deletingLastPathComponent().appendingPathComponent(newName)
        guard !FileManager.default.fileExists(atPath: dest.path) else {
            opMessage = L("已有同名文件")
            opFailed = true
            return
        }
        do {
            try FileManager.default.moveItem(at: item.url, to: dest)
            if item.isInSignedDir {
                SignedIPAStore.renameFile(from: item.name, to: newName)
            }
            if !item.isDirectory, let idx = files.firstIndex(where: { $0.id == item.id }) {
                // 文件改名只换这一行的 url/name（同目录，大小/日期/
                // 相对目录都不变），不用整树重扫；文件夹改名会动
                // 全部子项路径，仍走重扫。
                let old = files[idx]
                files[idx] = LocalFileItem(url: dest, name: newName, relativeDir: old.relativeDir,
                                           size: old.size, modified: old.modified,
                                           isDirectory: old.isDirectory, childCount: old.childCount)
            } else {
                files = AppFileLibrary.scan()
            }
            resetCurrentDirIfNeeded()
            opMessage = L("已改名")
            opFailed = false
        } catch {
            opMessage = error.localizedDescription
            opFailed = true
        }
    }

    private func zipSingle(_ item: LocalFileItem) {
        let out = uniqueSibling(of: item, stem: item.url.deletingPathExtension().lastPathComponent, ext: "zip")
        runZip(paths: [item.url], out: out)
    }

    private func zipSelection() {
        // 只打包文件：文件夹以前根本不在列表里，Rust 压包接不接
        // 目录项没验证过，别在这里新开行为，选了文件夹就跳过它。
        let items = files.filter { selection.contains($0.id) && !$0.isDirectory }
        guard !items.isEmpty else {
            // 选的全是文件夹、或什么都没选：原来静默 return，
            // 点了跟没点一样。给一句提示，别让用户干等。
            let hasFolders = files.contains { selection.contains($0.id) && $0.isDirectory }
            opMessage = hasFolders ? L("文件夹不参与打包") : L("请先选择要打包的文件")
            opFailed = false
            return
        }
        let root = IPALibrary.documentsDir
        var out = root.appendingPathComponent("打包.zip")
        var counter = 2
        while FileManager.default.fileExists(atPath: out.path) {
            out = root.appendingPathComponent("打包 \(counter).zip")
            counter += 1
        }
        runZip(paths: items.map { $0.url }, out: out)
        selection = []
        selecting = false
    }

    private func runZip(paths: [URL], out: URL) {
        opBusy = true
        opMessage = nil
        Task {
            let error = await Task.detached {
                FileZipTool.zip(paths: paths, to: out)
            }.value
            opBusy = false
            files = AppFileLibrary.scan()
            if let error {
                opMessage = error
                opFailed = true
            } else {
                opMessage = L("已压缩到 %@", out.lastPathComponent)
                opFailed = false
            }
        }
    }

    private func unzip(_ item: LocalFileItem) {
        let stem = item.url.deletingPathExtension().lastPathComponent
        let dest = uniqueSibling(of: item, stem: "\(stem)-解压", ext: "")
        opBusy = true
        opMessage = nil
        Task {
            let error = await Task.detached {
                FileZipTool.unzip(archive: item.url, to: dest)
            }.value
            opBusy = false
            files = AppFileLibrary.scan()
            if let error {
                opMessage = error
                opFailed = true
            } else {
                opMessage = L("已解压到 %@", dest.lastPathComponent)
                opFailed = false
            }
        }
    }
}

/// 文件页 IPA 切栏：未签名 / 已签名（轻松签文件列表同款）。
private enum FileListTab: Hashable {
    case unsigned
    case signed
}

/// 文件详情（轻松签文件列表右边的 ⓘ）：名字、大小、修改时间、路径，
/// 下面是操作（分享只对文件，文件夹是重命名/移动/复制/删除，
/// 跟行内菜单同例）。
/// 文件夹没有字节大小可言，大小那行显示“共 n 项”。
private struct FileDetailSheet: View {
    let item: LocalFileItem
    /// 是续签源时传 App 名（nil = 不是续签用的文件）。
    var renewalAppName: String? = nil
    var onDelete: () -> Void
    var onRename: () -> Void
    var onMove: () -> Void
    var onDuplicate: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                detailRow(L("名字"), item.name)
                detailRow(L("大小"), item.isDirectory
                          ? L("%d 项", item.childCount)
                          : ByteCountFormatter.string(fromByteCount: Int64(item.size), countStyle: .file))
                detailRow(L("修改时间"), item.modified?.formatted(date: .abbreviated, time: .standard) ?? L("未知"))
                detailRow(L("路径"), item.url.path)
                if let renewalAppName {
                    detailRow(L("续签用的应用"), renewalAppName)
                }
                Section {
                    if !item.isDirectory {
                        ShareLink(item: item.url) {
                            Label(L("分享"), systemImage: "square.and.arrow.up")
                        }
                    }
                    Button {
                        onRename()
                    } label: {
                        Label(L("重命名"), systemImage: "pencil")
                    }
                    Button {
                        onMove()
                    } label: {
                        Label(L("移动"), systemImage: "folder")
                    }
                    Button {
                        onDuplicate()
                    } label: {
                        Label(L("复制"), systemImage: "doc.on.doc")
                    }
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label(L("删除"), systemImage: "trash")
                    }
                }
            }
            .navigationTitle(L("详情"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("完成")) { dismiss() }
                }
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
        }
    }
}
