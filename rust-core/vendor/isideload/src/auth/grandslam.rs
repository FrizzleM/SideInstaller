use plist::Dictionary;
use plist_macro::plist_to_xml_string;
use plist_macro::pretty_print_dictionary;
use reqwest::{
    Certificate, ClientBuilder, StatusCode,
    header::{HeaderMap, HeaderValue},
};
use rootcause::prelude::*;
use std::time::Duration;
use tracing::{debug, warn};

use crate::{SideloadError, anisette::AnisetteClientInfo, util::plist::PlistDataExtract};

const APPLE_ROOT: &[u8] = include_bytes!("./apple_root.der");
const URL_BAG: &str = "https://gsa.apple.com/grandslam/GsService2/lookup";

/// What the requests Apple won't take from an Android phone say the client
/// is: a Mac. Every other request reports the Android phone (see
/// `RemoteV3AnisetteProvider::get_client_info`).
///
/// - The URL-bag lookup. Asked as the Android phone it answers with ten URLs
///   on gsd.apple.com; asked as a Mac, with the full bag on gsa.apple.com,
///   where the URLs this crate hardcodes live and where sign-in as an Android
///   phone was checked through to the developer portal.
/// - The second-factor pages under gsa.apple.com/auth: the trusted numbers,
///   sending a text or a call, checking its code, and sending the code to the
///   trusted devices again. Asked as the Android phone they answer a bare 403,
///   before they read who is asking.
const MAC_CLIENT_INFO: &str =
    "<Mac15,7> <macOS;27.0;26A5378j> <com.apple.AuthKit/1 (com.apple.akd/1.0)>";

/// Waits before each retry of a sign-in request GrandSlam answered with 429.
///
/// iLoader found these 429s are often momentary and a retry gets through
/// (upstream a00c3a7, iLoader 2.3.4). Upstream retries 10 times back to back;
/// a lasting limit only gets longer with every attempt, so this tries twice
/// more, spaced out, and then gives up.
#[cfg(not(test))]
const RETRY_429_DELAYS: [Duration; 2] = [Duration::from_secs(2), Duration::from_secs(5)];
#[cfg(test)]
const RETRY_429_DELAYS: [Duration; 2] = [Duration::from_millis(10), Duration::from_millis(10)];

pub struct GrandSlam {
    pub client: reqwest::Client,
    pub client_info: AnisetteClientInfo,
    url_bag: Dictionary,
}

impl GrandSlam {
    /// Create a new GrandSlam instance
    ///
    /// # Arguments
    /// - `client`: The reqwest client to use for requests
    pub async fn new(client_info: AnisetteClientInfo, debug: bool) -> Result<Self, Report> {
        let client = Self::build_reqwest_client(debug).context("Failed to build HTTP client")?;
        let base_headers = Self::mac_headers(&client_info, false)?;
        let url_bag = Self::fetch_url_bag(&client, base_headers).await?;
        Ok(Self {
            client,
            client_info,
            url_bag,
        })
    }

    /// A client that skips fetching the URL bag, for callers that only make
    /// developer-portal requests (which use fixed URLs). `get_url` on it fails,
    /// so it can't log in or provision anisette.
    pub fn without_url_bag(client_info: AnisetteClientInfo, debug: bool) -> Result<Self, Report> {
        let client = Self::build_reqwest_client(debug).context("Failed to build HTTP client")?;
        Ok(Self {
            client,
            client_info,
            url_bag: Dictionary::new(),
        })
    }

    /// Fetch the URL bag from GrandSlam and cache it
    pub async fn fetch_url_bag(
        client: &reqwest::Client,
        base_headers: HeaderMap,
    ) -> Result<Dictionary, Report> {
        debug!("Fetching URL bag from GrandSlam");
        let resp = client
            .get(URL_BAG)
            .headers(base_headers)
            .send()
            .await
            .context("Failed to fetch URL Bag")?
            .text()
            .await
            .context("Failed to read URL Bag response text")?;

        let dict: Dictionary =
            plist::from_bytes(resp.as_bytes()).context("Failed to parse URL Bag plist")?;
        let urls = dict
            .get("urls")
            .and_then(|v| v.as_dictionary())
            .cloned()
            .ok_or_else(|| report!("URL Bag plist missing 'urls' dictionary"))?;

        Ok(urls)
    }

