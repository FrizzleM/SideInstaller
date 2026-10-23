// Public so the anisette identity can be read back out of storage and handed to
// another AltStore-family app (SideInstaller's Account.sideconf seeding).
pub mod state;

use std::collections::BTreeMap;
use std::sync::{Arc, Mutex};
use std::time::{SystemTime, UNIX_EPOCH};

use base64::prelude::*;
use plist_macro::plist;
use reqwest::header::{CONTENT_TYPE, HeaderMap, HeaderValue};
use rootcause::prelude::*;
use serde::{Deserialize, Serialize};
use tokio::time::{Duration, timeout};
use tokio_tungstenite::tungstenite::Message;
use tracing::{debug, info, warn};

use crate::SideloadError;
use crate::anisette::remote_v3::state::AnisetteState;
use crate::anisette::{AnisetteClientInfo, AnisetteData, AnisetteProvider, is_not_provisioned};
use crate::auth::grandslam::GrandSlam;
use crate::util::plist::PlistDataExtract;
use crate::util::storage::{SideloadingStorage, new_storage};
use futures_util::{SinkExt, StreamExt};

pub const DEFAULT_ANISETTE_V3_URL: &str = "https://new.ani.sidestore.io";

/// The key of the anisette identity made before identities were kept per
/// server, and of the first one made since.
pub const LEGACY_STATE_KEY: &str = "anisette_state";

/// Which identity each anisette server takes (`Slots`).
const SLOTS_KEY: &str = "anisette_slots.json";

/// What GrandSlam is told the client is when the server's own client info
/// can't be used: a Windows PC, as iTunes reports it, with akd's user agent.
///
/// Since 2026-10-12 GrandSlam refuses a Mac with -80045 ("This action cannot be
/// completed at this time") on servers that make anisette data with Apple's
/// Android ADI library, and since 2026-10-15 it answers the Android phone used
/// in between with HTTP 503. The Windows PC gets through on those servers too
/// (only Apple's leniency allows it), and it is what the servers on the
/// Windows ADI library (ani.jkcoxson.com, win.ani.sidestore.io,
/// ani2.stikstore.app) hand out themselves.
pub const WINDOWS_CLIENT_INFO: &str =
    "<PC> <Windows;6.2(0,0);9200> <com.apple.AuthKit/1 (com.apple.iTunes/12.12.4.1)>";
const AKD_USER_AGENT: &str = "akd/1.0 CFNetwork/808.1.4";

/// What GrandSlam is told the client is on a server on Apple's macOS ADI
/// library that names a Mac older than macOS 10.13: a current Mac, with the
/// user agent to match. Both are SideStore's own defaults (AnisetteKit's
/// `defaultClientInfo` and `defaultUserAgent`).
///
/// The macOS-ADI servers (new.ani.sidestore.io, mac-ani.jkcoxson.com,
/// ani.iloader.app, ani3.stikstore.app, and since about 2026-10-22
/// ani.jkcoxson.com and ani2.stikstore.app) all name
/// `<MacBookPro13,3> <Mac OS X;10.12.6;16G29>`, and Apple has answered that Mac
/// with -23782 for some accounts ("A Mac with macOS version 10.13 or later is
/// required", SideInstaller issue #89) and asked others for a code by text it
/// then wouldn't send (2026-10-16). Since Apple started answering anisette
/// from its Android library with -80046 at the token request (2026-10-21),
/// the working route is these servers with this Mac: SideStore with its
/// default headers, on-device anisette off and a macOS-ADI server picked. Apple
/// takes it on a macOS-ADI identity (-20970 for a made-up account, 2026-10-23),
/// including for provisioning.
pub const CURRENT_MAC_CLIENT_INFO: &str =
    "<MacBookPro18,3> <macOS;26.6;25F84> <com.apple.AuthKit/1 (com.apple.akd/1.0)>";
const CURRENT_MAC_USER_AGENT: &str = "AuthKit/1 (Macintosh; OS X 26.6) (com.apple.akd/1.0)";

/// Device and OS of the stock client info of anisette-v3-server and of
/// AltServer/omnisette. Servers hand these out whatever library they run, and
/// every public server that does runs Apple's Android ADI library, so the Mac
/// they name is one they aren't. Most still name `com.apple.dt.Xcode` too,
/// which Apple's GSA edge has answered with HTTP 503 since September 2026.
const STOCK_CLIENTS: [&str; 2] = [
    "<MacBookPro13,2> <macOS;13.1;22C65>",
    "<MacBookPro15,1> <Mac OS X;10.15.2;19C57>",
];

/// The client info to tell GrandSlam, given what the server hands out.
///
/// The server's own, unless it is a stock one or an Android phone's (which
/// Apple answers with 503): then `WINDOWS_CLIENT_INFO`; or a Mac older than
/// macOS 10.13, as the macOS-ADI servers name: then `CURRENT_MAC_CLIENT_INFO`.
/// A server that hands out something else made it for the library it runs,
/// as the Windows-ADI servers do, and so will anisette v4's server-chosen
/// client.
pub fn client_info_to_use(advertised: &AnisetteClientInfo) -> AnisetteClientInfo {
    let client = advertised.client_info.trim();
    if client.is_empty() || android_adi(advertised) {
        return AnisetteClientInfo {
            client_info: WINDOWS_CLIENT_INFO.to_string(),
            user_agent: AKD_USER_AGENT.to_string(),
        };
    }
    if mac_version(client).is_some_and(|version| version < (10, 13)) {
        return AnisetteClientInfo {
            client_info: CURRENT_MAC_CLIENT_INFO.to_string(),
            user_agent: CURRENT_MAC_USER_AGENT.to_string(),
        };
    }
    let user_agent = advertised.user_agent.trim();
    AnisetteClientInfo {
        client_info: client.to_string(),
        user_agent: if user_agent.is_empty() { AKD_USER_AGENT } else { user_agent }.to_string(),
    }
}

