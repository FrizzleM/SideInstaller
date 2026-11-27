import AVFAudio
import CoreLocation
import Foundation
import UIKit

/// Keeps the app running in the background with silent audio (and optionally
/// background location), e.g. while the user approves the pairing PIN in
/// Settings or while a location is being simulated.
///
/// iOS stops the audio by itself at times: a call, Siri or an alarm
/// interrupts it, a new output such as AirPods connecting stops the engine,
/// and a media services reset leaves it dead. With nothing playing, iOS
/// suspends the app within seconds, mid-pairing, so the audio starts again
/// after each of these.
@MainActor
final class KeepAlive: NSObject {

    /// Both replaced after a media services reset, which leaves the old ones dead.
    private var engine = AVAudioEngine()
    private var player = AVAudioPlayerNode()
    /// From `startAudio` to `stopAudio`, also while something has stopped the
    /// engine and it waits to play again.
    private var audioRunning = false
    /// A call, Siri or an alarm has the audio. iOS lets it play again once
    /// that ends.
    private var interrupted = false
    private var observers: [NSObjectProtocol] = []
    /// Tries again after a restart iOS refused.
    private var retry: Task<Void, Never>?
    /// How many keep-alives play now. The pairing and a simulated location
    /// share the app's one audio session, so only the last to stop lets it go.
    private static var audioHolders = 0

    func startAudio() {
        guard !audioRunning else { return }
        guard play() else {
            if Self.audioHolders == 0 { Self.releaseSession() }
            return
        }
        audioRunning = true
        Self.audioHolders += 1
        observeAudio()
    }

    func stopAudio() {
        guard audioRunning else { return }
        audioRunning = false
        interrupted = false
        retry?.cancel()
        retry = nil
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers = []
        silence()
        if player.engine != nil { engine.detach(player) }
        Self.audioHolders -= 1
        if Self.audioHolders == 0 { Self.releaseSession() }
    }

    /// Activates the session and loops a second of silence through the
    /// engine. False if iOS refused.
    private func play() -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            // Read on every start: it follows the output, and AirPods can run
            // at another sample rate than the speaker. 0 Hz is no output yet.
            let format = engine.outputNode.inputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { return false }
            if player.engine == nil { engine.attach(player) }
            engine.connect(player, to: engine.mainMixerNode, format: format)

