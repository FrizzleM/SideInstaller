use std::sync::Arc;

use plist::Dictionary;
use plist_macro::{plist, plist_to_xml_string};
use reqwest::header::{HeaderMap, HeaderValue};
use rootcause::prelude::*;
use serde::de::DeserializeOwned;
use tracing::{error, warn};
use uuid::Uuid;

use crate::{
    SideloadError,
    anisette::AnisetteDataGenerator,
    auth::{
        apple_account::{AppToken, AppleAccount},
        grandslam::GrandSlam,
    },
    util::plist::PlistDataExtract,
};

pub use super::app_groups::*;
pub use super::app_ids::*;
pub use super::certificates::*;
pub use super::device_type::DeveloperDeviceType;
pub use super::devices::*;
pub use super::teams::*;

#[derive(Clone)]
pub struct DeveloperSession {
    token: AppToken,
    adsid: String,
    client: Arc<GrandSlam>,
    anisette_generator: AnisetteDataGenerator,
}

impl DeveloperSession {
    pub fn new(
        token: AppToken,
        adsid: String,
        client: Arc<GrandSlam>,
        anisette_generator: AnisetteDataGenerator,
    ) -> Self {
        DeveloperSession {
            token,
            adsid,
            client,
            anisette_generator,
        }
    }

    pub async fn from_account(account: &mut AppleAccount) -> Result<Self, Report> {
        let token = account
            .get_app_token("xcode.auth")
            .await
            .context("Failed to get xcode token from Apple account")?;

        let spd = account
            .spd
            .as_ref()
            .ok_or_else(|| report!("SPD not available, cannot get adsid"))?;

        Ok(DeveloperSession::new(
            token,
            spd.get_string("adsid")?,
            account.grandslam_client.clone(),
            account.anisette_generator.clone(),
        ))
    }

    pub async fn get_headers(&mut self) -> Result<HeaderMap, Report> {
        let mut headers = self
            .anisette_generator
            .get_anisette_data(self.client.clone())
            .await?
            .get_header_map()?;

        headers.insert(
            "X-Apple-GS-Token",
            HeaderValue::from_str(&self.token.token)?,
        );
        headers.insert("X-Apple-I-Identity-Id", HeaderValue::from_str(&self.adsid)?);

        Ok(headers)
    }

    pub fn get_grandslam_client(&self) -> Arc<GrandSlam> {
        self.client.clone()
    }

    async fn send_dev_request_internal(
        &mut self,
        url: &str,
        body: impl Into<Option<Dictionary>>,
    ) -> Result<(Dictionary, Option<SideloadError>), Report> {
        let body = body.into().unwrap_or_else(Dictionary::new);

        let base = plist!(dict {
            "clientId": "XABBG36SBA",
            "protocolVersion": "QH65B2",
            "requestId": Uuid::new_v4().to_string().to_uppercase(),
            "userLocale": ["en_US"],
        });

        let body = base.into_iter().chain(body.into_iter()).collect();

        let text = self
            .client
            .post(url)?
            .body(plist_to_xml_string(&body))
            .headers(
                self.get_headers()
                    .await
                    .context("Failed to get anisette headers")?,
            )
            .send()
            .await?
            .error_for_status()
            .context("Developer request failed")?
            .text()
            .await
            .context("Failed to read developer request response text")?;

        let dict: Dictionary = plist::from_bytes(text.as_bytes())
            .context("Failed to parse developer request plist")?;

        // All this error handling is here to ensure that:
        // 1. We always warn/log errors from the server even if it returns the expected data
        // 2. We return server errors if the expected data is missing
        // 3. We return parsing errors if there is no server error but the expected data is missing
        let response_code = dict.get("resultCode").and_then(|v| v.as_signed_integer());
        let mut server_error: Option<SideloadError> = None;
        if let Some(code) = response_code {
            if code != 0 {
                let result_string = dict
                    .get("resultString")
                    .and_then(|v| v.as_string())
                    .unwrap_or("No error message given.");
                let user_string = dict
                    .get("userString")
                    .and_then(|v| v.as_string())
                    .unwrap_or(result_string);
                server_error = Some(SideloadError::DeveloperError(code, user_string.to_string()));

                error!(
                    "Developer request returned error code {}: {} ({})",
                    code, user_string, result_string
                );
            }
        } else {
            warn!("No resultCode in developer request response");
        }

        Ok((dict, server_error))
    }

