//! A fake iPhone for tests: the device's side of iOS 27's device-initiated
//! pair-setup, as Settings › Developer Mode › "Pair with …" drives it.
//!
//! In that conversation the device is the rppairing "host" and SRP *client*: it
//! sends the handshake, M1, M3 (with the PIN the user typed) and M5 (its own
//! identity), and checks the accessory's proof (M4) and identity (M6). This is
//! the mirror of idevice's `PairableHost`, written from the same constants, so a
//! test can pair all the way to a pairing file with no iPhone. It also writes
//! stand-ins for Minis's commands (`minis_stub`).

use std::future::Future;
use std::net::SocketAddr;
use std::path::{Path, PathBuf};

use base64::{engine::general_purpose::STANDARD as B64, Engine as _};
use chacha20poly1305::aead::{Aead, Payload};
use chacha20poly1305::{ChaCha20Poly1305, Key, KeyInit, Nonce};
use ed25519_dalek::{Signature, Signer, SigningKey, Verifier, VerifyingKey};
use hkdf::Hkdf;
use idevice::remote_pairing::{RpPairingSocket, RpPairingSocketProvider};
use idevice_srp::{client::SrpClient, groups::G_3072};
use serde_json::json;
use sha2_10::Sha512;
use tokio::net::TcpStream;

pub const NAME: &str = "Fake iPhone";
pub const MODEL: &str = "iPhone17,3";
pub const UDID: &str = "00008140-0001FAKE0000801C";
pub const ALT_IRK: [u8; 16] = *b"fake-iphone-irk!";

// TLV8 types (idevice's `PairingDataComponentType`).
const METHOD: u8 = 0x00;
const IDENTIFIER: u8 = 0x01;
const SALT: u8 = 0x02;
const PUBLIC_KEY: u8 = 0x03;
const PROOF: u8 = 0x04;
const ENCRYPTED: u8 = 0x05;
const STATE: u8 = 0x06;
const ERROR: u8 = 0x07;
const SIGNATURE: u8 = 0x0a;
const INFO: u8 = 0x11;

/// What the host told the device about itself in M6.
pub struct Outcome {
    pub host_identifier: String,
    pub host_public_key: Vec<u8>,
}

type Tlv = Vec<(u8, Vec<u8>)>;

