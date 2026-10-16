use std::{future::Future, sync::Arc};

use crate::{
    SideloadError,
    anisette::{
        AnisetteClientInfo, AnisetteData, AnisetteDataGenerator,
        remote_v3::WINDOWS_CLIENT_INFO,
    },
    auth::{
        builder::AppleAccountBuilder,
        grandslam::{GrandSlam, GrandSlamErrorChecker},
    },
    util::plist::{PlistDataExtract, SensitivePlistAttachment},
};
use aes::{
    Aes256,
    cipher::{block_padding::Pkcs7, consts::U16},
};
use aes_gcm::{AeadInOut, AesGcm, KeyInit, Nonce};
use base64::{Engine, prelude::BASE64_STANDARD};
use cbc::cipher::{BlockModeDecrypt, KeyIvInit};
use hmac::{Hmac, Mac};
use plist::Dictionary;
use plist_macro::plist;
use reqwest::header::{HeaderMap, HeaderValue};
use rootcause::prelude::*;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use srp::{ClientVerifier, groups::G2048};
use tracing::{debug, info, warn};

pub struct AppleAccount {
    pub email: String,
    pub spd: Option<plist::Dictionary>,
    pub anisette_generator: AnisetteDataGenerator,
    pub grandslam_client: Arc<GrandSlam>,
    pub trusted_phone_numbers: Option<Vec<TrustedNumber>>,
    login_state: LoginState,
    debug: bool,
    last_error: Option<String>,
    /// How the pending phone code was asked for: a text or a call.
    phone_mode: PhoneCodeMode,
    /// The pages under gsa.apple.com/auth turned the client away with a bare
    /// 403, so they're asked as a Mac (see `send_auth`).
    auth_as_mac: bool,
}

#[derive(Debug, Clone)]
pub enum LoginState {
    LoggedIn,
    NeedsDevice2FA,
    NeedsDevice2FAVerification,
    NeedsSMS2FA(u32),
    NeedsSMS2FAVerification(u32),
    NeedsUnknown2FA,
    NeedsExtraStep(String),
    NeedsLogin,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct TrustedNumber {
    pub number_with_dial_code: String,
    #[serde(default)]
    pub last_two_digits: String,
    /// `sms` or `voice`: how Apple reaches this number. A landline is `voice`.
    #[serde(default)]
    pub push_mode: String,
    pub id: u32,
}

/// How a code reaches a trusted phone number. Upstream only texts; a call is
/// the same request with `"mode": "voice"`, which SideStore also offers.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum PhoneCodeMode {
    Sms,
    Voice,
}