    pub async fn send_dev_request<T: DeserializeOwned>(
        &mut self,
        url: &str,
        body: impl Into<Option<Dictionary>>,
        response_key: &str,
    ) -> Result<T, Report> {
        let (dict, server_error) = self.send_dev_request_internal(url, body).await?;

        let result: Result<T, _> = dict.get_struct(response_key);

        if result.is_err()
            && let Some(err) = server_error
        {
            bail!(err);
        }

        Ok(result.context("Failed to extract developer request result")?)
    }

    pub async fn send_dev_request_no_response(
        &mut self,
        url: &str,
        body: impl Into<Option<Dictionary>>,
    ) -> Result<Dictionary, Report> {
        let (dict, server_error) = self.send_dev_request_internal(url, body).await?;

        if let Some(err) = server_error {
            bail!(err);
        }

        Ok(dict)
    }

    /// Send a request to Xcode's JSON:API endpoint (`services_url`), the way
    /// AltSign's `sendServicesRequest` does: always a POST, with the real method
    /// in `X-HTTP-Method-Override` and the query (just `teamId`) in the body's
    /// `urlEncodedQueryParams`. Returns the parsed body, or `Null` when it is
    /// empty (a DELETE answers with no content).
    pub async fn send_services_request(
        &mut self,
        url: &str,
        team: &DeveloperTeam,
        method: &'static str,
    ) -> Result<serde_json::Value, Report> {
        let body = serde_json::json!({
            "urlEncodedQueryParams": format!("teamId={}", team.team_id),
        });

        let mut headers = self
            .get_headers()
            .await
            .context("Failed to get anisette headers")?;
        headers.insert(
            "Content-Type",
            HeaderValue::from_static("application/vnd.api+json"),
        );
        headers.insert("Accept", HeaderValue::from_static("application/vnd.api+json"));
        headers.insert("X-HTTP-Method-Override", HeaderValue::from_static(method));

        let response = self
            .client
            .post(url)?
            .headers(headers)
            .body(body.to_string())
            .send()
            .await
            .context("Developer services request failed")?;
        let status = response.status();
        let text = response
            .text()
            .await
            .context("Failed to read developer services response text")?;

        let json: serde_json::Value = if text.trim().is_empty() {
            serde_json::Value::Null
        } else {
            serde_json::from_str(&text)
                .context("Failed to parse developer services response")
                .attach_with(|| text.clone())?
        };

        // JSON:API errors: [{"status": "404", "code": "NOT_FOUND", "title": …, "detail": …}]
        if let Some(errors) = json.get("errors").and_then(|e| e.as_array())
            && !errors.is_empty()
        {
            let message = errors
                .iter()
                .map(|e| {
                    let field = |k: &str| e.get(k).and_then(|v| v.as_str()).unwrap_or_default();
                    match (field("code"), field("detail"), field("title")) {
                        (code, "", "") => code.to_string(),
                        (code, "", title) => format!("{title} ({code})"),
                        (code, detail, _) => format!("{detail} ({code})"),
                    }
                })
                .collect::<Vec<_>>()
                .join("; ");
            error!("Developer services request returned {status}: {message}");
            bail!("Developer services error {}: {message}", status.as_u16());
        }

        if !status.is_success() {
            error!("Developer services request returned {status}: {text}");
            bail!("Developer services request returned {status}");
        }

        Ok(json)
    }
}

#[cfg(test)]
mod services_request_tests {
    use super::*;
    use crate::anisette::{AnisetteClientInfo, AnisetteData, AnisetteProvider};
    use std::io::{Read, Write};
    use std::net::TcpListener;
    use std::sync::mpsc;
    use tokio::sync::RwLock;

    struct FixedAnisette;

    #[async_trait::async_trait]
    impl AnisetteProvider for FixedAnisette {
        async fn get_anisette_data(&self) -> Result<AnisetteData, Report> {
            Ok(AnisetteData::for_tests())
        }

        async fn get_client_info(&self) -> Result<AnisetteClientInfo, Report> {
            unreachable!()
        }

        async fn provision(&mut self, _gs: Arc<GrandSlam>) -> Result<(), Report> {
            Ok(())
        }

        fn needs_provisioning(&self) -> Result<bool, Report> {
            Ok(false)
        }
    }

