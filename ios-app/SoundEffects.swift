import AVFAudio
import AudioToolbox
import SwiftUI
import notify

/// The app's sound effects. Each is drawn here in code, written out once per
/// launch as a short WAV file and played as a system sound, so:
///
/// - Silent Mode mutes them, like keyboard clicks (see `silentModeAllows`
///   for while `KeepAlive` runs);
/// - they mix with whatever else is playing;
/// - they leave the app's audio session alone, which `KeepAlive` holds with
///   silent audio while a run waits in the background.
///
/// Settings › Sounds turns them off.
enum UISound: CaseIterable {
    /// A primary call to action: a round, soft "thock".
    case press
    /// A secondary button: a light tick.
    case tap
    /// Moving between places (a tab, a row, a disclosure): the quietest tick.
    case tick
    /// Something turned on, ticked or copied: two quick notes up.
    case rise
    /// Something turned off or unticked: the same two notes down.
    case fall
    /// A popup closed by hand: a short slide down.
    case dismiss
    /// A message that something worked: a bright four-note run up.
    case success
    /// A message that something went wrong: a soft "uh-oh", two notes down.
    case error
    /// A message that needs the user, such as a pairing code or a question:
    /// a glassy two-note ding.
    case attention
}

enum SoundEffects {
    /// UserDefaults key of Settings' switch; on until turned off.
    static let enabledKey = "soundEffects"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    /// Plays `sound`, unless sound effects are off or the iPhone is in
    /// Silent Mode.
    static func play(_ sound: UISound) {
        guard isEnabled else { return }
        queue.async {
            guard silentModeAllows() else { return }
            if let id = loadedIDs()[sound] { AudioServicesPlaySystemSound(id) }
        }
    }

    /// Whether Silent Mode lets a sound play. iOS mutes the app's system
    /// sounds in Silent Mode only while its audio session category follows
    /// Silent Mode, as the default and `.ambient` do. `.playback` doesn't, and
    /// `KeepAlive` uses it while a pairing or a simulated location runs, so
    /// then SpringBoard's ringer state decides.
    private static func silentModeAllows() -> Bool {
        switch AVAudioSession.sharedInstance().category {
        case .ambient, .soloAmbient: return true
        default: return ringerIsOn()
        }
    }

    /// SpringBoard's ringer state; registered on `queue`, kept for good.
    private static var ringerToken: Int32?

    /// The ringer as SpringBoard last posted it: 1 when it's on, 0 in Silent
    /// Mode. A state this app can't read also comes back 0, so in doubt this
    /// stays quiet.
    private static func ringerIsOn() -> Bool {
        if ringerToken == nil {
            var token: Int32 = 0
            guard notify_register_check("com.apple.springboard.ringerstate", &token)
                    == NOTIFY_STATUS_OK else { return false }
            ringerToken = token
        }
        var state: UInt64 = 0
        guard let token = ringerToken,
              notify_get_state(token, &state) == NOTIFY_STATUS_OK else { return false }
        return state != 0
    }

    /// Draws the sounds ahead of the first tap, off the main thread.
    static func prepare() {
        queue.async { _ = loadedIDs() }
    }

    private static let queue = DispatchQueue(label: "SoundEffects", qos: .userInteractive)
    /// The registered sounds; touched on `queue` only.
    private static var ids: [UISound: SystemSoundID]?

    private static func loadedIDs() -> [UISound: SystemSoundID] {
        if let ids { return ids }
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("SoundEffects", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var made: [UISound: SystemSoundID] = [:]
        for sound in UISound.allCases {
            let url = folder.appendingPathComponent("\(sound).wav")
            guard (try? sound.wav.write(to: url, options: .atomic)) != nil else { continue }
            var id: SystemSoundID = 0
            if AudioServicesCreateSystemSoundID(url as CFURL, &id) == kAudioServicesNoError {
                made[sound] = id
            }
        }
        ids = made
        return made
    }
}

// MARK: - Buttons

extension View {
    /// Draws the buttons in this view with `style`, and plays `sound` each
    /// time one fires: on the tap that runs its action, so a press that slides
    /// away, a scroll, or a disabled button stays silent.
    func buttonStyle<S: PrimitiveButtonStyle>(_ style: S, sound: UISound) -> some View {
        buttonStyle(SoundingPrimitiveButtonStyle(base: style, sound: sound))
    }

    /// `buttonStyle(_:sound:)` for a style that only draws the button.
    func buttonStyle<S: ButtonStyle>(_ style: S, sound: UISound) -> some View {
        buttonStyle(SoundingButtonStyle(base: style, sound: sound))
    }
}

/// Puts `base`'s button back together around an action that plays first.
private struct SoundingPrimitiveButtonStyle<Base: PrimitiveButtonStyle>: PrimitiveButtonStyle {
    var base: Base
    var sound: UISound

