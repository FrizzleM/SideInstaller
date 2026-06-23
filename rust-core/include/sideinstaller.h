// SideInstaller Rust core — C FFI surface.
//
// Defensive contract: no Rust panics cross this boundary. Fallible calls
// return an int32 code (0 == OK) and may hand back heap strings that the
// caller MUST release with si_string_free().
#ifndef SIDEINSTALLER_H
#define SIDEINSTALLER_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ---------------------------------------------------------------------------
// Logging spine (STEP 1)
// ---------------------------------------------------------------------------

// Receives every formatted log line (Rust/idevice tracing output). `msg` is
// only valid for the duration of the call — copy it. May be invoked from
// arbitrary Rust threads, so the Swift side must marshal to the main queue.
typedef void (*SILogCallback)(void *ctx, const char *msg);

// Install the global tracing subscriber. Returns 0 on success, 1 if logging
// was already initialised. Call once at launch.
int32_t si_log_init(SILogCallback cb, void *ctx);

// Liveness probe. Logs through tracing and returns a heap string describing
// the linked core. Free with si_string_free().
char *si_ping(void);

// Free any char* returned by this library.
void si_string_free(char *p);

// ---------------------------------------------------------------------------
// Pairing — RPPairing host (STEP 2)
// ---------------------------------------------------------------------------

// Fires once the host is bound and ready to advertise. The Swift side
// publishes `service_id` + the TXT records over Bonjour (NetService). All
// pointers are only valid for the duration of the call.
typedef void (*SIPairReadyCb)(void *ctx,
                              const char *service_id,
                              uint16_t port,
                              const char *const *txt_keys,
                              const char *const *txt_vals,
                              size_t txt_count);

// Fires with the PIN the user must confirm in Developer Mode settings.
typedef void (*SIPairPinCb)(const char *pin, void *ctx);

// Result of a pairing run. All char* fields are heap-allocated; release the
// whole struct with si_pairing_result_free().
typedef struct {
    char *error;
    char *device_name;
    char *device_model;
    char *device_udid;
    char *pairing_file_path;
    char *host_alt_irk_hex;
} SIPairResult;

// Run the RPPairing host. BLOCKS until a device pairs or an error occurs — run
// it off the main thread. Returns 0 on success, non-zero on error (with
// `out->error` set). `port` 0 lets the OS pick a port.
int32_t si_pairing_run_host(const char *bind_addr,
                            uint16_t port,
                            const char *name,
                            const char *model,
                            const char *out_path,
                            SIPairReadyCb ready_cb,
                            SIPairPinCb pin_cb,
                            void *ctx,
                            SIPairResult *out);

// Free the heap strings inside a SIPairResult.
void si_pairing_result_free(SIPairResult *r);

// ---------------------------------------------------------------------------
// Account — Apple ID sign-in + on-device signing (STEP 3)
// ---------------------------------------------------------------------------

// Opaque sign-session handle.
typedef struct SignSession SignSession;

// Invoked when a 2FA code is required: write a NUL-terminated code into
// `out_buf` (capacity `buf_len`) and return 1, or return 0 to cancel.
typedef int32_t (*SITwoFactorCb)(void *ctx, char *out_buf, size_t buf_len);

// Log in + open developer session + build the signer. BLOCKS — call off the
// main thread. Returns 0 on success (*out_session + *out_summary set), non-zero
// on error (*out_error set). Free strings with si_string_free, the session with
// si_sign_session_free.
int32_t si_apple_signin(const char *apple_id,
                        const char *password,
                        const char *anisette_url,
                        const char *machine_name,
                        const char *storage_dir,
                        SITwoFactorCb twofa_cb,
                        void *ctx,
                        SignSession **out_session,
                        char **out_summary,
                        char **out_error);

// Sign the IPA at ipa_path. BLOCKS. On success *out_signed_path is the signed
// .app bundle path (in a temp dir). Registers App ID + provisioning profile and
// retrieves/creates the dev certificate internally.
//
// device_udid (and the cosmetic device_name) identify the device this build is
// being installed onto. When a UDID is given, the device is registered with the
// developer portal BEFORE signing so the provisioning profile lists it —
// without this, installd rejects the install with 0xe8008015 ("a valid
// provisioning profile for this executable was not found"). Pass NULL/empty to
// skip registration.
int32_t si_sign_ipa(SignSession *session,
                    const char *ipa_path,
                    const char *device_name,
                    const char *device_udid,
                    char **out_signed_path,
                    char **out_error);

// Free a sign session.
void si_sign_session_free(SignSession *session);

// ---------------------------------------------------------------------------
// Certificate management — list + revoke iOS development certificates
// ---------------------------------------------------------------------------

// Opaque certificate-session handle.
typedef struct CertSession CertSession;

// Log in + open developer session + select the first team, for certificate
// management. BLOCKS — call off the main thread. Independent of the install
// pipeline (no device/pairing/VPN needed). Returns 0 on success (*out_session +
// *out_summary set), non-zero on error (*out_error set). Free strings with
// si_string_free, the session with si_cert_session_free.
int32_t si_cert_signin(const char *apple_id,
                       const char *password,
                       const char *anisette_url,
                       const char *machine_name,
                       const char *storage_dir,
                       SITwoFactorCb twofa_cb,
                       void *ctx,
                       CertSession **out_session,
                       char **out_summary,
                       char **out_error);

// List the team's iOS development certificates. BLOCKS. On success *out_json is
// a heap JSON array of objects: {name, serial_number, machine_name, machine_id,
// certificate_id, platform, status, expiration}. Free with si_string_free.
int32_t si_cert_list(CertSession *session,
                     char **out_json,
                     char **out_error);

// Revoke the development certificate with the given serial number. BLOCKS.
// Returns 0 on success, non-zero on error (*out_error set).
int32_t si_cert_revoke(CertSession *session,
                       const char *serial_number,
                       char **out_error);

// Free a certificate session.
void si_cert_session_free(CertSession *session);

#ifdef __cplusplus
}
#endif

#endif // SIDEINSTALLER_H
