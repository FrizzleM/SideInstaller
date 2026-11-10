//! Keeps Minis running while the user is in Settings.
//!
//! Pairing happens in Settings, with Minis in the background. iOS suspends a
//! background app within seconds, and `minis-bonjour`'s advertisements are
//! withdrawn while Minis is suspended, so the "Pair with …" entry would vanish
//! before it could be tapped. That is the likeliest reason Minis's own
//! `pair_via_bonjour.py` never got the entry to show. SideInstaller and
//! StikPair both play silent audio through pairing for the same reason.
//!
//! Minis has background audio, and `apple-player play` plays a file through it
//! with the playback session category, so playing silence keeps Minis running.
//! Minis's own Enhanced Background setting does the same, but only while an
//! agent task is running, not for a command typed into its terminal.

use std::path::{Path, PathBuf};

use crate::bridge::{Bridge, BridgeError};

/// Longer than pairing can take: up to 10 minutes for the user to find the
/// entry, then 5 for the code.
pub const PAIRING_SECONDS: u32 = 16 * 60;

const SAMPLE_RATE: u32 = 8_000;

/// 8-bit unsigned mono PCM WAV of silence (sample value 0x80), `seconds` long.
/// About 470 KB a minute: small, and readable by AVAudioPlayer.
pub fn silent_wav(seconds: u32) -> Vec<u8> {
    let data_len = SAMPLE_RATE * seconds;
    let mut wav = Vec::with_capacity(44 + data_len as usize);
    wav.extend_from_slice(b"RIFF");
    wav.extend_from_slice(&(36 + data_len).to_le_bytes());
    wav.extend_from_slice(b"WAVEfmt ");
    wav.extend_from_slice(&16u32.to_le_bytes()); // fmt chunk size
    wav.extend_from_slice(&1u16.to_le_bytes()); // PCM
    wav.extend_from_slice(&1u16.to_le_bytes()); // mono
    wav.extend_from_slice(&SAMPLE_RATE.to_le_bytes());
    wav.extend_from_slice(&SAMPLE_RATE.to_le_bytes()); // byte rate: 1 byte a sample
    wav.extend_from_slice(&1u16.to_le_bytes()); // block align
    wav.extend_from_slice(&8u16.to_le_bytes()); // bits per sample
    wav.extend_from_slice(b"data");
    wav.extend_from_slice(&data_len.to_le_bytes());
    wav.resize(44 + data_len as usize, 0x80);
    wav
}

/// Silence playing in Minis. Stopped by `stop`, or by `Drop` on any other way
/// out, so a failed run doesn't leave Minis playing.
pub struct KeepAlive {
    bridge: Bridge,
    session: Option<String>,
}

impl KeepAlive {
    /// Write the silence into `home` (once) and start playing it.
    pub async fn start(bridge: &Bridge, home: &Path, seconds: u32) -> Result<Self, String> {
        let file = silence_file(home, seconds);
        let wanted = 44 + u64::from(SAMPLE_RATE * seconds);
        let present = std::fs::metadata(&file).map(|m| m.len()).unwrap_or(0);
        if present != wanted {
            std::fs::write(&file, silent_wav(seconds))
                .map_err(|e| format!("couldn't write {}: {e}", file.display()))?;
        }
        let session = bridge.play(&file).await.map_err(|e| match e {
            BridgeError::Missing(_) => "Minis's apple-player command isn't here".to_string(),
            other => other.to_string(),
        })?;
        Ok(Self {
            bridge: bridge.clone(),
            session: Some(session),
        })
    }

    pub async fn stop(mut self) {
        if let Some(session) = self.session.take() {
            if let Err(e) = self.bridge.stop_player(&session).await {
                tracing::warn!("couldn't stop the keep-alive audio ({session}): {e}");
            }
        }
    }
}

impl Drop for KeepAlive {
    fn drop(&mut self) {
        if let Some(session) = self.session.take() {
            self.bridge.call_now("apple-player", &["stop", &session]);
        }
    }
}

fn silence_file(home: &Path, seconds: u32) -> PathBuf {
    home.join(format!("silence-{seconds}s.wav"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_silence_is_a_well_formed_wav() {
        let wav = silent_wav(2);
        assert_eq!(wav.len(), 44 + 16_000);
        assert_eq!(&wav[0..4], b"RIFF");
        assert_eq!(
            u32::from_le_bytes(wav[4..8].try_into().unwrap()) as usize,
            wav.len() - 8
        );
        assert_eq!(&wav[8..16], b"WAVEfmt ");
        assert_eq!(u16::from_le_bytes([wav[20], wav[21]]), 1, "PCM");
        assert_eq!(u32::from_le_bytes(wav[24..28].try_into().unwrap()), 8_000);
        assert_eq!(u16::from_le_bytes([wav[34], wav[35]]), 8, "bits");
        assert_eq!(&wav[36..40], b"data");
        assert_eq!(u32::from_le_bytes(wav[40..44].try_into().unwrap()), 16_000);
        assert!(
            wav[44..].iter().all(|&b| b == 0x80),
            "silence is the midpoint for 8-bit PCM"
        );
    }

    #[test]
    fn pairing_fits_inside_the_silence() {
        const { assert!(PAIRING_SECONDS >= 15 * 60) };
    }
}