            let frames = AVAudioFrameCount(format.sampleRate)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return false }
            buffer.frameLength = frames

            try engine.start()
            player.scheduleBuffer(buffer, at: nil, options: .loops)
            player.play()
            return true
        } catch {
            silence()
            return false
        }
    }

    /// Stops the player and the engine, leaving both set up.
    private func silence() {
        if player.engine != nil { player.stop() }
        engine.stop()
    }

    private var isPlaying: Bool { engine.isRunning && player.isPlaying }

    /// Plays again if something stopped it, or anyway when `force`d: after an
    /// interruption the session needs activating again, whatever the engine
    /// says. Retries a few times, since right after a route change the engine
    /// can refuse to start for a moment.
    private func resume(after cause: String, force: Bool = false) {
        guard audioRunning, !interrupted, force || !isPlaying else { return }
        retry?.cancel()
        retry = nil
        if restart(after: cause) { return }
        retry = Task { [weak self] in
            for delay in [0.5, 1, 2] {
                try? await Task.sleep(for: .seconds(delay))
                guard let self, !Task.isCancelled,
                      self.audioRunning, !self.interrupted, !self.isPlaying else { return }
                if self.restart(after: cause) { return }
            }
            self?.log("Keep-alive: silent audio didn't restart after \(cause). It tries again when SideInstaller is opened.")
        }
    }

    private func restart(after cause: String) -> Bool {
        silence()
        guard play() else { return false }
        log("Keep-alive: silent audio restarted after \(cause).")
        return true
    }

    private func interruptionBegan() {
        guard audioRunning, !interrupted else { return }
        interrupted = true
        retry?.cancel()
        retry = nil
        log("Keep-alive: silent audio interrupted (a call, Siri or an alarm). It restarts when that ends.")
    }

    /// Plays again whatever iOS recommends: the audio is silent and mixes
    /// with others. Forced only for an interruption seen beginning, so the
    /// second of two end notifications finds it playing and does nothing.
    private func interruptionEnded() {
        let wasInterrupted = interrupted
        interrupted = false
        resume(after: "an interruption", force: wasInterrupted)
    }

    private func mediaServicesReset() {
        guard audioRunning else { return }
        engine = AVAudioEngine()
        player = AVAudioPlayerNode()
        interrupted = false
        resume(after: "a media services reset", force: true)
    }

    private func observeAudio() {
        let center = NotificationCenter.default
        func observe(_ name: Notification.Name,
                     _ handle: @escaping @MainActor (KeepAlive, Notification) -> Void) {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    handle(self, note)
                }
            })
        }

        // Deprecated in iOS 27 for the two below, and maybe still sent there:
        // both are handled, and whichever comes second finds nothing to do.
        observe(AVAudioSession.interruptionNotification) { me, note in
            let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            switch type.flatMap(AVAudioSession.InterruptionType.init) {
            case .began: me.interruptionBegan()
            case .ended: me.interruptionEnded()
            default: break
            }
        }
        // iOS 27 的 AVAudioSession 新通知（didBecomeInactive /
        // resumptionRecommendation / deactivationContext）暂不接：
        // 跑道的 Xcode 26.6 自带 iOS 26.5 SDK，符号根本不存在，
        // #available 是运行时判断、救不了编译期缺符号；等工作流
        // 升到带 iOS 27 SDK 的 Xcode 再接回来。行为不丢：下面
        // 的 interruption / routeChange 两路本来就覆盖了这块。
        // AirPods connecting, headphones unplugged, CarPlay.
        observe(AVAudioSession.routeChangeNotification) { me, note in
            let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            me.resume(after: Self.describe(reason.flatMap(AVAudioSession.RouteChangeReason.init)))
        }
        // The engine stops itself when the output's sample rate or channel
        // count changes, often a moment after the route change.
        observe(.AVAudioEngineConfigurationChange) { me, note in
            guard (note.object as? AVAudioEngine) === me.engine else { return }
            me.resume(after: "the audio output changed")
        }
        observe(AVAudioSession.mediaServicesWereResetNotification) { me, _ in
            me.mediaServicesReset()
        }
        // iOS doesn't promise an interruption's end, so look again each time
        // the app comes back.
        observe(UIApplication.didBecomeActiveNotification) { me, _ in
            me.interrupted = false
            me.resume(after: "SideInstaller was opened again")
        }
    }

    private static func describe(_ reason: AVAudioSession.RouteChangeReason?) -> String {
        switch reason {
        case .newDeviceAvailable: return "a new audio output connected"
        case .oldDeviceUnavailable: return "an audio output disconnected"
        default: return "an audio route change"
        }
    }

    private func log(_ message: String) {
        Engine.shared.log(message)
    }

    /// 外部静音音频持有 session 的计数（v62 起停用：企业安装改走
    /// Engine，安装期的 InstallAudioKeeper 留着不用，不再有外部
    /// holder 调这里；计数 API 留着不删，免得以后外部音频 holder
    /// 又要重写）：只动计数、不启动全局 engine；调用方须成对
    /// 调用（start 成功时 retain、stop 时 release）。归零时才释放
    /// session，避免全局最后一个 holder 停掉时误杀正在跑的音频。
    static func retainAudioSession() {
        audioHolders += 1
    }

    static func releaseAudioSession() {
        audioHolders -= 1
        if audioHolders == 0 { releaseSession() }
    }

    /// Deactivates the session and puts it back in a category that Silent
    /// Mode mutes: `.playback` would let `SoundEffects` play through it.
    private static func releaseSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
        try? session.setCategory(.ambient)
    }

    private lazy var location: CLLocationManager = {
        let m = CLLocationManager()
        m.delegate = self
        m.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        m.distanceFilter = kCLDistanceFilterNone
        m.pausesLocationUpdatesAutomatically = false
        return m
    }()
    private var locationRunning = false

    /// 定位不可用时为真（被拒/受限/系统定位总开关关了）：这时只有
    /// 音频保活在撑，锁屏续签可能被挂起。AutoRefreshService 记日志、
    /// 设置页明示（Seal 被拒降级同款，只是它还多一句提醒）。
    var locationUnavailable = false

    func startLocation() {
        guard !locationRunning else { return }
        locationRunning = true
        location.requestAlwaysAuthorization()
        // 已经明确被拒/受限时不等回调，直接标降级；系统定位总开关
        // 关了也一样（下面 locationServicesEnabled 为假）。
        switch location.authorizationStatus {
        case .denied, .restricted:
            locationUnavailable = true
        default:
            break
        }
        if CLLocationManager.locationServicesEnabled() {
            location.allowsBackgroundLocationUpdates = true
            location.startUpdatingLocation()
        } else {
            locationUnavailable = true
        }
    }

    func stopLocation() {
        guard locationRunning else { return }
        location.stopUpdatingLocation()
        location.allowsBackgroundLocationUpdates = false
        locationRunning = false
    }

    func stopAll() {
        stopAudio()
        stopLocation()
    }
}

extension KeepAlive: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            guard locationRunning else { return }
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                locationUnavailable = false
                manager.allowsBackgroundLocationUpdates = true
                manager.startUpdatingLocation()
            case .denied, .restricted:
                // 定位被拒：降级为仅音频保活，并明说锁屏续签可能
                // 被挂起（Seal 同款降级 + 明示）。
                locationUnavailable = true
                Engine.shared.log("Keep-alive: location denied — audio-only keep-alive; lock-screen renewal may be suspended.")
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    }
}