/// Whether a server that hands out `advertised` makes its anisette data with
/// Apple's Android ADI library: it names a stock client or an Android phone,
/// as every server that runs anisette-v3-server or omnisette on that library
/// does.
///
/// Since 2026-10-21 Apple lets a sign-in through such a server get as far as
/// the password and the second factor, then refuses the developer token with
/// -80046, "This action cannot be completed at this time", whatever device it
/// names (xtool #378, iPASide #10, SideStore #1685/#1686). SideInstaller's
/// sign-in doesn't log in through one any more.
pub fn android_adi(advertised: &AnisetteClientInfo) -> bool {
    let client = advertised.client_info.trim();
    STOCK_CLIENTS.iter().any(|s| client.starts_with(s)) || client.contains("<Android;")
}

/// The macOS version a client info names, as (major, minor), if it names a Mac.
fn mac_version(client: &str) -> Option<(u32, u32)> {
    let rest = ["<macOS;", "<Mac OS X;"]
        .iter()
        .find_map(|marker| client.split_once(marker).map(|(_, rest)| rest))?;
    let version = rest.split([';', '>']).next()?.trim();
    let mut parts = version.split('.').map(|part| part.parse::<u32>().ok());
    let major = parts.next()??;
    let minor = parts.next().flatten().unwrap_or(0);
    Some((major, minor))
}

/// Whether `client` is a Mac on macOS 10.13 or later, as `CURRENT_MAC_CLIENT_INFO`.
pub fn is_current_mac(client: &str) -> bool {
    mac_version(client).is_some_and(|version| version >= (10, 13))
}

/// Which stored anisette identity each server takes.
///
/// An identity (`AnisetteState`) is provisioned through one server and works
/// with every server on the same ADI library. Servers on another library
/// answer it with ADI error -45061, "not provisioned": Apple's Android library
/// and its Windows one each refuse the other's. Keeping one identity per
/// library, and remembering which one a server took, lets sign-in move between
/// them without provisioning again. A new identity is a new machine to Apple,
/// so it costs a second-factor prompt, and a saved developer token only works
/// with the identity it was issued to.
#[derive(Serialize, Deserialize, Default, Debug)]
struct Slots {
    /// Server URL (no trailing slash) → key of the identity it took.
    #[serde(default)]
    servers: BTreeMap<String, String>,
    /// Identity key → Unix seconds it last worked.
    #[serde(default)]
    used: BTreeMap<String, u64>,
    /// Identity key → the client info provisioning reported. Identities made
    /// before SideInstaller 1.6.1 have none.
    #[serde(default)]
    provisioned_as: BTreeMap<String, String>,
}

impl Slots {
    fn load(storage: &dyn SideloadingStorage) -> Self {
        match storage.retrieve_data(SLOTS_KEY) {
            Ok(Some(raw)) if !raw.is_empty() => serde_json::from_slice(&raw).unwrap_or_else(|e| {
                warn!("Couldn't read which anisette identity each server takes ({e}); starting over");
                Slots::default()
            }),
            _ => Slots::default(),
        }
    }

    fn save(&self, storage: &dyn SideloadingStorage) -> Result<(), Report> {
        storage.store_data(SLOTS_KEY, &serde_json::to_vec(self)?)
    }

    /// Stored identities to try with a server that has none yet: the most
    /// recently used first, then the one from before identities were kept per
    /// server.
    fn candidates(&self, skip: &[String]) -> Vec<String> {
        let mut keys: Vec<(&String, &u64)> = self.used.iter().collect();
        keys.sort_by(|a, b| b.1.cmp(a.1));
        let mut out: Vec<String> = keys.into_iter().map(|(k, _)| k.clone()).collect();
        if !out.iter().any(|k| k == LEGACY_STATE_KEY) {
            out.push(LEGACY_STATE_KEY.to_string());
        }
        out.retain(|k| !skip.contains(k));
        out
    }

    /// A key no identity is stored under.
    fn new_key(&self, taken: impl Fn(&str) -> bool) -> String {
        if !self.used.contains_key(LEGACY_STATE_KEY) && !taken(LEGACY_STATE_KEY) {
            return LEGACY_STATE_KEY.to_string();
        }
        (2..)
            .map(|n| format!("{LEGACY_STATE_KEY}_{n}"))
            .find(|k| !self.used.contains_key(k) && !taken(k))
            .expect("an unused key")
    }

    fn assign(&mut self, server: &str, key: &str) {
        self.servers.insert(server.to_string(), key.to_string());
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0);
        self.used.insert(key.to_string(), now);
    }

    /// Whether the identity `key` can sign in reporting `client`. With
    /// `fresh_mac` (a full sign-in, see
    /// `RemoteV3AnisetteProvider::require_current_mac_identity`) and `client`
    /// a current Mac, only an identity provisioned as one can: one made as the
    /// macOS-ADI servers' old Mac before 1.6.1 is left for its saved token, and
    /// the sign-in provisions a new one, as SideStore's "Reset adi.pb" does
    /// once the client info has changed.
    fn fits(&self, key: &str, client: &str, fresh_mac: bool) -> bool {
        !(fresh_mac && is_current_mac(client))
            || self.provisioned_as.get(key).is_some_and(|c| is_current_mac(c))
    }
}

fn server_key(url: &str) -> String {
    url.trim().trim_end_matches('/').to_string()
}

/// The storage key of the anisette identity the server at `url` took last, or
/// `LEGACY_STATE_KEY` if it hasn't taken one. A developer token belongs to the
/// identity it was issued to, so whatever is handed on with a token should be
/// read from here.
pub fn state_key_for(storage: &dyn SideloadingStorage, url: &str) -> String {
    Slots::load(storage)
        .servers
        .remove(&server_key(url))
        .unwrap_or_else(|| LEGACY_STATE_KEY.to_string())
}

pub struct RemoteV3AnisetteProvider {
    pub state: Option<AnisetteState>,
    /// Storage key of `state`.
    state_key: Option<String>,
    url: String,
    storage: Box<dyn SideloadingStorage>,
    serial_number: String,
    client: reqwest::Client,
    /// `client_info_to_use` of what the server hands out, once asked.
    client_info: Mutex<Option<AnisetteClientInfo>>,
    /// `android_adi` of what the server hands out, once asked.
    android_adi: Mutex<Option<bool>>,
    /// Set by `require_current_mac_identity`; see `Slots::fits`.
    fresh_mac: bool,
}