    func makeBody(configuration: Configuration) -> some View {
        Button(role: configuration.role) {
            SoundEffects.play(sound)
            configuration.trigger()
        } label: {
            configuration.label
        }
        .buttonStyle(base)
    }
}

/// `SoundingPrimitiveButtonStyle` for a style that only draws the button.
struct SoundingButtonStyle<Base: ButtonStyle>: PrimitiveButtonStyle {
    var base: Base
    var sound: UISound

    func makeBody(configuration: Configuration) -> some View {
        Button(role: configuration.role) {
            SoundEffects.play(sound)
            configuration.trigger()
        } label: {
            configuration.label
        }
        .buttonStyle(base)
    }
}

// MARK: - Switches

/// The standard switch, with `rise` as the user turns it on and `fall` as
/// they turn it off. Only the user's flip plays; the app changing the value
/// doesn't.
struct SoundingToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Toggle(isOn: Binding(get: { configuration.isOn },
                             set: { isOn in
                                 configuration.$isOn.wrappedValue = isOn
                                 SoundEffects.play(isOn ? .rise : .fall)
                             })) {
            configuration.label
        }
        .toggleStyle(.switch)
    }
}

// MARK: - Drawing the sounds

/// One voice in a sound: a pitch that may slide, with overtones, struck and
/// left to ring out.
private struct Note {
    /// When it's struck, in seconds into the sound.
    var at: Double = 0
    /// Hertz at the strike.
    var pitch: Double
    /// Hertz it slides to over `glide` seconds, if it slides.
    var slidesTo: Double? = nil
    var glide: Double = 0
    /// Seconds for the ring to fall to about a third.
    var ring: Double
    var level: Double = 1
    /// Seconds to swell in, so the strike doesn't click.
    var attack: Double = 0.002
    var overtones: [Overtone] = []
}

/// A partial above a note's pitch.
private struct Overtone {
    /// Its pitch as a multiple of the note's.
    var ratio: Double
    var level: Double
    /// Its ring as a fraction of the note's: higher partials die sooner.
    var ring: Double
}

private extension Overtone {
    /// A soft wooden knock.
    static let wood = [Overtone(ratio: 2, level: 0.3, ring: 0.6),
                       Overtone(ratio: 3, level: 0.08, ring: 0.4)]
    /// Mallet on a bar, like a marimba: a clear fundamental with a bright,
    /// quickly fading top.
    static let mallet = [Overtone(ratio: 2, level: 0.28, ring: 0.55),
                         Overtone(ratio: 3, level: 0.1, ring: 0.35),
                         Overtone(ratio: 4.2, level: 0.05, ring: 0.25)]
    /// A small glass bell: slightly out-of-tune partials that shimmer.
    static let glass = [Overtone(ratio: 2.0, level: 0.22, ring: 0.5),
                        Overtone(ratio: 3.01, level: 0.08, ring: 0.3),
                        Overtone(ratio: 5.4, level: 0.035, ring: 0.15)]
    /// Felt-dampened: the warmth of the second partial and little else.
    static let muted = [Overtone(ratio: 2, level: 0.45, ring: 0.45),
                        Overtone(ratio: 3, level: 0.12, ring: 0.3)]
}

private extension UISound {
    /// What the sound is made of. Pitches stay above ~450 Hz, or an iPhone's
    /// speaker barely plays them.
    var recipe: (notes: [Note], click: Double, length: Double, peak: Double) {
        switch self {
        case .press:
            // A pitch that drops as it's struck, with a little sparkle on top.
            return ([Note(pitch: 640, slidesTo: 420, glide: 0.05, ring: 0.035,
                          attack: 0.001, overtones: Overtone.wood),
                     Note(pitch: 1760, ring: 0.018, level: 0.16, attack: 0.001)],
                    click: 0.3, length: 0.18, peak: 0.5)
        case .tap:
            return ([Note(pitch: 1900, slidesTo: 1450, glide: 0.012, ring: 0.012,
                          attack: 0.0008, overtones: [Overtone(ratio: 2, level: 0.25, ring: 0.5)])],
                    click: 0.22, length: 0.07, peak: 0.32)
        case .tick:
            return ([Note(pitch: 2600, slidesTo: 2250, glide: 0.006, ring: 0.006, attack: 0.0005)],
                    click: 0.12, length: 0.04, peak: 0.2)
        case .rise:
            return ([Note(pitch: 990, ring: 0.04, overtones: [Overtone(ratio: 2, level: 0.2, ring: 0.5)]),
                     Note(at: 0.05, pitch: 1480, ring: 0.07, overtones: [Overtone(ratio: 2, level: 0.2, ring: 0.5)])],
                    click: 0, length: 0.26, peak: 0.3)
        case .fall:
            return ([Note(pitch: 1480, ring: 0.04, overtones: [Overtone(ratio: 2, level: 0.2, ring: 0.5)]),
                     Note(at: 0.05, pitch: 990, ring: 0.07, overtones: [Overtone(ratio: 2, level: 0.2, ring: 0.5)])],
                    click: 0, length: 0.26, peak: 0.26)
        case .dismiss:
            return ([Note(pitch: 1150, slidesTo: 540, glide: 0.09, ring: 0.05, attack: 0.003,
                          overtones: [Overtone(ratio: 2, level: 0.15, ring: 0.5)])],
                    click: 0, length: 0.2, peak: 0.24)
        case .success:
            // A major arpeggio, A5 C♯6 E6 A6, the last left to ring.
            let pitches = [880.0, 1108.73, 1318.51, 1760]
            let notes = pitches.enumerated().map { i, pitch in
                Note(at: Double(i) * 0.075, pitch: pitch, ring: i == 3 ? 0.42 : 0.16,
                     level: 0.8 + Double(i) * 0.065, overtones: Overtone.mallet)
            }
            return (notes, click: 0, length: 1.35, peak: 0.5)
        case .error:
            // E5 then C5, each drooping a little, felt-dampened.
            return ([Note(pitch: 659.25, slidesTo: 650, glide: 0.1, ring: 0.11,
                          attack: 0.004, overtones: Overtone.muted),
                     Note(at: 0.14, pitch: 523.25, slidesTo: 512, glide: 0.25, ring: 0.2,
                          attack: 0.004, overtones: Overtone.muted)],
                    click: 0, length: 0.95, peak: 0.52)
        case .attention:
            // A grace note into a ringing C6.
            return ([Note(pitch: 784, ring: 0.05, level: 0.55, overtones: Overtone.glass),
                     Note(at: 0.065, pitch: 1046.5, ring: 0.34, overtones: Overtone.glass)],
                    click: 0, length: 1.2, peak: 0.45)
        }
    }