/// Pair with the pairable host listening at `addr`, typing `pin` when asked.
pub async fn pair(addr: SocketAddr, pin: impl Future<Output = String>) -> Result<Outcome, String> {
    let stream = TcpStream::connect(addr)
        .await
        .map_err(|e| format!("connect: {e}"))?;
    let mut socket = RpPairingSocket::new(stream);
    let mut seq = 0usize;

    // Handshake: a device-initiated pairing asks for pair-setup, not verify.
    send(
        &mut socket,
        &mut seq,
        json!({"request": {"_0": {"handshake": {"_0": {
            "hostOptions": {"attemptPairVerify": false},
            "wireProtocolVersion": 26
        }}}}}),
    )
    .await?;
    let reply = socket
        .recv_plain()
        .await
        .map_err(|e| format!("handshake reply: {e}"))?;
    let reply = serde_json::to_value(&reply).map_err(|e| e.to_string())?;
    let options = &reply["response"]["_1"]["handshake"]["_0"]["deviceOptions"];
    if options["allowsPairSetup"] != json!(true) {
        return Err(format!("the host doesn't allow pair-setup: {reply}"));
    }

    // M1
    send_tlv(
        &mut socket,
        &mut seq,
        &[(METHOD, vec![0]), (STATE, vec![1])],
        true,
    )
    .await?;

    // M2: salt and B; the host shows the PIN as it sends them.
    let m2 = recv_tlv(&mut socket).await?;
    expect_state(&m2, 2)?;
    let salt = get(&m2, SALT);
    let b_pub = get(&m2, PUBLIC_KEY);
    let pin = pin.await;

    // M3: A and the client proof.
    let srp = SrpClient::<Sha512>::new(&G_3072);
    let a_private = [0x5au8; 32];
    let a_pub = srp.compute_public_ephemeral(&a_private);
    let verifier = srp
        .process_reply(
            &a_private,
            b"Pair-Setup",
            pin.as_bytes(),
            &salt,
            &b_pub,
            false,
        )
        .map_err(|e| format!("SRP: {e:?}"))?;
    send_tlv(
        &mut socket,
        &mut seq,
        &[
            (STATE, vec![3]),
            (PUBLIC_KEY, a_pub),
            (PROOF, verifier.proof().to_vec()),
        ],
        false,
    )
    .await?;

    // M4: the server proof, or a refusal of the code.
    let m4 = recv_tlv(&mut socket).await?;
    if !get(&m4, ERROR).is_empty() {
        return Err("the host refused the code".into());
    }
    expect_state(&m4, 4)?;
    verifier
        .verify_server(&get(&m4, PROOF))
        .map_err(|e| format!("server proof: {e:?}"))?;
    let session_key = verifier.key().to_vec();
    let cipher = ChaCha20Poly1305::new(Key::from_slice(&hkdf32(
        &session_key,
        b"Pair-Setup-Encrypt-Salt",
        b"Pair-Setup-Encrypt-Info",
    )));

    // M5: this device's identity.
    let device_key = SigningKey::from_bytes(&[7u8; 32]);
    let device_ltpk = device_key.verifying_key().to_bytes();
    let mut signed = hkdf32(
        &session_key,
        b"Pair-Setup-Controller-Sign-Salt",
        b"Pair-Setup-Controller-Sign-Info",
    )
    .to_vec();
    signed.extend_from_slice(UDID.as_bytes());
    signed.extend_from_slice(&device_ltpk);
    let signature = device_key.sign(&signed);
    let info = opack_dict(&[
        ("altIRK", Opack::Data(&ALT_IRK)),
        ("accountID", Opack::Str("FAKE-ACCOUNT-ID")),
        ("model", Opack::Str(MODEL)),
        ("name", Opack::Str(NAME)),
        ("remotepairing_udid", Opack::Str(UDID)),
    ]);
    let identity = tlv_encode(&[
        (IDENTIFIER, UDID.as_bytes().to_vec()),
        (PUBLIC_KEY, device_ltpk.to_vec()),
        (SIGNATURE, signature.to_bytes().to_vec()),
        (INFO, info),
    ]);
    let sealed = cipher
        .encrypt(
            Nonce::from_slice(b"\x00\x00\x00\x00PS-Msg05"),
            Payload {
                msg: &identity,
                aad: b"",
            },
        )
        .map_err(|e| format!("M5 encrypt: {e:?}"))?;
    send_tlv(
        &mut socket,
        &mut seq,
        &[(ENCRYPTED, sealed), (STATE, vec![5])],
        false,
    )
    .await?;

    // M6: the host's identity, checked as a device checks it.
    let m6 = recv_tlv(&mut socket).await?;
    expect_state(&m6, 6)?;
    let opened = cipher
        .decrypt(
            Nonce::from_slice(b"\x00\x00\x00\x00PS-Msg06"),
            Payload {
                msg: &get(&m6, ENCRYPTED),
                aad: b"",
            },
        )
        .map_err(|e| format!("M6 decrypt: {e:?}"))?;
    let host = tlv_decode(&opened)?;
    let host_identifier = String::from_utf8(get(&host, IDENTIFIER)).map_err(|e| e.to_string())?;
    let host_public_key = get(&host, PUBLIC_KEY);
    let mut signed = hkdf32(
        &session_key,
        b"Pair-Setup-Accessory-Sign-Salt",
        b"Pair-Setup-Accessory-Sign-Info",
    )
    .to_vec();
    signed.extend_from_slice(host_identifier.as_bytes());
    signed.extend_from_slice(&host_public_key);
    let key: [u8; 32] = host_public_key
        .clone()
        .try_into()
        .map_err(|_| "host key isn't 32 bytes")?;
    let sig: [u8; 64] = get(&host, SIGNATURE)
        .try_into()
        .map_err(|_| "host signature isn't 64 bytes")?;
    VerifyingKey::from_bytes(&key)
        .map_err(|e| e.to_string())?
        .verify(&signed, &Signature::from_bytes(&sig))
        .map_err(|e| format!("host signature: {e}"))?;
    if get(&host, INFO).is_empty() {
        return Err("M6 carried no host info".into());
    }
    Ok(Outcome {
        host_identifier,
        host_public_key,
    })
}

async fn send(
    socket: &mut RpPairingSocket<TcpStream>,
    seq: &mut usize,
    value: serde_json::Value,
) -> Result<(), String> {
    socket
        .send_plain(value, *seq)
        .await
        .map_err(|e| format!("send: {e}"))?;
    *seq += 1;
    Ok(())
}

async fn send_tlv(
    socket: &mut RpPairingSocket<TcpStream>,
    seq: &mut usize,
    entries: &[(u8, Vec<u8>)],
    start_new_session: bool,
) -> Result<(), String> {
    let data = B64.encode(tlv_encode(entries));
    send(
        socket,
        seq,
        json!({"event": {"_0": {"pairingData": {"_0": {
            "data": data,
            "kind": "setupManualPairing",
            "sendingHost": NAME,
            "startNewSession": start_new_session
        }}}}}),
    )
    .await
}

