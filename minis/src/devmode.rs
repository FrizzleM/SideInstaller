//! `siboot developer-mode`: shows Developer Mode under Settings › Privacy &
//! Security, or turns it on, as SideInstaller's Settings › Developer Mode does
//! (`Engine.requestDeveloperMode` in ../ios-app): inside the tunnel, lockdownd
//! says whether it's on (`DeveloperModeStatus` in `com.apple.security.mac.amfi`),
//! and AMFI's RSD shim (`com.apple.amfi.lockdown.shim.remote`) takes the
//! request, action 0 to show the switch or 1 to turn it on.
//!
//! It goes through the same pairing and tunnel as the install, so it can only
//! help while the iPhone still answers on its pairing port with that pairing.
//! It never sends anything when Developer Mode is already on: turning it on
//! restarts the iPhone.

use std::time::Duration;

use idevice::amfi::AmfiClient;
use idevice::lockdown::LockdownClient;
use idevice::{IdeviceError, RsdService};
use tokio::time::timeout;

use crate::fail::{chain, Fail, Result};
use crate::tunnel::{self, Connection};
use crate::ui;

const AMFI_DOMAIN: &str = "com.apple.security.mac.amfi";
const STATUS_KEY: &str = "DeveloperModeStatus";
/// How long AMFI may take to answer a request. Turning Developer Mode on can
/// restart the iPhone before the answer comes.
const REPLY_WAIT: Duration = Duration::from_secs(20);

/// What the user asked for.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Request {
    /// Show the Developer Mode switch in Settings.
    Show,
    /// Turn Developer Mode on: the iPhone restarts, then asks to confirm.
    TurnOn,
}

#[derive(Debug, PartialEq, Eq)]
pub enum Outcome {
    /// It was on already, so nothing was sent.
    AlreadyOn,
    /// The switch now shows in Settings.
    Shown,
    /// AMFI took the request, and the iPhone restarts.
    TurningOn,
    /// The iPhone hung up right after the request, as it does when it
    /// restarts before answering.
    HungUp,
    /// iOS refused to turn it on because of the passcode, so the switch was
    /// shown in Settings instead.
    ShownForPasscode,
}

/// The services a request goes to: the tunnel's, or stand-ins in the tests.
pub trait Services {
    async fn lockdown(&mut self) -> std::result::Result<LockdownClient, IdeviceError>;
    async fn amfi(&mut self) -> std::result::Result<AmfiClient, IdeviceError>;
}

impl Services for Connection {
    async fn lockdown(&mut self) -> std::result::Result<LockdownClient, IdeviceError> {
        LockdownClient::connect_rsd(&mut self.adapter, &mut self.handshake).await
    }

    async fn amfi(&mut self) -> std::result::Result<AmfiClient, IdeviceError> {
        AmfiClient::connect_rsd(&mut self.adapter, &mut self.handshake).await
    }
}

/// Added to a failure before the request: what's left when siboot can't reach
/// the iPhone.
pub fn unreachable_note(f: Fail) -> Fail {
    let mut advice = format!(
        "{} siboot changes Developer Mode through this same pairing and tunnel, so it can't \
         until they work.",
        f.advice
    );
    // The probe's own advice already says where the switch is.
    if !f.advice.contains("Developer Mode") {
        advice.push_str(" If Developer Mode is under Settings › Privacy & Security, turn it on there instead.");
    }
    Fail { advice, raw: f.raw }
}

