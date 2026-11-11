//! Step 2: the pairing, made by siboot-pair in rootshell.
//!
//! From iOS 27 an iPhone pair-sets-up only with a host it dials itself: one
//! advertising `_remotepairing-pairable-host._tcp`, which Settings › Privacy &
//! Security › Developer Mode lists as "Pair with …". Minis's App Store build
//! can't advertise that; rootshell (App Store) can, so its siboot-pair
//! (../rootshell) pairs and then offers the pairing file on this iPhone's own
//! loopback, behind the 6-digit transfer code it shows.
//!
//! The file siboot saved on an earlier run comes first, while the iPhone
//! accepts it: siboot-pair keeps its host identity, so pairing again there
//! doesn't change it, and rootshell's offer is only needed the first time.
//! Either way the iPhone has to accept the file before anything is signed.

use std::net::SocketAddr;
use std::path::Path;
use std::time::Duration;

use idevice::remote_pairing::RpPairingFile;
use tokio::io::{AsyncBufReadExt, AsyncReadExt, AsyncWriteExt, BufReader};
use tokio::net::TcpStream;
use tokio::time::timeout;

use crate::fail::{Fail, Result};
use crate::{tunnel, ui, Args};

/// Where siboot-pair offers the file (rootshell/src/main.rs, `HANDOFF_PORT`).
const HANDOFF_PORT: u16 = 61207;
/// Codes typed before siboot gives up. siboot-pair ends its offer after five.
const CODE_TRIES: u32 = 3;
/// Far larger than a pairing file, which is about 1 KB.
const MAX_FILE: usize = 64 * 1024;
/// How long siboot-pair may take to answer a code. It answers at once while
/// rootshell runs, so silence means iOS has paused it.
const ANSWER_WAIT: Duration = Duration::from_secs(20);

/// How to make the pairing, for when there's none to take.
pub const ROOTSHELL_ROUTE: &str = "Pair in rootshell (App Store) first: turn on its Settings › \
     Location Diary Mode › Session Only, then run in its local shell, one line at a time: \
     `curl -fsSLO https://raw.githubusercontent.com/FrizzleM/SideInstaller/main/rootshell/bin/siboot-pair.wasm`, \
     `ifconfig en0 > ifconfig.txt`, `./siboot-pair.wasm`. Once it has paired, leave it running \
     and run siboot here again: it asks for the transfer code rootshell shows.";

pub async fn ensure(args: &Args, path: &Path) -> Result<()> {
    let mut saved_refused = None;
    if path.exists() {
        match tunnel::verify(args.device, path).await {
            Ok(()) => {
                ui::ok("this iPhone accepts the pairing file saved on an earlier run");
                return Ok(());
            }
            Err(f) => {
                ui::info("this iPhone doesn't accept the saved pairing file; taking the one from rootshell");
                ui::detail(&f.raw);
                saved_refused = Some(f);
            }
        }
    }
    let offer = SocketAddr::from(([127, 0, 0, 1], HANDOFF_PORT));
    let ask = || ui::ask("Transfer code shown in rootshell: ");
    if !take(offer, path, ask, ANSWER_WAIT).await? {
        return Err(saved_refused.unwrap_or_else(|| {
            Fail::new(
                format!("rootshell isn't offering a pairing file. {ROOTSHELL_ROUTE}"),
                format!("nothing answered on {offer}, and there's no {}", path.display()),
            )
        }));
    }
    tunnel::verify(args.device, path).await?;
    ui::ok("this iPhone accepts the pairing file from rootshell");
    Ok(())
}

/// siboot-pair's answer to one code.
enum Reply {
    File(Vec<u8>),
    WrongCode,
    Unexpected(String),
}

