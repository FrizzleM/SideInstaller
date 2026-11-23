import Foundation
import SideInstallerFFI
import SwiftUI

/// Mach-O 依赖查看/编辑：列出一个二进制（dylib / 可执行文件）
/// 的全部 dylib 加载命令，可改名、可删除（Rust 侧动手）。
enum MachOTool {
    struct Dep: Codable, Identifiable {
        let kind: String
        let name: String
        var id: String { kind + "\u{1}" + name }
    }

    struct Slice: Codable, Identifiable {
        let arch: String
        let deps: [Dep]
        let rpaths: [String]
        var id: String { arch }
    }

    struct Info: Codable {
        let fat: Bool
        let slices: [Slice]
    }

    static func info(url: URL) throws -> Info {
        var json: UnsafeMutablePointer<CChar>?
        var error: UnsafeMutablePointer<CChar>?
        let rc = url.path.withCString { p in si_macho_info(p, &json, &error) }
        defer {
            if let json { si_string_free(json) }
            if let error { si_string_free(error) }
        }
        guard rc == 0, let json else {
            throw EngineError.message(
                error.map { String(cString: $0) } ?? L("不是 Mach-O 文件"))
        }
        return try JSONDecoder().decode(Info.self, from: Data(String(cString: json).utf8))
    }

    /// 成功返回 nil，失败返回错误文本。
    static func edit(url: URL, op: [String: String]) -> String? {
        let json = (try? JSONSerialization.data(withJSONObject: op))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        var error: UnsafeMutablePointer<CChar>?
        let rc = url.path.withCString { p in
            json.withCString { j in si_macho_edit(p, j, &error) }
        }
        defer { if let error { si_string_free(error) } }
        guard rc == 0 else {
            return error.map { String(cString: $0) } ?? L("改不了")
        }
        return nil
    }
}

/// 一个文件的 Mach-O 依赖页：按架构分组列出依赖，可删、可改名。
struct MachOView: View {
    let url: URL
    let fileName: String

    @Environment(\.dismiss) private var dismiss
    @State private var info: MachOTool.Info?
    @State private var loadError: String?
    @State private var opError: String?
    @State private var renameTarget: MachOTool.Dep?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            Group {
                if let info {
                    List {
                        if let opError {
                            Text(opError)
                                .font(.footnote)
                                .foregroundStyle(Theme.negative)
                        }
                        ForEach(info.slices) { slice in
                            Section {
                                ForEach(slice.deps) { dep in
                                    depRow(dep)
                                }
                                ForEach(slice.rpaths, id: \.self) { path in
                                    HStack {
                                        tag(L("rpath"))
                                        Text(path)
                                            .font(.footnote.monospaced())
                                            .lineLimit(2)
                                    }
                                }
                                if slice.deps.isEmpty && slice.rpaths.isEmpty {
                                    Text(L("没有 dylib 依赖"))
                                        .font(.footnote)
                                        .foregroundStyle(Theme.muted)
                                }
                            } header: {
                                Text(slice.arch)
                            }
                        }
                        Section {
                            Text(L("删掉或改名后，这个文件的签名会失效：拿去注入签名时会被重新签，没问题；直接当插件用的话要先重签。装进 App 的依赖一般别乱删，删了 App 可能打不开。"))
                                .font(.footnote)
                                .foregroundStyle(Theme.muted)
                        }
                    }
                } else if let loadError {
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(Theme.muted)
                        Text(loadError)
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(30)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("Done")) { dismiss() }
                }
            }
        }
        .task { load() }
        .alert(L("改依赖名"), isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField(L("新名字"), text: $renameText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button(L("Cancel"), role: .cancel) { renameTarget = nil }
            Button(L("Save")) { performRename() }
        } message: {
            Text(L("新名字必须装得进原来的命令长度，太长会改不了。"))
        }
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(.tertiarySystemBackground))
            .clipShape(Capsule())
    }

    private func depRow(_ dep: MachOTool.Dep) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                tag(kindLabel(dep.kind))
                if dep.kind == "id" {
                    Text(L("它自己的名字"))
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
            }
            Text(dep.name)
                .font(.footnote.monospaced())
                .lineLimit(3)
        }
        .swipeActions(edge: .trailing) {
            if dep.kind != "id" {
                Button(role: .destructive) {
                    performRemove(dep)
                } label: {
                    Label(L("Delete"), systemImage: "trash")
                }
            }
            Button {
                renameText = dep.name
                renameTarget = dep
            } label: {
                Label(L("改名"), systemImage: "pencil")
            }
            .tint(Theme.blue)
        }
    }

    private func kindLabel(_ kind: String) -> String {
        switch kind {
        case "load": return L("依赖")
        case "weak": return L("弱依赖")
        case "reexport": return L("转发")
        case "upward": return L("上行")
        case "id": return L("本名")
        default: return kind
        }
    }

    private func load() {
        let target = url
        Task {
            do {
                info = try await Task.detached { try MachOTool.info(url: target) }.value
            } catch {
                loadError = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
            }
        }
    }

    private func performRemove(_ dep: MachOTool.Dep) {
        let target = url
        Task {
            let error = await Task.detached {
                MachOTool.edit(url: target, op: ["action": "remove", "name": dep.name])
            }.value
            opError = error
            if error == nil { load() }
        }
    }

    private func performRename() {
        guard let dep = renameTarget else { return }
        renameTarget = nil
        let newName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != dep.name else { return }
        let target = url
        Task {
            let error = await Task.detached {
                MachOTool.edit(url: target, op: ["action": "rename", "name": dep.name, "newName": newName])
            }.value
            opError = error
            if error == nil { load() }
        }
    }
}