impl RemoteV3AnisetteProvider {
    /// Create a new RemoteV3AnisetteProvider with the given URL and config path
    ///
    /// # Arguments
    /// - `url`: The URL of the remote anisette service
    /// - `storage`: The storage backend for anisette data
    /// - `serial_number`: The serial number of the device
    pub fn new(
        url: &str,
        storage: Box<dyn SideloadingStorage>,
        serial_number: String,
    ) -> Result<Self, Report> {
        Ok(Self {
            state: None,
            state_key: None,
            url: url.to_string(),
            storage,
            serial_number,
            client: reqwest::ClientBuilder::new()
                .build()
                .context("Failed to build HTTP client")?,
            client_info: Mutex::new(None),
            android_adi: Mutex::new(None),
            fresh_mac: false,
        })
    }

    pub fn default() -> Result<Self, Report> {
        Self::new(
            DEFAULT_ANISETTE_V3_URL,
            Box::new(new_storage()),
            "0".to_string(),
        )
    }

    pub fn set_url(mut self, url: &str) -> RemoteV3AnisetteProvider {
        self.url = url.to_string();
        self.client_info = Mutex::new(None);
        self.android_adi = Mutex::new(None);
        self
    }

    pub fn set_storage(mut self, storage: Box<dyn SideloadingStorage>) -> RemoteV3AnisetteProvider {
        self.storage = storage;
        self
    }

    pub fn set_serial_number(mut self, serial_number: String) -> RemoteV3AnisetteProvider {
        self.serial_number = serial_number;
        self
    }

    /// Storage key of the identity in use, once one is.
    pub fn state_key(&self) -> Option<&str> {
        self.state_key.as_deref()
    }
}

#[async_trait::async_trait]
impl AnisetteProvider for RemoteV3AnisetteProvider {
    async fn get_anisette_data(&self) -> Result<AnisetteData, Report> {
        self.fetch_headers(None).await
    }

    async fn resync(&self, sim: &str) -> Result<AnisetteData, Report> {
        self.fetch_headers(Some(sim)).await
    }

    /// The server's `/v3/client_info` through `client_info_to_use`, asked once.
    async fn get_client_info(&self) -> Result<AnisetteClientInfo, Report> {
        if let Some(info) = self.cached_client_info() {
            return Ok(info);
        }
        let advertised = self
            .client
            .get(format!("{}/v3/client_info", self.url))
            .timeout(Duration::from_secs(30))
            .send()
            .await
            .context("Failed to ask the anisette server for its client info")?
            .error_for_status()
            .context("The anisette server answered /v3/client_info with an error")?
            .json::<AnisetteClientInfo>()
            .await
            .context("Failed to read the anisette server's client info")?;
        let info = client_info_to_use(&advertised);
        if info.client_info == advertised.client_info.trim() {
            info!("Client info: {}, as the anisette server suggests", info.client_info);
        } else {
            info!(
                "Client info: {} (the anisette server suggests {})",
                info.client_info, advertised.client_info
            );
        }
        *self
            .android_adi
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = Some(android_adi(&advertised));
        *self
            .client_info
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = Some(info.clone());
        Ok(info)
    }

    fn runs_android_adi(&self) -> bool {
        self.android_adi
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .unwrap_or(false)
    }

    fn require_current_mac_identity(&mut self) {
        if !self.fresh_mac {
            self.fresh_mac = true;
            // Whatever was picked so far went by the old rule: pick again.
            self.state = None;
            self.state_key = None;
        }
    }

    fn needs_provisioning(&self) -> Result<bool, Report> {
        Ok(self.state.as_ref().is_none_or(|state| !state.is_provisioned()))
    }

    /// Picks the identity for this server (see `Slots`): the one it took last
    /// time; else the first stored one it takes; else a new one, provisioned
    /// through it. With `rejected`, the identity in use is left out. Only
    /// identities that `Slots::fits` the client this server reports are
    /// picked.
    async fn provision(&mut self, gs: Arc<GrandSlam>, rejected: bool) -> Result<(), Report> {
        let client = self.get_client_info().await?.client_info;
        let mut slots = Slots::load(self.storage.as_ref());
        let server = server_key(&self.url);
        let mut skip = Vec::new();
        if rejected {
            if let Some(key) = self.state_key.take() {
                if slots.servers.get(&server) == Some(&key) {
                    slots.servers.remove(&server);
                }
                skip.push(key);
            }
            self.state = None;
        }

        if let Some(key) = slots.servers.get(&server).cloned()
            && !skip.contains(&key)
        {
            if !slots.fits(&key, &client, self.fresh_mac) {
                info!(
                    "Anisette identity {key} wasn't provisioned as the Mac this sign-in reports; making a new one"
                );
                skip.push(key);
            } else if let Some(state) = self.load_state(&key) {
                debug!("Anisette identity: {key}, which this server took before");
                return self.use_state(&mut slots, &server, key, state);
            } else {
                slots.servers.remove(&server);
            }
        }

        for key in slots.candidates(&skip) {
            if !slots.fits(&key, &client, self.fresh_mac) {
                continue;
            }
            let Some(state) = self.load_state(&key) else {
                continue;
            };
            match self.fetch_headers_for(&state, None).await {
                Ok(_) => {
                    info!("Anisette identity: {key}, which this server takes");
                    return self.use_state(&mut slots, &server, key, state);
                }
                Err(e) if is_not_provisioned(&e) => {
                    info!("Anisette identity {key} isn't provisioned with this server");
                }
                Err(e) => {
                    return Err(e.context("Failed to check a stored anisette identity").into());
                }
            }
        }

        let key = slots.new_key(|k| self.load_state(k).is_some());
        info!("Provisioning a new anisette identity ({key}) with this server");
        let mut state = AnisetteState::new();
        Self::provision_state(&mut state, gs, &self.url)
            .await
            .context("Failed to provision")?;
        // Checked before it's kept, so a server that can't use what it
        // provisioned doesn't leave identities behind.
        self.fetch_headers_for(&state, None)
            .await
            .context("The anisette server refused the identity it just provisioned")?;
        self.store_state(&key, &state)?;
        slots.provisioned_as.insert(key.clone(), client);
        self.use_state(&mut slots, &server, key, state)
    }
}