    pub fn get_url(&self, key: &str) -> Result<String, Report> {
        let url = self
            .url_bag
            .get_string(key)
            .context("Unable to find key in URL bag")?;
        Ok(url)
    }

    pub fn get(&self, url: &str) -> Result<reqwest::RequestBuilder, Report> {
        let builder = self
            .client
            .get(url)
            .headers(Self::base_headers(&self.client_info, false)?);

        Ok(builder)
    }

    /// GET for the page under `/auth` that sends the code to the trusted
    /// devices, as a Mac (see `MAC_CLIENT_INFO`).
    pub fn get_auth(&self, url: &str) -> Result<reqwest::RequestBuilder, Report> {
        let builder = self
            .client
            .get(url)
            .headers(Self::mac_headers(&self.client_info, false)?);

        Ok(builder)
    }

    // The three below are the JSON requests of the phone pages under `/auth`,
    // as a Mac too.

    pub fn get_sms(&self, url: &str) -> Result<reqwest::RequestBuilder, Report> {
        let builder = self
            .client
            .get(url)
            .headers(Self::mac_headers(&self.client_info, true)?);

        Ok(builder)
    }

    pub fn put_sms(&self, url: &str) -> Result<reqwest::RequestBuilder, Report> {
        let builder = self
            .client
            .put(url)
            .headers(Self::mac_headers(&self.client_info, true)?);

        Ok(builder)
    }

    pub fn post_sms(&self, url: &str) -> Result<reqwest::RequestBuilder, Report> {
        let builder = self
            .client
            .post(url)
            .headers(Self::mac_headers(&self.client_info, true)?);

        Ok(builder)
    }

    pub fn post(&self, url: &str) -> Result<reqwest::RequestBuilder, Report> {
        let builder = self
            .client
            .post(url)
            .headers(Self::base_headers(&self.client_info, false)?);

        Ok(builder)
    }

    pub fn patch(&self, url: &str) -> Result<reqwest::RequestBuilder, Report> {
        let builder = self
            .client
            .patch(url)
            .headers(Self::base_headers(&self.client_info, false)?);

        Ok(builder)
    }

    /// POST `body` and return the plist's `Response`.
    ///
    /// With `retry_429`, a 429 Too Many Requests is retried after each of
    /// `RETRY_429_DELAYS`. A 429 left after that fails with reqwest's own status
    /// error, whose wording the app matches to stop sign-in and explain.
    pub async fn plist_request(
        &self,
        url: &str,
        body: &Dictionary,
        additional_headers: Option<HeaderMap>,
        retry_429: bool,
    ) -> Result<Dictionary, Report> {
        let delays: &[Duration] = if retry_429 { &RETRY_429_DELAYS } else { &[] };
        let mut delays = delays.iter();
        let response = loop {
            let response = self
                .post(url)?
                .headers(additional_headers.clone().unwrap_or_default())
                .body(plist_to_xml_string(body))
                .send()
                .await
                .context("Failed to send grandslam request")?;
            if response.status() != StatusCode::TOO_MANY_REQUESTS {
                break response;
            }
            let Some(delay) = delays.next() else {
                break response;
            };
            warn!("GrandSlam answered 429 Too Many Requests; retrying in {delay:?}");
            tokio::time::sleep(*delay).await;
        };

        let resp = response
            .error_for_status()
            .context("Received error response from grandslam")?
            .text()
            .await
            .context("Failed to read grandslam response as text")?;

        let dict: Dictionary = plist::from_bytes(resp.as_bytes())
            .context("Failed to parse grandslam response plist")
            .attach_with(|| resp.clone())?;

        let response_plist = dict
            .get("Response")
            .and_then(|v| v.as_dictionary())
            .cloned()
            .ok_or_else(|| {
                report!("grandslam response missing 'Response'")
                    .attach(pretty_print_dictionary(&dict))
            })?;

        Ok(response_plist)
    }