async fn recv_tlv(socket: &mut RpPairingSocket<TcpStream>) -> Result<Tlv, String> {
    let message = socket
        .recv_plain()
        .await
        .map_err(|e| format!("recv: {e}"))?;
    let message = serde_json::to_value(&message).map_err(|e| e.to_string())?;
    let data = message["event"]["_0"]["pairingData"]["_0"]["data"]
        .as_str()
        .ok_or_else(|| format!("not a pairingData event: {message}"))?;
    tlv_decode(&B64.decode(data).map_err(|e| e.to_string())?)
}

fn expect_state(tlv: &Tlv, state: u8) -> Result<(), String> {
    match get(tlv, STATE).as_slice() {
        [s] if *s == state => Ok(()),
        other => Err(format!("expected state {state}, got {other:?}")),
    }
}

fn hkdf32(ikm: &[u8], salt: &[u8], info: &[u8]) -> [u8; 32] {
    let mut out = [0u8; 32];
    Hkdf::<Sha512>::new(Some(salt), ikm)
        .expand(info, &mut out)
        .expect("32 bytes is a valid HKDF length");
    out
}

/// TLV8: type, length, value; values over 255 bytes go in consecutive entries.
fn tlv_encode(entries: &[(u8, Vec<u8>)]) -> Vec<u8> {
    let mut out = Vec::new();
    for (kind, data) in entries {
        if data.is_empty() {
            out.extend_from_slice(&[*kind, 0]);
        }
        for chunk in data.chunks(255) {
            out.push(*kind);
            out.push(chunk.len() as u8);
            out.extend_from_slice(chunk);
        }
    }
    out
}

fn tlv_decode(bytes: &[u8]) -> Result<Tlv, String> {
    let mut out: Tlv = Vec::new();
    let mut i = 0;
    while i < bytes.len() {
        let (kind, len) = (bytes[i], *bytes.get(i + 1).ok_or("truncated TLV")? as usize);
        let value = bytes.get(i + 2..i + 2 + len).ok_or("truncated TLV value")?;
        out.push((kind, value.to_vec()));
        i += 2 + len;
    }
    Ok(out)
}

/// Every entry of `kind`, joined, as fragments of one value are.
fn get(tlv: &Tlv, kind: u8) -> Vec<u8> {
    tlv.iter()
        .filter(|(k, _)| *k == kind)
        .flat_map(|(_, v)| v.clone())
        .collect()
}