impl RemoteV3AnisetteProvider {
    fn cached_client_info(&self) -> Option<AnisetteClientInfo> {
        self.client_info
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .clone()
    }

    /// The provisioned identity stored under `key`, if there is one.
    fn load_state(&self, key: &str) -> Option<AnisetteState> {
        let raw = self.storage.retrieve_data(key).ok().flatten()?;
        if raw.is_empty() {
            return None;
        }
        match plist::from_bytes::<AnisetteState>(&raw) {
            Ok(state) if state.is_provisioned() => Some(state),
            Ok(_) => None,
            Err(e) => {
                warn!("Couldn't read the anisette identity stored as {key}: {e}");
                None
            }
        }
    }

    fn store_state(&self, key: &str, state: &AnisetteState) -> Result<(), Report> {
        let mut writer = std::io::BufWriter::new(Vec::new());
        plist::to_writer_xml(&mut writer, state)?;
        self.storage.store_data(key, &writer.into_inner()?)?;
        Ok(())
    }

    fn use_state(
        &mut self,
        slots: &mut Slots,
        server: &str,
        key: String,
        state: AnisetteState,
    ) -> Result<(), Report> {
        slots.assign(server, &key);
        if let Err(e) = slots.save(self.storage.as_ref()) {
            warn!("Couldn't save which anisette identity this server takes: {e}");
        }
        self.state = Some(state);
        self.state_key = Some(key);
        Ok(())
    }

    /// Headers from `/v3/get_headers` for the identity in use.
    async fn fetch_headers(&self, sim: Option<&str>) -> Result<AnisetteData, Report> {
        let state = self
            .state
            .as_ref()
            .filter(|state| state.is_provisioned())
            .ok_or(SideloadError::AnisetteNotProvisioned)?;
        self.fetch_headers_for(state, sim).await
    }

    /// Headers from `/v3/get_headers` for `state`. With `sim`, the server first
    /// applies the resync data GrandSlam sent with an hsc 434 (upstream 0.4.5's
    /// request: `sim` plus the device ID and local user ID). An identity the
    /// server isn't provisioned with fails with
    /// `SideloadError::AnisetteNotProvisioned`.
    async fn fetch_headers_for(
        &self,
        state: &AnisetteState,
        sim: Option<&str>,
    ) -> Result<AnisetteData, Report> {
        let adi_pb = state
            .adi_pb
            .as_ref()
            .ok_or(SideloadError::AnisetteNotProvisioned)?;
        let client_info = self.get_client_info().await?;

        let mut body = serde_json::json!({
            "identifier": BASE64_STANDARD.encode(state.keychain_identifier),
            "adi_pb": BASE64_STANDARD.encode(adi_pb),
        });
        if let Some(sim) = sim {
            body["sim"] = serde_json::Value::String(sim.to_string());
            body["device_id"] = serde_json::Value::String(state.get_device_id());
            body["md_lu"] = serde_json::Value::String(hex::encode(state.get_md_lu()));
        }

        // Answered in under a second when a server is well. On 2026-10-23
        // new.ani.sidestore.io answered about one request in three with HTTP
        // 502 and left others unanswered for a minute: a 5xx is asked again
        // (a sign-in makes several of these requests, and one failing ends
        // the attempt), and a silent server is given up on sooner, so the
        // sign-in moves to a server on the same library, which takes the same
        // identity.
        let mut asked = 0;
        let headers = loop {
            asked += 1;
            let response = self
                .client
                .post(format!("{}/v3/get_headers", self.url))
                .header(CONTENT_TYPE, "application/json")
                .body(body.to_string())
                .timeout(Duration::from_secs(20))
                .send()
                .await?;
            if response.status().is_server_error() && asked < 3 {
                warn!("The anisette server answered {}; asking again", response.status());
                tokio::time::sleep(Duration::from_secs(1)).await;
                continue;
            }
            break response
                .error_for_status()?
                .json::<AnisetteHeaders>()
                .await?;
        };

        match headers {
            AnisetteHeaders::Headers {
                machine_id,
                one_time_password,
                routing_info,
            } => {
                let data = AnisetteData {
                    machine_id,
                    one_time_password,
                    routing_info,
                    _device_description: client_info.client_info.clone(),
                    device_unique_identifier: state.get_device_id(),
                    _local_user_id: hex::encode(state.get_md_lu()),
                    generated_at: SystemTime::now(),
                };

                Ok(data)
            }
            // "ADI Login error: -45061" from the Windows-ADI servers,
            // "provision.adi.ADIException: not provisioned (-45061)" from the
            // Android-ADI ones.
            AnisetteHeaders::GetHeadersError { message } if message.contains("-45061") => {
                Err(report!(SideloadError::AnisetteNotProvisioned)
                    .attach(message)
                    .into())
            }
            AnisetteHeaders::GetHeadersError { message } => {
                Err(report!("Failed to get anisette headers").attach(message))
            }
        }
    }