/// Send one code on `stream` and read siboot-pair's answer: `NO`, or
/// `OK <length>` and the file.
async fn exchange(stream: &mut TcpStream, code: &str) -> std::io::Result<Reply> {
    stream.write_all(format!("SIBOOT1 {code}\n").as_bytes()).await?;
    let mut reader = BufReader::new(stream);
    let mut answer = String::new();
    if reader.read_line(&mut answer).await? == 0 {
        return Err(std::io::Error::new(
            std::io::ErrorKind::UnexpectedEof,
            "rootshell closed the connection without answering",
        ));
    }
    let answer = answer.trim();
    if answer == "NO" {
        return Ok(Reply::WrongCode);
    }
    let Some(len) = answer.strip_prefix("OK ").and_then(|n| n.parse::<usize>().ok()) else {
        return Ok(Reply::Unexpected(answer.to_string()));
    };
    if len == 0 || len > MAX_FILE {
        return Ok(Reply::Unexpected(answer.to_string()));
    }
    let mut file = vec![0u8; len];
    reader.read_exact(&mut file).await?;
    Ok(Reply::File(file))
}

/// Take the pairing file siboot-pair is offering at `offer`, for the transfer
/// code it shows, into `path`. The code proves the request comes from the
/// person at the iPhone, not another app. False when nothing is offering one,
/// or no code was typed. Each answer may take up to `wait`.
async fn take(
    offer: SocketAddr,
    path: &Path,
    mut ask: impl FnMut() -> Option<String>,
    wait: Duration,
) -> Result<bool> {
    let connect = || timeout(Duration::from_secs(2), TcpStream::connect(offer));
    let Ok(Ok(mut stream)) = connect().await else {
        return Ok(false);
    };
    ui::ok("rootshell is offering the pairing file it made");
    for attempt in 1..=CODE_TRIES {
        let Some(typed) = ask() else {
            return Ok(false);
        };
        let code: String = typed.chars().filter(char::is_ascii_digit).collect();
        // siboot-pair answers one request per connection.
        if attempt > 1 {
            stream = match connect().await {
                Ok(Ok(s)) => s,
                _ => {
                    return Err(Fail::new(
                        "rootshell stopped offering the pairing file. Run `./siboot-pair.wasm` in \
                         rootshell again, then siboot here.",
                        "",
                    ))
                }
            };
        }
        let file = match timeout(wait, exchange(&mut stream, &code)).await {
            Err(_) => {
                return Err(Fail::new(
                    "rootshell didn't answer: iOS has probably paused it. Check its Settings › \
                     Location Diary Mode is on Session Only, open rootshell for a moment, then \
                     come back here and run siboot again.",
                    format!("no answer on {offer} within {} s", wait.as_secs()),
                ))
            }
            Ok(Err(e)) => {
                return Err(Fail::new(
                    "The hand-over from rootshell broke off. Run siboot again.",
                    e.to_string(),
                ))
            }
            Ok(Ok(Reply::Unexpected(answer))) => {
                return Err(Fail::new("rootshell sent something that isn't a pairing file.", answer))
            }
            Ok(Ok(Reply::WrongCode)) => {
                ui::warn("That isn't the code rootshell shows.");
                continue;
            }
            Ok(Ok(Reply::File(file))) => file,
        };
        // Checked before it replaces a file that may still work.
        if let Err(e) = RpPairingFile::from_bytes(&file) {
            return Err(Fail::new("rootshell sent something that isn't a pairing file.", e.to_string()));
        }
        save(path, &file)?;
        ui::ok(&format!("took the pairing file from rootshell ({} bytes)", file.len()));
        return Ok(true);
    }
    Err(Fail::new(
        "The transfer code didn't match. Run siboot again and type the code rootshell shows.",
        "",
    ))
}