    fn base_headers(
        client_info: &AnisetteClientInfo,
        sms: bool,
    ) -> Result<reqwest::header::HeaderMap, Report> {
        let mut headers = reqwest::header::HeaderMap::new();
        if !sms {
            headers.insert("Content-Type", HeaderValue::from_static("text/x-xml-plist"));
            headers.insert("Accept", HeaderValue::from_static("text/x-xml-plist"));
        } else {
            headers.insert("Content-Type", HeaderValue::from_static("application/json"));
            headers.insert("Accept", HeaderValue::from_static("application/json"));
        }
        headers.insert(
            "X-Mme-Client-Info",
            HeaderValue::from_str(&client_info.client_info)?,
        );
        headers.insert(
            "User-Agent",
            HeaderValue::from_str(&client_info.user_agent)?,
        );
        headers.insert("X-Xcode-Version", HeaderValue::from_static("14.2 (14C18)"));
        headers.insert(
            "X-Apple-App-Info",
            HeaderValue::from_static("com.apple.gs.xcode.auth"),
        );

        Ok(headers)
    }

    /// `base_headers`, saying the client is a Mac (see `MAC_CLIENT_INFO`).
    fn mac_headers(
        client_info: &AnisetteClientInfo,
        sms: bool,
    ) -> Result<reqwest::header::HeaderMap, Report> {
        let mut headers = Self::base_headers(client_info, sms)?;
        headers.insert(
            "X-Mme-Client-Info",
            HeaderValue::from_static(MAC_CLIENT_INFO),
        );
        Ok(headers)
    }

    /// Build a reqwest client with the Apple root certificate
    ///
    /// # Arguments
    /// - `debug`: DANGER, If true, accept invalid certificates and enable verbose connection logging
    /// # Errors
    /// Returns an error if the reqwest client cannot be built
    pub fn build_reqwest_client(debug: bool) -> Result<reqwest::Client, Report> {
        let cert = Certificate::from_der(APPLE_ROOT)?;
        let client = ClientBuilder::new()
            .add_root_certificate(cert)
            .http1_title_case_headers()
            .danger_accept_invalid_certs(debug)
            .connection_verbose(debug)
            // A fresh connection per request. SideSign (35993d7) found GSA
            // answering reused connections with 5xx; upstream f6a4d5d does this.
            .pool_max_idle_per_host(0)
            .build()?;

        Ok(client)
    }
}

pub trait GrandSlamErrorChecker {
    fn check_grandslam_error(self) -> Result<Dictionary, Report<SideloadError>>;
}

impl GrandSlamErrorChecker for Dictionary {
    fn check_grandslam_error(self) -> Result<Self, Report<SideloadError>> {
        let result = match self.get("Status") {
            Some(plist::Value::Dictionary(d)) => d,
            _ => &self,
        };

        if result.get_signed_integer("ec").unwrap_or(0) != 0 {
            bail!(SideloadError::AuthWithMessage(
                result.get_signed_integer("ec").unwrap_or(-1),
                result.get_str("em").unwrap_or("Unknown error").to_string(),
            ))
        }

        Ok(self)
    }
}

#[cfg(test)]
mod client_info_tests {
    use super::{GrandSlam, MAC_CLIENT_INFO};
    use crate::anisette::AnisetteClientInfo;
    use plist::Dictionary;

    const ANDROID: &str = "<Pixel 7> <Android;14;UQ1A.240205.002> <com.apple.AuthKit/1 (com.apple.akd/1.0)>";

    fn said(request: reqwest::RequestBuilder) -> String {
        let request = request.build().unwrap();
        request.headers()["X-Mme-Client-Info"].to_str().unwrap().to_string()
    }

    #[test]
    fn only_the_pages_under_auth_are_asked_as_a_mac() {
        let grandslam = GrandSlam {
            client: GrandSlam::build_reqwest_client(false).unwrap(),
            client_info: AnisetteClientInfo {
                client_info: ANDROID.into(),
                user_agent: "akd/1.0 CFNetwork/808.1.4".into(),
            },
            url_bag: Dictionary::new(),
        };
        let service = "https://gsa.apple.com/grandslam/GsService2";
        assert_eq!(said(grandslam.post(service).unwrap()), ANDROID);
        assert_eq!(said(grandslam.get(&format!("{service}/validate")).unwrap()), ANDROID);
        assert_eq!(said(grandslam.patch(service).unwrap()), ANDROID);

        let auth = "https://gsa.apple.com/auth";
        assert_eq!(said(grandslam.get_sms(auth).unwrap()), MAC_CLIENT_INFO);
        assert_eq!(said(grandslam.put_sms(&format!("{auth}/verify/phone")).unwrap()), MAC_CLIENT_INFO);
        assert_eq!(
            said(grandslam.post_sms(&format!("{auth}/verify/phone/securitycode")).unwrap()),
            MAC_CLIENT_INFO
        );
        assert_eq!(
            said(grandslam.get_auth(&format!("{auth}/verify/trusteddevice")).unwrap()),
            MAC_CLIENT_INFO
        );
    }
}