    async fn provisioning_headers(state: &AnisetteState) -> Result<HeaderMap, Report> {
        let mut headers = HeaderMap::new();
        headers.insert(
            "X-Apple-I-MD-LU",
            HeaderValue::from_str(&hex::encode(state.get_md_lu()))?,
        );
        // headers.insert(
        //     "X-Apple-I-Client-Time",
        //     HeaderValue::from_str(
        //         &Utc::now()
        //             .round_subsecs(0)
        //             .format("%+")
        //             .to_string()
        //             .replace("+00:00", "Z"),
        //     )?,
        // );
        // headers.insert("X-Apple-I-TimeZone", HeaderValue::from_static("UTC"));
        // headers.insert("X-Apple-Locale", HeaderValue::from_static("en_US"));
        headers.insert(
            "X-Mme-Device-Id",
            HeaderValue::from_str(&state.get_device_id())?,
        );

        Ok(headers)
    }
    async fn provision_state(
        state: &mut AnisetteState,
        gs: Arc<GrandSlam>,
        url: &str,
    ) -> Result<(), Report> {
        let start_provisioning = gs.get_url("midStartProvisioning")?;
        let end_provisioning = gs.get_url("midFinishProvisioning")?;

        let websocket_url = format!("{}/v3/provisioning_session", url)
            .replace("https://", "wss://")
            .replace("http://", "ws://");

        debug!("Starting provisioning at {}", websocket_url);
        let (mut ws_stream, _) = timeout(
            Duration::from_secs(30),
            tokio_tungstenite::connect_async(&websocket_url),
        )
        .await
        .map_err(|_| {
            report!("Timed out connecting to provisioning socket. Try a different anisette server.")
        })
        .context("Failed to connect to provisioning socket")?
        .context("Failed to connect to provisioning socket")?;

        debug!("Connected to provisioning socket");

        loop {
            let Some(msg) = ws_stream.next().await else {
                continue;
            };
            let msg = msg.context("Failed to read anisette provisioning socket message")?;
            if msg.is_close() {
                bail!("Anisette provisioning socket closed unexpectedly");
            }
            let msg = msg
                .into_text()
                .context("Failed to parse provisioning message")?;

            debug!("Received provisioning message: {}", msg);
            let provision_msg: ProvisioningMessage =
                serde_json::from_str(&msg).context("Unknown provisioning message")?;

            match provision_msg {
                ProvisioningMessage::GiveIdentifier => {
                    ws_stream
                        .send(Message::Text(
                            serde_json::json!({
                                "identifier": BASE64_STANDARD.encode(state.keychain_identifier),
                            })
                            .to_string()
                            .into(),
                        ))
                        .await
                        .context("Failed to send identifier")?;
                }
                ProvisioningMessage::GiveStartProvisioningData => {
                    let body = plist!(dict {
                        "Header": {},
                        "Request": {}
                    });

                    let response = gs
                        .plist_request(
                            &start_provisioning,
                            &body,
                            Some(Self::provisioning_headers(state).await?),
                            false,
                        )
                        .await
                        .context("Failed to send start provisioning request")?;

                    let spim = response
                        .get_str("spim")
                        .context("Start provisioning response missing spim")?;

                    ws_stream
                        .send(Message::Text(
                            serde_json::json!({
                                "spim": spim,
                            })
                            .to_string()
                            .into(),
                        ))
                        .await
                        .context("Failed to send start provisioning data")?;
                }
                ProvisioningMessage::GiveEndProvisioningData { cpim } => {
                    let body = plist!(dict {
                        "Header": {},
                        "Request": {
                            "cpim": cpim,
                        }
                    });

                    let response = gs
                        .plist_request(
                            &end_provisioning,
                            &body,
                            Some(Self::provisioning_headers(state).await?),
                            false,
                        )
                        .await
                        .context("Failed to send end provisioning request")?;

                    ws_stream
                        .send(Message::Text(
                            serde_json::json!({
                                "ptm": response
                                    .get_str("ptm")
                                    .context("End provisioning response missing ptm")?,
                                "tk": response
                                    .get_str("tk")
                                    .context("End provisioning response missing tk")?,
                            })
                            .to_string()
                            .into(),
                        ))
                        .await
                        .context("Failed to send start provisioning data")?;
                }
                ProvisioningMessage::ProvisioningSuccess { adi_pb } => {
                    state.adi_pb = Some(BASE64_STANDARD.decode(adi_pb)?);
                    ws_stream.close(None).await?;
                    info!("Provisioning successful");
                    break;
                }
                ProvisioningMessage::Timeout => bail!("Anisette provisioning timed out"),
                ProvisioningMessage::InvalidIdentifier => {
                    bail!("Anisette provisioning failed: invalid identifier")
                }
                ProvisioningMessage::StartProvisioningError { message } => {
                    return Err(
                        report!("Anisette provisioning failed: start provisioning error")
                            .attach(message),
                    );
                }
                ProvisioningMessage::EndProvisioningError { message } => {
                    return Err(
                        report!("Anisette provisioning failed: end provisioning error")
                            .attach(message),
                    );
                }
            }
        }

        Ok(())
    }
}

#[derive(Deserialize)]
#[serde(tag = "result")]
enum ProvisioningMessage {
    GiveIdentifier,
    GiveStartProvisioningData,
    GiveEndProvisioningData { cpim: String },
    ProvisioningSuccess { adi_pb: String },
    Timeout,
    InvalidIdentifier,
    StartProvisioningError { message: String },
    EndProvisioningError { message: String },
}

#[derive(Deserialize)]
#[serde(tag = "result")]
enum AnisetteHeaders {
    GetHeadersError {
        message: String,
    },
    Headers {
        #[serde(rename = "X-Apple-I-MD-M")]
        machine_id: String,
        #[serde(rename = "X-Apple-I-MD")]
        one_time_password: String,
        #[serde(rename = "X-Apple-I-MD-RINFO")]
        routing_info: String,
    },
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::anisette::AnisetteDataGenerator;
    use crate::util::storage::InMemoryStorage;
    use std::io::{Read, Write};
    use std::net::TcpListener;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use tokio::sync::RwLock;

    const STOCK: &str =
        "<MacBookPro13,2> <macOS;13.1;22C65> <com.apple.AuthKit/1 (com.apple.dt.Xcode/3594.4.19)>";

    fn info(client_info: &str, user_agent: &str) -> AnisetteClientInfo {
        AnisetteClientInfo {
            client_info: client_info.into(),
            user_agent: user_agent.into(),
        }
    }