    /// The sound as a 16-bit mono WAV file.
    var wav: Data {
        let recipe = recipe
        return Synth.wav(Synth.render(recipe.notes, click: recipe.click,
                                      length: recipe.length, peak: recipe.peak))
    }
}

/// Renders `Note`s into samples, and samples into a WAV file.
private enum Synth {
    static let rate = 44_100

    /// `notes` mixed, with a `click` of noise at the very start (0 for none),
    /// `length` seconds long and scaled so its loudest sample is `peak`.
    static func render(_ notes: [Note], click: Double, length: Double, peak: Double) -> [Int16] {
        let sr = Double(rate)
        let count = Int(length * sr)
        var mix = [Double](repeating: 0, count: count)

        for note in notes {
            let first = Int(note.at * sr)
            // Past nine time constants it's below -78 dB: done.
            let last = min(count, first + Int(note.ring * 9 * sr))
            guard first < last else { continue }
            let partials = [Overtone(ratio: 1, level: 1, ring: 1)] + note.overtones
            var phase = 0.0
            for i in first..<last {
                let t = Double(i - first) / sr
                var pitch = note.pitch
                if let target = note.slidesTo, note.glide > 0 {
                    pitch *= pow(target / note.pitch, min(t / note.glide, 1))
                }
                phase += 2 * .pi * pitch / sr
                // A sine-shaped swell, then the ring.
                let swell = t < note.attack ? pow(sin(.pi / 2 * t / note.attack), 2) : 1
                var sample = 0.0
                for partial in partials {
                    sample += partial.level * sin(phase * partial.ratio)
                        * exp(-t / (note.ring * partial.ring))
                }
                mix[i] += note.level * swell * sample
            }
        }

        // The click: white noise, high-passed, gone within a few milliseconds.
        if click > 0 {
            var seed: UInt32 = 0x9E37_79B9
            var previous = 0.0
            for i in 0..<min(count, rate / 100) {
                seed = seed &* 1_664_525 &+ 1_013_904_223
                let noise = Double(seed) / Double(UInt32.max) * 2 - 1
                mix[i] += click * (noise - previous) * exp(-Double(i) / sr / 0.0012)
                previous = noise
            }
        }

        // Fade the last 8 ms so nothing ends on a click.
        let fade = min(count, Int(0.008 * sr))
        for i in 0..<fade {
            mix[count - 1 - i] *= Double(i) / Double(fade)
        }

        let loudest = mix.lazy.map(abs).max() ?? 0
        let scale = loudest > 0 ? peak / loudest : 0
        return mix.map { Int16(max(-1, min(1, $0 * scale)) * Double(Int16.max)) }
    }

    /// 16-bit mono PCM in a RIFF WAVE container.
    static func wav(_ samples: [Int16]) -> Data {
        var data = Data()
        func put<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        let bytes = UInt32(samples.count * 2)
        data.append(contentsOf: Array("RIFF".utf8)); put(36 + bytes)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); put(UInt32(16))
        put(UInt16(1))                 // PCM
        put(UInt16(1))                 // mono
        put(UInt32(rate))
        put(UInt32(rate * 2))          // bytes per second
        put(UInt16(2))                 // bytes per frame
        put(UInt16(16))                // bits per sample
        data.append(contentsOf: Array("data".utf8)); put(bytes)
        for sample in samples { put(sample) }
        return data
    }
}