#[cfg(test)]
mod retry_429_tests {
    use super::{GrandSlam, RETRY_429_DELAYS};
    use crate::anisette::AnisetteClientInfo;
    use plist::Dictionary;
    use std::io::{Read, Write};
    use std::net::TcpListener;
    use std::sync::{
        Arc,
        atomic::{AtomicUsize, Ordering},
    };

    const OK_BODY: &str = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\
        <plist version=\"1.0\"><dict><key>Response</key><dict>\
        <key>ok</key><true/></dict></dict></plist>";

    /// Answers each request with 429 until `rate_limited` have been, then 200,
    /// one connection per request, and counts the requests.
    fn serve(rate_limited: usize) -> (String, Arc<AtomicUsize>) {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let url = format!("http://{}/grandslam/GsService2", listener.local_addr().unwrap());
        let seen = Arc::new(AtomicUsize::new(0));
        let counter = seen.clone();
        std::thread::spawn(move || {
            for stream in listener.incoming() {
                let mut stream = stream.unwrap();
                read_request(&mut stream);
                let n = counter.fetch_add(1, Ordering::SeqCst);
                let reply = if n < rate_limited {
                    "HTTP/1.1 429 Too Many Requests\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                        .to_string()
                } else {
                    format!(
                        "HTTP/1.1 200 OK\r\nContent-Type: text/x-xml-plist\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{OK_BODY}",
                        OK_BODY.len()
                    )
                };
                stream.write_all(reply.as_bytes()).unwrap();
            }
        });
        (url, seen)
    }

    /// Reads one request: headers, then `Content-Length` bytes of body.
    fn read_request(stream: &mut std::net::TcpStream) {
        let mut buf = Vec::new();
        let mut chunk = [0u8; 4096];
        loop {
            let n = stream.read(&mut chunk).unwrap();
            buf.extend_from_slice(&chunk[..n]);
            let text = String::from_utf8_lossy(&buf);
            if let Some(end) = text.find("\r\n\r\n") {
                let length = text[..end]
                    .lines()
                    .find_map(|l| {
                        let (k, v) = l.split_once(':')?;
                        k.eq_ignore_ascii_case("content-length").then(|| v.trim().parse().ok())?
                    })
                    .unwrap_or(0usize);
                if buf.len() >= end + 4 + length || n == 0 {
                    return;
                }
            }
            if n == 0 {
                return;
            }
        }
    }

    fn request(url: &str, retry_429: bool) -> Result<Dictionary, String> {
        let grandslam = GrandSlam {
            client: GrandSlam::build_reqwest_client(false).unwrap(),
            client_info: AnisetteClientInfo {
                client_info: "<test>".into(),
                user_agent: "test".into(),
            },
            url_bag: Dictionary::new(),
        };
        tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .unwrap()
            .block_on(grandslam.plist_request(url, &Dictionary::new(), None, retry_429))
            .map_err(|e| format!("{e}"))
    }

    #[test]
    fn a_passing_429_is_retried() {
        let (url, seen) = serve(RETRY_429_DELAYS.len());
        let response = request(&url, true).unwrap();
        assert_eq!(response.get("ok").and_then(|v| v.as_boolean()), Some(true));
        assert_eq!(seen.load(Ordering::SeqCst), RETRY_429_DELAYS.len() + 1);
    }

    #[test]
    fn a_lasting_429_keeps_the_status_wording() {
        // The app stops sign-in on "429 Too Many Requests" in the error.
        let (url, seen) = serve(usize::MAX);
        let error = request(&url, true).unwrap_err();
        assert!(error.contains("429 Too Many Requests"), "{error}");
        assert_eq!(seen.load(Ordering::SeqCst), RETRY_429_DELAYS.len() + 1);
    }

    #[test]
    fn provisioning_requests_are_not_retried() {
        let (url, seen) = serve(usize::MAX);
        assert!(request(&url, false).is_err());
        assert_eq!(seen.load(Ordering::SeqCst), 1);
    }
}