    #[test]
    fn stock_and_android_clients_become_the_windows_pc() {
        for advertised in [
            STOCK,
            "<MacBookPro13,2> <macOS;13.1;22C65> <com.apple.AuthKit/1 (com.apple.akd/1.0)>",
            "<MacBookPro15,1> <Mac OS X;10.15.2;19C57> <com.apple.AuthKit/1 (com.apple.dt.Xcode/3594.4.19)>",
            "<Pixel 7> <Android;14;UQ1A.240205.002> <com.apple.AuthKit/1 (com.apple.akd/1.0)>",
            "",
        ] {
            let used = client_info_to_use(&info(advertised, "whatever"));
            assert_eq!(used.client_info, WINDOWS_CLIENT_INFO, "{advertised}");
            assert_eq!(used.user_agent, AKD_USER_AGENT);
        }
    }

    /// What every macOS-ADI server hands out (2026-10-23).
    const SIERRA_MAC: &str =
        "<MacBookPro13,3> <Mac OS X;10.12.6;16G29> <com.apple.AuthKit/1 (com.apple.akd/1.0)>";

    #[test]
    fn a_server_made_client_is_kept() {
        let used = client_info_to_use(&info(WINDOWS_CLIENT_INFO, "akd/1.0 CFNetwork/808.1.4"));
        assert_eq!(used.client_info, WINDOWS_CLIENT_INFO);
        // A Mac-ADI server that names a current Mac of its own.
        let mac = "<Mac14,2> <macOS;14.6;23G80> <com.apple.AuthKit/1 (com.apple.akd/1.0)>";
        let used = client_info_to_use(&info(mac, ""));
        assert_eq!(used.client_info, mac);
        assert_eq!(used.user_agent, AKD_USER_AGENT);
        let used = client_info_to_use(&info(mac, "akd/1.0 CFNetwork/1568 Darwin/24.0.0"));
        assert_eq!(used.user_agent, "akd/1.0 CFNetwork/1568 Darwin/24.0.0");
    }

    #[test]
    fn the_macos_adi_servers_old_mac_becomes_a_current_one() {
        let used = client_info_to_use(&info(SIERRA_MAC, "akd/1.0 CFNetwork/811.5.4 Darwin/16.7.0"));
        assert_eq!(used.client_info, CURRENT_MAC_CLIENT_INFO);
        assert_eq!(used.user_agent, CURRENT_MAC_USER_AGENT);
        let older = "<MacBookPro11,1> <Mac OS X;10.9.5;13F1911> <com.apple.AuthKit/1 (com.apple.akd/1.0)>";
        assert_eq!(client_info_to_use(&info(older, "")).client_info, CURRENT_MAC_CLIENT_INFO);
        // 10.13 is the floor Apple named with -23782, so it stays.
        let high_sierra = "<MacBookPro14,1> <Mac OS X;10.13.6;17G66> <com.apple.AuthKit/1 (com.apple.akd/1.0)>";
        assert_eq!(client_info_to_use(&info(high_sierra, "")).client_info, high_sierra);
    }

    #[test]
    fn android_adi_is_told_by_the_stock_and_android_clients() {
        for advertised in [
            STOCK,
            "<MacBookPro15,1> <Mac OS X;10.15.2;19C57> <com.apple.AuthKit/1 (com.apple.akd/1.0)>",
            "<Pixel 7> <Android;14;UQ1A.240205.002> <com.apple.AuthKit/1 (com.apple.akd/1.0)>",
        ] {
            assert!(android_adi(&info(advertised, "")), "{advertised}");
        }
        for advertised in [SIERRA_MAC, WINDOWS_CLIENT_INFO, CURRENT_MAC_CLIENT_INFO, ""] {
            assert!(!android_adi(&info(advertised, "")), "{advertised}");
        }
    }

    #[test]
    fn mac_versions_are_read_from_either_spelling() {
        assert_eq!(mac_version(SIERRA_MAC), Some((10, 12)));
        assert_eq!(mac_version(CURRENT_MAC_CLIENT_INFO), Some((26, 6)));
        assert_eq!(mac_version("<Mac15,7> <macOS;27.0;26A5378j> <x>"), Some((27, 0)));
        assert_eq!(mac_version("<iMac21,1> <macOS;15;24A335> <x>"), Some((15, 0)));
        assert_eq!(mac_version(WINDOWS_CLIENT_INFO), None);
        assert_eq!(mac_version("<Pixel 7> <Android;14;UQ1A.240205.002> <x>"), None);
        assert!(is_current_mac(CURRENT_MAC_CLIENT_INFO));
        assert!(!is_current_mac(SIERRA_MAC));
        assert!(!is_current_mac(WINDOWS_CLIENT_INFO));
    }

    #[test]
    fn a_full_mac_sign_in_only_fits_identities_made_as_a_current_mac() {
        let mut slots = Slots::default();
        slots.provisioned_as.insert("current".into(), CURRENT_MAC_CLIENT_INFO.into());
        slots.provisioned_as.insert("windows".into(), WINDOWS_CLIENT_INFO.into());
        // Everything fits outside a full sign-in that reports a current Mac.
        for key in ["current", "windows", LEGACY_STATE_KEY] {
            assert!(slots.fits(key, CURRENT_MAC_CLIENT_INFO, false), "{key}");
            assert!(slots.fits(key, WINDOWS_CLIENT_INFO, true), "{key}");
        }
        assert!(slots.fits("current", CURRENT_MAC_CLIENT_INFO, true));
        assert!(!slots.fits("windows", CURRENT_MAC_CLIENT_INFO, true));
        // Made before 1.6.1, so with nothing recorded.
        assert!(!slots.fits(LEGACY_STATE_KEY, CURRENT_MAC_CLIENT_INFO, true));
    }

    #[test]
    fn slots_from_before_provisioned_as_was_kept_still_load() {
        let old = r#"{"servers":{"https://a":"anisette_state"},"used":{"anisette_state":5}}"#;
        let slots: Slots = serde_json::from_str(old).unwrap();
        assert_eq!(slots.servers["https://a"], LEGACY_STATE_KEY);
        assert!(slots.provisioned_as.is_empty());
    }

