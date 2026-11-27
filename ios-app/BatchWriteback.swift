import SwiftUI

/// A-5(c)（SIDE-36）：图标 / 信息到达时的批量写回——
/// 各路 detached 任务把结果交到这里攒着，50ms 内到齐的合并成一次
/// @State 写回，不再每张图 / 每条信息各触发一次整页 body 求值。
/// 定时器到点必写，尾批不丢；“文件被替换就丢弃”的核对仍在各 load*
/// 函数的 detached 任务里做（提交前核对，见 B31-1 / C30 同款）。
///
/// 视图里用 @State 存一个实例；apply 闭包里写回对应的 @State 字典。
/// @State 的存储是引用式的，闭包里捕获的视图副本写回仍落到同一份
/// 存储，与各 load* 函数里 Task.detached + MainActor.run 的现成
/// 写法同理。flush 任务强持有本实例，视图先走了、尾批仍会写完。
@MainActor
final class BatchWriteback<Key: Hashable, Value> {
    private var pending: [Key: Value] = [:]
    private var flushTask: Task<Void, Never>?
    private let apply: ([Key: Value]) -> Void

    init(apply: @escaping ([Key: Value]) -> Void) {
        self.apply = apply
    }

    /// detached 任务里经 MainActor.run 调：只攒、不写回。
    func enqueue(_ value: Value, for key: Key) {
        pending[key] = value
        if flushTask == nil {
            flushTask = Task {
                try? await Task.sleep(for: .milliseconds(50))
                self.flush()
            }
        }
    }

    private func flush() {
        flushTask = nil
        guard !pending.isEmpty else { return }
        let batch = pending
        pending = [:]
        apply(batch)
    }
}
