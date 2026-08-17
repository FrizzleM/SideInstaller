//! Turns developer-portal capabilities ("entitlements") on for an App ID.
//!
//! An entitlement like Increased Memory Limit isn't something the signer can
//! grant itself: Apple has to enable the capability on the App ID first, and
//! only then does a freshly issued provisioning profile carry it. So this is a
//! pure developer-portal call — no device, pairing or tunnel — and the app has
//! to be signed and installed *again* afterwards to pick the change up.
//!
//! The route is the JSON:API one on developerservices2 that Xcode uses, as
//! GetMoreRam and `isideload::dev::app_ids::add_increased_memory_limit` both
//! do. isideload's version hardcodes INCREASED_MEMORY_LIMIT and pastes the body
//! together with `format!`; this takes the capability id as an argument and
//! builds the body with serde_json, so an App ID whose name contains a quote
//! can't produce a malformed request.
//!
//! Capability ids are not validated here — the list of what's worth offering
//! lives in Swift, and Apple is the authority on what a given team may enable.
//! Each id is sent as its own request so that one refusal (most of them, on a
//! free account) doesn't cost the rest, and every outcome is reported back.

use std::ffi::c_char;
use std::panic::{catch_unwind, AssertUnwindSafe};

use isideload::dev::{app_ids::AppIdsApi, device_type::DeveloperDeviceType};
use serde::Serialize;

use crate::certs::CertSession;
use crate::ffi_util::{cstr, opt_str};

/// The content type this route speaks, for both request and response.
const JSON_API: &str = "application/vnd.api+json";

/// One App ID, flattened for Swift.
#[derive(Serialize)]
struct AppIdInfo {
    /// Apple's opaque id — what the capability call addresses.
    app_id_id: String,
    /// The reverse-DNS bundle identifier.
    identifier: String,
    name: String,
}

/// What Apple said about one capability.
#[derive(Serialize)]
struct CapabilityResult {
    capability: String,
    ok: bool,
    /// Apple's message when `ok` is false, trimmed to something displayable.
    error: String,
}

/// List the team's App IDs as a JSON array of `AppIdInfo`.
///
/// # Safety
/// `session` must be a valid pointer from `cert_signin`; out pointers valid.
pub unsafe fn appid_list(
    session: *mut CertSession,
    out_json: *mut *mut c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    if session.is_null() {
        *out_error = cstr("null session");
        return 2;
    }
    let session = &mut *session;

    let result = catch_unwind(AssertUnwindSafe(|| {
        let (rt, dev, team) = (&session.rt, &mut session.dev, &session.team);
        rt.block_on(async {
            let response = dev
                .list_app_ids(team, DeveloperDeviceType::Ios)
                .await
                .map_err(|e| format!("list app IDs failed: {e}"))?;
            tracing::info!("Entitlements: {} App ID(s)", response.app_ids.len());
            let infos: Vec<AppIdInfo> = response
                .app_ids
                .iter()
                .map(|a| AppIdInfo {
                    app_id_id: a.app_id_id.clone(),
                    identifier: a.identifier.clone(),
                    name: a.name.clone(),
                })
                .collect();
            serde_json::to_string(&infos).map_err(|e| format!("serialize app IDs: {e}"))
        })
    }));

    match result {
        Ok(Ok(json)) => {
            *out_json = cstr(json);
            0
        }
        Ok(Err(e)) => {
            *out_error = cstr(e);
            1
        }
        Err(_) => {
            *out_error = cstr("panic while listing App IDs");
            2
        }
    }
}