impl PhoneCodeMode {
    pub fn as_str(self) -> &'static str {
        match self {
            PhoneCodeMode::Sms => "sms",
            PhoneCodeMode::Voice => "voice",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TwoFactorCallbackParams {
    pub last_error: Option<String>,
    // If this is true, we don't know what's going to work, so present the user with all the options and let them choose
    pub unknown: bool,
    /// A code went to `selected_number_id` instead of the trusted devices.
    pub sms: bool,
    /// With `sms`: that code is being read out in a call rather than texted.
    pub voice: bool,
    pub numbers: Vec<TrustedNumber>,
    pub selected_number_id: Option<u32>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TwoFactorCallbackResponse {
    SubmitCode(String),
    SendSms(u32),
    /// Have Apple call this trusted number and read the code out.
    CallNumber(u32),
    SendToDevices,
    ResendCode,
    Abort,
}

#[derive(Debug, Clone)]
pub struct SMSTwoFactorError {
    pub code: String,
    pub title: String,
    pub message: String,
}

#[derive(Debug)]
enum SmsSendOutcome {
    Sent,
    ActiveChallenge,
    ServiceError(SMSTwoFactorError),
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct SmsChallengeResponse {
    mode: String,
    #[serde(rename = "type")]
    challenge_type: String,
    authentication_type: String,
    trusted_phone_numbers: Vec<TrustedNumber>,
    trusted_phone_number: TrustedNumber,
    security_code: SmsSecurityCode,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct SmsSecurityCode {
    length: u8,
    too_many_codes_sent: bool,
    too_many_codes_validated: bool,
    security_code_locked: bool,
    security_code_cooldown: bool,
}

impl AppleAccount {
    /// Create a new AppleAccountBuilder with the given email
    ///
    /// # Arguments
    /// - `email`: The Apple ID email address
    pub fn builder(email: &str) -> AppleAccountBuilder {
        AppleAccountBuilder::new(email)
    }

    /// Build the apple account with the given email
    ///
    /// Reccomended to use the AppleAccountBuilder instead
    /// # Arguments
    /// - `email`: The Apple ID email address
    /// - `anisette_provider`: The anisette provider to use
    /// - `debug`: DANGER, If true, accept invalid certificates and enable verbose connection
    pub async fn new(
        email: &str,
        anisette_generator: AnisetteDataGenerator,
        debug: bool,
    ) -> Result<Self, Report> {
        if debug {
            warn!("Debug mode enabled: this is a security risk!");
        }

        let client_info = match anisette_generator.get_client_info().await {
            Ok(client_info) => client_info,
            // The anisette server is asked before Apple. When it can't be
            // reached at all, Apple is checked too: if the URL bag can't be
            // fetched either, the device's network is the problem, and that
            // error says so, as it did when the bag came first.
            Err(e) if is_unreachable(&e) => {
                let fallback = AnisetteClientInfo {
                    client_info: WINDOWS_CLIENT_INFO.to_string(),
                    user_agent: "akd/1.0 CFNetwork/808.1.4".to_string(),
                };
                if let Err(apple) = GrandSlam::new(fallback, debug).await {
                    return Err(apple
                        .context("Neither the anisette server nor Apple could be reached")
                        .into());
                }
                return Err(e.context("Failed to get anisette client info").into());
            }
            Err(e) => return Err(e.context("Failed to get anisette client info").into()),
        };

        let grandslam_client = GrandSlam::new(client_info, debug).await?;

        Ok(AppleAccount {
            email: email.to_string(),
            spd: None,
            anisette_generator,
            grandslam_client: Arc::new(grandslam_client),
            debug,
            login_state: LoginState::NeedsLogin,
            trusted_phone_numbers: None,
            last_error: None,
            phone_mode: PhoneCodeMode::Sms,
            auth_as_mac: false,
        })
    }

    /// Log in to the Apple ID account
    /// # Arguments
    /// - `password`: The Apple ID password
    /// - `two_factor_callback`: Called whenever Apple is waiting on the user. It answers with
    ///   a code, a request for a code by another route, or an abort.
    /// # Errors
    /// Returns an error if the login fails
    pub async fn login<C, Fut>(
        &mut self,
        password: &str,
        two_factor_callback: C,
    ) -> Result<(), Report>
    where
        C: Fn(TwoFactorCallbackParams) -> Fut + Send + Sync,
        Fut: Future<Output = Result<TwoFactorCallbackResponse, Report>> + Send,
    {
        info!("Logging in to Apple ID: {}", censor_email(&self.email));
        if self.debug {
            warn!("Debug mode enabled: this is a security risk!");
        }

        self.login_state = self
            .login_inner(password)
            .await
            .context("Failed to log in to Apple ID")?;

        debug!("Initial login successful");

        let mut attempts = 0;

        loop {
            attempts += 1;
            // Every prompt, resend and change of method is a step, so leave room
            // for someone who mistypes a code and then switches to a text.
            if attempts > 30 {
                bail!(
                    "Couldn't login after 30 attempts, aborting (current state: {:?})",
                    self.login_state
                );
            }
            match self.login_state.clone() {
                LoginState::LoggedIn => {
                    info!("Successfully logged in to Apple ID");
                    return Ok(());
                }
                LoginState::NeedsDevice2FA => {
                    self.load_trusted_numbers().await;
                    self.send_trusted_device_2fa()
                        .await
                        .context("Failed to complete trusted device 2FA")?;
                    self.login_state = LoginState::NeedsDevice2FAVerification;
                }
                LoginState::NeedsDevice2FAVerification => {
                    // Not loaded yet when Apple sent the code unasked.
                    self.load_trusted_numbers().await;
                    let response = two_factor_callback(self.callback_params(false, None)).await?;
                    self.last_error = None;
                    self.login_state = match response {
                        TwoFactorCallbackResponse::SubmitCode(code) => self
                            .verify_trusted_device_2fa(code)
                            .await
                            .context("Failed to verify trusted device 2FA")?,
                        TwoFactorCallbackResponse::SendSms(number) => {
                            self.select_number(number, PhoneCodeMode::Sms)?
                        }
                        TwoFactorCallbackResponse::CallNumber(number) => {
                            self.select_number(number, PhoneCodeMode::Voice)?
                        }
                        TwoFactorCallbackResponse::SendToDevices
                        | TwoFactorCallbackResponse::ResendCode => LoginState::NeedsDevice2FA,
                        TwoFactorCallbackResponse::Abort => {
                            bail!("No 2FA code provided, aborting")
                        }
                    };
                }
                LoginState::NeedsSMS2FA(id) => {
                    self.load_trusted_numbers().await;
                    let id = self.resolve_number_id(id);
                    info!("Phone 2FA required ({})", self.phone_mode.as_str());
                    self.login_state = self
                        .send_sms_2fa(id)
                        .await
                        .context("Failed to request a phone 2FA code")?;
                }
                LoginState::NeedsSMS2FAVerification(id) => {
                    let response =
                        two_factor_callback(self.callback_params(false, Some(id))).await?;
                    self.last_error = None;
                    self.login_state = match response {
                        TwoFactorCallbackResponse::SubmitCode(code) => self
                            .verify_sms_2fa(code, id)
                            .await
                            .context("Failed to verify phone 2FA")?,
                        TwoFactorCallbackResponse::SendSms(number) => {
                            self.select_number(number, PhoneCodeMode::Sms)?
                        }
                        TwoFactorCallbackResponse::CallNumber(number) => {
                            self.select_number(number, PhoneCodeMode::Voice)?
                        }
                        TwoFactorCallbackResponse::ResendCode => LoginState::NeedsSMS2FA(id),
                        TwoFactorCallbackResponse::SendToDevices => LoginState::NeedsDevice2FA,
                        TwoFactorCallbackResponse::Abort => {
                            bail!("No 2FA code provided, aborting")
                        }
                    };
                }
                LoginState::NeedsUnknown2FA => {
                    info!(
                        "The most recently attempted 2FA Method failed, please try a different method."
                    );
                    let response = two_factor_callback(self.callback_params(true, None)).await?;
                    self.last_error = None;
                    self.login_state = match response {
                        TwoFactorCallbackResponse::SubmitCode(_) => {
                            bail!("Cannot submit code without knowing which method to use")
                        }
                        TwoFactorCallbackResponse::SendSms(number) => {
                            self.select_number(number, PhoneCodeMode::Sms)?
                        }
                        TwoFactorCallbackResponse::CallNumber(number) => {
                            self.select_number(number, PhoneCodeMode::Voice)?
                        }
                        TwoFactorCallbackResponse::SendToDevices => LoginState::NeedsDevice2FA,
                        TwoFactorCallbackResponse::ResendCode => {
                            bail!("Cannot resend code without knowing which method to use")
                        }
                        TwoFactorCallbackResponse::Abort => {
                            bail!("No 2FA method selected, aborting")
                        }
                    };
                }
                LoginState::NeedsExtraStep(s) => {
                    info!("Additional authentication step required: {}", s);
                    if self.get_pet().is_err() {
                        bail!("Additional authentication required: {}", s);
                    }
                    self.login_state = LoginState::LoggedIn;
                }
                LoginState::NeedsLogin => {
                    debug!("Logging in again...");
                    self.login_state = self
                        .login_inner(password)
                        .await
                        .context("Failed to login again")?;
                }
            }
        }
    }

    /// Get the user's first and last name associated with the Apple ID
    pub fn get_name(&self) -> Result<(String, String), Report> {
        let spd = self
            .spd
            .as_ref()
            .ok_or_else(|| report!("SPD not available, cannot get name"))?;

        Ok((spd.get_string("fn")?, spd.get_string("ln")?))
    }

    fn get_pet(&self) -> Result<String, Report> {
        let spd = self
            .spd
            .as_ref()
            .ok_or_else(|| report!("SPD not available, cannot get pet"))?;

        let pet = spd
            .get_dict("t")?
            .get_dict("com.apple.gs.idms.pet")?
            .get_string("token")?;

        Ok(pet)
    }

    fn callback_params(
        &self,
        unknown: bool,
        selected_number_id: Option<u32>,
    ) -> TwoFactorCallbackParams {
        let phone = selected_number_id.is_some();
        TwoFactorCallbackParams {
            last_error: self.last_error.clone(),
            unknown,
            sms: phone,
            voice: phone && self.phone_mode == PhoneCodeMode::Voice,
            numbers: self.trusted_phone_numbers.clone().unwrap_or_default(),
            selected_number_id,
        }
    }

    /// Fetch the trusted numbers once per login. Not fatal when it fails: the
    /// device code works without them, and so does the number Apple implied.
    async fn load_trusted_numbers(&mut self) {
        if self.trusted_phone_numbers.is_some() {
            return;
        }
        let numbers = match self.get_trusted_numbers().await {
            Ok(numbers) => numbers,
            Err(e) => {
                warn!("Couldn't load trusted phone numbers: {:?}", e);
                Vec::new()
            }
        };
        self.trusted_phone_numbers = Some(numbers);
    }

    /// `secondaryAuth` names no number, so that flow starts from id 1 as upstream
    /// does; switch to a real trusted number when 1 isn't one.
    fn resolve_number_id(&self, id: u32) -> u32 {
        Self::pick_number_id(self.trusted_phone_numbers.as_deref().unwrap_or_default(), id)
    }

    fn pick_number_id(numbers: &[TrustedNumber], id: u32) -> u32 {
        match numbers.first() {
            Some(first) if !numbers.iter().any(|n| n.id == id) => first.id,
            _ => id,
        }
    }

    async fn send_trusted_device_2fa(&mut self) -> Result<(), Report> {
        debug!("Trusted device 2FA required");

        let anisette_data = self
            .anisette_generator
            .get_anisette_data(self.grandslam_client.clone())
            .await
            .context("Failed to get anisette data for 2FA")?;

        let request_code_url = self
            .grandslam_client
            .get_url("trustedDeviceSecondaryAuth")?;

        let headers = self.build_2fa_headers(&anisette_data).await?;
        let (status, text) = self
            .send_auth(reqwest::Method::GET, &request_code_url, false, headers, None)
            .await
            .context("Failed to request trusted device 2fa")?;
        if !status.is_success() {
            bail!(
                "Trusted device 2FA request failed with http status {}: {}",
                status.as_u16(),
                text
            );
        }

        info!("Trusted device 2FA request sent");

        Ok(())
    }

    async fn verify_trusted_device_2fa(&mut self, code: String) -> Result<LoginState, Report> {
        let anisette_data = self
            .anisette_generator
            .get_anisette_data(self.grandslam_client.clone())
            .await
            .context("Failed to get anisette data for 2FA")?;

        let submit_code_url = self.grandslam_client.get_url("validateCode")?;

        let res = self
            .grandslam_client
            .get(&submit_code_url)?
            .headers(self.build_2fa_headers(&anisette_data).await?)
            .header("security-code", code)
            .send()
            .await
            .context("Failed to submit trusted device 2fa code")?
            .error_for_status()
            .context("Trusted device 2FA code submission failed")?
            .text()
            .await
            .context("Failed to read trusted device 2FA response text")?;

        let plist: Dictionary = plist::from_bytes(res.as_bytes())
            .context("Failed to parse trusted device response plist")
            .attach_with(|| res.clone())?;
        let res = plist
            .check_grandslam_error()
            .context("Trusted device 2FA rejected");
        if let Err(ref report) = res {
            for cause in report.iter_reports() {
                if let Some(&SideloadError::AuthWithMessage(code, ref message)) =
                    cause.downcast_current_context::<SideloadError>()
                {
                    // Incorrect Verification Code, let the user try again
                    if code == -21669 {
                        warn!("{} - {}", code, message);
                        self.last_error = format!("{} - {}", code, message).into();

                        return Ok(LoginState::NeedsDevice2FAVerification);
                    }
                }
            }
        }
        res?;

        debug!("Trusted device 2FA completed, need to login again");

        Ok(LoginState::NeedsLogin)
    }

    async fn send_sms_2fa(&mut self, id: u32) -> Result<LoginState, Report> {
        let anisette_data = self
            .anisette_generator
            .get_anisette_data(self.grandslam_client.clone())
            .await
            .context("Failed to get anisette data for 2FA")?;

        let mode = self.phone_mode;
        let send_body = serde_json::json!({
            "phoneNumber": {
                "id": id
            },
            "mode": mode.as_str()
        });

        let headers = self.build_2fa_headers(&anisette_data).await?;
        let (status, text) = self
            .send_auth(
                reqwest::Method::PUT,
                "https://gsa.apple.com/auth/verify/phone",
                true,
                headers,
                Some(send_body.to_string()),
            )
            .await
            .context("Failed to request phone 2FA code")?;

        match Self::classify_sms_send_response(status.as_u16(), &text, id, mode)? {
            SmsSendOutcome::Sent => {
                info!("Phone 2FA code requested ({})", mode.as_str());
            }
            SmsSendOutcome::ActiveChallenge => {
                info!("Phone 2FA challenge already active, proceeding to verification");
            }
            SmsSendOutcome::ServiceError(error) => {
                warn!("{} - {} ({})", error.title, error.message, error.code);
                self.last_error = format!("{} - {}", error.title, error.message).into();
                if matches!(error.code.as_str(), "-22979" | "-22981") {
                    // Apple refused to send a new code, but the last one sent is
                    // still valid: keep the selected number and let the user
                    // enter it without triggering another send.
                    return Ok(LoginState::NeedsSMS2FAVerification(id));
                }
                // -28248 means this method isn't available. Upstream fails the
                // sign-in on any other refusal; offering the other routes instead
                // matters here because a call may be refused where a text isn't.
                return Ok(LoginState::NeedsUnknown2FA);
            }
        }

        Ok(LoginState::NeedsSMS2FAVerification(id))
    }

    async fn verify_sms_2fa(&mut self, code: String, id: u32) -> Result<LoginState, Report> {
        let anisette_data = self
            .anisette_generator
            .get_anisette_data(self.grandslam_client.clone())
            .await
            .context("Failed to get anisette data for 2FA")?;

        let body = serde_json::json!({
            "securityCode": {
                "code": code
            },
            "phoneNumber": {
                "id": id
            },
            "mode": self.phone_mode.as_str()
        });

        let headers = self.build_2fa_headers(&anisette_data).await?;
        let (status, text) = self
            .send_auth(
                reqwest::Method::POST,
                "https://gsa.apple.com/auth/verify/phone/securitycode",
                true,
                headers,
                Some(body.to_string()),
            )
            .await
            .context("Failed to submit phone 2FA code")?;
        if !status.is_success() {
            let error = Self::parse_sms_error(text, status.as_u16())?;

            if error.code == "-21669" {
                // Incorrect Verification Code, let the user try again
                warn!("{} - {}", error.title, error.message);
                self.last_error = format!("{} - {}", error.title, error.message).into();
                return Ok(LoginState::NeedsSMS2FAVerification(id));
            }

            bail!(
                "Phone 2FA code submission failed (code {}): {} - {}",
                error.code,
                error.title,
                error.message
            );
        };

        debug!("Phone 2FA completed, need to login again");
        Ok(LoginState::NeedsLogin)
    }

    fn classify_sms_send_response(
        status: u16,
        text: &str,
        requested_number_id: u32,
        requested_mode: PhoneCodeMode,
    ) -> Result<SmsSendOutcome, Report> {
        if (200..300).contains(&status) {
            return Ok(SmsSendOutcome::Sent);
        }

        if let Some(error) = Self::parse_sms_service_error(text) {
            return Ok(SmsSendOutcome::ServiceError(error));
        }

        if status == 412
            && let Ok(challenge) = serde_json::from_str::<SmsChallengeResponse>(text)
            && challenge.mode == requested_mode.as_str()
            && challenge.challenge_type == "verification"
            && challenge.authentication_type == "hsa2"
            && challenge.trusted_phone_number.id == requested_number_id
            && challenge
                .trusted_phone_numbers
                .iter()
                .any(|number| number.id == requested_number_id)
            && challenge.security_code.length == 6
            && !challenge.security_code.too_many_codes_sent
            && !challenge.security_code.too_many_codes_validated
            && !challenge.security_code.security_code_locked
            && !challenge.security_code.security_code_cooldown
        {
            return Ok(SmsSendOutcome::ActiveChallenge);
        }

        bail!(
            "Phone 2FA request failed with http status {}: {}",
            status,
            text
        );
    }

    fn parse_sms_service_error(text: &str) -> Option<SMSTwoFactorError> {
        let json = serde_json::from_str::<serde_json::Value>(text).ok()?;
        let first_error = json.get("serviceErrors")?.as_array()?.first()?;
        let code = first_error
            .get("code")
            .and_then(|c| c.as_str())
            .unwrap_or("unknown");
        let title = first_error
            .get("title")
            .and_then(|t| t.as_str())
            .unwrap_or("No title provided");
        let message = first_error
            .get("message")
            .and_then(|m| m.as_str())
            .unwrap_or("No message provided");

        Some(SMSTwoFactorError {
            code: code.to_string(),
            title: title.to_string(),
            message: message.to_string(),
        })
    }

    fn parse_sms_error(text: String, status: u16) -> Result<SMSTwoFactorError, Report> {
        Self::parse_sms_service_error(&text).ok_or_else(|| {
            report!(
                "Phone 2FA code submission failed with http status {}: {}",
                status,
                text
            )
        })
    }

    async fn get_trusted_numbers(&mut self) -> Result<Vec<TrustedNumber>, Report> {
        let anisette_data = self
            .anisette_generator
            .get_anisette_data(self.grandslam_client.clone())
            .await
            .context("Failed to get anisette data for 2FA")?;

        let headers = self.build_2fa_headers(&anisette_data).await?;
        let (status, text) = self
            .send_auth(
                reqwest::Method::GET,
                "https://gsa.apple.com/auth",
                true,
                headers,
                None,
            )
            .await
            .context("Failed to read the trusted phone numbers")?;
        let status = status.as_u16();
        if let Ok(json) = serde_json::from_str::<serde_json::Value>(&text)
            && let Some(numbers) = json.get("trustedPhoneNumbers")
        {
            let numbers: Vec<TrustedNumber> = serde_json::from_value(numbers.clone())
                .context("Failed to parse trusted phone numbers")?;
            debug!(
                "Retrieved {} trusted phone numbers (status {}): {:?}",
                numbers.len(),
                status,
                numbers
            );
            return Ok(numbers);
        }

        bail!(
            "Failed to retrieve trusted phone numbers (status {}): {}",
            status,
            text
        );
    }

    fn select_number(
        &mut self,
        selected_number_id: u32,
        mode: PhoneCodeMode,
    ) -> Result<LoginState, Report> {
        let numbers = self.trusted_phone_numbers.clone().unwrap_or_default();
        if let Some(number) = numbers.iter().find(|n| n.id == selected_number_id) {
            debug!(
                "Selected trusted number: {} ({})",
                number.number_with_dial_code,
                mode.as_str()
            );
            self.phone_mode = mode;
            return Ok(LoginState::NeedsSMS2FA(number.id));
        }
        bail!("Selected trusted number ID not found in trusted numbers");
    }

    /// Sends a request to a page under gsa.apple.com/auth and returns its
    /// status and body. It says the client is the one the rest of sign-in
    /// reports; if a page turns that away with a bare 403 (no `serviceErrors`),
    /// as these pages did the Android phone, it's sent again as a Mac, and so
    /// are the session's later ones (see `GrandSlam`'s `MAC_CLIENT_INFO`).
    async fn send_auth(
        &mut self,
        method: reqwest::Method,
        url: &str,
        json: bool,
        headers: HeaderMap,
        body: Option<String>,
    ) -> Result<(reqwest::StatusCode, String), Report> {
        loop {
            let mut request = self
                .grandslam_client
                .auth(method.clone(), url, json, self.auth_as_mac)?
                .headers(headers.clone());
            if let Some(body) = &body {
                request = request.body(body.clone());
            }
            let response = request.send().await?;
            let status = response.status();
            let text = response.text().await.context("Failed to read the response")?;
            if Self::refuses_client(status.as_u16(), &text)
                && !self.auth_as_mac
                && !self.grandslam_client.is_mac()
            {
                warn!(
                    "{url} turned {} away with a bare 403; asking as a Mac",
                    self.grandslam_client.client_info.client_info
                );
                self.auth_as_mac = true;
                continue;
            }
            return Ok((status, text));
        }
    }

    /// A 403 without Apple's `serviceErrors`: the page refusing the client
    /// itself rather than answering the request.
    fn refuses_client(status: u16, text: &str) -> bool {
        status == 403 && Self::parse_sms_service_error(text).is_none()
    }

    async fn build_2fa_headers(&self, anisette_data: &AnisetteData) -> Result<HeaderMap, Report> {
        let mut headers = anisette_data.get_header_map()?;

        let spd = self
            .spd
            .as_ref()
            .ok_or_else(|| report!("SPD data not available, cannot build 2FA headers"))?;

        let adsid = spd
            .get_str("adsid")
            .context("Failed to build 2FA headers")?;
        let token = spd
            .get_str("GsIdmsToken")
            .context("Failed to build 2FA headers")?;
        let identity = BASE64_STANDARD.encode(format!("{}:{}", adsid, token));

        headers.insert(
            "X-Apple-Identity-Token",
            reqwest::header::HeaderValue::from_str(&identity)?,
        );
        headers.insert(
            "X-Apple-I-MD-RINFO",
            reqwest::header::HeaderValue::from_str(&anisette_data.routing_info)?,
        );

        Ok(headers)
    }

    async fn login_inner(&mut self, password: &str) -> Result<LoginState, Report> {
        let anisette_data = self
            .anisette_generator
            .get_anisette_data(self.grandslam_client.clone())
            .await
            .context("Failed to get anisette data for login")?;

        let gs_service_url = self.grandslam_client.get_url("gsService")?;
        debug!("GrandSlam service URL: {}", gs_service_url);

        let mut cpd = anisette_data.get_client_provided_data();

        let srp_client = srp::Client::<G2048, Sha256>::new_with_options(false);
        let a: Vec<u8> = (0..32).map(|_| rand::random::<u8>()).collect();
        let a_pub = srp_client.compute_public_ephemeral(&a);

        let email = self.email.clone();
        let init_request = |cpd: &Dictionary| {
            plist!(dict {
                "Header": {
                    "Version": "1.0.1"
                },
                "Request": {
                    "A2k": a_pub.clone(), // A2k = client public ephemeral
                    "cpd": cpd.clone(), // cpd = client provided data
                    "o": "init", // o = operation
                    "ps": [ // ps = protocols supported
                        "s2k",
                        "s2k_fo"
                    ],
                    "u": email.clone(), // u = username
                }
            })
        };

        debug!("Sending initial login request");

        let mut response = self
            .grandslam_client
            .plist_request(&gs_service_url, &init_request(&cpd), None, true)
            .await
            .context("Failed to send initial login request")?;

        // Anisette servers on Apple's Windows ADI library (ani.jkcoxson.com,
        // win.ani.sidestore.io) get this at the first sign-in of a machine
        // (the macOS-ADI ones haven't, 2026-10-16):
        // hsc 434, -22421 "This action could not be completed. Try again.", with
        // resync data for the ADI library. Once the server has applied it, the
        // same request goes through, and later sign-ins need no resync.
        if let Some(sim) = Self::resync_sim(&response) {
            info!("GrandSlam asked for an anisette resync (hsc 434); retrying");
            cpd = self
                .anisette_generator
                .resync(&sim)
                .await
                .context("Anisette resync failed")?
                .get_client_provided_data();
            response = self
                .grandslam_client
                .plist_request(&gs_service_url, &init_request(&cpd), None, true)
                .await
                .context("Failed to send initial login request after the anisette resync")?;
        }

        let response = response
            .check_grandslam_error()
            .context("GrandSlam error during initial login request")?;

        debug!("Login step 1 completed");

        let salt = response
            .get_data("s")
            .context("Failed to parse initial login response")?;
        let b_pub = response
            .get_data("B")
            .context("Failed to parse initial login response")?;
        let iters = response
            .get_signed_integer("i")
            .context("Failed to parse initial login response")?;
        let c = response
            .get_str("c")
            .context("Failed to parse initial login response")?;
        let selected_protocol = response
            .get_str("sp")
            .context("Failed to parse initial login response")?;

        debug!(
            "Selected SRP protocol: {}, iterations: {}",
            selected_protocol, iters
        );

        if selected_protocol != "s2k" && selected_protocol != "s2k_fo" {
            bail!("Unsupported SRP protocol selected: {}", selected_protocol);
        }

        let hashed_password = Sha256::digest(password.as_bytes());

        let password_hash = if selected_protocol == "s2k_fo" {
            hex::encode(hashed_password).into_bytes()
        } else {
            hashed_password.to_vec()
        };

        let mut password_buf = [0u8; 32];
        pbkdf2::pbkdf2::<hmac::Hmac<Sha256>>(&password_hash, salt, iters as u32, &mut password_buf)
            .context("Failed to derive password using PBKDF2")?;

        let verifier = srp_client
            .process_reply(&a, self.email.as_bytes(), &password_buf, salt, b_pub)
            .context("Failed to compute SRP proof")?;

        let req2 = plist!(dict {
            "Header": {
                "Version": "1.0.1"
            },
            "Request": {
                "M1": verifier.proof().to_vec(), // A2k = client public ephemeral
                "c": c, // c = client proof from step 1
                "cpd": cpd, // cpd = client provided data
                "o": "complete", // o = operation
                "u": self.email.clone(), // u = username
            }
        });

        debug!("Sending proof login request");

        let mut close_headers = HeaderMap::new();
        close_headers.insert("Connection", HeaderValue::from_static("close"));

        let response2 = self
            .grandslam_client
            .plist_request(&gs_service_url, &req2, Some(close_headers), true)
            .await
            .context("Failed to send proof login request")?
            .check_grandslam_error()
            .context("GrandSlam error during proof login request")?;

        debug!("Login step 2 response received, verifying server proof");

        let m2 = response2
            .get_data("M2")
            .context("Failed to parse proof login response")?;
        verifier
            .verify_server(m2)
            .map_err(|e| report!("Negotiation failed, server proof mismatch: {}", e))?;

        debug!("Server proof verified");

        let spd_encrypted = response2
            .get_data("spd")
            .context("Failed to get SPD from login response")?;

        let spd_decrypted = Self::decrypt_cbc(&verifier, spd_encrypted)
            .context("Failed to decrypt SPD from login response")?;
        let spd: plist::Dictionary =
            plist::from_bytes(&spd_decrypted).context("Failed to parse decrypted SPD plist")?;

        self.spd = Some(spd);

        let status = response2
            .get_dict("Status")
            .context("Failed to parse proof login response")?;

        debug!("Login step 2 completed");

        Ok(Self::state_after_proof(status))
    }

    /// The resync data (base64) in a GrandSlam `Response` whose `Status` asks
    /// for an anisette resync with hsc 434, or `None`.
    fn resync_sim(response: &Dictionary) -> Option<String> {
        let status = response.get("Status")?.as_dictionary()?;
        if status.get("hsc").and_then(|v| v.as_signed_integer()) != Some(434) {
            return None;
        }
        match status.get("X-Apple-I-MD-DATA")? {
            plist::Value::String(sim) => Some(sim.clone()),
            plist::Value::Data(sim) => Some(BASE64_STANDARD.encode(sim)),
            _ => None,
        }
    }

    /// What the `Status` of an accepted password proof asks for next.
    fn state_after_proof(status: &Dictionary) -> LoginState {
        if let Some(plist::Value::String(s)) = status.get("au") {
            return match s.as_str() {
                "trustedDeviceSecondaryAuth" => LoginState::NeedsDevice2FA,
                // Names no number: start from 1 as upstream does; the
                // state swaps in a real trusted number if 1 isn't one.
                "secondaryAuth" => LoginState::NeedsSMS2FA(1),
                "repair" => LoginState::LoggedIn, // Just means that you don't have 2FA set up
                unknown => LoginState::NeedsExtraStep(unknown.to_string()),
            };
        }

        // The Android phone this crate reported from 2026-10-13 to 2026-10-15
        // got no `au`. With hsc 409 a second step is still due, and Apple has
        // already pushed a code to the trusted devices: asking for another
        // isn't needed, `validateCode` takes that one. Taken for a finished
        // sign-in, the app token request after it fails with -22411.
        if status.get("hsc").and_then(|v| v.as_signed_integer()) == Some(409) {
            info!("Apple has sent a 2FA code to the trusted devices");
            return LoginState::NeedsDevice2FAVerification;
        }

        LoginState::LoggedIn
    }

    pub async fn get_app_token(&mut self, app: &str) -> Result<AppToken, Report> {
        let app = if app.contains("com.apple.gs.") {
            app.to_string()
        } else {
            format!("com.apple.gs.{}", app)
        };

        let anisette_data = self
            .anisette_generator
            .get_anisette_data(self.grandslam_client.clone())
            .await
            .context("Failed to get anisette data for login")?;

        let spd = self
            .spd
            .as_ref()
            .ok_or_else(|| report!("SPD data not available, cannot get app token"))?;

        let dsid = spd.get_str("adsid").context("Failed to get app token")?;
        let auth_token = spd
            .get_str("GsIdmsToken")
            .context("Failed to get app token")?;
        let session_key = spd.get_data("sk").context("Failed to get app token")?;
        let c = spd.get_data("c").context("Failed to get app token")?;

        let checksum = Hmac::<Sha256>::new_from_slice(session_key)
            .context("Failed to create HMAC for app token checksum")
            .attach_with(|| SensitivePlistAttachment::new(spd.clone()))?
            .chain_update("apptokens".as_bytes())
            .chain_update(dsid.as_bytes())
            .chain_update(app.as_bytes())
            .finalize()
            .into_bytes()
            .to_vec();

        let gs_service_url = self.grandslam_client.get_url("gsService")?;
        let cpd = anisette_data.get_client_provided_data();

        let request = plist!(dict {
            "Header": {
                "Version": "1.0.1"
            },
            "Request": {
                "app": [app.clone()],
                "c": c,
                "checksum": checksum,
                "cpd": cpd,
                "o": "apptokens",
                "u": dsid,
                "t": auth_token
            }
        });

        let resp = self
            .grandslam_client
            .plist_request(&gs_service_url, &request, None, true)
            .await
            .context("Failed to send app token request")?
            .check_grandslam_error()
            .context("GrandSlam error during app token request")?;

        let encrypted_token = resp
            .get_data("et")
            .context("Failed to get encrypted token")?;

        debug!("Acquired encrypted token for {}", app);
        let decrypted_token = Self::decrypt_gcm(encrypted_token, session_key)
            .context("Failed to decrypt app token")?;
        debug!("Decrypted app token for {}", app);

        let token: Dictionary = plist::from_bytes(&decrypted_token)
            .context("Failed to parse decrypted app token plist")?;

        let status = token
            .get_signed_integer("status-code")
            .context("Failed to get status code from app token")?;
        if status != 200 {
            bail!("App token request failed with status code {}", status);
        }
        let token_dict = token
            .get_dict("t")
            .context("Failed to get token dictionary from app token")?;
        let app_token = token_dict
            .get_dict(&app)
            .context("Failed to get app token string")?;

        let app_token = AppToken {
            token: app_token
                .get_str("token")
                .context("Failed to get app token string")?
                .to_string(),
            duration: app_token
                .get_signed_integer("duration")
                .context("Failed to get app token duration")? as u64,
            expiry: app_token
                .get_signed_integer("expiry")
                .context("Failed to get app token expiry")? as u64,
        };

        info!("Successfully retrieved app token for {}", app);

        Ok(app_token)
    }

    fn create_session_key(usr: &ClientVerifier<Sha256>, name: &str) -> Result<Vec<u8>, Report> {
        Ok(Hmac::<Sha256>::new_from_slice(usr.key())?
            .chain_update(name.as_bytes())
            .finalize()
            .into_bytes()
            .to_vec())
    }

    fn decrypt_cbc(usr: &ClientVerifier<Sha256>, data: &[u8]) -> Result<Vec<u8>, Report> {
        let extra_data_key = Self::create_session_key(usr, "extra data key:")?;
        let extra_data_iv = Self::create_session_key(usr, "extra data iv:")?;
        let extra_data_iv = &extra_data_iv[..16];

        Ok(
            cbc::Decryptor::<aes::Aes256>::new_from_slices(&extra_data_key, extra_data_iv)?
                .decrypt_padded_vec::<Pkcs7>(data)?,
        )
    }

    fn decrypt_gcm(data: &[u8], key: &[u8]) -> Result<Vec<u8>, Report> {
        if data.len() < 3 + 16 + 16 {
            bail!(
                "Encrypted token is too short to be valid (only {} bytes)",
                data.len()
            );
        }
        let header = &data[0..3];
        if header != b"XYZ" {
            bail!(
                "Encrypted token is in an unknown format: {}",
                String::from_utf8_lossy(header)
            );
        }
        let iv = &data[3..19];
        let ciphertext_and_tag = &data[19..];

        if key.len() != 32 {
            bail!("Session key is not the correct length: {} bytes", key.len());
        }
        if iv.len() != 16 {
            bail!("IV is not the correct length: {} bytes", iv.len());
        }

        debug!(
            "Decrypting GCM data with key of length {} and IV of length {}",
            key.len(),
            iv.len()
        );
        let key = aes_gcm::Key::<AesGcm<Aes256, U16>>::try_from(key)?;
        debug!("GCM key created successfully");
        let cipher = AesGcm::<Aes256, U16>::new(&key);
        debug!("GCM cipher initialized successfully");
        let nonce = Nonce::<U16>::try_from(iv)?;
        debug!("GCM nonce created successfully");

        let mut buf = ciphertext_and_tag.to_vec();

        cipher
            .decrypt_in_place(&nonce, header, &mut buf)
            .map_err(|e| report!("Failed to decrypt gcm: {}", e))?;
        debug!("GCM decryption successful");

        Ok(buf)
    }
}

#[cfg(test)]
mod sms_send_response_tests {
    // Upstream's contract tests from f560857 (dropped from its branch in c7e1bc4),
    // with the request mode added, plus the call and number-fallback cases.
    use super::{AppleAccount, PhoneCodeMode, SmsSendOutcome, TrustedNumber};
    use serde_json::{Value, json};

    fn active_challenge() -> Value {
        json!({
            "trustedPhoneNumbers": [{
                "numberWithDialCode": "+1 •• •• •• •• 00",
                "lastTwoDigits": "00",
                "pushMode": "sms",
                "id": 2
            }],
            "securityCode": {
                "length": 6,
                "tooManyCodesSent": false,
                "tooManyCodesValidated": false,
                "securityCodeLocked": false,
                "securityCodeCooldown": false
            },
            "mode": "sms",
            "type": "verification",
            "authenticationType": "hsa2",
            "trustedPhoneNumber": {
                "numberWithDialCode": "+1 •• •• •• •• 00",
                "lastTwoDigits": "00",
                "pushMode": "sms",
                "id": 2
            }
        })
    }

    fn classify(status: u16, body: &str, id: u32) -> rootcause::Report {
        AppleAccount::classify_sms_send_response(status, body, id, PhoneCodeMode::Sms).unwrap_err()
    }

    #[test]
    fn accepts_success_status_without_a_response_body() {
        let outcome =
            AppleAccount::classify_sms_send_response(200, "", 2, PhoneCodeMode::Sms).unwrap();

        assert!(matches!(outcome, SmsSendOutcome::Sent));
    }

    #[test]
    fn accepts_precondition_failed_when_the_requested_sms_challenge_is_active() {
        let body = active_challenge().to_string();
        let outcome =
            AppleAccount::classify_sms_send_response(412, &body, 2, PhoneCodeMode::Sms).unwrap();

        assert!(matches!(outcome, SmsSendOutcome::ActiveChallenge));
    }

    #[test]
    fn rejects_an_active_challenge_for_a_different_phone_number() {
        let body = active_challenge().to_string();
        let error = classify(412, &body, 3);

        assert!(error.to_string().contains("http status 412"));
    }

    #[test]
    fn rejects_a_malformed_precondition_failed_response() {
        let error = classify(412, r#"{"trustedPhoneNumbers":"invalid"}"#, 2);

        assert!(error.to_string().contains("http status 412"));
    }

    #[test]
    fn rejects_an_active_challenge_with_any_lockout_flag() {
        for flag in [
            "tooManyCodesSent",
            "tooManyCodesValidated",
            "securityCodeLocked",
            "securityCodeCooldown",
        ] {
            let mut challenge = active_challenge();
            challenge["securityCode"][flag] = Value::Bool(true);

            let error = classify(412, &challenge.to_string(), 2);

            assert!(
                error.to_string().contains("http status 412"),
                "flag {flag} should make the challenge invalid"
            );
        }
    }

    #[test]
    fn preserves_apple_service_errors_before_classifying_a_challenge() {
        let body = json!({
            "serviceErrors": [{
                "code": "-22979",
                "title": "Too many verification codes",
                "message": "Enter the last code you received or try again later."
            }]
        })
        .to_string();
        let outcome =
            AppleAccount::classify_sms_send_response(412, &body, 2, PhoneCodeMode::Sms).unwrap();

        match outcome {
            SmsSendOutcome::ServiceError(error) => assert_eq!(error.code, "-22979"),
            _ => panic!("expected the Apple service error to be preserved"),
        }
    }

    #[test]
    fn classifies_too_many_codes_sent_as_a_service_error() {
        for code in ["-22979", "-22981"] {
            let body = json!({
                "serviceErrors": [{
                    "code": code,
                    "title": "Too many verification codes",
                    "message": "Enter the last code you received or try again later."
                }]
            })
            .to_string();
            let outcome =
                AppleAccount::classify_sms_send_response(412, &body, 2, PhoneCodeMode::Sms)
                    .unwrap();

            match outcome {
                SmsSendOutcome::ServiceError(error) => assert_eq!(error.code, code),
                _ => panic!("code {code} should be preserved as a service error"),
            }
        }
    }

    #[test]
    fn classifies_unknown_2fa_method_as_a_service_error() {
        let body = json!({
            "serviceErrors": [{
                "code": "-28248",
                "title": "Unknown 2FA method",
                "message": "Please select a different verification method."
            }]
        })
        .to_string();
        let outcome =
            AppleAccount::classify_sms_send_response(412, &body, 2, PhoneCodeMode::Sms).unwrap();

        match outcome {
            SmsSendOutcome::ServiceError(error) => assert_eq!(error.code, "-28248"),
            _ => panic!("expected the Apple service error to be preserved"),
        }
    }

    #[test]
    fn rejects_an_unexpected_non_json_error_response_with_its_status() {
        let error = classify(500, "upstream failure", 2);

        assert!(error.to_string().contains("http status 500"));
    }

    #[test]
    fn an_active_call_only_matches_a_call_request() {
        let mut challenge = active_challenge();
        challenge["mode"] = json!("voice");
        let body = challenge.to_string();

        let outcome =
            AppleAccount::classify_sms_send_response(412, &body, 2, PhoneCodeMode::Voice).unwrap();
        assert!(matches!(outcome, SmsSendOutcome::ActiveChallenge));
        assert!(classify(412, &body, 2).to_string().contains("http status 412"));
    }

    #[test]
    fn falls_back_to_a_real_trusted_number() {
        let numbers: Vec<TrustedNumber> = serde_json::from_value(json!([
            { "numberWithDialCode": "+39 ••• ••• ••89", "id": 3 },
            { "numberWithDialCode": "+1 (•••) •••-••00", "lastTwoDigits": "00", "pushMode": "voice", "id": 5 }
        ]))
        .unwrap();

        assert_eq!(AppleAccount::pick_number_id(&numbers, 1), 3);
        assert_eq!(AppleAccount::pick_number_id(&numbers, 5), 5);
        assert_eq!(AppleAccount::pick_number_id(&[], 1), 1);
        assert_eq!(numbers[0].push_mode, "");
        assert_eq!(numbers[1].push_mode, "voice");
    }
}

#[cfg(test)]
mod state_after_proof_tests {
    use super::{AppleAccount, LoginState};
    use plist::Dictionary;

    fn status(hsc: i64, au: Option<&str>) -> Dictionary {
        let mut status = Dictionary::new();
        status.insert("ec".into(), 0.into());
        status.insert("hsc".into(), hsc.into());
        if let Some(au) = au {
            status.insert("au".into(), au.into());
        }
        status
    }

    #[test]
    fn a_named_step_is_followed() {
        assert!(matches!(
            AppleAccount::state_after_proof(&status(409, Some("trustedDeviceSecondaryAuth"))),
            LoginState::NeedsDevice2FA
        ));
        assert!(matches!(
            AppleAccount::state_after_proof(&status(409, Some("secondaryAuth"))),
            LoginState::NeedsSMS2FA(1)
        ));
        assert!(matches!(
            AppleAccount::state_after_proof(&status(409, Some("repair"))),
            LoginState::LoggedIn
        ));
    }

    #[test]
    fn a_pending_step_apple_names_none_for_waits_for_the_code_it_sent() {
        // What gsa.apple.com answered an Android client on 2026-10-13.
        assert!(matches!(
            AppleAccount::state_after_proof(&status(409, None)),
            LoginState::NeedsDevice2FAVerification
        ));
    }

    fn response(status: Dictionary) -> Dictionary {
        let mut response = Dictionary::new();
        response.insert("Status".into(), status.into());
        response
    }

    #[test]
    fn a_resync_request_yields_its_sim_as_base64() {
        // ani.jkcoxson.com's first init on 2026-10-15 got a string.
        let mut asked = status(434, None);
        asked.insert("ec".into(), (-22421).into());
        asked.insert("X-Apple-I-MD-DATA".into(), "c2ltLWRhdGE=".into());
        assert_eq!(
            AppleAccount::resync_sim(&response(asked.clone())).as_deref(),
            Some("c2ltLWRhdGE=")
        );

        asked.insert(
            "X-Apple-I-MD-DATA".into(),
            plist::Value::Data(b"sim-data".to_vec()),
        );
        assert_eq!(
            AppleAccount::resync_sim(&response(asked)).as_deref(),
            Some("c2ltLWRhdGE=")
        );
    }

    #[test]
    fn anything_else_needs_no_resync() {
        assert_eq!(AppleAccount::resync_sim(&response(status(200, None))), None);
        assert_eq!(AppleAccount::resync_sim(&response(status(434, None))), None);
        let mut other = status(409, None);
        other.insert("X-Apple-I-MD-DATA".into(), "c2ltLWRhdGE=".into());
        assert_eq!(AppleAccount::resync_sim(&response(other)), None);
        assert_eq!(AppleAccount::resync_sim(&Dictionary::new()), None);
    }

    #[test]
    fn nothing_pending_is_logged_in() {
        assert!(matches!(
            AppleAccount::state_after_proof(&status(200, None)),
            LoginState::LoggedIn
        ));
        assert!(matches!(
            AppleAccount::state_after_proof(&Dictionary::new()),
            LoginState::LoggedIn
        ));
    }
}

impl std::fmt::Display for AppleAccount {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "Apple Account: ")?;
        match self.get_name() {
            Ok((first, last)) => write!(f, "{} {} ", first, last),
            Err(_) => Ok(()),
        }?;
        write!(f, "{} ({:?})", self.email, self.login_state)
    }
}

#[derive(Debug, Clone)]
pub struct AppToken {
    pub token: String,
    pub duration: u64,
    pub expiry: u64,
}

fn censor_email(email: &str) -> String {
    if std::env::var("DEBUG_SENSITIVE").is_ok() {
        return email.to_string();
    }
    if let Some(at_pos) = email.find('@') {
        let (local, domain) = email.split_at(at_pos);
        if local.len() <= 2 {
            format!("{}***{}", &local[0..1], &domain)
        } else {
            format!(
                "{}***{}{}",
                &local[0..1],
                &local[local.len() - 1..],
                &domain
            )
        }
    } else {
        "***".to_string()
    }
}

/// True if `report` comes from a request that never reached its server: no
/// connection (DNS included) or no answer in time.
fn is_unreachable(report: &Report) -> bool {
    report.iter_reports().any(|cause| {
        cause
            .downcast_current_context::<reqwest::Error>()
            .is_some_and(|e| e.is_connect() || e.is_timeout())
    })
}

#[cfg(test)]
mod unreachable_tests {
    use super::is_unreachable;
    use rootcause::prelude::*;

    fn get(url: &str) -> Report {
        tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .unwrap()
            .block_on(async {
                reqwest::get(url)
                    .await
                    .context("Failed to ask")
                    .unwrap_err()
                    .into()
            })
    }

    #[test]
    fn a_closed_port_or_unknown_host_is_unreachable() {
        let port = std::net::TcpListener::bind("127.0.0.1:0").unwrap().local_addr().unwrap().port();
        assert!(is_unreachable(&get(&format!("http://127.0.0.1:{port}/v3/client_info"))));
        assert!(is_unreachable(&get("http://no-such-host.invalid/v3/client_info")));
        assert!(!is_unreachable(&report!("Failed to read the anisette server's client info").into()));
    }
}

#[cfg(test)]
mod auth_page_tests {
    use super::AppleAccount;

    #[test]
    fn only_a_bare_403_refuses_the_client() {
        // How the pages under /auth turned the Android phone away.
        assert!(AppleAccount::refuses_client(403, ""));
        assert!(AppleAccount::refuses_client(403, "<html>Forbidden</html>"));
        // A refusal of the request itself is answered, not retried as a Mac.
        let refused = r#"{"serviceErrors":[{"code":"-22981","title":"t","message":"m"}]}"#;
        assert!(!AppleAccount::refuses_client(403, refused));
        assert!(!AppleAccount::refuses_client(401, ""));
        assert!(!AppleAccount::refuses_client(200, ""));
    }
}