    #[test]
    fn new_identities_start_at_the_legacy_key_then_count_up() {
        let mut slots = Slots::default();
        assert_eq!(slots.new_key(|_| false), LEGACY_STATE_KEY);
        assert_eq!(slots.new_key(|k| k == LEGACY_STATE_KEY), "anisette_state_2");
        slots.assign("https://a", LEGACY_STATE_KEY);
        slots.assign("https://b", "anisette_state_2");
        assert_eq!(slots.new_key(|_| false), "anisette_state_3");
    }

    #[test]
    fn candidates_are_the_most_recent_first_then_the_legacy_one() {
        let mut slots = Slots::default();
        slots.used.insert("anisette_state_2".into(), 10);
        slots.used.insert("anisette_state_3".into(), 30);
        assert_eq!(
            slots.candidates(&[]),
            ["anisette_state_3", "anisette_state_2", LEGACY_STATE_KEY]
        );
        assert_eq!(
            slots.candidates(&["anisette_state_3".to_string()]),
            ["anisette_state_2", LEGACY_STATE_KEY]
        );
    }

    /// An anisette server whose ADI library takes identities whose `adi_pb`
    /// starts with `family`, and answers others as Apple's libraries do. The
    /// served family can be changed while it runs. Counts header requests.
    struct FakeServer {
        url: String,
        family: Arc<Mutex<u8>>,
        header_requests: Arc<AtomicUsize>,
    }

    fn serve(family: u8, advertised: &'static str) -> FakeServer {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let url = format!("http://{}", listener.local_addr().unwrap());
        let served = Arc::new(Mutex::new(family));
        let header_requests = Arc::new(AtomicUsize::new(0));
        let (family_in, count_in) = (served.clone(), header_requests.clone());
        std::thread::spawn(move || {
            for stream in listener.incoming() {
                let mut stream = stream.unwrap();
                let (path, body) = read_request(&mut stream);
                let reply = if path == "/v3/client_info" {
                    serde_json::json!({ "client_info": advertised, "user_agent": AKD_USER_AGENT })
                } else {
                    count_in.fetch_add(1, Ordering::SeqCst);
                    let body: serde_json::Value = serde_json::from_str(&body).unwrap();
                    let blob = BASE64_STANDARD
                        .decode(body["adi_pb"].as_str().unwrap())
                        .unwrap();
                    if blob.first() == Some(&*family_in.lock().unwrap()) {
                        serde_json::json!({
                            "result": "Headers",
                            "X-Apple-I-MD": "otp",
                            "X-Apple-I-MD-M": "machine",
                            "X-Apple-I-MD-RINFO": "17106176",
                        })
                    } else {
                        serde_json::json!({
                            "result": "GetHeadersError",
                            "message": "ADI Login error: -45061",
                        })
                    }
                }
                .to_string();
                let response = format!(
                    "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{reply}",
                    reply.len()
                );
                stream.write_all(response.as_bytes()).unwrap();
            }
        });
        FakeServer {
            url,
            family: served,
            header_requests,
        }
    }