/// Ask for `request`. `confirm` is asked before anything that restarts the
/// iPhone, and nothing is sent unless it says yes.
pub async fn run(
    device: &mut impl Services,
    request: Request,
    confirm: impl FnOnce() -> bool,
) -> Result<Outcome> {
    let on = match read_status(device).await {
        Ok(on) => on,
        Err(f) => {
            ui::warn("Couldn't read whether Developer Mode is on, so siboot asks anyway.");
            ui::detail(&f.raw);
            None
        }
    };
    match on {
        Some(true) => return Ok(Outcome::AlreadyOn),
        Some(false) => ui::info("Developer Mode is off"),
        None => {}
    }

    if request == Request::Show {
        return match send(device, Action::Show).await? {
            Sent::Done => Ok(Outcome::Shown),
            Sent::HungUp(raw) => Err(Fail::new(
                "The iPhone stopped answering before it said whether it shows Developer Mode. \
                 Look under Settings › Privacy & Security; if it isn't there, run siboot \
                 developer-mode again.",
                raw,
            )),
            Sent::Refused(raw) => Err(Fail::new(
                "This iPhone refused to show Developer Mode in Settings.",
                raw,
            )),
        };
    }

    ui::warn("Without a passcode, this iPhone restarts right away to turn Developer Mode on,");
    ui::warn("and Minis stops with it. Once you unlock it, tap Turn On in the alert iOS shows.");
    ui::info("With a passcode, iOS refuses, and siboot shows the switch in Settings instead.");
    if !confirm() {
        return Err(Fail::new(
            "Nothing was sent, so Developer Mode stays off. `siboot developer-mode` without \
             --turn-on only shows it in Settings, and restarts nothing.",
            "",
        ));
    }
    match send(device, Action::TurnOn).await? {
        Sent::Done => Ok(Outcome::TurningOn),
        Sent::HungUp(raw) => {
            ui::detail(&raw);
            Ok(Outcome::HungUp)
        }
        // AMFI answers {Error: "Device has a passcode set"}.
        Sent::Refused(raw) if raw.to_lowercase().contains("passcode") => {
            ui::info("iOS turns it on from here only while the iPhone has no passcode");
            ui::detail(&raw);
            match send(device, Action::Show).await? {
                Sent::Done => Ok(Outcome::ShownForPasscode),
                Sent::HungUp(raw) | Sent::Refused(raw) => Err(Fail::new(
                    "iOS turns Developer Mode on from here only while the iPhone has no passcode, \
                     and it didn't take the request to show it in Settings either. Run siboot \
                     developer-mode (without --turn-on) again.",
                    raw,
                )),
            }
        }
        Sent::Refused(raw) => Err(Fail::new(
            "This iPhone refused to turn Developer Mode on.",
            raw,
        )),
    }
}

/// Whether Developer Mode is on, as lockdownd says (as pymobiledevice3 reads
/// it). None when the answer isn't a yes or no.
async fn read_status(device: &mut impl Services) -> Result<Option<bool>> {
    let mut lockdown = tunnel::step("connecting to lockdownd", 15, device.lockdown()).await?;
    let value = tunnel::step(
        "asking whether Developer Mode is on",
        15,
        lockdown.get_value(Some(STATUS_KEY), Some(AMFI_DOMAIN)),
    )
    .await?;
    Ok(value.as_boolean())
}

#[derive(Clone, Copy)]
enum Action {
    Show,
    TurnOn,
}

/// What became of one AMFI request.
enum Sent {
    Done,
    /// The connection closed, or went quiet, after the request.
    HungUp(String),
    /// The iPhone answered with an error.
    Refused(String),
}