/// Write the pairing file, readable by this user only: it holds the private key.
fn save(path: &Path, file: &[u8]) -> Result<()> {
    let failed = |e: std::io::Error| Fail::new(format!("Couldn't save the pairing file at {}.", path.display()), e.to_string());
    if let Some(dir) = path.parent() {
        std::fs::create_dir_all(dir).map_err(failed)?;
    }
    std::fs::write(path, file).map_err(failed)?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o600)).map_err(failed)?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;
    use tokio::net::TcpListener;

    const QUICK: Duration = Duration::from_secs(5);

    fn temp_home(tag: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("siboot-test-{tag}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    fn a_pairing_file() -> Vec<u8> {
        RpPairingFile::generate("siboot test").to_bytes()
    }

    /// siboot-pair's side of the hand-off (rootshell/src/main.rs, `offer`):
    /// one request per connection, `NO` for a wrong code.
    async fn rootshell_offering(code: &'static str, file: Vec<u8>) -> SocketAddr {
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        tokio::spawn(async move {
            loop {
                let (mut conn, _) = listener.accept().await.unwrap();
                let mut asked = String::new();
                BufReader::new(&mut conn).read_line(&mut asked).await.unwrap();
                if asked.trim() == format!("SIBOOT1 {code}") {
                    conn.write_all(format!("OK {}\n", file.len()).as_bytes()).await.unwrap();
                    conn.write_all(&file).await.unwrap();
                    return;
                }
                conn.write_all(b"NO\n").await.unwrap();
            }
        });
        addr
    }

    fn typing(codes: &'static [&'static str]) -> impl FnMut() -> Option<String> {
        let mut codes = codes.iter();
        move || codes.next().map(|c| c.to_string())
    }

    #[tokio::test]
    async fn the_file_comes_over_for_the_code_and_only_this_user_can_read_it() {
        let home = temp_home("take");
        let path = home.join("rp_pairing_file.plist");
        let file = a_pairing_file();
        let offer = rootshell_offering("481516", file.clone()).await;
        assert!(take(offer, &path, typing(&["481 516"]), QUICK).await.unwrap());
        assert_eq!(std::fs::read(&path).unwrap(), file);
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            assert_eq!(std::fs::metadata(&path).unwrap().permissions().mode() & 0o777, 0o600);
        }
    }

    #[tokio::test]
    async fn a_mistyped_code_gets_another_try() {
        let home = temp_home("retry");
        let path = home.join("rp_pairing_file.plist");
        let offer = rootshell_offering("481516", a_pairing_file()).await;
        assert!(take(offer, &path, typing(&["481517", "481516"]), QUICK).await.unwrap());
        assert!(path.exists());
    }

    #[tokio::test]
    async fn three_wrong_codes_say_so_and_keep_the_old_file() {
        let home = temp_home("wrong");
        let path = home.join("rp_pairing_file.plist");
        std::fs::write(&path, b"the old file").unwrap();
        let offer = rootshell_offering("481516", a_pairing_file()).await;
        let failure = take(offer, &path, typing(&["1", "2", "3"]), QUICK).await.err().unwrap();
        assert!(failure.advice.contains("didn't match"), "{}", failure.advice);
        assert_eq!(std::fs::read(&path).unwrap(), b"the old file");
    }

    #[tokio::test]
    async fn something_that_isnt_a_pairing_file_is_refused() {
        let home = temp_home("junk");
        let path = home.join("rp_pairing_file.plist");
        let offer = rootshell_offering("481516", b"not a plist".to_vec()).await;
        let failure = take(offer, &path, typing(&["481516"]), QUICK).await.err().unwrap();
        assert!(failure.advice.contains("isn't a pairing file"), "{}", failure.advice);
        assert!(!path.exists());
    }

    /// What siboot met on the iPhone with rootshell in the background: the
    /// connection goes through, and then nothing answers.
    #[tokio::test]
    async fn a_rootshell_that_never_answers_is_given_up_on() {
        let home = temp_home("silent");
        let path = home.join("rp_pairing_file.plist");
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let offer = listener.local_addr().unwrap();
        let held = tokio::spawn(async move {
            let (conn, _) = listener.accept().await.unwrap();
            tokio::time::sleep(Duration::from_secs(30)).await;
            drop(conn);
        });
        let started = std::time::Instant::now();
        let failure = take(offer, &path, typing(&["481516"]), Duration::from_millis(300))
            .await
            .err()
            .expect("a silent rootshell should end the wait");
        assert!(started.elapsed() < Duration::from_secs(5));
        assert!(failure.advice.contains("didn't answer"), "{}", failure.advice);
        assert!(!path.exists());
        held.abort();
    }

    #[tokio::test]
    async fn nothing_offering_means_nothing_taken() {
        let home = temp_home("none");
        let path = home.join("rp_pairing_file.plist");
        let closed = {
            let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
            listener.local_addr().unwrap()
        };
        assert!(!take(closed, &path, typing(&[]), QUICK).await.unwrap());
        assert!(!path.exists());
    }
}