    /// Reads one request; returns its path and body.
    fn read_request(stream: &mut std::net::TcpStream) -> (String, String) {
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
                    let path = text.split_whitespace().nth(1).unwrap_or("").to_string();
                    return (path, text[end + 4..].to_string());
                }
            }
            if n == 0 {
                return (String::new(), String::new());
            }
        }
    }

    /// Shares one in-memory store between providers, as the app's storage
    /// directory is shared between sign-ins.
    #[derive(Clone)]
    struct Shared(Arc<InMemoryStorage>);

    impl SideloadingStorage for Shared {
        fn store(&self, key: &str, value: &str) -> Result<(), Report> {
            self.0.store(key, value)
        }
        fn retrieve(&self, key: &str) -> Result<Option<String>, Report> {
            self.0.retrieve(key)
        }
    }

    fn store_identity(storage: &Shared, key: &str, family: u8) {
        let state = AnisetteState {
            keychain_identifier: [family; 16],
            adi_pb: Some(vec![family, 1, 2, 3]),
        };
        let mut writer = std::io::BufWriter::new(Vec::new());
        plist::to_writer_xml(&mut writer, &state).unwrap();
        storage.store_data(key, &writer.into_inner().unwrap()).unwrap();
    }

    fn no_bag() -> Arc<GrandSlam> {
        Arc::new(GrandSlam::without_url_bag(info(WINDOWS_CLIENT_INFO, AKD_USER_AGENT), false).unwrap())
    }

    fn generator(url: &str, storage: &Shared) -> AnisetteDataGenerator {
        let provider =
            RemoteV3AnisetteProvider::new(url, Box::new(storage.clone()), "0".into()).unwrap();
        AnisetteDataGenerator::new(Arc::new(RwLock::new(provider)))
    }

    fn run<T>(future: impl std::future::Future<Output = T>) -> T {
        tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .unwrap()
            .block_on(future)
    }

    const ANDROID: u8 = b'A';
    const WINDOWS: u8 = b'W';

    #[test]
    fn each_family_of_servers_keeps_its_own_identity() {
        let storage = Shared(Arc::new(InMemoryStorage::new()));
        // An identity from before identities were kept per server: Android.
        store_identity(&storage, LEGACY_STATE_KEY, ANDROID);
        store_identity(&storage, "anisette_state_2", WINDOWS);
        let mut slots = Slots::default();
        slots.used.insert("anisette_state_2".into(), 1);
        slots.save(&storage).unwrap();

        let android = serve(ANDROID, STOCK);
        let windows = serve(WINDOWS, WINDOWS_CLIENT_INFO);

        run(async {
            generator(&android.url, &storage)
                .get_anisette_data(no_bag())
                .await
                .unwrap();
            generator(&windows.url, &storage)
                .get_anisette_data(no_bag())
                .await
                .unwrap();
        });
        assert_eq!(state_key_for(&storage, &android.url), LEGACY_STATE_KEY);
        assert_eq!(state_key_for(&storage, &format!("{}/", windows.url)), "anisette_state_2");

        // Remembered: the next sign-ins go straight to the identity each took.
        let before = android.header_requests.load(Ordering::SeqCst);
        run(async {
            generator(&android.url, &storage)
                .get_anisette_data(no_bag())
                .await
                .unwrap();
        });
        assert_eq!(android.header_requests.load(Ordering::SeqCst), before + 1);
    }

    #[test]
    fn a_server_that_changes_library_is_matched_again() {
        let storage = Shared(Arc::new(InMemoryStorage::new()));
        store_identity(&storage, LEGACY_STATE_KEY, ANDROID);
        store_identity(&storage, "anisette_state_2", WINDOWS);
        let mut slots = Slots::default();
        slots.used.insert("anisette_state_2".into(), 1);
        slots.save(&storage).unwrap();

        let server = serve(ANDROID, STOCK);
        run(async {
            generator(&server.url, &storage)
                .get_anisette_data(no_bag())
                .await
                .unwrap()
        });
        assert_eq!(state_key_for(&storage, &server.url), LEGACY_STATE_KEY);

        // The same address now runs the Windows library: the identity it took
        // is refused, and the stored Windows one is picked without
        // provisioning (which this GrandSlam client, with no URL bag, can't).
        *server.family.lock().unwrap() = WINDOWS;
        run(async {
            generator(&server.url, &storage)
                .get_anisette_data(no_bag())
                .await
                .unwrap()
        });
        assert_eq!(state_key_for(&storage, &server.url), "anisette_state_2");
        // And the Android identity is still there for other servers.
        assert!(storage.retrieve_data(LEGACY_STATE_KEY).unwrap().is_some());
    }

    #[test]
    fn a_server_no_identity_fits_gets_a_new_one_provisioned() {
        let storage = Shared(Arc::new(InMemoryStorage::new()));
        store_identity(&storage, LEGACY_STATE_KEY, ANDROID);
        let windows = serve(WINDOWS, WINDOWS_CLIENT_INFO);

        let error = run(async {
            generator(&windows.url, &storage)
                .get_anisette_data(no_bag())
                .await
                .unwrap_err()
        });
        // Provisioning reads the URL bag, which this client doesn't have:
        // reaching it is what this checks.
        let text = format!("{error:?}");
        assert!(text.contains("Failed to provision"), "{text}");
        // Nothing was kept or remapped for the failed attempt.
        assert_eq!(state_key_for(&storage, &windows.url), LEGACY_STATE_KEY);
        assert!(storage.retrieve_data("anisette_state_2").unwrap().is_none());
    }

    const MAC: u8 = b'M';

    #[test]
    fn a_full_sign_in_leaves_an_old_mac_identity_to_its_saved_token() {
        let storage = Shared(Arc::new(InMemoryStorage::new()));
        // A macOS-ADI identity made by 1.6.0, as the servers' old Mac.
        store_identity(&storage, LEGACY_STATE_KEY, MAC);
        let server = serve(MAC, SIERRA_MAC);

        // Reusing a saved token: the identity the server took is used.
        run(async {
            generator(&server.url, &storage)
                .get_anisette_data(no_bag())
                .await
                .unwrap()
        });
        assert_eq!(state_key_for(&storage, &server.url), LEGACY_STATE_KEY);

        // A full sign-in reports the current Mac, so it provisions a new
        // identity (which this client, with no URL bag, gets as far as trying)
        // and leaves the old one where it was.
        let error = run(async {
            let mut generator = generator(&server.url, &storage);
            generator.get_anisette_data(no_bag()).await.unwrap();
            generator.require_current_mac_identity().await;
            generator.get_anisette_data(no_bag()).await.unwrap_err()
        });
        let text = format!("{error:?}");
        assert!(text.contains("Failed to provision"), "{text}");
        assert_eq!(state_key_for(&storage, &server.url), LEGACY_STATE_KEY);
        assert!(storage.retrieve_data(LEGACY_STATE_KEY).unwrap().is_some());

        // One made as the current Mac is what a full sign-in picks.
        store_identity(&storage, "anisette_state_2", MAC);
        let mut slots = Slots::load(&storage);
        slots.used.insert("anisette_state_2".into(), 1);
        slots.provisioned_as.insert("anisette_state_2".into(), CURRENT_MAC_CLIENT_INFO.into());
        slots.save(&storage).unwrap();
        run(async {
            let mut generator = generator(&server.url, &storage);
            generator.require_current_mac_identity().await;
            generator.get_anisette_data(no_bag()).await.unwrap()
        });
        assert_eq!(state_key_for(&storage, &server.url), "anisette_state_2");
    }

    #[test]
    fn a_server_on_the_android_library_says_so_once_asked() {
        let storage = Shared(Arc::new(InMemoryStorage::new()));
        let android = serve(ANDROID, STOCK);
        let mac = serve(MAC, SIERRA_MAC);
        run(async {
            let provider =
                RemoteV3AnisetteProvider::new(&android.url, Box::new(storage.clone()), "0".into())
                    .unwrap();
            assert!(!provider.runs_android_adi(), "unknown until asked");
            provider.get_client_info().await.unwrap();
            assert!(provider.runs_android_adi());

            let provider =
                RemoteV3AnisetteProvider::new(&mac.url, Box::new(storage.clone()), "0".into())
                    .unwrap();
            assert_eq!(
                provider.get_client_info().await.unwrap().client_info,
                CURRENT_MAC_CLIENT_INFO
            );
            assert!(!provider.runs_android_adi());
        });
    }

    #[test]
    fn the_server_client_info_is_asked_once() {
        let storage = Shared(Arc::new(InMemoryStorage::new()));
        let server = serve(WINDOWS, STOCK);
        let provider =
            RemoteV3AnisetteProvider::new(&server.url, Box::new(storage), "0".into()).unwrap();
        run(async {
            assert_eq!(
                provider.get_client_info().await.unwrap().client_info,
                WINDOWS_CLIENT_INFO
            );
            assert!(provider.cached_client_info().is_some());
        });
    }
}