/// Send `action` on a fresh AMFI connection: iOS closes it after one request.
async fn send(device: &mut impl Services, action: Action) -> Result<Sent> {
    let mut amfi = tunnel::step("connecting to AMFI on the iPhone", 15, device.amfi()).await?;
    let answered = match action {
        Action::Show => timeout(REPLY_WAIT, amfi.reveal_developer_mode_option_in_ui()).await,
        Action::TurnOn => timeout(REPLY_WAIT, amfi.enable_developer_mode()).await,
    };
    Ok(match answered {
        Err(_) => Sent::HungUp(format!("no answer within {} s", REPLY_WAIT.as_secs())),
        Ok(Ok(())) => Sent::Done,
        Ok(Err(IdeviceError::Socket(e))) => Sent::HungUp(e.to_string()),
        Ok(Err(e)) => Sent::Refused(chain(&e)),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use idevice::Idevice;
    use std::sync::{Arc, Mutex};
    use tokio::io::{AsyncReadExt, AsyncWriteExt, DuplexStream};

    /// How a stand-in AMFI answers one request.
    #[derive(Clone, Copy)]
    enum Answer {
        Success,
        Passcode,
        OtherError,
        HangUp,
    }

    /// A stand-in iPhone: lockdownd answers the status read with `status`
    /// (or an error when None), and each AMFI connection answers its one
    /// request with the next of `answers`. Records the actions it was sent.
    struct FakeIphone {
        status: Option<plist::Value>,
        answers: Vec<Answer>,
        sent: Arc<Mutex<Vec<i64>>>,
        lockdown_asked: Arc<Mutex<Vec<(String, String)>>>,
    }

    impl FakeIphone {
        fn new(status: Option<plist::Value>, answers: &[Answer]) -> Self {
            Self {
                status,
                answers: answers.iter().rev().copied().collect(),
                sent: Arc::default(),
                lockdown_asked: Arc::default(),
            }
        }

        fn sent(&self) -> Vec<i64> {
            self.sent.lock().unwrap().clone()
        }
    }

    async fn read_message(stream: &mut DuplexStream) -> Option<plist::Dictionary> {
        let mut len = [0u8; 4];
        stream.read_exact(&mut len).await.ok()?;
        let mut body = vec![0u8; u32::from_be_bytes(len) as usize];
        stream.read_exact(&mut body).await.ok()?;
        plist::from_bytes(&body).ok()
    }

    async fn write_message(stream: &mut DuplexStream, message: plist::Dictionary) {
        let mut body = Vec::new();
        plist::Value::Dictionary(message).to_writer_xml(&mut body).unwrap();
        stream.write_all(&(body.len() as u32).to_be_bytes()).await.unwrap();
        stream.write_all(&body).await.unwrap();
    }

    fn dict(pairs: &[(&str, plist::Value)]) -> plist::Dictionary {
        pairs.iter().map(|(k, v)| (k.to_string(), v.clone())).collect()
    }

    impl Services for FakeIphone {
        async fn lockdown(&mut self) -> std::result::Result<LockdownClient, IdeviceError> {
            let (ours, mut theirs) = tokio::io::duplex(64 * 1024);
            let status = self.status.clone();
            let asked = self.lockdown_asked.clone();
            tokio::spawn(async move {
                let Some(request) = read_message(&mut theirs).await else { return };
                let field = |k: &str| request.get(k).and_then(|v| v.as_string()).unwrap_or("").to_string();
                asked.lock().unwrap().push((field("Key"), field("Domain")));
                let reply = match status {
                    Some(value) => dict(&[("Request", "GetValue".into()), ("Value", value)]),
                    None => dict(&[("Request", "GetValue".into()), ("Error", "MissingValue".into())]),
                };
                write_message(&mut theirs, reply).await;
            });
            Ok(LockdownClient::new(Idevice::new(Box::new(ours), "siboot")))
        }

        async fn amfi(&mut self) -> std::result::Result<AmfiClient, IdeviceError> {
            let answer = self.answers.pop().expect("siboot opened more AMFI connections than expected");
            let (ours, mut theirs) = tokio::io::duplex(64 * 1024);
            let sent = self.sent.clone();
            tokio::spawn(async move {
                let Some(request) = read_message(&mut theirs).await else { return };
                let action = request.get("action").and_then(|v| v.as_signed_integer()).unwrap_or(-1);
                sent.lock().unwrap().push(action);
                let reply = match answer {
                    Answer::Success => dict(&[("success", true.into())]),
                    Answer::Passcode => dict(&[("Error", "Device has a passcode set".into())]),
                    Answer::OtherError => dict(&[("Error", "Something else".into())]),
                    Answer::HangUp => return,
                };
                write_message(&mut theirs, reply).await;
            });
            Ok(AmfiClient::new(Idevice::new(Box::new(ours), "")))
        }
    }

    fn never_asked() -> bool {
        panic!("asked to confirm a restart that shouldn't be sent")
    }

    #[tokio::test]
    async fn already_on_sends_nothing() {
        for request in [Request::Show, Request::TurnOn] {
            let mut iphone = FakeIphone::new(Some(true.into()), &[]);
            let outcome = run(&mut iphone, request, never_asked).await.unwrap();
            assert_eq!(outcome, Outcome::AlreadyOn);
            assert!(iphone.sent().is_empty());
            assert_eq!(
                iphone.lockdown_asked.lock().unwrap().as_slice(),
                [(STATUS_KEY.to_string(), AMFI_DOMAIN.to_string())]
            );
        }
    }

    #[tokio::test]
    async fn off_is_shown_without_asking() {
        let mut iphone = FakeIphone::new(Some(false.into()), &[Answer::Success]);
        let outcome = run(&mut iphone, Request::Show, never_asked).await.unwrap();
        assert_eq!(outcome, Outcome::Shown);
        assert_eq!(iphone.sent(), [0]);
    }

    #[tokio::test]
    async fn an_unreadable_status_still_sends_the_request() {
        let mut iphone = FakeIphone::new(None, &[Answer::Success]);
        assert_eq!(run(&mut iphone, Request::Show, never_asked).await.unwrap(), Outcome::Shown);
        assert_eq!(iphone.sent(), [0]);

        // Not a yes or no: unknown, too.
        let mut iphone = FakeIphone::new(Some("maybe".into()), &[Answer::Success]);
        assert_eq!(run(&mut iphone, Request::Show, never_asked).await.unwrap(), Outcome::Shown);
        assert_eq!(iphone.sent(), [0]);
    }

    #[tokio::test]
    async fn turning_on_needs_a_yes() {
        let mut iphone = FakeIphone::new(Some(false.into()), &[]);
        let f = run(&mut iphone, Request::TurnOn, || false).await.unwrap_err();
        assert!(f.advice.contains("Nothing was sent"), "{}", f.advice);
        assert!(iphone.sent().is_empty());

        let mut iphone = FakeIphone::new(Some(false.into()), &[Answer::Success]);
        let outcome = run(&mut iphone, Request::TurnOn, || true).await.unwrap();
        assert_eq!(outcome, Outcome::TurningOn);
        assert_eq!(iphone.sent(), [1]);
    }

    #[tokio::test]
    async fn a_passcode_refusal_shows_the_switch_instead() {
        let mut iphone = FakeIphone::new(Some(false.into()), &[Answer::Passcode, Answer::Success]);
        let outcome = run(&mut iphone, Request::TurnOn, || true).await.unwrap();
        assert_eq!(outcome, Outcome::ShownForPasscode);
        assert_eq!(iphone.sent(), [1, 0]);
    }

    #[tokio::test]
    async fn a_hang_up_after_turning_on_is_the_restart() {
        let mut iphone = FakeIphone::new(Some(false.into()), &[Answer::HangUp]);
        let outcome = run(&mut iphone, Request::TurnOn, || true).await.unwrap();
        assert_eq!(outcome, Outcome::HungUp);
        assert_eq!(iphone.sent(), [1]);
    }

    #[tokio::test]
    async fn other_refusals_stop_with_what_the_iphone_said() {
        let mut iphone = FakeIphone::new(Some(false.into()), &[Answer::OtherError]);
        let f = run(&mut iphone, Request::TurnOn, || true).await.unwrap_err();
        assert!(f.advice.contains("refused to turn Developer Mode on"), "{}", f.advice);
        assert!(f.raw.contains("Something else"), "{}", f.raw);
        assert_eq!(iphone.sent(), [1]);

        let mut iphone = FakeIphone::new(Some(false.into()), &[Answer::OtherError]);
        let f = run(&mut iphone, Request::Show, never_asked).await.unwrap_err();
        assert!(f.advice.contains("refused to show Developer Mode"), "{}", f.advice);

        let mut iphone = FakeIphone::new(Some(false.into()), &[Answer::HangUp]);
        let f = run(&mut iphone, Request::Show, never_asked).await.unwrap_err();
        assert!(f.advice.contains("stopped answering"), "{}", f.advice);
    }

    #[test]
    fn the_note_keeps_the_original_advice_and_cause() {
        let f = unreachable_note(Fail::new("Couldn't reach 10.7.0.1:49152.", "refused"));
        assert!(f.advice.starts_with("Couldn't reach 10.7.0.1:49152. siboot changes"));
        assert!(f.advice.ends_with("turn it on there instead."), "{}", f.advice);
        assert_eq!(f.raw, "refused");

        // Said once, where the advice already names the switch.
        let f = unreachable_note(Fail::new("Turn on Developer Mode (Settings › …).", ""));
        assert_eq!(f.advice.matches("Settings ›").count(), 1, "{}", f.advice);
    }
}
