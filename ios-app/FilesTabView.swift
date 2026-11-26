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
            // A-6：相对路径不用 replacingOccurrences 全串扫描——
            // 枚举出的 url 一定以 root.path + "/" 开头，直接按前缀长切。
            let rel = String(url.path.dropFirst(root.path.count + 1))
            let dir = (rel as NSString).deletingLastPathComponent
            items.append(LocalFileItem(
                url: url,
                name: url.lastPathComponent,
                relativeDir: dir == "." ? "" : dir,
                size: values?.fileSize ?? 0,
                modified: values?.contentModificationDate,
                isDirectory: isDirectory,
                childCount: 0))
        }
        // A-6：childCount 不再每目录多一次 listing——枚举时顺带累计：
        // 每个条目的 relativeDir 就是它所属目录的相对路径，计数一次
        // 即得全部目录的直接子项数；枚举器已跳过隐藏项，与旧算法
        // （contentsOfDirectory 后滤掉 . 开头）数出来一致。
        var childCounts: [String: Int] = [:]
        for item in items {
            childCounts[item.relativeDir, default: 0] += 1
        }
        items = items.map { item in
            guard item.isDirectory else { return item }
            let ownRel = item.relativeDir.isEmpty ? item.name : "\(item.relativeDir)/\(item.name)"
            return LocalFileItem(
                url: item.url,
                name: item.name,
                relativeDir: item.relativeDir,
                size: item.size,
                modified: item.modified,
                isDirectory: true,
                childCount: childCounts[ownRel] ?? 0)
        }
        return items.sorted { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) }
    }

    /// 把外部文件拷进 Documents 根目录，重名自动改名，返回落点。
    static func importIntoDocuments(_ source: URL) throws -> URL {
        guard !source.lastPathComponent.hasPrefix(".") else {
            throw EngineError.message(L("名字不能以. 开头"))
        }
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
    /// F-2 (0.9.164): the installed apps, for the IPA row's newer/older tag —
    /// the shared instance RootView already observes, so the tag follows
    /// the device list without another load.
    @ObservedObject private var appsManager = SideloadedAppsManager.shared
    /// IPA 文件行图标已试集合（键 = 路径#大小#修改时间，文件换了就重取，
    /// 不死循环重试）。图标本体在共享 ThumbnailCache 里（A-37-3），
    /// 本页只留一个 iconEpoch：批量写回/清旧图时 +1 触发重绘。
    @State private var fileIconsTried: Set<String> = []
    @State private var iconEpoch = 0
    /// A-5(c)：文件行图标的批量写回（loadFileIcon 攒 50ms 合并一次写回，
    /// 不再每张图各触发一次整页 body 求值；懒建，首次加载时立）。
    @State private var fileIconBatcher: BatchWriteback<String, UIImage>?
    /// Declared so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer
    @EnvironmentObject private var workspace: CertWorkspace

    /// First scan happens in onAppear; starting empty so the list isn't
    /// scanned twice on first appearance.
    @State private var files: [LocalFileItem] = []
    /// B-3：文件列表重扫代际号——每次 refreshFiles 调用 +1 并捕获，
    /// 写回前核对，旧扫描直接丢弃；delete 成功路也 +1，使在途的
    /// 旧扫描失效，已删文件不再被它的写回带回列表。
    @State private var filesRefreshGeneration = 0
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
    /// F2 (0.9.151): batch install — the running Task is the cancel
    /// handle; the index/name of the item now installing is the batch
    /// progress (the per-install progress itself is engine.installProgress,
    /// Install pill 同款，不另起一套）.
    @State private var batchInstallTask: Task<Void, Never>?
    @State private var batchInstallIndex = 0
    @State private var batchInstallTotal = 0
    @State private var batchInstallCurrent: String?
    /// F-1 (0.9.160): the unsigned IPA being imported for Apple ID
    /// install (`installUnsignedFile`); `id` is the file path, same as
    /// the Downloads page's `installingID`.
    @State private var installingFileID: String?
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
    /// A-5(c)：文件行信息的批量写回（loadFileIPAInfo 同款，懒建）。
    @State private var fileInfoBatcher: BatchWriteback<String, IPALibrary.AppInfo>?
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
    /// 通用失败提示（UI-5：由 B-3 的删除失败 alert 泛化而来——页尾 opMessage
    /// 在列表底下，顶部看不到，任何失败都可经这条 alert 可见；
    /// UI-2(b)：opMessage 的 .onChange 里 opFailed == true 时也会把
    /// opMessage 写到这里（不逐个改写各失败写入点）。
    @State private var opErrorMessage: String?
    /// 当前进的文件夹（相对 Documents 的路径，"" = 根目录）：
    /// 点文件夹行就进，返回条回上级；删了当前文件夹就回根目录。
    @State private var currentDir = ""
    /// 新建文件夹：名字输入（alert 里填）+ 是否弹出。
    @State private var newFolderName = ""
    @State private var showNewFolderAlert = false
    /// 要移动的文件/文件夹（sheet 的 item，nil 就不弹）。
    @State private var moveItem: LocalFileItem?
    /// F4 (0.9.154): the batch-move sheet, shown from the selection bar
    /// (the single-move sheet above is per file, via `moveItem`).
    @State private var showMoveSelectionSheet = false
    @StateObject private var lanServer = LANTransferServer()
    /// 文件页已签名安装：走 Engine 配对链路（v68 回退，证书页
    /// startEngineInstall 同款）。进行中标志 + 完成弹框（inFlight
    /// 隔离：结果判定只看 fileInstallInFlight 期间 engine.isRunning
    /// 的变化，ID 线的安装跑完不会误弹到这里）；重试用的记录/
    /// 文件地址（装时记下）；失败原因快照（证书页同款，不直接
    /// 读 engine 的全局 lastError，免得别的页的失败串到这里）。
    @State private var fileInstallInFlight = false
    /// 文件页这次安装的归属凭证（证书页 enterpriseInstallRunID 同款）：
    /// 起跑时快照 engine.installSessionID，结束时只认同一会话；对不上
    /// 说明这段“进行中”是别的安装的，不记日志、不弹框。
    @State private var fileInstallRunID: UUID?
    @State private var showingFileInstallSuccessAlert = false
    @State private var fileInstallRecord: SignedIPARecord?
    @State private var fileInstallURL: URL?
    @State private var fileInstallErrorText: String?
    /// 已签名行安装方式选择（OTA 0.9.104）：点行先选“配对安装”还是
    /// “流量安装（OTA）”，再走对应入口；选择记录只当对话框锚点。
    @State private var installChoiceRecord: SignedIPARecord?
    /// 流量安装（OTA）表单：记录 + 已生成的 manifest 地址；置位即弹 sheet。
    @State private var otaRecord: SignedIPARecord?
    @State private var otaManifestURL: URL?
    /// itms 链接已拉起：表单内改显示信任引导，不再显示上传步骤。
    @State private var otaLaunched = false
    /// 局域网地址点按复制后的短暂「已复制」提示。
    @State private var lanCopied = false

    /// U-UI：应用库段（原证书页的应用库，0.9.102 搬入文件页）。
    @State private var libraryTab = CertLibraryTab.unsigned
    @State private var librarySearchText = ""
    @State private var unsignedIPAs: [LocalFileItem] = []
    /// B-3：未签名列表重扫代际号（与 filesRefreshGeneration 各管各路）——
    /// 每次 refreshUnsignedIPAs 调用 +1 并捕获，写回前核对，旧扫描
    /// 直接丢弃，连带 onRefreshed 的选中裁剪也不按旧列表跑。
    @State private var unsignedIPAsRefreshGeneration = 0
    /// 未签名栏的 IPA 信息缓存（路径 → Info.plist 解析结果），只解析一次。
    @State private var unsignedInfo: [String: IPALibrary.AppInfo] = [:]
    /// 已经试过的路径（含解析失败），避免重复读盘。
    @State private var unsignedInfoTried: Set<String> = []
    /// 应用库图标已尝试集合（存“路径#指纹”，文件变了就换 key 重取，
    /// 不沿用旧图）。图标本体在共享 ThumbnailCache 里（A-37-3），
    /// 重绘由 iconEpoch（见文件行图标处）触发。加载是行内 .task 触发
    /// （只取可见行），不在列表刷新时批量跑。
    @State private var unsignedIconsTried: Set<String> = []
    @State private var signedIconsTried: Set<String> = []
    /// A-5(c)：应用库图标的批量写回（loadLibraryIcon 同款，已签名 /
    /// 未签名各一台，懒建）。
    @State private var librarySignedIconBatcher: BatchWriteback<String, UIImage>?
    @State private var libraryUnsignedIconBatcher: BatchWriteback<String, UIImage>?
    @State private var signedRecords = SignedIPAStore.load()
    @State private var selectingSigned = false
    @State private var selectedSignedIDs: Set<String> = []
    @State private var recordPendingDelete: SignedIPARecord?
    @State private var showingDeleteConfirm = false
    @State private var showingBatchDeleteConfirm = false
    // 批量签名（未签名栏）：只签名不安装，跟多开同理。
    @State private var batchingUnsigned = false
    @State private var selectedUnsignedIDs: Set<String> = []
    @State private var batchMessage: String?
    @State private var batchFailed = false
    // 批量签名警告确认：掉签/未脱壳先汇总弹一次，点继续才签。
    @State private var pendingBatchWarnings: [String] = []
    @State private var pendingBatchTargets: [LocalFileItem] = []
    @State private var pendingBatchMods = CertSignMods()
    @State private var showingBatchWarningAlert = false
    // 签名日志（应用库「记录」栏）。
    @State private var logEntries: [CertSignLogEntry] = []
    @State private var showingLogClearConfirm = false
    /// U-UI：应用库段自己的导入 picker（与 EnterpriseCertView 的同名 @State 各管各的）。
    @State private var showIPAPicker = false
    /// U-UI：批量签名前的吊销状态缓存（签名段那份在 EnterpriseCertView）。
    @State private var revocationStatus: CertRevocationStatus = .unknown
    @State private var revocationChecking = false
    @State private var revocationCheckedAt: Date?
    /// U-UI：文件页顶部分段——文件列表 / 应用文件夹库。
    private enum FileViewTab { case files, library }
    @State private var fileView = FileViewTab.files

    /// A-38-A5：一次遍历同时产出六个派生值——原来 ipas/others/systemFiles/
    /// totalSize/ipaCounts 各是 files 的一遍 filter/reduce，每 body 求值
    /// 多遍遍历；现在一次 for 循环全产出。每次求值现算的纯派生，不缓存
    /// （@State 新增 0）。注意 systemFiles 不排 IPA：原 `files.filter
    /// { $0.isSystem }` 里 IPA 与系统文件可重叠，语义一字不动。
    private struct FilePartition {
        var ipas: [LocalFileItem] = []
        var others: [LocalFileItem] = []
        var systemFiles: [LocalFileItem] = []
        var totalSize: Int = 0
        var unsigned: Int = 0
        var signed: Int = 0
    }
    private var filePartition: FilePartition {
        var p = FilePartition()
        for item in files {
            p.totalSize += item.size
            if item.isIPA {
                p.ipas.append(item)
                if item.isInSignedDir { p.signed += 1 } else { p.unsigned += 1 }
            } else if !item.isSystem {
                p.others.append(item)
            }
            if item.isSystem { p.systemFiles.append(item) }
        }
        return p
    }

    /// 下面的五个派生值都是 filePartition 的委托——单点访问仍跑一遍
    /// 单遍遍历（与原来一遍 filter 同价）；body 内取一次 partition
    /// 传进各行构建函数，才真正只遍历一次。
    private var ipas: [LocalFileItem] { filePartition.ipas }
    private var others: [LocalFileItem] { filePartition.others }
    private var systemFiles: [LocalFileItem] { filePartition.systemFiles }
    private var totalSize: Int { filePartition.totalSize }

    /// 切栏计数：未签名/已签名 IPA 各多少（搜索不影响切栏总数）。
    private var ipaCounts: (unsigned: Int, signed: Int) {
        let p = filePartition
        return (p.unsigned, p.signed)
    }
    private var unsignedCount: Int { ipaCounts.unsigned }
    private var signedCount: Int { ipaCounts.signed }

    /// 文件列表排序：默认扫描顺序 / 名称 / 大小（大在前）/ 最新
    /// （修改时间晚在前）。只改显示顺序，不动磁盘顺序。
    private enum FileSort: String, CaseIterable {
        case `default`, name, size, newest
        var label: String {
            switch self {
            case .default: return L("默认")
            case .name: return L("Name")
            case .size: return L("Size")
            case .newest: return L("Latest")
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

    /// 切栏 + 搜索过滤后的 IPA 列表（根目录视图用，递归扫描的全量）——
    /// A-38-A5：接受 body-local 的 partition，不再自己读 ipas 派生。
    private func filteredIPAs(partition: FilePartition) -> [LocalFileItem] {
        sortedFiles(matching(partition.ipas).filter { fileTabMatches($0) })
    }

    /// 当前文件夹视图里切栏过滤后的可见项：未签名 tab 显示未签名 IPA
    /// + 其他文件 + 系统文件；已签名 tab 只显示已签名 IPA（其他文件、
    /// 系统文件与文件夹内的非 IPA 行一律不显示）。
    /// A-38-A5：接受 body-local 的当前文件夹项，body 内只调一次；不取
    /// partition——它的输入是 currentDirItems（按文件夹过滤），partition
    /// 的六元组里没有文件夹维度的切分。
    private func visibleDirItems(in items: [LocalFileItem]) -> [LocalFileItem] {
        items.filter { item in
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

    /// A-38-A5：续签源字典版——body 内行构建走字典查表，匹配语义与
    /// renewalSource(for:) 一字不动（路径优先、包名兜底、非 IPA 不查
    /// 包名）。本体保留给非 body 调用方（renewalDeleteWarning 等）。
    private func renewalSource(for item: LocalFileItem,
                               byPath: [String: RenewalSourceEntry],
                               byBundleID: [String: RenewalSourceEntry]) -> RenewalSourceEntry? {
        if let hit = byPath[item.url.path] { return hit }
        guard item.isIPA else { return nil }
        guard let bundleID = fileIPAInfo[item.url.path]?.bundleID, !bundleID.isEmpty else { return nil }
        return byBundleID[bundleID]
    }

    /// IPA 行第二行（轻松签文件列表同款）：V版本 | 大小 | Bundle ID；
    /// 版本缺了就省掉 V 那段，解析失败只显示大小，不造假。
    private func ipaSecondLine(_ item: LocalFileItem) -> String {
        let size = CZFFormattedSize.size(item.size)
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

    /// F-2 (0.9.164): the installed-version comparison tag for an IPA row
    /// (Downloads page 同款): the parsed info the row already loaded
    /// decides the file's version; no info yet means no tag, not a guess.
    private func installedVersionTag(for item: LocalFileItem) -> (text: String, color: Color)? {
        guard item.isIPA,
              let info = fileIPAInfo[item.url.path],
              let fileVersion = info.version, !fileVersion.isEmpty,
              !info.bundleID.isEmpty,
              let installed = appsManager.installedVersion(forBundleID: info.bundleID) else { return nil }
        return czfVersionComparisonTag(fileVersion: fileVersion, installedVersion: installed)
    }

    /// A-38-A1：IPA 行信息 + 图标一次解析（只取可见行，行 .task 触发）：
    /// 两路各开一次包太贵，合流函数一次开包同产两半；键里带大小 + 修改
    /// 时间，文件被覆盖换了就重解析；解析失败也记已尝试，不重复读盘。
    /// 替换途中文件校验只做一次，覆盖两半；写回仍走各自的
    /// BatchWriteback；两个 tried 集都保留——两半都已尝试才直接返回，
    /// 否则解析一次、按需写回未尝试的那半。跟证书页未签名栏同例。
    private func loadFileIPAInfoAndIcon(for item: LocalFileItem) {
        guard item.isIPA else { return }
        // LocalFileItem.id 就是 url.path，两半的键本就是同一个值。
        let key = fileIconKey(item)
        let infoTried = fileIPAInfoTried.contains(key)
        let iconTried = fileIconsTried.contains(key)
        guard !infoTried || !iconTried else { return }
        fileIPAInfoTried.insert(key)
        fileIconsTried.insert(key)
        // A-5(c)：批量写回懒建（首次加载时立一次，此后复用）。
        if fileInfoBatcher == nil {
            fileInfoBatcher = BatchWriteback { batch in
                for (path, info) in batch { self.fileIPAInfo[path] = info }
            }
        }
        if fileIconBatcher == nil {
            fileIconBatcher = BatchWriteback { batch in
                // A-37-3：写共享缓存（路径为键，id 就是 url.path），
                // 再 bump iconEpoch 触发重绘；@State 字典不再存图。
                for (id, image) in batch { ThumbnailCache.set(image, for: id) }
                self.iconEpoch += 1
            }
        }
        // 显式捕获：不把整个 item 隐式带进 detached 任务，免得
        // Swift 6 并发检查找麻烦。
        Task.detached(priority: .userInitiated) { [url = item.url, id = item.id, path = item.url.path,
                         size = item.size, modified = item.modified?.timeIntervalSince1970 ?? 0,
                         infoTried, iconTried] in
            let (info, data) = IPALibrary.appInfoAndIconData(at: url)
            // B31-1（ECV 同款核对）：解析途中文件被替换就丢掉旧信息/旧图。
            let attrs = try? FileManager.default.attributesOfItem(atPath: path)
            let liveSize = attrs?[.size] as? Int
            let liveModified = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            guard liveSize == size, liveModified == modified else { return }
            if !infoTried, let info {
                await MainActor.run { self.fileInfoBatcher?.enqueue(info, for: path) }
            }
            if !iconTried, let data,
               let image = IPALibrary.thumbnail(from: data, maxPixelSize: 120) {
                await MainActor.run { self.fileIconBatcher?.enqueue(image, for: id) }
            }
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
                workspace.openEnterpriseSign = true
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
                    if useIcons { Label(L("Install"), systemImage: "square.and.arrow.down") } else { Text(L("Install")) }
                }
            }
            if !item.isInSignedDir {
                Button {
                    CZFHaptics.impact(.light)
                    installUnsignedFile(item)
                    actionItem = nil
                } label: {
                    if useIcons { Label(L("Install"), systemImage: "square.and.arrow.down") } else { Text(L("Install")) }
                }
                .disabled(installingFileID != nil)
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
            if useIcons { Label(L("Copy"), systemImage: "doc.on.doc") } else { Text(L("Copy")) }
        }
        .disabled(opBusy)
        if !item.isDirectory {
            Button {
                zipSingle(item)
                actionItem = nil
            } label: {
                if useIcons { Label(L("压缩成 ZIP"), systemImage: "archivebox") } else { Text(L("压缩成 ZIP")) }
            }
            .disabled(opBusy)
            if item.isZip {
                Button {
                    unzip(item)
                    actionItem = nil
                } label: {
                    if useIcons { Label(L("解压"), systemImage: "tray.and.arrow.up") } else { Text(L("解压")) }
                }
                .disabled(opBusy)
            }
        }
        Button(role: .destructive) {
            CZFHaptics.impact(.light)
            // B-1（shareFile 同例）：菜单本身正在收起，pendingDeleteItem
            // 推迟一轮 runloop 再立，免得确认弹窗被收起中的 presentation 吞掉；
            // actionItem = nil 仍立即执行，菜单马上收起。
            DispatchQueue.main.async { pendingDeleteItem = item }
            actionItem = nil
        } label: {
            if useIcons { Label(L("Delete"), systemImage: "trash") } else { Text(L("Delete")) }
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

    /// F-1 (0.9.160): unsigned IPA → Apple ID install, the Downloads
    /// page's `install(_:)` 同款：`importCustomIPA` 进安装页的 custom
    /// 槽，成功就立 `sharedIPAReady`，RootView 打开安装 sheet——不
    /// 用回安装页再选一次文件。导入被拒时原因写到页尾 opMessage，
    /// 不开 sheet（`importCustomIPA` 自己的进行中守卫也拦第二路，
    /// 这里的 `installingFileID` 只拦本页重复点）。
    private func installUnsignedFile(_ item: LocalFileItem) {
        guard installingFileID == nil else {
            opMessage = L("An import is already running. Wait for it to finish, then try again.")
            opFailed = true
            return
        }
        installingFileID = item.id
        Task { @MainActor in
            let ok = await engine.importCustomIPA(from: item.url)
            if ok {
                engine.sharedIPAReady = true
            } else if let error = engine.lastError {
                opMessage = error
                opFailed = true
            }
            installingFileID = nil
        }
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
        let sessionBefore = engine.installSessionID
        localInstall.appendStepLog(L("配对安装开始：%@", appName))
        engine.runInstallSignedIPA(ipaURL: ipaURL)
        if !engine.isRunning {
            if let guide = engine.guide,
               guide != guideBefore
               || guide == Guides.importPairing || guide == Guides.vpn
               || guide == Guides.deviceIPMismatch {
                fileInstallErrorText = ([guide.title] + guide.steps).joined(separator: "\n")
            } else {
                fileInstallErrorText = L("配对安装没能启动：请检查配对文件与隧道是否就绪，或去「安装」页看日志。")
            }
            localInstall.appendStepLog(L("配对安装失败：%@", fileInstallErrorText ?? ""))
            return
        }
        // 真正起跑了才立进行中标志 + 归属凭证：会话没变说明这
        // 次调用根本没起跑（起跑瞬间输了竞态），按“已有安装在
        // 进行”处理，绝不把别人的结束认成自己的；onChange 只
        // 认同一会话的结束（见 body 层）。证书页同款。
        guard engine.installSessionID != sessionBefore, let session = engine.installSessionID else {
            fileInstallErrorText = L("已有安装在进行，先等当前安装完成再试。")
            localInstall.appendStepLog(L("配对安装失败：%@", fileInstallErrorText ?? ""))
            return
        }
        fileInstallInFlight = true
        fileInstallRunID = session
    }

    /// 流量安装（OTA，企业证书 + R2 公网 manifest，0.9.104）：只生成 manifest，
    /// 不起本地服务、不走配对、不走隧道。v1 手动上传：App 生成 manifest 写到
    /// 已签名 IPA 旁边，用户经 WebDAV 桥或 R2 控制台把 manifest + IPA 传到 R2，
    /// 再点“已上传，开始安装”拉起系统安装。生成失败时页内留错，不静默。
    private func startOTAInstall(record: SignedIPARecord) {
        otaLaunched = false
        // C33：入口就留重试凭证——两条失败路只置错 + 关 sheet，重试按钮
        // 以 record 非空为条件，入口不置就永远没有重试。
        fileInstallRecord = record
        guard let manifestURL = OTAInstallServer.writePublicManifest(for: record) else {
            fileInstallErrorText = L("安装清单生成失败，改用配对安装。")
            return
        }
        otaManifestURL = manifestURL
        otaRecord = record
    }

    /// 流量安装表单：上传步骤 + 两个 R2 直链 + 分享/开始安装/改用配对安装。
    /// 拉起系统安装后改显示信任引导（App 内收不到 installd 回调，只知已拉起）。
    @ViewBuilder
    private func otaSheet(record: SignedIPARecord) -> some View {
        NavigationStack {
            List {
                Section {
                    if otaLaunched {
                        Text(L("After installing, the first launch will say “Untrusted Enterprise Developer”: go to Settings → General → VPN & Device Management to trust the certificate, tap “Allow and Restart”, then open the app again."))
                    } else {
                        Text(L("Upload these two files to R2, then install: %@ and %@. Upload via the WebDAV bridge https://r2-webdav.wozofa.workers.dev or the R2 console; .plist as text/xml, .ipa as application/octet-stream. After uploading, tap “Uploaded, Start Install”.", OTAInstallServer.publicManifestFileName(for: record.fileName), record.fileName))
                        Text(OTAInstallServer.publicManifestR2URL(for: record.fileName))
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                            .textSelection(.enabled)
                        Text(OTAInstallServer.publicIPAR2URL(for: record.fileName))
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                            .textSelection(.enabled)
                    }
                }
                Section {
                    if !otaLaunched {
                        Button(L("分享")) {
                            if let manifestURL = otaManifestURL {
                                shareOTAFiles(record: record, manifestURL: manifestURL)
                            }
                        }
                        Button(L("Uploaded, Start Install")) {
                            let manifestR2 = OTAInstallServer.publicManifestR2URL(for: record.fileName)
                            // open 的返回值不能当条件用：裸 open(link) 在条件位置会
                            // 解析成 iOS 18+ 的 async 重载，Button 闭包里编不过
                            // （0.9.104 首查唯一红字）。Engine 同款：带 completionHandler
                            // 的同步重载 + Task { @MainActor in } 写状态。
                            guard let link = OTAInstallServer.publicInstallURL(manifestR2URL: manifestR2) else {
                                fileInstallErrorText = L("Cellular install couldn't open the system installer: check the R2 links, or use pairing install instead.")
                                otaRecord = nil
                                return
                            }
                            UIApplication.shared.open(link) { opened in
                                Task { @MainActor in
                                    if opened {
                                        otaLaunched = true
                                    } else {
                                        fileInstallErrorText = L("Cellular install couldn't open the system installer: check the R2 links, or use pairing install instead.")
                                        otaRecord = nil
                                    }
                                }
                            }
                        }
                    }
                    Button(L("改用配对安装")) {
                        otaRecord = nil
                        installSignedFile(LocalFileItem(url: SignedIPAStore.url(for: record),
                            name: record.appName, relativeDir: "Signed",
                            size: record.size, modified: record.date,
                            isDirectory: false, childCount: 0))
                    }
                }
            }
            .navigationTitle(L("Cellular Install (OTA)"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Cancel")) { otaRecord = nil }
                }
            }
        }
    }

    /// 分享 manifest + 已签名 IPA（shareFile 同款 present 写法，双文件版）。
    private func shareOTAFiles(record: SignedIPARecord, manifestURL: URL) {
        DispatchQueue.main.async {
            let sheet = UIActivityViewController(activityItems: [manifestURL, SignedIPAStore.url(for: record)], applicationActivities: nil)
            guard let top = UIApplication.shared.topViewController else { return }
            sheet.popoverPresentationController?.sourceView = top.view
            sheet.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY,
                                                                     width: 0, height: 0)
            top.present(sheet, animated: true)
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
                            .foregroundStyle(Theme.muted)
                    } else {
                        Text(L("配对安装进行中"))
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Button(L("取消安装")) { CZFHaptics.impact(.light); engine.cancelOneClick() }
                    .font(.footnote)
                }
            } else if let error = fileInstallErrorText {
                HStack(spacing: 8) {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(Theme.negative)
                    Spacer()
                    if let record = fileInstallRecord {
                        Button(L("重试安装")) {
                            CZFHaptics.impact(.light)
                            let url = SignedIPAStore.url(for: record)
                            if FileManager.default.fileExists(atPath: url.path) {
                                startEnterpriseInstall(ipaURL: url, record: record)
                            } else {
                                // C33 遗留：文件已被外部删掉，重试无意义，清掉凭证并留错。
                                fileInstallRecord = nil
                                fileInstallErrorText = L("File not found")
                            }
                        }
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
        // A-38-A5：每 body 求值一次建成——文件分区（单遍遍历）与续签源
        // 字典（路径/包名各一），传进各行构建函数；行内不再各做一次
        // filter/first(where:)。全是每求值现算的纯派生，不缓存
        // （@State 新增 0）。
        let partition = filePartition
        let renewalByPath = Dictionary(renewalSources.map { ($0.ipaPath, $0) },
                                       uniquingKeysWith: { first, _ in first })
        let renewalByBundleID = Dictionary(renewalSources.map { ($0.bundleID, $0) },
                                           uniquingKeysWith: { first, _ in first })
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // U-UI：文件页顶部分段——文件列表 / 应用文件夹库（证书页搬来的库）。
                    Picker("", selection: $fileView) {
                        Text(L("File")).tag(FileViewTab.files)
                        Text(L("应用文件夹库")).tag(FileViewTab.library)
                    }
                    .pickerStyle(.segmented)
                    .cascadeItem(0)
                    if fileView == .files {
                        filesBranchContent(partition: partition,
                                           renewalByPath: renewalByPath,
                                           renewalByBundleID: renewalByBundleID)
                    } else {
                        libraryBranchContent
                    }
                    // 页尾（原来顶栏区的安装状态、导入卡、计数都到这里）：
                    // 安装状态平时不显示，安装进行中/失败时才出现。
                    bodyFooter(partition: partition)
                }
                .padding([.horizontal, .top], 20)
                .padding(.bottom, 20)
            }
            .scrollBounceBehavior(.basedOnSize)
            .refreshable {
                // F2 (0.9.141): pull to rescan the file library. refreshFiles
                // scans on a detached task and lands on the main actor; the
                // spinner clears when the call returns and the list updates
                // as soon as the scan lands.
                refreshFiles()
            }
            .blueTopBar()
            .navigationBarTitleDisplayMode(.inline)
            // UI-2(b)：失败统一走顶部 alert——opMessage 一变、且本次是失败
            // （opFailed == true），就把文案写到 opErrorMessage 里；
            // 成功路径不触发（opFailed 为 false），静默。
            .onChange(of: opMessage) { _, new in
                if opFailed, let new {
                    opErrorMessage = new
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(L("文件列表"))
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    fileMenu
                }
            }
            .background(AppBackground())
        }
        .onAppear {
            refreshFiles()
            renewalSources = RenewalSourceStore.load()
        }
        // F-1 (0.9.159): an install that deleted its source IPA rescans
        // this list now, instead of waiting for the next time it's opened.
        .onReceive(NotificationCenter.default.publisher(for: Engine.downloadsChanged)) { _ in
            refreshFiles()
        }
        .sheet(isPresented: $showIPAPicker) {
            FileImporterRepresentableView(
                allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data]
            ) { urls in
                if let url = urls.first {
                    workspace.selectedIPA = url
                    workspace.openEnterpriseSign = true
                }
            }
        }
        // 配对安装跑完：finished 置位才算成功（取消不算）。只认
        // fileInstallInFlight 期间的变化，ID 线的安装跑完不会误弹
        // 到这里；失败原因快照到页内本地量，不直接绑 engine 的
        // 全局量。文件页安装跑完写一条「仅安装」日志（见 startEnterpriseInstall）。
        .onChange(of: engine.isRunning) { old, new in handleEngineRunningChange(old: old, new: new) }
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
            Button(L("Delete"), role: .destructive) {
                if let item = pendingDeleteItem { delete(item) }
                pendingDeleteItem = nil
            }
            Button(L("Cancel"), role: .cancel) { pendingDeleteItem = nil }
        } message: {
            if let item = pendingDeleteItem, let warning = renewalDeleteWarning(for: item) {
                Text(warning)
            } else {
                Text(L("删除后无法恢复"))
            }
        }
        // 批量删确认，带数量。
        .alert(L("删除所选 %d 个？", selection.count), isPresented: $pendingDeleteSelection) {
            Button(L("Delete"), role: .destructive) {
                pendingDeleteSelection = false
                deleteSelection()
            }
            Button(L("Cancel"), role: .cancel) { pendingDeleteSelection = false }
        } message: {
            if let warning = renewalDeleteWarning(forSelection: selection) {
                Text(warning)
            } else {
                Text(L("删除后无法恢复"))
            }
        }
        // UI-5：通用失败提示（B-3 的删除失败 alert 泛化而来——页尾 importCard 的
        // opMessage 在列表底下，顶部看不到；失败 alert 只在操作执行后
        // 才立起，此时确认 alert 已收起，不跟 B-1 的确认抢 present）。
        .alert(L("Error"), isPresented: Binding(
            get: { opErrorMessage != nil },
            set: { if !$0 { opErrorMessage = nil } }
        )) {
            Button(L("OK"), role: .cancel) { opErrorMessage = nil }
        } message: {
            Text(opErrorMessage ?? "")
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
            Button(L("Cancel"), role: .cancel) {
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
            Button(L("Cancel"), role: .cancel) { renameItem = nil }
            Button(L("Save")) { performRename() }
        } message: {
            Text(L("扩展名别改错，不然文件可能打不开。"))
        }
        .alert(L("新建文件夹"), isPresented: $showNewFolderAlert) {
            TextField(L("请输入文件夹名字"), text: $newFolderName)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button(L("Cancel"), role: .cancel) { showNewFolderAlert = false }
            Button(L("创建")) {
                showNewFolderAlert = false
                createFolder()
            }
        }
        .sheet(item: $machoItem) { item in
            MachOView(url: item.url, fileName: item.name)
        }
        .sheet(item: $detailItem) { item in
            detailSheetContent(item: item, renewalByPath: renewalByPath, renewalByBundleID: renewalByBundleID)
        }
        .sheet(item: $moveItem) { item in
            moveSheetContent(item: item)
        }
        // F4 (0.9.154): the batch-move sheet (see moveSelectionSheetContent).
        .sheet(isPresented: $showMoveSelectionSheet) {
            moveSelectionSheetContent()
        }
        .confirmationDialog(installChoiceRecord?.appName ?? "", isPresented: Binding(
            get: { installChoiceRecord != nil },
            set: { if !$0 { installChoiceRecord = nil } }
        )) {
            installChoiceButtons()
        }
        .sheet(item: $otaRecord) { record in
            otaSheet(record: record)
        }
        .sheet(isPresented: $showImporter) {
            FileImporterRepresentableView(
                allowedContentTypes: [.item],
                allowsMultipleSelection: true
            ) { urls in importFiles(urls) }
        }
    }

    /// A-38-A5：body 拆分——文件列表分支（切栏区 / 搜索排序行 / 列表区）。
    /// 内容与原 body 一字不动，只把派生值换成 body-local 的 partition
    /// 与续签源字典（行内不再各做一次 filter/first(where:)）。
    @ViewBuilder
    private func filesBranchContent(partition: FilePartition,
                                    renewalByPath: [String: RenewalSourceEntry],
                                    renewalByBundleID: [String: RenewalSourceEntry]) -> some View {
        if selecting {
            selectionBar.cascadeItem(2)
        }
        // 轻松签文件列表式切栏（只过滤 IPA 行）：放搜索框上面，
        // 跟证书页应用库切栏同例，segmented 样式。
        Picker("", selection: $fileTab) {
            Text(L("未签名 (%d)", partition.unsigned)).tag(FileListTab.unsigned)
            Text(L("已签名 (%d)", partition.signed)).tag(FileListTab.signed)
        }
        .pickerStyle(.menu)
        // 切栏触感：点切栏、或菜单"查看文件位置"切栏变化时
        // 各震一次 .light；后者菜单按钮本身不另震，免得一次点按震两次。
        .onChange(of: fileTab) { _, _ in
            CZFHaptics.impact(.light)
            // B-6：切栏清掉根列表的选择集，免得工具栏还停在
            // 选择模式；应用库两栏自有独立选择集，不动。
            selection = []
            selecting = false
        }
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
            let dirItems = currentDirItems
            let dirVisible = visibleDirItems(in: dirItems)
            if dirItems.isEmpty {
                emptyCard.cascadeItem(2)
            } else if dirVisible.isEmpty {
                Text(L("没有匹配的 IPA。"))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            } else {
                folderSection(items: dirVisible, renewalByPath: renewalByPath, renewalByBundleID: renewalByBundleID).cascadeItem(2)
            }
        } else if files.isEmpty {
            emptyCard.cascadeItem(2)
        } else {
            // IPA 行不再单开「IPA 文件」组：切栏 + 搜索过滤
            // 后的 ipaList 就是全部 IPA（轻松签文件列表式，
            // 无卡片头）；其他文件、系统文件不再分组头，合并为
            // 扁平列表（过滤逻辑不动）。
            ipaList(partition: partition, renewalByPath: renewalByPath, renewalByBundleID: renewalByBundleID).cascadeItem(2)
            if fileTab == .unsigned {
                let flatFiles = sortedFiles(matching(partition.others) + matching(partition.systemFiles))
                if !flatFiles.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(flatFiles) { item in
                            fileRow(item, renewalByPath: renewalByPath, renewalByBundleID: renewalByBundleID)
                            if item.id != flatFiles.last?.id {
                                Divider()
                            }
                        }
                    }
                    .cascadeItem(3)
                }
            }
        }
    }

    /// A-38-A5：body 拆分——应用文件夹库分支。
    private var libraryBranchContent: some View {
        libraryContentView
            .task {
                signedRecords = SignedIPAStore.load()
                let changed = await Task.detached { SignedIPAStore.fillMissingCertInfo() }.value
                if changed { signedRecords = SignedIPAStore.load() }
                refreshUnsignedIPAs()
                logEntries = CertSignLogStore.load()
                checkRevocation()
            }
            .onChange(of: libraryTab) { _, tab in
                if tab == .unsigned {
                    refreshUnsignedIPAs()
                }
            }
    }

    /// A-38-A5：body 拆分——页尾（安装状态、导入卡、文件计数）。F6 (0.9.155)：
    /// 合计行旁常驻显示设备剩余空间——与下载预检同一读数，平时也看得见，
    /// 不必等下载失败才知道空间不够。
    @ViewBuilder
    private func bodyFooter(partition: FilePartition) -> some View {
        fileInstallStatus
        importCard.cascadeItem(5)
        lanCard.cascadeItem(6)
        Text(L("%d 个文件 · %@", files.count,
               ByteCountFormatter.string(fromByteCount: Int64(partition.totalSize), countStyle: .file)))
            .font(.footnote)
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity, alignment: .center)
        if let free = Self.freeSpaceBytes {
            Text(L("Free space: %@", ByteCountFormatter.string(fromByteCount: free, countStyle: .file)))
                .font(.footnote)
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    /// F6 (0.9.155): device free space — the same
    /// `volumeAvailableCapacityForImportantUsage` read the downloader's
    /// pre-flight check uses, on the Documents volume the library lives on.
    private static var freeSpaceBytes: Int64? {
        (try? IPALibrary.documentsDir.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))
            .flatMap(\.volumeAvailableCapacityForImportantUsage)
    }

    /// A-38-A5：body 拆分——配对安装跑完的收尾（finished 置位才算成功，
    /// 取消不算）。原 onChange(of: engine.isRunning) 闭包本体一字不动。
    private func handleEngineRunningChange(old: Bool, new: Bool) {
        if old && !new && fileInstallInFlight {
            // 当前又有安装在跑（isRunning 已翻回 true）：这次
            // 投递是上一次安装的滞后投递，不是当前这跑的结束
            // ——不认、不清，新跑的结束投递随后会来；不清的
            // 话新跑结束时 inFlight 还在，不会丢完成。
            guard !engine.isRunning else { return }
            fileInstallInFlight = false
            // 归属凭证：只认自己那次安装的结束。凭证对不上
            // （别的安装在标志立着时结束）时不记日志、不弹框。
            let runID = fileInstallRunID
            fileInstallRunID = nil
            guard runID != nil, runID == engine.installSessionID else { return }
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

    /// A-38-A5：body 拆分——IPA 详情 sheet 内容。原 sheet 闭包本体一字
    /// 不动，只把续签名换成 body-local 的字典查表。
    private func detailSheetContent(item: LocalFileItem,
                                    renewalByPath: [String: RenewalSourceEntry],
                                    renewalByBundleID: [String: RenewalSourceEntry]) -> some View {
        FileDetailSheet(item: item, ipaInfo: fileIPAInfo[item.url.path], renewalAppName: renewalSource(for: item, byPath: renewalByPath, byBundleID: renewalByBundleID)?.appName, onDelete: {
            detailItem = nil
            // B-1（fileActionButtons 同例）：sheet 正在收起，确认弹窗
            // 推迟一轮 runloop 再立，免得被收起中的 sheet 吞掉。
            DispatchQueue.main.async { pendingDeleteItem = item }
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

    /// A-38-A5：body 拆分——导入文件的 detached 任务本体。原 sheet 闭包
    /// 里的 Task.detached 一字不动。
    private func importFiles(_ urls: [URL]) {
        // A-1：逐个 copyItem 全在主线程，大 IPA 导入时 UI 全程冻结；
        // 整个循环移进 detached 任务，结束回主线程一次写回 + 重扫。
        // L() 只在主线程调（文案格式化），detached 里只攒原始错误串。
        Task.detached {
            // B-7：攒全部失败（文件名 + 个数），不再只留最后一次——
            // 先坏后好的组合里，坏掉的那个文件会无声消失。
            var failures: [(name: String, reason: String)] = []
            for url in urls {
                do {
                    _ = try AppFileLibrary.importIntoDocuments(url)
                } catch {
                    failures.append((url.lastPathComponent, error.localizedDescription))
                }
            }
            let failureCount = failures.count
            let firstFailure = failures.first
            await MainActor.run {
                let failureText: String? = firstFailure.map {
                    L("%d files, first %@: %@", failureCount, $0.name, $0.reason)
                }
                importError = failureText.map { L("导入失败：%@", $0) }
                // UI-2(b)：导入失败同时走顶部 alert 通道（页尾
                // importCard 在列表底下）；页尾渲染保留。
                if let failureText {
                    opErrorMessage = L("导入失败：%@", failureText)
                }
                refreshFiles()
            }
        }
    }

    /// A-38-A5：body 拆分——已签名安装方式选择 dialog 的按钮组。
    @ViewBuilder
    private func installChoiceButtons() -> some View {
        Button(L("Pairing Install")) {
            if let record = installChoiceRecord {
                installSignedFile(LocalFileItem(url: SignedIPAStore.url(for: record),
                    name: record.appName, relativeDir: "Signed",
                    size: record.size, modified: record.date,
                    isDirectory: false, childCount: 0))
            }
        }
        Button(L("Cellular Install (OTA)")) {
            if let record = installChoiceRecord { startOTAInstall(record: record) }
        }
        Button(L("Cancel"), role: .cancel) { installChoiceRecord = nil }
    }

    /// A-38-A5：body 拆分——右上角 ••• 菜单（导入 / 新建文件夹 / 刷新 / 选择）。
    private var fileMenu: some View {
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
                refreshFiles(resetDir: true)
            } label: {
                Label(L("Refresh"), systemImage: "arrow.clockwise")
            }
            if fileView == .files && !files.isEmpty {
                Button {
                    selecting.toggle()
                    selection = []
                } label: {
                    Label(selecting ? L("Done") : L("选择"), systemImage: "checkmark.circle")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundStyle(.white)
        }
    }

    /// 文件页顶栏：只留标题 + 切栏 + 搜索（轻松签文件列表式紧凑顶栏）；
    /// 原来的大标题计数、导入卡、安装状态、操作行都移到页尾或 ••• 菜单里。

    /// F2 (0.9.151): the selected IPAs — any tab, since the unsigned and
    /// signed lists share this selection; folders and non-IPA files never
    /// install, and are counted as skipped by installSelection.
    private var selectionIPAs: [LocalFileItem] {
        files.filter { selection.contains($0.id) && $0.isIPA && !$0.isDirectory }
    }

    /// 多选时的操作条：压缩成一个 zip / 批量安装 / 批量删除。
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
                    .buttonStyle(SecondaryButtonStyle(), sound: .tap)
                    .disabled(selection.isEmpty || opBusy || batchInstallTask != nil)
                    // F4 (0.9.154): move every selected file/folder to one
                    // destination (see moveSelectionSheetContent).
                    Button {
                        showMoveSelectionSheet = true
                    } label: {
                        Text(L("移动"))
                    }
                    .buttonStyle(SecondaryButtonStyle(), sound: .tap)
                    .disabled(selection.isEmpty || opBusy || batchInstallTask != nil)
                    Button {
                        installSelection()
                    } label: {
                        HStack {
                            if batchInstallTask != nil { ProgressView() }
                            Text(L("安装所选"))
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle(), sound: .tap)
                    .disabled(selectionIPAs.isEmpty || opBusy || batchInstallTask != nil)
                    Button(role: .destructive) {
                        pendingDeleteSelection = true
                    } label: {
                        Text(L("删除所选"))
                    }
                    .buttonStyle(SecondaryButtonStyle(), sound: .tap)
                    .disabled(selection.isEmpty || opBusy || batchInstallTask != nil)
                }
                // F2：批量安装进行中——第几个/共几个 + 当次安装进度 +
                // 取消（取消同时停掉批量 Task 与当次安装，见
                // cancelBatchInstall；Install pill 同款进度也在跑）。
                if let current = batchInstallCurrent {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(L("正在安装第 %d/%d 个：%@", batchInstallIndex, batchInstallTotal, current))
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                        if engine.installProgress > 0 {
                            Text("(\(Int(engine.installProgress * 100))%)")
                                .font(.footnote)
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Button(L("取消安装")) { cancelBatchInstall() }
                            .font(.footnote)
                    }
                }
            }
        }
    }

    private var importCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .foregroundStyle(Theme.muted)
                    Text(L("文件管理"))
                        .font(.headline)
                }
                Text(L("这里是 App 自己的文件目录：下载的、导入的、已签名的 IPA 都在这。也可以在「文件」App 里往 SideInstaller 的目录放文件，回到这里就能看到。"))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                Button {
                    showImporter = true
                } label: {
                    Text(L("导入文件"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle(), sound: .tap)
                if let importError {
                    Text(importError)
                        .font(.footnote)
                        .foregroundStyle(Theme.negative)
                }
                if opBusy {
                    HStack(spacing: 6) {
                        ProgressView()
                        Text(L("处理中…"))
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                    }
                } else if let opMessage {
                    Text(opMessage)
                        .font(.footnote)
                        .foregroundStyle(opFailed ? Theme.negative : Theme.positive)
                }
            }
        }
    }

    /// 局域网传输卡：原来 importCard 下半截，拆出来单成一卡。
    private var lanCard: some View {
        PanelCard {
            lanSection
        }
    }

    /// 局域网传输开关：开着时同 Wi-Fi 的浏览器能管理这个目录。
    private var lanSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "wifi")
                    .foregroundStyle(Theme.muted)
                Text(L("局域网传输"))
                    .font(.headline)
            }
            if lanServer.isRunning {
                Text(L("电脑和手机连同一个 Wi-Fi，浏览器打开这个地址就能上传、下载、删除这里的文件："))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
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
                            .foregroundStyle(lanCopied ? Theme.positive : Theme.muted)
                        if lanCopied {
                            Text(L("Copied"))
                                .font(.footnote)
                                .foregroundStyle(Theme.positive)
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
                    .foregroundStyle(Theme.muted)
                Button {
                    lanServer.start()
                } label: {
                    Text(L("开启局域网传输"))
                        .font(.footnote)
                }
                if let error = lanServer.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(Theme.negative)
                }
            }
        }
    }

    private var emptyCard: some View {
        PanelCard {
            Text(L("还没有文件。点上面「导入文件」放 IPA 进来，或在源页面下载后这里会出现。"))
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
    }

    /// 文件页顶部搜索条：按名字过滤当前视图（根目录各组、或当前文件夹内）。
    private var fileSearchBar: some View {
        SearchBar(text: $fileSearchText, placeholder: L("搜索"))
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
                        Text(L("Back"))
                    }
                    .font(.footnote.weight(.semibold))
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Text(currentDirName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(L("%d 项", currentDirItems.count))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    /// 当前文件夹内的直接子项（文件夹 + 文件同一列表，轻松签式）：
    /// 行格式跟根目录 fileRow 一模一样，不另起一套。
    private func folderSection(items: [LocalFileItem],
                               renewalByPath: [String: RenewalSourceEntry],
                               renewalByBundleID: [String: RenewalSourceEntry]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(items) { item in
                fileRow(item, renewalByPath: renewalByPath, renewalByBundleID: renewalByBundleID)
                if item.id != items.last?.id {
                    Divider()
                }
            }
        }
    }

    /// 轻松签文件列表式 IPA 列表（切栏 + 搜索过滤后）：行格式见
    /// fileRow 的 IPA 分支（图标 + 名 + 版本|大小|Bundle ID + 文件名），
    /// 点行弹底部动作菜单；空态按切栏/搜索区分文案，不空白。
    /// 无卡片头（参考图里列表就是平铺的），跟其他文件组区分开。
    @ViewBuilder
    private func ipaList(partition: FilePartition,
                         renewalByPath: [String: RenewalSourceEntry],
                         renewalByBundleID: [String: RenewalSourceEntry]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // A-5(a)：ForEach 外求一次存局部量，不再每行重建数组。
            let list = filteredIPAs(partition: partition)
            if list.isEmpty {
                Text(fileSearchText.isEmpty
                     ? (fileTab == .unsigned ? L("还没有未签名的 IPA。") : L("还没有已签名的 IPA。"))
                     : L("没有匹配的 IPA。"))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            } else {
                ForEach(list) { item in
                    fileRow(item, renewalByPath: renewalByPath, renewalByBundleID: renewalByBundleID)
                    if item.id != list.last?.id {
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
        let size = CZFFormattedSize.size(item.size)
        guard let modified = item.modified else { return size }
        return "\(size)  \(fileTimeText(modified))"
    }

    /// A-40-1：文件行时间文案静态缓存——照抄 SIDE-39 A-39-2 的
    /// DownloadsListView.dateTextCache 模式；每行每 body 求值现建
    /// Date.FormatStyle 太贵。key 必须带今天（值本身依赖今天：
    /// isDateInToday 分支，今天显时间、明天显日期）。调用方全在
    /// 主线程 body 里，不另加锁。
    private static var fileTimeTextCache: [String: String] = [:]

    /// 今天显示时间（14:38:19），以前的显示日期（2026/10/27），轻松签同款。
    private func fileTimeText(_ date: Date) -> String {
        let today = Calendar.current.startOfDay(for: Date())
        let key = "\(date.timeIntervalSince1970)#\(Localizer.locale.identifier)#\(today.timeIntervalSince1970)"
        if let cached = Self.fileTimeTextCache[key] { return cached }
        let text: String
        if Calendar.current.isDateInToday(date) {
            text = date.formatted(date: .omitted, time: .standard)
        } else {
            text = date.formatted(date: .numeric, time: .omitted)
        }
        if Self.fileTimeTextCache.count > 512 { Self.fileTimeTextCache.removeAll() }
        Self.fileTimeTextCache[key] = text
        return text
    }

    /// 文件行图标：IPA 真图 / 文件夹蓝标 / 其他灰标，三路不同
    /// View 类型，函数前必须加 @ViewBuilder（AGENTS.md 血泪）。
    /// 真图 60×60 圆角填满；系统标放 60×60 框里居中，行高对齐。
    @ViewBuilder
    private func fileIcon(for item: LocalFileItem) -> some View {
        // A-37-3：读 iconEpoch 建立依赖——图标本体在共享缓存里，
        // 批量写回只 bump epoch、不写 @State；不读它，body 不会
        // 重算，图就永远不出现。别把这行当死代码清掉。
        let _ = iconEpoch
        if item.isDirectory {
            Image(systemName: "folder.fill")
                .foregroundStyle(Theme.accent)
                .font(.title3)
                .frame(width: 60, height: 60)
        } else if item.isIPA,
                  let uiImage = ThumbnailCache.image(for: item.id) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
        } else {
            // IPA 还没取到图、取图失败、非 IPA 文件：一律中性占位，
            // 不造假图、不空框（IPA 占位与应用库同款灰色文档标）。
            Image(systemName: "doc")
                .foregroundStyle(Theme.muted)
                .font(.title3)
                .frame(width: 60, height: 60)
        }
    }

    /// 图标取图键：路径 + 大小 + 修改时间——文件被覆盖换了就重取。
    private func fileIconKey(_ item: LocalFileItem) -> String {
        "\(item.id)#\(item.size)#\(item.modified?.timeIntervalSince1970 ?? 0)"
    }

    private func fileRow(_ item: LocalFileItem,
                         renewalByPath: [String: RenewalSourceEntry],
                         renewalByBundleID: [String: RenewalSourceEntry]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if selecting {
                    Image(systemName: selection.contains(item.id)
                          ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selection.contains(item.id) ? Theme.accent : Theme.muted)
                }
                // 轻松签文件列表式：IPA 有真实图标就显示真图（应用库
                // 同款解析，见 loadFileIcon），没取到就中性占位；
                // 文件夹蓝色、其他文件灰色文档图标。图标区统一
                // 60×60 框，行高对齐，不晃。
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
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                        // F-2 (0.9.164): how this file's version compares
                        // with the installed one.
                        if let tag = installedVersionTag(for: item) {
                            Text(tag.text)
                                .font(.caption)
                                .foregroundStyle(tag.color)
                                .lineLimit(1)
                        }
                        Text(item.name)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(2)
                        Text(fileSecondLine(item))
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if let source = renewalSource(for: item, byPath: renewalByPath, byBundleID: renewalByBundleID) {
                    // 续签用的源文件：行内一眼认出，删之前先想想。
                    Text(L("续签"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.badgePositive, in: Capsule())
                        .accessibilityLabel(L("续签用的文件：%@", source.appName))
                }
                // ⓘ 详情：所有行都有（IPA 行也补上，与非 IPA 行一致）；
                // 文件夹不再另放 chevron，点行就进文件夹。
                Button {
                    detailItem = item
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Theme.accent)
                    .font(.title3)
                    .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        // IPA 行图标 + 信息：行出现时触发一次合流解析（文件换了就重取，
        // 键里带大小 + 修改时间；取不到也记 tried，不死循环）。
        // 非 IPA 行直接跳过（loadFileIPAInfoAndIcon 里 guard）。
        .task(id: fileIconKey(item)) { loadFileIPAInfoAndIcon(for: item) }
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

    /// 文件列表重扫：递归扫盘放 Task.detached，扫完回主线程写 files
    /// （照抄 loadFileIcon 写法）；onAppear 与各操作后刷新都走这里，
    /// 不在主线程同步扫盘。resetDir 为 true 时，写完列表后立即按新
    /// 列表复核 currentDir——删/移/改名后原地复核用的就是新列表，
    /// 语义与同步扫盘时一致（只换线程，不换顺序）。
    /// B-3：调用时 filesRefreshGeneration +1 并捕获，写回前核对代际，
    /// 过期的旧扫描直接丢弃，不盖住新列表。
    private func refreshFiles(resetDir: Bool = false) {
        filesRefreshGeneration += 1
        let generation = filesRefreshGeneration
        Task.detached {
            let items = AppFileLibrary.scan()
            await MainActor.run {
                guard generation == self.filesRefreshGeneration else { return }
                files = items
                if resetDir { resetCurrentDirIfNeeded() }
            }
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
        // A-2：读内存里的 renewalSources（进页时已读好），不再每行现读
        // RenewalSources.json + 解码；匹配逻辑就是 renewalSource(for:)。
        guard let entry = renewalSource(for: item) else { return nil }
        return L("这是 %@ 续签用的文件，删了它下次就续不了，要重新导入 IPA 才能续。删除后无法恢复", entry.appName)
    }

    /// 批量删里的续签源提示：选中的文件里有续签用过的，就把 App 名列出来。
    private func renewalDeleteWarning(forSelection selected: Set<String>) -> String? {
        // A-2：同上，读内存缓存，不逐条读盘（renewalSource(for:) 内含 isIPA 门）。
        let names = files.filter { selected.contains($0.id) }
            .compactMap { renewalSource(for: $0)?.appName }
        guard !names.isEmpty else { return nil }
        return L("其中 %@ 是续签用的文件，删了它们下次就续不了，要重新导入 IPA 才能续。删除后无法恢复", names.joined(separator: "、"))
    }

    /// B1+B5：签名/续签进行中的源文件不删不移不改名——签名步/续签步正读它。
    /// 只拦集里的路径，不拦无关文件。返回 true 表示已拒并已置失败提示，
    /// 调用方直接 return；批量删的计数循环不用它（见 deleteSelection，
    /// 那里要分别计数再统一报）。
    private func rejectIfBusySigningOrRenewing(path: String) -> Bool {
        if engine.isSigningSource(path: path) {
            opErrorMessage = L("This file is being signed. Wait until it finishes.")
            opMessage = L("This file is being signed. Wait until it finishes.")
            opFailed = true
            return true
        }
        if engine.isRenewingSource(path: path) {
            opErrorMessage = L("This file is being renewed. Wait until it finishes.")
            opMessage = L("This file is being renewed. Wait until it finishes.")
            opFailed = true
            return true
        }
        return false
    }

    /// 单删：磁盘上确认没了才从数组里去掉它（含文件夹子项），
    /// 不用整树重扫；删除没成功（文件还在）就重扫恢复真相，
    /// 别把还在的文件藏掉。
    private func delete(_ item: LocalFileItem) {
        // B-2：文件夹禁删（LAN/WebDAV 早已同规则，应用内对齐）——
        // Signed 文件夹本身就是目录行，一并拦住；提示走 B-3 的 alert，
        // 不要只禁不提示。
        guard !item.isDirectory else {
            opErrorMessage = L("Folders can't be deleted")
            opMessage = L("Folders can't be deleted")
            opFailed = true
            return
        }
        // B-8：正在安装的源文件不删——删了签名步读不到文件，安装死在签名失败。
        guard !engine.isInstallingSource(path: item.url.path) else {
            opErrorMessage = L("This file is being installed. Wait until it finishes.")
            opMessage = L("This file is being installed. Wait until it finishes.")
            opFailed = true
            return
        }
        // B1+B5：正在签名/续签的源文件不删——签名步/续签步正读它。
        guard !rejectIfBusySigningOrRenewing(path: item.url.path) else { return }
        if removeFileFromDisk(item) {
            files.removeAll {
                $0.url.path == item.url.path || $0.url.path.hasPrefix(item.url.path + "/")
            }
            // B-3：本地已删掉，在途的旧重扫若还写回会把已删文件带回来——
            // 代际号 +1 使它过期，写回时直接丢弃；本路不另调 refreshFiles。
            filesRefreshGeneration += 1
            resetCurrentDirIfNeeded()
            // C8/A-9：删掉的 IPA 可能是某 App 的续签源——只当删的是 IPA
            // 才重算配对（installable() 只产 IPA，删非 IPA 不可能改配对）。
            // 文件页本身不隔离在 @MainActor 上，包进 Task 回主线程调。
            if item.isIPA {
                Task { @MainActor in SideloadedAppsManager.shared.refreshRefreshableOnly() }
            }
        } else {
            refreshFiles(resetDir: true)
            opMessage = L("删除失败，文件仍在")
            opFailed = true
            // B-3：失败提示再走一条顶部可见的 alert（页尾 opMessage 在列表底下）。
            opErrorMessage = L("删除失败，文件仍在")
        }
    }

    /// 在当前目录（根目录或进的文件夹里）新建文件夹（轻松签
    /// 新建文件夹同款）：重名就拒，不覆盖。
    private func createFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        // B4 (0.9.153): illegal names used to return silently — the alert
        // just closed and nothing happened. Say why, on the same
        // opMessage/opFailed road as the duplicate-name refusal below
        // (UI-2(b) lifts it into the top alert).
        guard !name.isEmpty, !name.contains("/"), !name.hasPrefix(".") else {
            opMessage = L("Names can't be empty, contain /, or start with .")
            opFailed = true
            return
        }
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
            refreshFiles()
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
                        .foregroundStyle(Theme.muted)
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
                    Button(L("Cancel")) { moveItem = nil }
                }
            }
        }
    }

    /// F4 (0.9.154): the batch-move sheet — the single-move sheet's
    /// destinations, narrowed to the ones every selected item can go to
    /// (see moveSelectionDestinations), so a tap can't pick a folder one
    /// of the items can't go into.
    @ViewBuilder
    private func moveSelectionSheetContent() -> some View {
        NavigationStack {
            List {
                if moveSelectionDestinations.isEmpty {
                    Text(L("没有可移动到的文件夹，先新建一个。"))
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
                ForEach(moveSelectionDestinations, id: \.dir) { dest in
                    Button {
                        showMoveSelectionSheet = false
                        moveSelectionToFolder(dest.dir)
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
                    Button(L("Cancel")) { showMoveSelectionSheet = false }
                }
            }
        }
    }

    /// F4 (0.9.154): the destinations every selected item can move to —
    /// the intersection of the single-item lists, so a tap can't pick a
    /// folder one of the items can't go into (itself, its child, or the
    /// folder it already sits in).
    private var moveSelectionDestinations: [(dir: String, name: String)] {
        let items = files.filter { selection.contains($0.id) }
        guard let first = items.first else { return [] }
        var common = moveDestinations(for: first)
        for item in items.dropFirst() {
            let dirs = Set(moveDestinations(for: item).map(\.dir))
            common.removeAll { !dirs.contains($0.dir) }
        }
        return common
    }

    /// F4 (0.9.154): move every selected file/folder to one destination,
    /// reusing the single-item move (same guards, same refusal) and
    /// reporting the failures by name at the end instead of the last
    /// item's message. `moveItemToFolder` reports through opMessage /
    /// opFailed, so each item's verdict is read back before the next
    /// item overwrites it; the selection clears like deleteSelection's.
    private func moveSelectionToFolder(_ destDir: String) {
        let items = files.filter { selection.contains($0.id) }
        guard !items.isEmpty else { return }
        var moved = 0
        var failedNames: [String] = []
        for item in items {
            opMessage = nil
            opFailed = false
            moveItemToFolder(item, destDir)
            if opFailed { failedNames.append(item.name) } else { moved += 1 }
        }
        selection = []
        selecting = false
        if failedNames.isEmpty {
            opMessage = L("已移动 %d 个。", moved)
            opFailed = false
        } else {
            let shown = failedNames.prefix(5).joined(separator: "、")
            var list = shown
            if failedNames.count > 5 {
                list += "、" + L("等 %d 个", failedNames.count - 5)
            }
            opMessage = L("已移动 %d 个，失败 %d 个。失败：%@", moved, failedNames.count, list)
            opFailed = true
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
        // B-8：正在安装的源文件不移走——移走后签名步读不到文件。
        guard !engine.isInstallingSource(path: item.url.path) else {
            opErrorMessage = L("This file is being installed. Wait until it finishes.")
            opMessage = L("This file is being installed. Wait until it finishes.")
            opFailed = true
            return
        }
        // B1+B5：正在签名/续签的源文件不移走——签名步/续签步正读它。
        guard !rejectIfBusySigningOrRenewing(path: item.url.path) else { return }
        // B-38-B5：保留文件夹（根目录下的 Signed / Custom）不改名/不移动——改名/移走后
        // 清单按写死路径找文件，整库瞬间不可见。
        if item.isDirectory && item.relativeDir.isEmpty && (item.name == "Signed" || item.name == "Custom") {
            opErrorMessage = L("This folder can't be renamed or moved.")
            opMessage = L("This folder can't be renamed or moved.")
            opFailed = true
            return
        }
        do {
            try FileManager.default.moveItem(at: item.url, to: dest)
            refreshFiles(resetDir: true)
            // B-4：移动后刷新续签缓存与应用库列表，角标立即跟新位置。
            renewalSources = RenewalSourceStore.load()
            refreshUnsignedIPAs()
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
        // A-1：uniqueSibling 只算名字不建文件（主线程算好目标名），
        // copyItem 本体放 detached——1.26GB 拷贝不再冻住主线程；
        // 目标已存在时 copyItem 抛错，失败分支写提示，不静默覆盖。
        // 写法照抄同文件 runZip 的 Task + detached 模式。
        // B-38-B4：串行守卫——行菜单按钮已禁用（第一道防线），这里是第二道
        // 防线（防非 UI 调用方与竞态）；同一时刻最多一路在跑，输出名不撞车。
        guard !opBusy else { return }
        let stem = item.url.deletingPathExtension().lastPathComponent
        let dest = uniqueSibling(of: item, stem: stem, ext: item.url.pathExtension)
        opBusy = true
        opMessage = nil
        Task {
            // 修法（checks 首轮红）：trailing closure 签名里 `[capture] -> T in`
            // 不带参数列表编不过（1707:92 Consecutive statements / Expected expression）；
            // 去掉显式返回类型，靠外层 `let error: String?` 标注推断（runZip 同款）。
            let error: String? = await Task.detached { [source = item.url, dest] in
                do {
                    try FileManager.default.copyItem(at: source, to: dest)
                    return nil
                } catch {
                    return error.localizedDescription
                }
            }.value
            opBusy = false
            refreshFiles()
            if let error {
                opMessage = error
                opFailed = true
            } else {
                opMessage = L("已复制为 %@", dest.lastPathComponent)
                opFailed = false
                // B-4：副本落盘后续签缓存与应用库列表同步刷新。
                renewalSources = RenewalSourceStore.load()
                refreshUnsignedIPAs()
            }
        }
    }

    /// 批量删：先删完所有项，最后只扫一次（原来每项各扫一次，
    /// 删 N 个就是 N 次整树枚举，全在主线程）。
    private func deleteSelection() {
        var failed = 0
        var skippedFolders = 0
        var skippedInstalling = 0
        var skippedSigning = 0
        var skippedRenewing = 0
        var hadIPA = false
        // A-2：已签名项先分区——一次 load 取出对应记录，一次批量 remove
        // （一次读清单、一次写回）；非签名项仍逐项 removeFileFromDisk。
        // 清单里没记录的已签名文件（幽灵文件）回落逐项删，不漏删。
        var signedToRemove: [SignedIPARecord] = []
        let signedRecords = SignedIPAStore.load()
        for item in files where selection.contains(item.id) {
            // B-2：文件夹跳过不删，记数后统一提示。
            if item.isDirectory { skippedFolders += 1; continue }
            // B-8：正在安装的源文件跳过不删，记数后统一提示
            // （与单删同动作：批量删是单删的另一入口，不另立规则）。
            if engine.isInstallingSource(path: item.url.path) { skippedInstalling += 1; continue }
            // B1+B5：正在签名/续签的源文件同样跳过不删，记数后统一提示。
            if engine.isSigningSource(path: item.url.path) { skippedSigning += 1; continue }
            if engine.isRenewingSource(path: item.url.path) { skippedRenewing += 1; continue }
            if item.isIPA { hadIPA = true }
            if item.isInSignedDir,
               let record = signedRecords.first(where: { $0.fileName == item.name }) {
                signedToRemove.append(record)
                continue
            }
            if !removeFileFromDisk(item) { failed += 1 }
        }
        if !signedToRemove.isEmpty {
            SignedIPAStore.remove(signedToRemove)
            for record in signedToRemove
            where FileManager.default.fileExists(atPath: SignedIPAStore.url(for: record).path) {
                failed += 1
            }
        }
        selection = []
        selecting = false
        refreshFiles(resetDir: true)
        // C8/A-9：选中项里含 IPA 才重算一次配对；删的全是非 IPA 就不算。
        if hadIPA {
            Task { @MainActor in SideloadedAppsManager.shared.refreshRefreshableOnly() }
        }
        if failed > 0 {
            opMessage = L("有 %d 个文件删除失败", failed)
            opFailed = true
            // B-3：失败提示再走一条顶部可见的 alert。
            opErrorMessage = L("有 %d 个文件删除失败", failed)
        } else if skippedFolders > 0 {
            // B-2：只跳过了文件夹、其余全删干净时，也要可见地报一句。
            opMessage = L("Folders can't be deleted")
            opFailed = true
            opErrorMessage = L("Folders can't be deleted")
        } else if skippedInstalling > 0 {
            // B-8：只跳过了正在安装的文件、其余全删干净时，也要可见地报一句。
            opMessage = L("This file is being installed. Wait until it finishes.")
            opFailed = true
            opErrorMessage = L("This file is being installed. Wait until it finishes.")
        } else if skippedSigning > 0 {
            // B1：只跳过了正在签名的文件、其余全删干净时，也要可见地报一句。
            opMessage = L("This file is being signed. Wait until it finishes.")
            opFailed = true
            opErrorMessage = L("This file is being signed. Wait until it finishes.")
        } else if skippedRenewing > 0 {
            // B5：只跳过了正在续签的文件、其余全删干净时，也要可见地报一句。
            opMessage = L("This file is being renewed. Wait until it finishes.")
            opFailed = true
            opErrorMessage = L("This file is being renewed. Wait until it finishes.")
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

    /// The rename rules, shared with the Downloads page (F3, 0.9.152):
    /// empty, `/` and leading `.` are refused; a bare IPA name gets `.ipa`
    /// back. Returns nil for an illegal name. Callers check "unchanged"
    /// themselves first — it is a silent no-op, not an error.
    static func validatedRenameName(_ raw: String, isDirectory: Bool, isIPA: Bool) -> String? {
        var newName = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, !newName.contains("/"), !newName.hasPrefix(".") else { return nil }
        // 已签 IPA 改名去后缀后，证书页清单仍留一条幽灵记录
        // （点安装必失败）：IPA 文件改名没写 .ipa 就补上。
        if !isDirectory, isIPA, !newName.lowercased().hasSuffix(".ipa") {
            newName += ".ipa"
        }
        return newName
    }

    private func performRename() {
        guard let item = renameItem else { return }
        renameItem = nil
        // B-8：正在安装的源文件不改名——改名框先收起（renameItem = nil 在前），
        // 再立失败 alert，不跟改名框抢 present。
        guard !engine.isInstallingSource(path: item.url.path) else {
            opErrorMessage = L("This file is being installed. Wait until it finishes.")
            opMessage = L("This file is being installed. Wait until it finishes.")
            opFailed = true
            return
        }
        // B1+B5：正在签名/续签的源文件不改名——签名步/续签步正读它。
        guard !rejectIfBusySigningOrRenewing(path: item.url.path) else { return }
        // B-38-B5：保留文件夹（根目录下的 Signed / Custom）不改名/不移动——改名/移走后
        // 清单按写死路径找文件，整库瞬间不可见。
        if item.isDirectory && item.relativeDir.isEmpty && (item.name == "Signed" || item.name == "Custom") {
            opErrorMessage = L("This folder can't be renamed or moved.")
            opMessage = L("This folder can't be renamed or moved.")
            opFailed = true
            return
        }
        var newName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard newName != item.name else { return }
        // B4 (0.9.153): same as createFolder — an illegal name used to
        // close the alert and do nothing. Say why instead. (An unchanged
        // name above stays a silent no-op: it isn't illegal.)
        guard let validated = Self.validatedRenameName(renameText, isDirectory: item.isDirectory,
                                                       isIPA: item.url.pathExtension.lowercased() == "ipa") else {
            opMessage = L("Names can't be empty, contain /, or start with .")
            opFailed = true
            return
        }
        newName = validated
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
                refreshFiles(resetDir: true)
            }
            resetCurrentDirIfNeeded()
            // B-4：改名后刷新续签缓存与应用库列表，角标立即跟新名。
            renewalSources = RenewalSourceStore.load()
            refreshUnsignedIPAs()
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
        // C-2：产物名本地化（Archive.zip / Archive 2.zip），计数器循环原样。
        let archiveStem = L("Archive")
        var out = root.appendingPathComponent(archiveStem + ".zip")
        var counter = 2
        while FileManager.default.fileExists(atPath: out.path) {
            out = root.appendingPathComponent("\(archiveStem) \(counter).zip")
            counter += 1
        }
        runZip(paths: items.map { $0.url }, out: out)
        selection = []
        selecting = false
    }

    private func runZip(paths: [URL], out: URL) {
        // B-38-B4：同 duplicate ——入口串行守卫，同时盖住 zipSingle 与 zipSelection 两路。
        guard !opBusy else { return }
        opBusy = true
        opMessage = nil
        Task {
            let error = await Task.detached {
                FileZipTool.zip(paths: paths, to: out)
            }.value
            opBusy = false
            refreshFiles()
            if let error {
                LogStore.shared.append("压缩失败：\(error)")
                opMessage = friendlyRustError(error)
                opFailed = true
            } else {
                opMessage = L("已压缩到 %@", out.lastPathComponent)
                opFailed = false
            }
        }
    }

    /// F2 (0.9.151): install every selected IPA, one after another, each
    /// through the single-install path (`Engine.installOneCustomIPA`:
    /// import + sign + install). Refusals mirror batchSign's: a run
    /// already going, a signing run, or an import in flight all refuse
    /// up front instead of failing item by item. The targets are captured
    /// at tap time; progress is the batch row in selectionBar, cancellation
    /// is the batch Task + engine.cancelOneClick (the row's Cancel button).
    /// The summary names every failure with its reason (past 5, only the
    /// count is kept); non-IPA selections are skipped and counted, never
    /// installed. A stopped outcome (the run never started, or a cancel)
    /// ends the batch — the items after it are listed with the same reason,
    /// not silently dropped.
    private func installSelection() {
        guard batchInstallTask == nil else { return }
        let targets = selectionIPAs
        guard !targets.isEmpty else { return }
        if engine.isRunning {
            opMessage = L("已有安装在进行，先等当前安装完成再批量安装。")
            opFailed = true
            return
        }
        if workspace.batchBusy || workspace.signBusy {
            opMessage = L("正在签名，等它跑完再批量安装。")
            opFailed = true
            return
        }
        if engine.isImportingIPA {
            opMessage = L("An import is already running. Wait for it to finish, then try again.")
            opFailed = true
            return
        }
        let skipped = selection.count - targets.count
        // 批量签名的 batchBusy 也是批量安装的互斥锁：入口立起来，批量
        // 签名在批量安装跑着时进不来（batchSign 入口认它）。
        workspace.batchBusy = true
        batchInstallTotal = targets.count
        batchInstallIndex = 0
        batchInstallCurrent = nil
        opMessage = nil
        batchInstallTask = Task { @MainActor in
            var outcomes: [Engine.BatchInstallOutcome] = []
            var stopped = false
            for (offset, item) in targets.enumerated() {
                if Task.isCancelled || stopped { break }
                batchInstallIndex = offset + 1
                batchInstallCurrent = (item.name as NSString).deletingPathExtension
                let outcome = await engine.installOneCustomIPA(item.url)
                outcomes.append(outcome)
                stopped = outcome.stopped
            }
            // 没跑到的各项：停批的原因同样记一条，不静默丢掉。
            if outcomes.count < targets.count {
                let reason = outcomes.last?.error ?? L("Install stopped")
                for item in targets[outcomes.count...] {
                    outcomes.append(Engine.BatchInstallOutcome(
                        name: (item.name as NSString).deletingPathExtension,
                        error: reason, stopped: true))
                }
            }
            batchInstallTask = nil
            batchInstallCurrent = nil
            batchInstallTotal = 0
            batchInstallIndex = 0
            workspace.batchBusy = false
            selection = []
            selecting = false
            let ok = outcomes.filter { $0.error == nil }.count
            let failed = outcomes.filter { $0.error != nil }
            var message: String
            if failed.isEmpty {
                message = L("批量安装完成：%d 个已安装。", ok)
            } else {
                let shown = failed.prefix(5).map { outcome in
                    "\(outcome.name)：\(outcome.error ?? "")"
                }
                var list = shown.joined(separator: "、")
                if failed.count > 5 {
                    list += "、" + L("等 %d 个", failed.count - 5)
                }
                message = L("批量安装完成：成功 %d 个，失败 %d 个。失败：%@", ok, failed.count, list)
            }
            if skipped > 0 {
                message += " " + L("其中 %d 个不是 IPA，已跳过。", skipped)
            }
            opMessage = message
            opFailed = !failed.isEmpty
        }
    }

    /// F2: stop the batch install — cancel the batch Task (the loop stops
    /// after the current item) and the running install itself (the row's
    /// Cancel button 同款：engine.cancelOneClick).
    private func cancelBatchInstall() {
        batchInstallTask?.cancel()
        engine.cancelOneClick()
    }

    private func unzip(_ item: LocalFileItem) {
        // B-38-B4：同 duplicate ——入口串行守卫。
        guard !opBusy else { return }
        let stem = item.url.deletingPathExtension().lastPathComponent
        let dest = uniqueSibling(of: item, stem: L("%@ (extracted)", stem), ext: "")
        opBusy = true
        opMessage = nil
        Task {
            let error = await Task.detached {
                FileZipTool.unzip(archive: item.url, to: dest)
            }.value
            opBusy = false
            refreshFiles()
            if let error {
                LogStore.shared.append("解压失败：\(error)")
                opMessage = friendlyRustError(error)
                opFailed = true
            } else {
                opMessage = L("已解压到 %@", dest.lastPathComponent)
                opFailed = false
            }
        }
    }

    /// 文件页（Documents 管理）原样保留；这里只是证书页里的
    /// 一个应用库切栏：未签名栏复用文件库数据（只读展示 +
    /// 点进签名），已签名栏就是原来的已签名列表。
    private var libraryContentView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "square.stack")
                    .foregroundStyle(Theme.muted)
                Text(L("应用库"))
                    .font(.headline)
                Spacer()
                // 选择改顶栏右上按钮（原来在“共 N 个”计数行里，计数行已删）：
                // 未签名栏切批量签名、已签名栏切批量删除，记录段没有选择。
                if libraryTab != .log {
                    Button {
                        if libraryTab == .unsigned {
                            batchingUnsigned.toggle()
                            if !batchingUnsigned { selectedUnsignedIDs.removeAll() }
                        } else {
                            selectingSigned.toggle()
                            if !selectingSigned { selectedSignedIDs.removeAll() }
                        }
                    } label: {
                        Text((libraryTab == .unsigned ? batchingUnsigned : selectingSigned) ? L("Done") : L("选择"))
                            .font(.footnote)
                    }
                    .disabled(libraryTab == .unsigned ? workspace.batchBusy : false)
                }
                // 应用库页内直接导入（轻松签应用页同款入口）：
                // 复用签名段的文件导入 picker，选完走 workspace 交接
                // 进设置·企业证书页；“从文件库选择”不在这里重复——
                // 未签名栏本身就是文件库，点行就进签名。
                Button {
                    showIPAPicker = true
                } label: {
                    Text(L("Import"))
                        .font(.footnote)
                }
            }
            Picker("", selection: $libraryTab) {
                Text(L("未签名")).tag(CertLibraryTab.unsigned)
                Text(L("已签名")).tag(CertLibraryTab.signed)
            }
            .pickerStyle(.menu)
            // 轻松签应用页同款搜索框，两个切栏都按名字过滤。
            SearchBar(text: $librarySearchText, placeholder: L("搜索"))
            libraryContent
            // 记录段不在切栏里了，页尾留一行入口（切到记录段后本行隐藏，点切栏回未签名/已签名）。
            if libraryTab != .log {
                Button {
                    libraryTab = .log
                } label: {
                    HStack {
                        Text(L("记录"))
                            .font(.footnote)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Theme.muted)
                            .font(.footnote)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .alert(L("删除这个已签名 IPA？"), isPresented: $showingDeleteConfirm) {
            Button(L("Delete"), role: .destructive) {
                if let record = recordPendingDelete {
                    // B-8：正在安装的已签名 IPA 不删——删了签名步读不到文件。
                    // B1+B5：正在签名/续签的同样不删。
                    if engine.isInstallingSource(path: SignedIPAStore.url(for: record).path) {
                        opErrorMessage = L("This file is being installed. Wait until it finishes.")
                        opMessage = L("This file is being installed. Wait until it finishes.")
                        opFailed = true
                    } else if engine.isSigningSource(path: SignedIPAStore.url(for: record).path) {
                        opErrorMessage = L("This file is being signed. Wait until it finishes.")
                        opMessage = L("This file is being signed. Wait until it finishes.")
                        opFailed = true
                    } else if engine.isRenewingSource(path: SignedIPAStore.url(for: record).path) {
                        opErrorMessage = L("This file is being renewed. Wait until it finishes.")
                        opMessage = L("This file is being renewed. Wait until it finishes.")
                        opFailed = true
                    } else {
                        SignedIPAStore.remove(record)
                        signedRecords = SignedIPAStore.load()
                    }
                }
                recordPendingDelete = nil
            }
            Button(L("Cancel"), role: .cancel) {
                recordPendingDelete = nil
            }
        } message: {
            Text(L("会删掉文件和这条记录，之后要重签才能再装。"))
        }
        .alert(L("删除选中的已签名 IPA？"), isPresented: $showingBatchDeleteConfirm) {
            Button(L("Delete"), role: .destructive) {
                let targets = signedRecords.filter { selectedSignedIDs.contains($0.id) }
                // B-8：正在安装的跳过不删（与单删同动作），其余照常删。
                // B1+B5：正在签名/续签的同样跳过。
                var blocked = false
                var blockedSigning = false
                var blockedRenewing = false
                let deletable = targets.filter { record in
                    if engine.isInstallingSource(path: SignedIPAStore.url(for: record).path) {
                        blocked = true
                        return false
                    }
                    if engine.isSigningSource(path: SignedIPAStore.url(for: record).path) {
                        blockedSigning = true
                        return false
                    }
                    if engine.isRenewingSource(path: SignedIPAStore.url(for: record).path) {
                        blockedRenewing = true
                        return false
                    }
                    return true
                }
                if !deletable.isEmpty {
                    SignedIPAStore.remove(deletable)
                }
                signedRecords = SignedIPAStore.load()
                selectedSignedIDs.removeAll()
                selectingSigned = false
                if blocked {
                    opErrorMessage = L("This file is being installed. Wait until it finishes.")
                    opMessage = L("This file is being installed. Wait until it finishes.")
                    opFailed = true
                } else if blockedSigning {
                    opErrorMessage = L("This file is being signed. Wait until it finishes.")
                    opMessage = L("This file is being signed. Wait until it finishes.")
                    opFailed = true
                } else if blockedRenewing {
                    opErrorMessage = L("This file is being renewed. Wait until it finishes.")
                    opMessage = L("This file is being renewed. Wait until it finishes.")
                    opFailed = true
                }
            }
            Button(L("Cancel"), role: .cancel) {}
        } message: {
            Text(L("一次删掉选中的 %d 个，文件和记录一起删。", selectedSignedIDs.count))
        }
    }

    /// switch 返回两种不同 View，普通函数必须加 @ViewBuilder
    /// 才能编（body 自带，普通函数没有）。
    @ViewBuilder
    private var libraryContent: some View {
        switch libraryTab {
        case .unsigned:
            unsignedList
        case .signed:
            signedList
        case .log:
            logList
        }
    }

    /// 未签名栏：文件库里还没签过的 IPA（Signed 目录里的已签
    /// 成品不算未签名）。只读展示名字、目录、大小，不逐行解
    /// Info.plist（证书页每敲一键都重读是已知性能坑）；点
    /// 「去签名」就进签名段表单。扁平列表，不按目录分组。
    private var unsignedList: some View {
        VStack(alignment: .leading, spacing: 12) {
            // A-5(a)：ForEach 外求一次存局部量，不再每行重建数组。
            let list = filteredUnsigned
            if list.isEmpty {
                Text(librarySearchText.isEmpty
                     ? L("文件库里还没有没签过的 IPA。去文件页导入一个，或者去设置里的企业证书页点「从文件导入」。")
                     : L("没有匹配的 IPA。"))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            } else {
                if batchingUnsigned {
                    HStack(spacing: 12) {
                        Button {
                            CZFHaptics.impact()
                            selectedUnsignedIDs = Set(list.map { $0.id })
                        } label: {
                            Text(L("Select all")).font(.footnote)
                        }
                        Button {
                            CZFHaptics.impact()
                            selectedUnsignedIDs.removeAll()
                        } label: {
                            Text(L("取消全选")).font(.footnote)
                        }
                        Spacer()
                        Button {
                            CZFHaptics.impact()
                            batchSign()
                        } label: {
                            Text(L("签名选中（%d）", selectedUnsignedIDs.count)).font(.footnote)
                        }
                        .disabled(selectedUnsignedIDs.isEmpty || workspace.batchBusy || engine.isImportingIPA)
                        .alert(L("签名提醒"), isPresented: $showingBatchWarningAlert) {
                            Button(L("继续签名")) {
                                runBatchSign(targets: pendingBatchTargets, mods: pendingBatchMods)
                                clearPendingBatch()
                            }
                            Button(L("Cancel"), role: .cancel) {
                                clearPendingBatch()
                                // 批量忙标志在 batchSign 入口就立起来了，取消
                                // 时这里放掉；确认那路 runBatchSign 自己接管，
                                // 跑完才放，不在这里清。
                                workspace.batchBusy = false
                            }
                        } message: {
                            Text(pendingBatchWarnings.joined(separator: "\n"))
                        }
                    }
                    if let batchMessage {
                        Text(batchMessage)
                            .font(.footnote)
                            .foregroundStyle(batchFailed ? Theme.negative : Theme.positive)
                    }
                }
                ForEach(list) { item in
                    unsignedRow(item)
                    if item.id != list.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    /// 搜索过滤只读缓存：名字命中文件名或解析出的 App 名都算，
    /// 敲键绝不触发解析（解析只在切栏/进页/签完刷新时跑一次）。
    private var filteredUnsigned: [LocalFileItem] {
        guard !librarySearchText.isEmpty else { return unsignedIPAs }
        let query = librarySearchText.lowercased()
        return unsignedIPAs.filter { item in
            // A-37-2：key + 查表每项只求一次（原来名字、Bundle ID 各求一遍）。
            let info = unsignedInfo[unsignedInfoKey(for: item)]
            return item.name.lowercased().contains(query)
                || (info?.name.lowercased().contains(query) == true)
                || (info?.bundleID.lowercased().contains(query) == true)
        }
    }

    /// 轻松签应用页未签名行：名字 / V版本 | 大小 | Bundle ID / 文件名，
    /// 整行可点进签名段表单（不要行内按钮）。
    private func unsignedRowTexts(_ item: LocalFileItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(unsignedDisplayName(item))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(unsignedSecondLine(item))
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
            Text(item.name)
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// if 两分支是两种不同 View，普通函数必须加 @ViewBuilder
    ///（跟 libraryContent 的 switch 同例，不加编不过）。
    @ViewBuilder
    private func unsignedRow(_ item: LocalFileItem) -> some View {
        if batchingUnsigned {
            Button {
                if selectedUnsignedIDs.contains(item.id) {
                    selectedUnsignedIDs.remove(item.id)
                } else {
                    selectedUnsignedIDs.insert(item.id)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: selectedUnsignedIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedUnsignedIDs.contains(item.id) ? Theme.accent : Theme.muted)
                    libraryIcon(for: item.url.path, signed: false)
                    unsignedRowTexts(item)
                }
            }
            .buttonStyle(.plain)
            .task(id: "\(item.url.path)#\(item.size)#\(item.modified?.timeIntervalSince1970 ?? 0)") { loadLibraryIcon(for: item.url.path, signed: false, fingerprint: item.modified.map { "\(item.size)-\($0.timeIntervalSince1970)" }) }
        } else {
            Button {
                workspace.selectedIPA = item.url
                workspace.openEnterpriseSign = true
            } label: {
                HStack(spacing: 10) {
                    libraryIcon(for: item.url.path, signed: false)
                    unsignedRowTexts(item)
                }
            }
            .buttonStyle(.plain)
            .task(id: "\(item.url.path)#\(item.size)#\(item.modified?.timeIntervalSince1970 ?? 0)") { loadLibraryIcon(for: item.url.path, signed: false, fingerprint: item.modified.map { "\(item.size)-\($0.timeIntervalSince1970)" }) }
        }
    }

    /// 批量签名：只签名不安装（一次装多个做不出来，跟多开同理），
    /// 逐个签进「已签名」；签名段表单的改动批量同样带上（见 batchSign）。
    /// 批量签名：先在后台跑单签同一组签前检查（掉签、未脱壳），
    /// 有警告先弹一次汇总确认，点继续才签；没警告直接签。
    /// 吊销状态读上次手动检查的结果——没查过就不警告，不猜。
    private func batchSign() {
        guard !workspace.batchBusy, !selectedUnsignedIDs.isEmpty else { return }
        guard EnterpriseCertStore.ready else {
            // 应用库页没有“上方证书组”（证书组在签名页顶部），
            // 原文案会把用户指到不存在的地方：改指签名页。
            batchMessage = L("先去设置里的企业证书页，把证书、描述文件和密码备齐。")
            batchFailed = true
            return
        }
        // 与单签互斥（见 S2）：单签跑着、或 Engine 安装跑着时
        // 不进批量，否则两路撞同一个输出文件。忙标志在入口就
        // 立起来（不只在 runBatchSign 里），否则脱壳预检那几秒
        // 窗口里单签还能进来，两路照样撞上。
        if workspace.signBusy {
            batchMessage = L("正在签名，等它跑完再批量签名。")
            batchFailed = true
            return
        }
        if engine.isRunning {
            batchMessage = L("已有安装在进行，先等当前安装完成再批量签名。")
            batchFailed = true
            return
        }
        // B-51-B3：导入进行中不批量签——下载完 copyImport 会删掉旧导入文件。
        if engine.isImportingIPA {
            batchMessage = L("An import is already running. Wait for it to finish, then try again.")
            batchFailed = true
            return
        }
        let targets = unsignedIPAs.filter { selectedUnsignedIDs.contains($0.id) }
        guard !targets.isEmpty else { return }
        workspace.batchBusy = true
        batchMessage = nil
        // 签名段表单的改动（插件、最低系统版本、图标等）批量同样带上，
        // 与单签 startSign 一致；但名字/Bundle ID/版本是单 App 身份，
        // 批量目标各有自己的值，表单里手填的自定义值不能盖到全部目标上，
        // 这里清掉只留跨 App 通用项；打包名同理（不然全部产物共用
        // 同一主名、只靠 2、3… 序号区分，文件名跟 App 对不上）；
        // 包成 let，避免 var 被 Task.detached 捕获。
        let mods: CertSignMods = {
            var m = CertSignMods()
            m.name = ""
            m.bundleID = ""
            m.version = ""
            m.outputName = ""
            return m
        }()
        let urls = targets.map { $0.url }
        Task.detached(priority: .userInitiated) {
            var undumpedURLs: [URL] = []
            for url in urls {
                // 按 IPA 粒度判定：包里任一 .app 未脱壳即该 IPA
                // 未脱壳（见 SS2），不再只看第一个 .app。
                if let undumped = IPADecryptionCheck.undumpedAppsFast(of: url) ?? IPADecryptionCheck.undumpedApps(of: url), !undumped.isEmpty {
                    undumpedURLs.append(url)
                }
            }
            await MainActor.run {
                var warnings: [String] = []
                if self.revocationStatus == .revoked {
                    warnings.append(L("证书已经掉签，签名后可能无法安装。"))
                }
                if !undumpedURLs.isEmpty {
                    let names = undumpedURLs.compactMap { url in
                        targets.first(where: { $0.url == url }).map { self.unsignedDisplayName($0) }
                    }
                    if !names.isEmpty {
                        warnings.append(L("以下程序未脱壳，签名后可能无法安装，建议重新脱壳签名：%@", names.joined(separator: "、")))
                    }
                }
                if let expiry = self.expiryWarningText() {
                    warnings.append(expiry)
                }
                if warnings.isEmpty {
                    self.runBatchSign(targets: targets, mods: mods)
                } else {
                    self.pendingBatchWarnings = warnings
                    self.pendingBatchTargets = targets
                    self.pendingBatchMods = mods
                    self.showingBatchWarningAlert = true
                }
            }
        }
    }

    private func clearPendingBatch() {
        pendingBatchWarnings = []
        pendingBatchTargets = []
        pendingBatchMods = CertSignMods()
    }

    /// 批量签名执行：只签名不安装；每项各签一次，多开不展开
    ///（多开只对单签的「仅签名」生效，见 multiOpenSection 注释，
    /// batchSign 本来就不走 multiCount，这里也不新开行为）。
    private func runBatchSign(targets: [LocalFileItem], mods: CertSignMods) {
        // B-51-B3：批量警告框"继续签名"直接调这里，绕过 batchSign——入口再拦
        // 一道。batchSign 在警告预检前已把 batchBusy 立起来，拒掉时这里放掉。
        guard !engine.isImportingIPA else {
            workspace.batchBusy = false
            batchMessage = L("An import is already running. Wait for it to finish, then try again.")
            batchFailed = true
            return
        }
        workspace.batchBusy = true
        // B1：批量签名在跑时把目标路径登记进 Engine，文件页/LAN/WebDAV
        // 的删/移/改名入口会拒掉这些源；收尾 MainActor.run 里注销。
        for item in targets { engine.signingSourcePaths.insert(item.url.path) }
        batchMessage = nil
        Task {
            var ok = 0
            var fail = 0
            var firstError: String?
            for item in targets {
                do {
                    _ = try await CertSigner.signToFile(ipa: item.url, mods: mods)
                    CertSignLogStore.append(CertSignLogEntry(id: UUID(), date: Date(),
                        appName: unsignedDisplayName(item), kind: .batch, success: true,
                        detail: L("已存到「已签名」")))
                    ok += 1
                } catch {
                    fail += 1
                    let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
                    if firstError == nil { firstError = message }
                    CertSignLogStore.append(CertSignLogEntry(id: UUID(), date: Date(),
                        appName: unsignedDisplayName(item), kind: .batch, success: false,
                        detail: message))
                }
            }
            await MainActor.run {
                self.signedRecords = SignedIPAStore.load()
                self.refreshUnsignedIPAs {
                    self.selectedUnsignedIDs = self.selectedUnsignedIDs.intersection(self.unsignedIPAs.map { $0.id })
                }
                self.logEntries = CertSignLogStore.load()
                // B1：批量签名收尾，注销目标路径（与入口登记配对）。
                for item in targets { self.engine.signingSourcePaths.remove(item.url.path) }
                self.workspace.batchBusy = false
                if fail == 0 {
                    self.batchMessage = L("批量签完：%d 个已存到「已签名」。", ok)
                    self.batchFailed = false
                } else {
                    var message = L("批量签完：成功 %d 个，失败 %d 个。", ok, fail)
                    if let firstError { message += " " + friendlySignError(firstError) }
                    self.batchMessage = message
                    self.batchFailed = true
                }
            }
        }
    }

    private var logList: some View {
        VStack(alignment: .leading, spacing: 12) {
            if logEntries.isEmpty {
                Text(L("还没有签名记录。签一次就会记一条，成功失败都有。"))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            } else {
                HStack(spacing: 12) {
                    Text(L("共 %d 条", logEntries.count))
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Button { showingLogClearConfirm = true } label: {
                        Text(L("清空")).font(.footnote)
                    }
                }
                ForEach(logEntries) { entry in
                    logRow(entry)
                    if entry.id != logEntries.last?.id { Divider() }
                }
            }
        }
        .alert(L("清空签名记录？"), isPresented: $showingLogClearConfirm) {
            Button(L("清空"), role: .destructive) {
                CertSignLogStore.clear()
                logEntries = []
            }
            Button(L("Cancel"), role: .cancel) {}
        } message: {
            Text(L("只删记录，不动已签名的 IPA 文件。"))
        }
    }

    /// 签名日志行：跟已签名行同款格式（真实图标 + 名 + 成功/失败、
    /// 种类·日期、detail 最多两行）。记录本身只存名字（不改
    /// CertSignLogEntry 结构、不迁移旧日志）：图标按 appName 匹
    /// 配首个同名已签名记录取已签名行那套解析（SignedIPAStore
    /// 路径 + loadLibraryIcon，.task 触发）；匹配不上就走中性
    /// 占位——宁可占位，不造假图、不空行。
    private func logRow(_ entry: CertSignLogEntry) -> some View {
        let iconPath = signedRecords.first(where: { $0.appName == entry.appName })
            .map { SignedIPAStore.url(for: $0).path } ?? ""
        return HStack(alignment: .top, spacing: 10) {
            libraryIcon(for: iconPath, signed: true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(entry.appName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(entry.success ? L("成功") : L("Failed"))
                        .font(.caption)
                        .foregroundStyle(entry.success ? Theme.positive : Theme.negative)
                }
                Text("\(logKindText(entry.kind)) · \(Self.logDateFormatter.string(from: entry.date))")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                if !entry.detail.isEmpty {
                    Text(entry.detail)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(2)
                }
            }
        }
        .task(id: iconPath) {
            guard !iconPath.isEmpty else { return }
            loadLibraryIcon(for: iconPath, signed: true)
        }
    }

    private func logKindText(_ kind: CertSignLogKind) -> String {
        switch kind {
        case .signOnly: return L("仅签名")
        case .signAndInstall: return L("签名并安装")
        case .batch: return L("批量签名")
        case .installOnly: return L("仅安装")
        }
    }

    private static let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    private func unsignedDisplayName(_ item: LocalFileItem) -> String {
        if let name = unsignedInfo[unsignedInfoKey(for: item)]?.name, !name.isEmpty {
            return name
        }
        return (item.name as NSString).deletingPathExtension
    }

    /// 第二行：V版本 | 大小 | Bundle ID；版本缺了就省掉 V 那段，
    /// 解析失败只显示大小，不造假。
    private func unsignedSecondLine(_ item: LocalFileItem) -> String {
        let size = CZFFormattedSize.size(item.size)
        guard let info = unsignedInfo[unsignedInfoKey(for: item)] else { return size }
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

    /// 未签名列表重扫：递归扫盘放 Task.detached，扫完回主线程写
    /// unsignedIPAs 再跑 ensureUnsignedInfo（它按新列表筛缓存、给
    /// 新出现的 IPA 排队解析；先写列表再跑它，顺序与同步扫盘时一致）。
    /// onRefreshed 在列表写完后、同一主线程块里跑：批量签完那处靠它
    /// 按新列表裁掉已签走的选中项（同步扫盘时 intersection 读的就是新列表）。
    /// B-3：调用时 unsignedIPAsRefreshGeneration +1 并捕获，写回前核对
    /// 代际，过期的旧扫描直接丢弃，onRefreshed 也不按旧列表跑。
    private func refreshUnsignedIPAs(onRefreshed: (() -> Void)? = nil) {
        unsignedIPAsRefreshGeneration += 1
        let generation = unsignedIPAsRefreshGeneration
        // A-3：files 已有同一棵树的扫描结果，直接派生，不再整树重扫；
        // 冷启动兜底：files 还空（refreshFiles 的 detached 扫描没落地）
        // 才走一次旧的扫盘路径，免得进页即空列表。
        if !files.isEmpty {
            unsignedIPAs = files.filter { $0.isIPA && !$0.isInSignedDir }
            ensureUnsignedInfo()
            onRefreshed?()
            return
        }
        Task.detached {
            let items = AppFileLibrary.scan().filter { $0.isIPA && !$0.isInSignedDir }
            await MainActor.run {
                guard generation == self.unsignedIPAsRefreshGeneration else { return }
                unsignedIPAs = items
                ensureUnsignedInfo()
                onRefreshed?()
            }
        }
    }

    /// 未签名栏的 IPA 信息只解析一次：切到未签名栏/进页/签完刷新时，
    /// 把还没试过的路径在后台统一解析，结果按路径缓存；解析失败也记
    /// 已尝试，不重复读盘。删掉的路径清掉缓存，免得同名新文件沿用旧信息。
    private func ensureUnsignedInfo() {
        // C30/A-5(b)：缓存键是“路径#指纹”（大小 + 修改时间，取自
        // LocalFileItem 自带字段，不读盘）：同路径文件被替换后 key 变了，旧信息被
        // 下面的过滤清掉、重新排队解析，不再沿用旧名字/版本/Bundle ID。
        // 图标路（unsignedIconsTried）早就是这个键，信息路补齐。
        let current = Set(unsignedIPAs.map { unsignedInfoKey(for: $0) })
        unsignedInfo = unsignedInfo.filter { current.contains($0.key) }
        unsignedInfoTried = unsignedInfoTried.intersection(current)
        let pending = unsignedIPAs.filter { !unsignedInfoTried.contains(unsignedInfoKey(for: $0)) }
        guard !pending.isEmpty else { return }
        for item in pending { unsignedInfoTried.insert(unsignedInfoKey(for: item)) }
        let keys = pending.map { unsignedInfoKey(for: $0) }
        let itemByKey = Dictionary(uniqueKeysWithValues: zip(keys, pending))
        let urls = pending.map { $0.url }
        Task.detached(priority: .userInitiated) {
            var found: [String: IPALibrary.AppInfo] = [:]
            for (url, key) in zip(urls, keys) {
                if let info = IPALibrary.appInfo(at: url) {
                    found[key] = info
                }
            }
            await MainActor.run {
                for (key, info) in found {
                    // C30（B12-6 同款核对）：解析途中文件被替换、key 已变
                    // 时丢掉旧结果；tried 集里仍是旧 key，下一轮重排。
                    guard let item = itemByKey[key], self.unsignedInfoKey(for: item) == key else { continue }
                    self.unsignedInfo[key] = info
                }
            }
        }
    }

    /// 应用库行图标：IPA 里取的真实图标（大圆角 52pt）；还没取到或
    /// 取不到时显示中性灰圆角方块（不是假 App 图，只占位）。
    @ViewBuilder
    private func libraryIcon(for path: String, signed: Bool) -> some View {
        // A-37-3：读 iconEpoch 建立依赖——图标本体在共享缓存里，
        // 批量写回只 bump epoch、不写 @State；不读它，body 不会
        // 重算，图就永远不出现。别把这行当死代码清掉。
        let _ = iconEpoch
        if let image = ThumbnailCache.image(for: path) {
            Image(uiImage: image)
                .resizable()
                .frame(width: 60, height: 60)
                .cornerRadius(Theme.controlRadius)
        } else {
            RoundedRectangle(cornerRadius: Theme.controlRadius)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 60, height: 60)
        }
    }

    /// 行内图标加载（只取可见行，行 .task 触发）：key 已尝试直接跳过
    /// （含取失败，不重复解包）；文件变了 key 就变，先清旧图再取，
    /// 不让旧图标冒充新文件。解包只取图标文件，不整包解压。
    /// A-37-1：调用方有大小/修改时间快照时传 fingerprint（未签名行传
    /// LocalFileItem 的 size/modified），不再主线程 stat 磁盘；没快照
    /// 的调用方（已签名行、日志行）不传，走现查。
    private func loadLibraryIcon(for path: String, signed: Bool, fingerprint: String? = nil) {
        let key = "\(path)#\(fingerprint ?? iconFingerprint(for: path))"
        if signed {
            guard !signedIconsTried.contains(key) else { return }
            signedIconsTried.insert(key)
            // A-37-3：清共享缓存里的旧图 + bump epoch（行回占位，等新图）。
            ThumbnailCache.remove(path)
            iconEpoch += 1
            // A-5(c)：批量写回懒建（首次加载时立一次，此后复用）。
            if librarySignedIconBatcher == nil {
                librarySignedIconBatcher = BatchWriteback { batch in
                    for (path, image) in batch { ThumbnailCache.set(image, for: path) }
                    self.iconEpoch += 1
                }
            }
        } else {
            guard !unsignedIconsTried.contains(key) else { return }
            unsignedIconsTried.insert(key)
            // A-37-3：清共享缓存里的旧图 + bump epoch（行回占位，等新图）。
            ThumbnailCache.remove(path)
            iconEpoch += 1
            if libraryUnsignedIconBatcher == nil {
                libraryUnsignedIconBatcher = BatchWriteback { batch in
                    for (path, image) in batch { ThumbnailCache.set(image, for: path) }
                    self.iconEpoch += 1
                }
            }
        }
        let url = URL(fileURLWithPath: path)
        Task.detached(priority: .userInitiated) { [key] in
            guard let data = IPALibrary.iconData(at: url),
                  // A-7：下采样在 detached 里做——行高 60pt，用 120×120 缩略图。
                  let image = IPALibrary.thumbnail(from: data, maxPixelSize: 120) else { return }
            // A-12：C30 核对从 MainActor.run 里移出来——attributesOfItem 磁盘 stat
            // 在 detached 里做，解码途中文件被替换、key 已变时丢掉旧图；新 key 的
            // 任务会重取，不钉住错图。MainActor.run 内只剩批量写回。
            guard "\(path)#\(self.iconFingerprint(for: path))" == key else { return }
            await MainActor.run {
                if signed {
                    self.librarySignedIconBatcher?.enqueue(image, for: path)
                } else {
                    self.libraryUnsignedIconBatcher?.enqueue(image, for: path)
                }
            }
        }
    }

    /// C30：信息缓存键——路径 + 文件指纹；名字叫 unsignedInfoKey：
    /// infoKey 已被 MadeiraSigningHandoff.infoKey 占用。
    /// A-5(b)：指纹改取 LocalFileItem 自带的 size/modified，不再
    /// attributesOfItem 磁盘 stat；key 格式不变（"路径#大小-修改时间秒"），
    /// 图标路（loadLibraryIcon）仍走 iconFingerprint，不动。
    private func unsignedInfoKey(for item: LocalFileItem) -> String {
        "\(item.url.path)#\(item.size)-\(item.modified?.timeIntervalSince1970 ?? 0)"
    }

    /// 图标指纹：文件大小 + 修改时间（重签覆盖同路径时变）。
    /// 文件没了就返回空串，key 照样唯一，不会死循环重取。
    private func iconFingerprint(for path: String) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int,
              let modified = attrs[.modificationDate] as? Date else { return "" }
        return "\(size)-\(modified.timeIntervalSince1970)"
    }

    private var signedList: some View {
        VStack(alignment: .leading, spacing: 12) {
            // A-5(a)：ForEach 外求一次存局部量，不再每行重建数组。
            let list = filteredSigned
            if signedRecords.isEmpty {
                Text(L("还没有已签名的 IPA。用设置里企业证书页的「仅签名」签好就会存到这里，随时能装、能分享。"))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            } else if list.isEmpty {
                Text(L("没有匹配的已签名 IPA。"))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            } else {
                if selectingSigned {
                    HStack(spacing: 12) {
                        Button {
                            CZFHaptics.impact()
                            // 全选只选当前可见的（搜了就只选搜到的）。
                            selectedSignedIDs = Set(list.map { $0.id })
                        } label: {
                            Text(L("Select all"))
                                .font(.footnote)
                        }
                        Button {
                            CZFHaptics.impact()
                            selectedSignedIDs.removeAll()
                        } label: {
                            Text(L("取消全选"))
                                .font(.footnote)
                        }
                        Spacer()
                        Button {
                            CZFHaptics.impact()
                            showingBatchDeleteConfirm = true
                        } label: {
                            Text(L("删除选中（%d）", selectedSignedIDs.count))
                                .font(.footnote)
                        }
                        .disabled(selectedSignedIDs.isEmpty)
                    }
                }
                ForEach(list) { record in
                    signedRow(record)
                    if record.id != list.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func signedRow(_ record: SignedIPARecord) -> some View {
        let iconPath = SignedIPAStore.url(for: record).path
        return VStack(alignment: .leading, spacing: 6) {
            // 点行先选安装方式（配对安装 / 流量安装 OTA）；选择模式下点行改选。
            Button {
                if selectingSigned {
                    if selectedSignedIDs.contains(record.id) {
                        selectedSignedIDs.remove(record.id)
                    } else {
                        selectedSignedIDs.insert(record.id)
                    }
                } else {
                    CZFHaptics.impact(.light)
                    // OTA 0.9.104：点行先选安装方式（配对安装 / 流量安装），
                    // 不再一点就直装配对——流量安装是不用 WiFi 的主路。
                    installChoiceRecord = record
                }
            } label: {
                HStack(spacing: 10) {
                    if selectingSigned {
                        Image(systemName: selectedSignedIDs.contains(record.id)
                              ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedSignedIDs.contains(record.id) ? Theme.accent : Theme.muted)
                    }
                    libraryIcon(for: iconPath, signed: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.appName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(signedSecondLine(record))
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                        Text(record.fileName)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .task(id: "\(iconPath)#\(record.size)-\(record.date.timeIntervalSince1970)") { loadLibraryIcon(for: iconPath, signed: true) }
            // 行下按钮排已删：安装走点行选方式，分享/删除进长按菜单。
            .contextMenu {
                ShareLink(item: SignedIPAStore.url(for: record)) {
                    Label(L("分享"), systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) {
                    recordPendingDelete = record
                    showingDeleteConfirm = true
                } label: {
                    Label(L("Delete"), systemImage: "trash")
                }
            }
        }
    }

    /// 搜索过滤：名字命中 App 名或文件名都算。
    private var filteredSigned: [SignedIPARecord] {
        guard !librarySearchText.isEmpty else { return signedRecords }
        let query = librarySearchText.lowercased()
        return signedRecords.filter { record in
            record.appName.lowercased().contains(query)
                || record.fileName.lowercased().contains(query)
                || record.bundleID.lowercased().contains(query)
        }
    }

    /// 已签名行第二行（轻松签应用库同款）：V版本 | 大小 | Bundle ID；
    /// 版本缺了就省掉 V 那段（跟未签名行同例）。
    /// F-1 (0.9.165)：末尾追加到期信号——剩 N 天 / 今天到期 / 已过期，
    /// 跟 EnterpriseCertView.remainingText 同一套 key、同一套自然日
    /// 算法（remainingDays）；老记录没到期日就不显示，等
    /// fillMissingCertInfo 进页补上。
    private func signedSecondLine(_ record: SignedIPARecord) -> String {
        let size = CZFFormattedSize.size(record.size)
        var parts: [String] = []
        if let version = record.version, !version.isEmpty {
            parts.append("V\(version)")
        }
        parts.append(size)
        if !record.bundleID.isEmpty {
            parts.append(record.bundleID)
        }
        if let expiry = record.expiresAt {
            let days = remainingDays(to: expiry)
            if days < 0 {
                parts.append(L(" (expired)"))
            } else if days == 0 {
                parts.append(L("（今天到期）"))
            } else {
                parts.append(L("（剩 %d 天）", days))
            }
        }
        return parts.joined(separator: " | ")
    }

    /// 剩余天数：按自然日对齐（与已装 App 页 AppsView.daysRemaining
    /// 同一套算法，见 S7）。旧算法 dateComponents(from: Date(),
    /// to: expiry) 按不足 24 小时截断，同一到期日在企业页算 0
    /// 天、在 App 页算 1 天，两边说法打架；自然日对齐后“1 =
    /// tomorrow”，到期当天算 0 天（显示“今天到期”）。
    private func remainingDays(to expiration: Date) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: expiration)).day ?? 0
    }

    /// 签前到期警告（7 天内到期，只警告不拦截；已过期走 S4
    /// 拦截，不在这里重复报）：复用 S7 的 remainingDays（startOfDay
    /// 自然日）。单签与批量共用同一句，批量一次运行只拼一次。
    private func expiryWarningText() -> String? {
        var parts: [String] = []
        let now = Date()
        if let expiration = EnterpriseCertStore.certInfo?.expiration, expiration >= now {
            let days = remainingDays(to: expiration)
            if days <= 7 {
                parts.append(days == 0 ? L("证书今天到期") : L("证书 %d 天后到期", days))
            }
        }
        if let expiration = EnterpriseCertStore.provisionInfo?.expiration, expiration >= now {
            let days = remainingDays(to: expiration)
            if days <= 7 {
                parts.append(days == 0 ? L("描述文件今天到期") : L("描述文件 %d 天后到期", days))
            }
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "，") + L("，仍要签名吗？")
    }

    /// 签名失败文案：p12 打不开基本就是密码不对（Rust 侧原话就是
    /// “a wrong password reads the same”），按轻松签原文给中文提示，
    /// 其他错误原样透传；日志和界面用同一句，不两张皮。
    private func friendlySignError(_ message: String) -> String {
        if message.contains("PKCS#12") {
            return L("密码错误，请重新输入")
        }
        return message
    }

    /// 吊销检查放后台线程跑（信任评估可能联网 OCSP）。
    /// B-4：照抄 EnterpriseCertView.refreshCertState 的指纹守卫——调用前
    /// 抓 EnterpriseCertStore.certStateFingerprint()，写回前核对指纹未变
    /// 才写 revocationStatus/revocationCheckedAt；revocationChecking = false
    /// 复位放在守卫外（if 块之后），任何出口都复位，不卡住下次检查。
    private func checkRevocation() {
        guard !revocationChecking, EnterpriseCertStore.hasP12 else { return }
        revocationChecking = true
        let fingerprint = EnterpriseCertStore.certStateFingerprint()
        Task.detached(priority: .userInitiated) {
            let status = CertRevocationChecker.check()
            await MainActor.run {
                if fingerprint == EnterpriseCertStore.certStateFingerprint() {
                    self.revocationStatus = status
                    self.revocationCheckedAt = Date()
                }
                self.revocationChecking = false
            }
        }
    }
}

/// 文件页 IPA 切栏：未签名 / 已签名（轻松签文件列表同款）。
private enum FileListTab: Hashable {
    case unsigned
    case signed
}

/// 应用库切栏。
private enum CertLibraryTab: Identifiable, Hashable {
    case unsigned
    case signed
    case log

    var id: String {
        switch self {
        case .unsigned: return "unsigned"
        case .signed: return "signed"
        case .log: return "log"
        }
    }
}

/// 文件详情（轻松签文件列表右边的 ⓘ）：名字、大小、修改时间、路径，
/// 下面是操作（分享只对文件，文件夹是重命名/移动/复制/删除，
/// 跟行内菜单同例）。
/// 文件夹没有字节大小可言，大小那行显示“共 n 项”。
private struct FileDetailSheet: View {
    let item: LocalFileItem
    /// The IPA info the list row already parsed, if it has (nil = not an
    /// IPA, or the row hadn't parsed it yet — the sheet parses it itself).
    var ipaInfo: IPALibrary.AppInfo? = nil
    /// 是续签源时传 App 名（nil = 不是续签用的文件）。
    var renewalAppName: String? = nil
    var onDelete: () -> Void
    var onRename: () -> Void
    var onMove: () -> Void
    var onDuplicate: () -> Void
    @Environment(\.dismiss) private var dismiss
    /// F-2 (0.9.158): the row's parse, when the caller hadn't got it yet.
    @State private var parsedInfo: IPALibrary.AppInfo? = nil
    /// F-3 (0.9.163): the IPA's SHA-256 hex, hashed off the main thread
    /// once the sheet opens — nil until it lands.
    @State private var sha256: String? = nil

    /// The IPA metadata to show: the caller's parse first, the sheet's own
    /// background parse once it lands.
    private var shownIPAInfo: IPALibrary.AppInfo? { ipaInfo ?? parsedInfo }

    var body: some View {
        NavigationStack {
            List {
                detailRow(L("名字"), item.name)
                detailRow(L("Size"), item.isDirectory
                          ? L("%d 项", item.childCount)
                          : ByteCountFormatter.string(fromByteCount: Int64(item.size), countStyle: .file))
                detailRow(L("修改时间"), item.modified?.formatted(date: .abbreviated, time: .standard) ?? L("unknown"))
                detailRow(L("路径"), item.url.path, middleTruncation: true)
                // F-2 (0.9.158): the IPA's own metadata — version, Bundle
                // ID, minimum iOS — parsed already for the row's second
                // line, so this is display only, no new parsing on the
                // common path. Each value copies on long-press.
                if item.isIPA, let info = shownIPAInfo {
                    if let version = info.version, !version.isEmpty {
                        detailRow(L("Version"), version)
                    }
                    if !info.bundleID.isEmpty {
                        detailRow(L("Bundle ID"), info.bundleID)
                    }
                    if let minOS = info.minOS, !minOS.isEmpty {
                        detailRow(L("Minimum iOS"), "iOS \(minOS)")
                    }
                }
                if let renewalAppName {
                    detailRow(L("续签用的应用"), renewalAppName)
                }
                // F-3 (0.9.163): the IPA's SHA-256, so a download can be
                // checked for completeness or tampering before installing.
                // The value copies on long-press like every other row
                // (`detailRow`'s context menu); "Loading…" until the
                // background hash lands.
                if item.isIPA {
                    detailRow(L("SHA-256"), sha256 ?? L("Loading…"))
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
                        Label(L("Copy"), systemImage: "doc.on.doc")
                    }
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label(L("Delete"), systemImage: "trash")
                    }
                }
            }
            .navigationTitle(L("详情"))
            .navigationBarTitleDisplayMode(.inline)
            .blueTopBar()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("Done")) { dismiss() }
                }
            }
            // F-2 (0.9.158): the row hadn't parsed this IPA yet — parse it
            // off the main thread (`appInfo(at:)` is lock-guarded, so a
            // background read can't race the row's own parse).
            .task {
                if ipaInfo == nil, item.isIPA {
                    // Only the URL crosses into the detached task (a
                    // Sendable value); the row itself stays on this side.
                    let url = item.url
                    parsedInfo = await Task.detached { IPALibrary.appInfo(at: url) }.value
                }
                // F-3 (0.9.163): the SHA-256, hashed off the main thread —
                // a big IPA takes a moment, and `sha256(of:)` already
                // reads a megabyte at a time, so this is just the hop.
                if item.isIPA, sha256 == nil {
                    let url = item.url
                    sha256 = await Task.detached { IPALibrary.sha256(of: url) }.value
                }
            }
        }
    }

    private func detailRow(_ label: String, _ value: String, middleTruncation: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.muted)
            Text(value)
                .font(.subheadline)
                .lineLimit(2)
                .truncationMode(middleTruncation ? .middle : .tail)
                // F-2 (0.9.158): every detail value copies on long-press —
                // the metadata rows above all go through here.
                .contextMenu {
                    Button(L("Copy")) { UIPasteboard.general.string = value }
                }
        }
    }
}
