import Foundation

/// 共享的 ByteCountFormatter——行上每求值现建 formatter 是固定税
///（SIDE-38 A4 的 Date.FormatStyle 同类毛病）。ByteCountFormatter
/// 不是线程安全的，只许主线程调（下面 7 处全在主线程 body 里）。
enum CZFFormattedSize {
    static let byteCount: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()
    static func size(_ bytes: Int) -> String {
        byteCount.string(fromByteCount: Int64(bytes))
    }
}