enum Opack<'a> {
    Str(&'a str),
    Data(&'a [u8]),
}

/// An OPACK dictionary of strings and data, as idevice's encoder writes one.
fn opack_dict(entries: &[(&str, Opack)]) -> Vec<u8> {
    fn sized(out: &mut Vec<u8>, inline: u8, long: u8, bytes: &[u8]) {
        if bytes.len() <= 0x20 {
            out.push(inline + bytes.len() as u8);
        } else {
            out.push(long);
            out.push(bytes.len() as u8);
        }
        out.extend_from_slice(bytes);
    }
    let mut out = vec![0xe0 + entries.len() as u8];
    for (key, value) in entries {
        sized(&mut out, 0x40, 0x61, key.as_bytes());
        match value {
            Opack::Str(s) => sized(&mut out, 0x40, 0x61, s.as_bytes()),
            Opack::Data(d) => sized(&mut out, 0x70, 0x91, d),
        }
    }
    out
}

/// Stand-ins for Minis's commands, in `<home>/stub-bin`. Each logs its
/// arguments to `<home>/minis-calls.log` and answers with the envelope
/// bonjour.md describes. `advertise` reports the guest port as Minis's own:
/// there is no app in between to forward.
pub fn minis_stub(home: &Path) -> PathBuf {
    let dir = home.join("stub-bin");
    std::fs::create_dir_all(&dir).unwrap();
    let log = home.join("minis-calls.log");
    let log = log.to_string_lossy();
    let scripts = [
        (
            "minis-bonjour",
            r#"case "$1" in
types) echo '{"ok":true,"tool":"minis-bonjour","action":"types","data":{"types":["_remotepairing-pairable-host._tcp","_http._tcp"],"source":"Info.plist NSBonjourServices","restricted":true}}' ;;
list) echo '{"ok":true,"tool":"minis-bonjour","action":"list","data":{"advertisements":[],"forwards":[],"declared_types":["_remotepairing-pairable-host._tcp"],"app_in_background":false}}' ;;
advertise) printf '{"ok":true,"tool":"minis-bonjour","action":"advertise","data":{"id":"adv-1","kind":"advertise","type":"%s","name":"%s","requested_name":"%s","guest_port":%s,"listener_port":%s,"state":"ready"}}\n' "$2" "$3" "$3" "$4" "$4" ;;
stop) echo '{"ok":true,"tool":"minis-bonjour","action":"stop","data":{"stopped":["adv-1"],"count":1}}' ;;
*) echo '{"ok":false,"tool":"minis-bonjour","action":"?","error":{"code":"invalid_args","message":"unknown command"}}'; exit 2 ;;
esac"#,
        ),
        (
            "apple-notification",
            r#"case "$1" in
settings) echo '{"ok":true,"tool":"apple-notification","action":"settings","data":{"authorization_status":"authorized"}}' ;;
*) echo '{"ok":true,"tool":"apple-notification","action":"schedule","data":{"id":"n-1"}}' ;;
esac"#,
        ),
        (
            "apple-player",
            r#"case "$1" in
play) echo '{"ok":true,"tool":"apple-player","action":"play","data":{"session_id":"s-1","media_type":"audio","status":"playing"}}' ;;
*) echo '{"ok":true,"tool":"apple-player","action":"stop","data":{}}' ;;
esac"#,
        ),
    ];
    for (name, body) in scripts {
        let path = dir.join(name);
        std::fs::write(
            &path,
            format!("#!/bin/sh\necho \"{name} $*\" >> '{log}'\n{body}\n"),
        )
        .unwrap();
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o755)).unwrap();
        }
    }
    dir
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Pairs with a `siboot pair` running elsewhere (under the iSH emulator, say)
    /// whose Minis commands are `minis_stub`'s, logging to `$SIBOOT_FAKE_LOG`.
    /// The port comes from its `minis-bonjour advertise` call and the code from
    /// the notification it posts, as a person would read it:
    /// `SIBOOT_FAKE_LOG=… cargo test dial_a_running_siboot -- --ignored`.
    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    #[ignore = "needs a siboot waiting to pair"]
    async fn dial_a_running_siboot() {
        let log = PathBuf::from(std::env::var("SIBOOT_FAKE_LOG").expect("set SIBOOT_FAKE_LOG"));
        let advertised = wait_for_line(&log, "minis-bonjour advertise").await;
        let port: u16 = advertised.split(' ').nth(4).unwrap().parse().unwrap();
        let pin = async {
            let posted = wait_for_line(&log, "apple-notification schedule").await;
            let body = posted.split("--body ").nth(1).unwrap();
            body.chars()
                .filter(char::is_ascii_digit)
                .take(6)
                .collect::<String>()
        };
        let outcome = pair(SocketAddr::from(([127, 0, 0, 1], port)), pin)
            .await
            .expect("paired");
        println!("paired with host {}", outcome.host_identifier);
    }

    async fn wait_for_line(log: &Path, prefix: &str) -> String {
        for _ in 0..1200 {
            if let Ok(text) = std::fs::read_to_string(log) {
                if let Some(line) = text.lines().find(|l| l.starts_with(prefix)) {
                    return line.to_string();
                }
            }
            tokio::time::sleep(std::time::Duration::from_millis(100)).await;
        }
        panic!("no `{prefix}` line in {} within 2 minutes", log.display());
    }

    #[test]
    fn tlv_round_trips_long_values_in_fragments() {
        let long = vec![9u8; 384];
        let encoded = tlv_encode(&[(STATE, vec![3]), (PUBLIC_KEY, long.clone())]);
        assert_eq!(encoded.len(), 3 + 2 + 255 + 2 + 129);
        let decoded = tlv_decode(&encoded).unwrap();
        assert_eq!(get(&decoded, PUBLIC_KEY), long);
        assert_eq!(get(&decoded, STATE), vec![3]);
        assert!(tlv_decode(&[STATE, 4, 1]).is_err());
    }

    #[test]
    fn opack_matches_idevices_encoding() {
        let dict = opack_dict(&[("name", Opack::Str("A")), ("altIRK", Opack::Data(&[1, 2]))]);
        assert_eq!(
            dict,
            [
                0xe2, 0x44, b'n', b'a', b'm', b'e', 0x41, b'A', 0x46, b'a', b'l', b't', b'I', b'R',
                b'K', 0x72, 1, 2
            ]
        );
        let long = "x".repeat(40);
        let dict = opack_dict(&[("k", Opack::Str(&long))]);
        assert_eq!(&dict[..5], &[0xe1, 0x41, b'k', 0x61, 40]);
    }
}