    /// Answers one request with `reply` and hands back the raw request.
    fn serve_once(reply: &'static str) -> (String, mpsc::Receiver<String>) {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let base = format!("http://{}/services/v1/", listener.local_addr().unwrap());
        let (tx, rx) = mpsc::channel();
        std::thread::spawn(move || {
            let (mut stream, _) = listener.accept().unwrap();
            let mut buf = Vec::new();
            let mut chunk = [0u8; 4096];
            loop {
                let n = stream.read(&mut chunk).unwrap();
                buf.extend_from_slice(&chunk[..n]);
                let text = String::from_utf8_lossy(&buf).to_string();
                if let Some(end) = text.find("\r\n\r\n") {
                    let length = text[..end]
                        .lines()
                        .find_map(|l| {
                            let (k, v) = l.split_once(':')?;
                            k.eq_ignore_ascii_case("content-length")
                                .then(|| v.trim().parse().ok())?
                        })
                        .unwrap_or(0usize);
                    if buf.len() >= end + 4 + length || n == 0 {
                        tx.send(text).unwrap();
                        break;
                    }
                }
                if n == 0 {
                    break;
                }
            }
            stream.write_all(reply.as_bytes()).unwrap();
        });
        (base, rx)
    }

    fn delete(url: &str) -> Result<serde_json::Value, String> {
        let client = GrandSlam::without_url_bag(
            AnisetteClientInfo {
                client_info: "<test>".into(),
                user_agent: "test".into(),
            },
            false,
        )
        .unwrap();
        let mut session = DeveloperSession::new(
            AppToken {
                token: "gs-token".into(),
                duration: 0,
                expiry: 0,
            },
            "adsid".into(),
            Arc::new(client),
            AnisetteDataGenerator::new(Arc::new(RwLock::new(FixedAnisette))),
        );
        let team = DeveloperTeam {
            name: None,
            team_id: "TEAM123456".into(),
            r#type: None,
            status: None,
        };
        tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .unwrap()
            .block_on(session.send_services_request(url, &team, "DELETE"))
            .map_err(|e| format!("{e}"))
    }

    fn header<'a>(request: &'a str, name: &str) -> Vec<&'a str> {
        request
            .lines()
            .filter_map(|l| l.split_once(':'))
            .filter(|(k, _)| k.eq_ignore_ascii_case(name))
            .map(|(_, v)| v.trim())
            .collect()
    }

    #[test]
    fn sends_a_post_with_the_method_override_and_team() {
        let (base, request) = serve_once("HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n");
        let result = delete(&format!("{base}certificates/ABCDE12345"));
        assert_eq!(result, Ok(serde_json::Value::Null));

        let request = request.recv().unwrap();
        assert!(
            request.starts_with("POST /services/v1/certificates/ABCDE12345 HTTP/1.1\r\n"),
            "{request}"
        );
        assert_eq!(header(&request, "X-HTTP-Method-Override"), ["DELETE"]);
        // Replaces GrandSlam's plist content type rather than adding a second.
        assert_eq!(header(&request, "Content-Type"), ["application/vnd.api+json"]);
        assert_eq!(header(&request, "Accept"), ["application/vnd.api+json"]);
        assert_eq!(header(&request, "X-Apple-GS-Token"), ["gs-token"]);
        assert_eq!(header(&request, "X-Apple-I-Identity-Id"), ["adsid"]);
        assert_eq!(header(&request, "X-Apple-I-MD"), ["otp"]);
        let body = request.split_once("\r\n\r\n").unwrap().1;
        assert_eq!(body, r#"{"urlEncodedQueryParams":"teamId=TEAM123456"}"#);
    }

    #[test]
    fn reports_json_api_errors() {
        const BODY: &str = r#"{"errors":[{"status":"404","code":"NOT_FOUND","title":"The specified resource does not exist","detail":"There is no resource of type 'certificates' with id 'ABCDE12345'"}]}"#;
        let reply: &'static str = Box::leak(
            format!(
                "HTTP/1.1 404 Not Found\r\nContent-Type: application/vnd.api+json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{BODY}",
                BODY.len()
            )
            .into_boxed_str(),
        );
        let (base, _request) = serve_once(reply);
        let error = delete(&format!("{base}certificates/ABCDE12345")).unwrap_err();
        assert!(
            error.contains("404")
                && error.contains("There is no resource of type 'certificates' with id 'ABCDE12345' (NOT_FOUND)"),
            "{error}"
        );
    }

    #[test]
    fn reports_a_bare_http_error() {
        let (base, _request) = serve_once(
            "HTTP/1.1 401 Unauthorized\r\nContent-Length: 0\r\nConnection: close\r\n\r\n",
        );
        let error = delete(&format!("{base}certificates/ABCDE12345")).unwrap_err();
        assert!(error.contains("401"), "{error}");
    }
}