/// Enable each capability in `capabilities` (comma-separated ids) on the App ID
/// with `app_id_id`. Always reports per-capability results in `*out_json`
/// unless the whole call failed before any request went out.
///
/// # Safety
/// `session` must be a valid pointer from `cert_signin`; the C strings valid;
/// out pointers valid and writable.
pub unsafe fn appid_enable(
    session: *mut CertSession,
    app_id_id: *const c_char,
    capabilities: *const c_char,
    out_json: *mut *mut c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    if session.is_null() {
        *out_error = cstr("null session");
        return 2;
    }
    let session = &mut *session;
    let app_id_id = opt_str(app_id_id, "");
    let capabilities = opt_str(capabilities, "");
    if app_id_id.is_empty() {
        *out_error = cstr("empty App ID");
        return 2;
    }
    let wanted: Vec<String> = capabilities
        .split(',')
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect();
    if wanted.is_empty() {
        *out_error = cstr("no capabilities requested");
        return 2;
    }

    let result = catch_unwind(AssertUnwindSafe(|| {
        let (rt, dev, team) = (&session.rt, &mut session.dev, &session.team);
        rt.block_on(async {
            // Re-listed rather than cached: the App ID's own identifier and name
            // go into the body, and a stale copy would rename it.
            let listing = dev
                .list_app_ids(team, DeveloperDeviceType::Ios)
                .await
                .map_err(|e| format!("list app IDs failed: {e}"))?;
            let app = listing
                .app_ids
                .into_iter()
                .find(|a| a.app_id_id == app_id_id)
                .ok_or_else(|| format!("App ID {app_id_id} is no longer on this team"))?;

            let team_id = team.team_id.clone();
            let mut results: Vec<CapabilityResult> = Vec::with_capacity(wanted.len());

            for capability in &wanted {
                let body = serde_json::json!({
                    "data": {
                        "relationships": {
                            "bundleIdCapabilities": {
                                "data": [{
                                    "relationships": {
                                        "capability": {
                                            "data": { "id": capability, "type": "capabilities" }
                                        }
                                    },
                                    "type": "bundleIdCapabilities",
                                    "attributes": { "settings": [], "enabled": true }
                                }]
                            }
                        },
                        "id": &app.app_id_id,
                        "attributes": {
                            "hasExclusiveManagedCapabilities": false,
                            "teamId": &team_id,
                            "bundleType": "bundle",
                            "identifier": &app.identifier,
                            "seedId": &team_id,
                            "name": &app.name
                        },
                        "type": "bundleIds"
                    }
                })
                .to_string();

                // Fetched per request: the anisette one-time password inside
                // these headers is exactly that, and a batch can outlive one.
                let mut headers = match dev.get_headers().await {
                    Ok(h) => h,
                    Err(e) => {
                        results.push(CapabilityResult {
                            capability: capability.clone(),
                            ok: false,
                            error: format!("anisette headers: {e}"),
                        });
                        continue;
                    }
                };
                // The JSON:API content type has to go into this map, not onto
                // the builder afterwards: `RequestBuilder::headers` REPLACES a
                // same-named header while `RequestBuilder::header` APPENDS one.
                // `GrandSlam::patch` has already seeded `text/x-xml-plist` for
                // the plist API, so appending left the request carrying two
                // conflicting Content-Types and Apple answered every capability
                // with an empty 400.
                for (name, value) in [("Content-Type", JSON_API), ("Accept", JSON_API)] {
                    match value.parse() {
                        Ok(v) => {
                            headers.insert(name, v);
                        }
                        Err(_) => continue,
                    }
                }

                let url = format!(
                    "https://developerservices2.apple.com/services/v1/bundleIds/{}",
                    app.app_id_id
                );
                let request = match dev.get_grandslam_client().patch(&url) {
                    Ok(r) => r,
                    Err(e) => {
                        results.push(CapabilityResult {
                            capability: capability.clone(),
                            ok: false,
                            error: format!("build request: {e}"),
                        });
                        continue;
                    }
                };

                let sent = request.headers(headers).body(body).send().await;

                match sent {
                    Ok(response) => {
                        let status = response.status();
                        if status.is_success() {
                            tracing::info!("Entitlements: {capability} enabled on {}", app.identifier);
                            results.push(CapabilityResult {
                                capability: capability.clone(),
                                ok: true,
                                error: String::new(),
                            });
                        } else {
                            let detail = response.text().await.unwrap_or_default();
                            tracing::warn!(
                                "Entitlements: {capability} refused ({status}) — {detail}"
                            );
                            results.push(CapabilityResult {
                                capability: capability.clone(),
                                ok: false,
                                error: summarize_apple_error(status.as_u16(), &detail),
                            });
                        }
                    }
                    Err(e) => results.push(CapabilityResult {
                        capability: capability.clone(),
                        ok: false,
                        error: format!("request failed: {e}"),
                    }),
                }
            }

            serde_json::to_string(&results).map_err(|e| format!("serialize results: {e}"))
        })
    }));

    match result {
        Ok(Ok(json)) => {
            *out_json = cstr(json);
            0
        }
        Ok(Err(e)) => {
            *out_error = cstr(e);
            1
        }
        Err(_) => {
            *out_error = cstr("panic while enabling entitlements");
            2
        }
    }
}

/// Pull the human-readable part out of Apple's JSON:API error body, falling
/// back to the status code. Their payload is
/// `{"errors":[{"title":"...","detail":"..."}]}`, and the detail is the line
/// worth showing ("There is no capability matching ..." and the like).
fn summarize_apple_error(status: u16, body: &str) -> String {
    if let Ok(value) = serde_json::from_str::<serde_json::Value>(body) {
        if let Some(errors) = value.get("errors").and_then(|e| e.as_array()) {
            let messages: Vec<String> = errors
                .iter()
                .filter_map(|e| {
                    e.get("detail")
                        .or_else(|| e.get("title"))
                        .and_then(|d| d.as_str())
                        .map(|s| s.to_string())
                })
                .collect();
            if !messages.is_empty() {
                return messages.join("; ");
            }
        }
    }
    let trimmed = body.trim();
    if trimmed.is_empty() {
        format!("Apple returned HTTP {status}.")
    } else {
        // Long HTML error pages are worse than useless in a table cell.
        let short: String = trimmed.chars().take(200).collect();
        format!("HTTP {status}: {short}")
    }
}
