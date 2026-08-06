import AVFAudio
import CoreLocation
import Foundation

/// Keeps the app running on silent audio and background location, so the
/// RPPairing listener survives the trip to Settings to approve the PIN.
@MainActor
final class KeepAlive: NSObject {

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var audioRunning = false

    func startAudio() {
        guard !audioRunning else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            let format = engine.outputNode.inputFormat(forBus: 0)
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)

            let frames = AVAudioFrameCount(format.sampleRate)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
            buffer.frameLength = frames

            try engine.start()
            player.scheduleBuffer(buffer, at: nil, options: .loops)
            player.play()
            audioRunning = true
        } catch {
            audioRunning = false
        }
    }

    func stopAudio() {
        guard audioRunning else { return }
        player.stop()
        engine.stop()
        engine.detach(player)
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        audioRunning = false
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

    func startLocation() {
        guard !locationRunning else { return }
        locationRunning = true
        location.requestAlwaysAuthorization()
        if CLLocationManager.locationServicesEnabled() {
            location.allowsBackgroundLocationUpdates = true
            location.startUpdatingLocation()
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
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            MainActor.assumeIsolated {
                guard locationRunning else { return }
                manager.allowsBackgroundLocationUpdates = true
                manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    }
}
