// Jackson Coxson

use std::ffi::{CStr, CString, c_char};
use std::os::raw::c_int;
use std::ptr::null_mut;

use idevice::cryptexd::{
    Cryptex1Assets, CryptexInstallRequest, CryptexdClient, InstalledCryptex, NonceDomain,
};
use idevice::xpc::{Dictionary, XPCObject};
use idevice::{IdeviceError, ReadWrite};
use plist_ffi::{PlistWrapper, plist_t};

#[cfg(feature = "core_device_proxy")]
use crate::run_sync_local;
use crate::{IdeviceFfiError, ReadWriteOpaque, ffi_err, run_sync};
#[cfg(feature = "core_device_proxy")]
use crate::{core_device_proxy::AdapterHandle, rsd::RsdHandshakeHandle};
#[cfg(feature = "core_device_proxy")]
use idevice::RsdService as _;

/// Opaque handle to a CryptexdClient
///
/// The daemon serves one routine per connection, so every call below consumes
/// the handle: it is freed by the call and must not be used again, even when
/// the call fails.
pub struct CryptexdHandle(pub CryptexdClient<Box<dyn ReadWrite>>);

/// Opaque handle to the payloads a Cryptex1 DeveloperDiskImage install needs
pub struct Cryptex1AssetsHandle(pub Cryptex1Assets);

/// A cryptex installed on the device
#[repr(C)]
pub struct InstalledCryptexC {
    /// Free with `idevice_string_free`
    pub identifier: *mut c_char,
    /// Free with `idevice_string_free`
    pub version: *mut c_char,
}

/// Which nonce domain a get-nonce or roll-nonce request refers to
#[repr(C)]
#[derive(Clone, Copy)]
pub struct CryptexNonceDomain {
    /// When 1, `value` is a nonce domain handle, e.g. a build identity's
    /// `Cryptex1,NonceDomain`. When 0, it is a domain index, e.g.
    /// `IDEVICE_CRYPTEXD_NONCE_DOMAIN_CRYPTEX`.
    pub is_handle: c_int,
    pub value: u64,
}

impl From<CryptexNonceDomain> for NonceDomain {
    fn from(value: CryptexNonceDomain) -> Self {
        if value.is_handle == 0 {
            NonceDomain::Index(value.value)
        } else {
            NonceDomain::Handle(value.value)
        }
    }
}

/// The nonce domain index cryptexes are personalized against
pub const IDEVICE_CRYPTEXD_NONCE_DOMAIN_CRYPTEX: u64 = 2;
/// The `image-type-index` a DeveloperDiskImage install uses
pub const IDEVICE_CRYPTEXD_DDI_IMAGE_TYPE_INDEX: i64 = 10;
/// The `persistence` a DeveloperDiskImage install uses
pub const IDEVICE_CRYPTEXD_DDI_PERSISTENCE: u64 = 2;
/// The `nonce-persistence` a DeveloperDiskImage install uses
pub const IDEVICE_CRYPTEXD_DDI_NONCE_PERSISTENCE: u64 = 1;

// cbindgen can only emit literals, so keep them honest against the crate's.
const _: () = {
    assert!(IDEVICE_CRYPTEXD_NONCE_DOMAIN_CRYPTEX == idevice::cryptexd::NONCE_DOMAIN_CRYPTEX);
    assert!(IDEVICE_CRYPTEXD_DDI_IMAGE_TYPE_INDEX == idevice::cryptexd::DDI_IMAGE_TYPE_INDEX);
    assert!(IDEVICE_CRYPTEXD_DDI_PERSISTENCE == idevice::cryptexd::DDI_PERSISTENCE);
    assert!(IDEVICE_CRYPTEXD_DDI_NONCE_PERSISTENCE == idevice::cryptexd::DDI_NONCE_PERSISTENCE);
};

/// The payloads and parameters one install needs
#[repr(C)]
pub struct CryptexInstallRequestC {
    /// The cryptex disk image, i.e. the manifest's `Cryptex1,GenericDmg`
    pub image: *const u8,
    pub image_len: usize,
    /// `Cryptex1,GenericTrustCache`
    pub trustcache: *const u8,
    pub trustcache_len: usize,
    /// The Cryptex1 personalization ticket
    pub im4m: *const u8,
    pub im4m_len: usize,
    /// `Cryptex1,CryptexInfoPlist`, which names and versions the cryptex
    pub info: *const u8,
    pub info_len: usize,
    /// `Cryptex1,GenericVolume` root hash
    pub volumehash: *const u8,
    pub volumehash_len: usize,
    /// The `Cryptex1,*` parameters from the build identity, as a plist
    /// dictionary. Non-negative integers are sent as uint64, which the daemon
    /// requires.
    pub cryptex1_properties: plist_t,
    pub image_type_index: i64,
    pub persistence: u64,
    pub nonce_persistence: u64,
    pub auth: u64,
}

fn installed_to_c(cryptex: InstalledCryptex) -> Result<InstalledCryptexC, IdeviceError> {
    let identifier =
        CString::new(cryptex.identifier).map_err(|_| IdeviceError::FfiInvalidString)?;
    let version = CString::new(cryptex.version).map_err(|_| IdeviceError::FfiInvalidString)?;
    Ok(InstalledCryptexC {
        identifier: identifier.into_raw(),
        version: version.into_raw(),
    })
}

/// The daemon rejects int64 where it wants uint64, so send everything that fits
/// in a uint64 as one.
fn to_xpc_unsigned(value: plist::Value) -> XPCObject {
    match value {
        plist::Value::Integer(i) => match i.as_unsigned() {
            Some(u) => XPCObject::UInt64(u),
            None => XPCObject::Int64(i.as_signed().unwrap_or_default()),
        },
        plist::Value::Array(a) => XPCObject::Array(a.into_iter().map(to_xpc_unsigned).collect()),
        plist::Value::Dictionary(d) => XPCObject::Dictionary(to_xpc_dictionary(d)),
        other => XPCObject::from(other),
    }
}

fn to_xpc_dictionary(dict: plist::Dictionary) -> Dictionary {
    let mut out = Dictionary::new();
    for (key, value) in dict {
        out.insert(key, to_xpc_unsigned(value));
    }
    out
}

fn write_data(data: Vec<u8>, out: *mut *mut u8, out_len: *mut usize) {
    let mut data = data.into_boxed_slice();
    unsafe {
        *out_len = data.len();
        *out = data.as_mut_ptr();
    }
    std::mem::forget(data);
}

/// Creates a new CryptexdClient using RSD connection
///
/// # Arguments
/// * [`provider`] - An adapter created by this library
/// * [`handshake`] - An RSD handshake from the same provider
/// * [`handle`] - Pointer to store the newly created handle
///
/// # Returns
/// An IdeviceFfiError on error, null on success
///
/// # Safety
/// `provider` and `handshake` must be valid pointers to handles allocated by this library
/// `handle` must be a valid pointer to a location where the handle will be stored
#[cfg(feature = "core_device_proxy")]
#[unsafe(no_mangle)]
pub unsafe extern "C" fn cryptexd_connect_rsd(
    provider: *mut AdapterHandle,
    handshake: *mut RsdHandshakeHandle,
    handle: *mut *mut CryptexdHandle,
) -> *mut IdeviceFfiError {
    if provider.is_null() || handshake.is_null() || handle.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let res: Result<CryptexdClient<Box<dyn ReadWrite>>, IdeviceError> = run_sync_local(async {
        let provider_ref = unsafe { &mut (*provider).0 };
        let handshake_ref = unsafe { &mut (*handshake).0 };

        CryptexdClient::connect_rsd(provider_ref, handshake_ref).await
    });

    match res {
        Ok(client) => {
            unsafe { *handle = Box::into_raw(Box::new(CryptexdHandle(client))) };
            null_mut()
        }
        Err(e) => ffi_err!(e),
    }
}

/// Creates a new CryptexdClient from a socket
///
/// # Arguments
/// * [`socket`] - The socket to use for communication. Consumed regardless of the result.
/// * [`handle`] - Pointer to store the newly created handle
///
/// # Returns
/// An IdeviceFfiError on error, null on success
///
/// # Safety
/// `socket` must be a valid pointer to a handle allocated by this library
/// `handle` must be a valid pointer to a location where the handle will be stored
#[unsafe(no_mangle)]
pub unsafe extern "C" fn cryptexd_new(
    socket: *mut ReadWriteOpaque,
    handle: *mut *mut CryptexdHandle,
) -> *mut IdeviceFfiError {
    if socket.is_null() || handle.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let socket = unsafe { Box::from_raw(socket) };
    let res = run_sync(async move { CryptexdClient::new(socket.inner.unwrap()).await });

    match res {
        Ok(client) => {
            unsafe { *handle = Box::into_raw(Box::new(CryptexdHandle(client))) };
            null_mut()
        }
        Err(e) => ffi_err!(e),
    }
}

/// Reads the device's AppleImage4 chip instance, which identifies it in a
/// Cryptex1 personalization request
///
/// The keys are the daemon's `img4_chip_*` names, e.g. `img4_chip_chip`
/// (ChipID), `img4_chip_bord` (BoardID) and `img4_chip_ecid` (ECID).
///
/// # Arguments
/// * [`handle`] - The CryptexdClient handle. Consumed by this call.
/// * [`identifiers`] - Pointer to store the identifiers
///
/// # Returns
/// An IdeviceFfiError on error, null on success
///
/// # Safety
/// All pointer parameters must be valid
#[unsafe(no_mangle)]
pub unsafe extern "C" fn cryptexd_read_personalization_identifiers(
    handle: *mut CryptexdHandle,
    identifiers: *mut plist_t,
) -> *mut IdeviceFfiError {
    if handle.is_null() || identifiers.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let client = unsafe { Box::from_raw(handle) }.0;
    match run_sync(async move { client.read_personalization_identifiers().await }) {
        Ok(res) => {
            unsafe {
                *identifiers = PlistWrapper::new_node(plist::Value::Dictionary(res)).into_ptr();
            }
            null_mut()
        }
        Err(e) => ffi_err!(e),
    }
}

/// Lists the cryptexes installed on the device
///
/// # Arguments
/// * [`handle`] - The CryptexdClient handle. Consumed by this call.
/// * [`cryptexes`] - Pointer to store the list, freed with `cryptexd_free_installed`
/// * [`len`] - Pointer to store the number of entries
///
/// # Returns
/// An IdeviceFfiError on error, null on success
///
/// # Safety
/// All pointer parameters must be valid
#[unsafe(no_mangle)]
pub unsafe extern "C" fn cryptexd_copy_installed(
    handle: *mut CryptexdHandle,
    cryptexes: *mut *mut InstalledCryptexC,
    len: *mut usize,
) -> *mut IdeviceFfiError {
    if handle.is_null() || cryptexes.is_null() || len.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let client = unsafe { Box::from_raw(handle) }.0;
    let res = run_sync(async move { client.copy_installed().await });

    let installed = match res {
        Ok(installed) => installed,
        Err(e) => return ffi_err!(e),
    };
    let mut c_installed = Vec::with_capacity(installed.len());
    for cryptex in installed {
        match installed_to_c(cryptex) {
            Ok(c) => c_installed.push(c),
            Err(e) => return ffi_err!(e),
        }
    }

    let mut c_installed = c_installed.into_boxed_slice();
    unsafe {
        *len = c_installed.len();
        *cryptexes = c_installed.as_mut_ptr();
    }
    std::mem::forget(c_installed);
    null_mut()
}

/// Frees the list from `cryptexd_copy_installed`
///
/// # Safety
/// `cryptexes` must be a pointer returned by `cryptexd_copy_installed` with its
/// reported length, or NULL
#[unsafe(no_mangle)]
pub unsafe extern "C" fn cryptexd_free_installed(cryptexes: *mut InstalledCryptexC, len: usize) {
    if cryptexes.is_null() {
        return;
    }
    let cryptexes = unsafe { Vec::from_raw_parts(cryptexes, len, len) };
    for cryptex in cryptexes {
        unsafe { free_installed_fields(&cryptex) };
    }
}

unsafe fn free_installed_fields(cryptex: &InstalledCryptexC) {
    if !cryptex.identifier.is_null() {
        let _ = unsafe { CString::from_raw(cryptex.identifier) };
    }
    if !cryptex.version.is_null() {
        let _ = unsafe { CString::from_raw(cryptex.version) };
    }
}

/// Frees an InstalledCryptexC allocated by this library
///
/// # Safety
/// `cryptex` must be a pointer allocated by this library, or NULL
#[unsafe(no_mangle)]
pub unsafe extern "C" fn cryptexd_free_installed_cryptex(cryptex: *mut InstalledCryptexC) {
    if cryptex.is_null() {
        return;
    }
    let cryptex = unsafe { Box::from_raw(cryptex) };
    unsafe { free_installed_fields(&cryptex) };
}

/// Reads a nonce domain's nonce structure
///
/// Use `cryptexd_cryptex_nonce` for the nonce a TSS request wants.
///
/// # Arguments
/// * [`handle`] - The CryptexdClient handle. Consumed by this call.
/// * [`domain`] - The nonce domain to read
/// * [`nonce`] - Pointer to store the nonce, freed with `idevice_data_free`
/// * [`nonce_len`] - Pointer to store the number of bytes
///
/// # Returns
/// An IdeviceFfiError on error, null on success
///
/// # Safety
/// All pointer parameters must be valid
#[unsafe(no_mangle)]
pub unsafe extern "C" fn cryptexd_get_nonce(
    handle: *mut CryptexdHandle,
    domain: CryptexNonceDomain,
    nonce: *mut *mut u8,
    nonce_len: *mut usize,
) -> *mut IdeviceFfiError {
    if handle.is_null() || nonce.is_null() || nonce_len.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let client = unsafe { Box::from_raw(handle) }.0;
    match run_sync(async move { client.get_nonce(domain.into()).await }) {
        Ok(data) => {
            write_data(data, nonce, nonce_len);
            null_mut()
        }
        Err(e) => ffi_err!(e),
    }
}

/// Reads the nonce a Cryptex1 TSS request is personalized against
///
/// # Arguments
/// * [`handle`] - The CryptexdClient handle. Consumed by this call.
/// * [`nonce_domain_handle`] - The build identity's `Cryptex1,NonceDomain`
/// * [`nonce`] - Pointer to store the nonce, freed with `idevice_data_free`
/// * [`nonce_len`] - Pointer to store the number of bytes
///
/// # Returns
/// An IdeviceFfiError on error, null on success
///
/// # Safety
/// All pointer parameters must be valid
#[unsafe(no_mangle)]
pub unsafe extern "C" fn cryptexd_cryptex_nonce(
    handle: *mut CryptexdHandle,
    nonce_domain_handle: u64,
    nonce: *mut *mut u8,
    nonce_len: *mut usize,
) -> *mut IdeviceFfiError {
    if handle.is_null() || nonce.is_null() || nonce_len.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let client = unsafe { Box::from_raw(handle) }.0;
    match run_sync(async move { client.cryptex_nonce(nonce_domain_handle).await }) {
        Ok(data) => {
            write_data(data, nonce, nonce_len);
            null_mut()
        }
        Err(e) => ffi_err!(e),
    }
}

/// Rolls (regenerates) a nonce domain's nonce, invalidating anything
/// personalized against the previous one
///
/// # Arguments
/// * [`handle`] - The CryptexdClient handle. Consumed by this call.
/// * [`domain`] - The nonce domain to roll
///
/// # Returns
/// An IdeviceFfiError on error, null on success
///
/// # Safety
/// `handle` must be a valid pointer to a handle allocated by this library
#[unsafe(no_mangle)]
pub unsafe extern "C" fn cryptexd_roll_nonce(
    handle: *mut CryptexdHandle,
    domain: CryptexNonceDomain,
) -> *mut IdeviceFfiError {
    if handle.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let client = unsafe { Box::from_raw(handle) }.0;
    match run_sync(async move { client.roll_nonce(domain.into()).await }) {
        Ok(()) => null_mut(),
        Err(e) => ffi_err!(e),
    }
}

/// Uninstalls a cryptex by the identifier `cryptexd_copy_installed` reports
///
/// # Arguments
/// * [`handle`] - The CryptexdClient handle. Consumed by this call.
/// * [`identifier`] - The cryptex's identifier
/// * [`version`] - The version to scope the uninstall to, or NULL for all of them
///
/// # Returns
/// An IdeviceFfiError on error, null on success
///
/// # Safety
/// All non-NULL pointer parameters must be valid
#[unsafe(no_mangle)]
pub unsafe extern "C" fn cryptexd_uninstall(
    handle: *mut CryptexdHandle,
    identifier: *const c_char,
    version: *const c_char,
) -> *mut IdeviceFfiError {
    if handle.is_null() || identifier.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let identifier = match unsafe { CStr::from_ptr(identifier) }.to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return ffi_err!(IdeviceError::FfiInvalidString),
    };
    let version = if version.is_null() {
        None
    } else {
        match unsafe { CStr::from_ptr(version) }.to_str() {
            Ok(s) => Some(s.to_string()),
            Err(_) => return ffi_err!(IdeviceError::FfiInvalidString),
        }
    };

    let client = unsafe { Box::from_raw(handle) }.0;
    match run_sync(async move { client.uninstall(&identifier, version.as_deref()).await }) {
        Ok(()) => null_mut(),
        Err(e) => ffi_err!(e),
    }
}

/// Installs a cryptex
///
/// # Arguments
/// * [`handle`] - The CryptexdClient handle. Consumed by this call.
/// * [`request`] - The payloads and parameters to install
///
/// # Returns
/// An IdeviceFfiError on error, null on success
///
/// # Safety
/// All pointer parameters must be valid, and the request's buffers must be
/// readable for their stated lengths
#[unsafe(no_mangle)]
pub unsafe extern "C" fn cryptexd_install(
    handle: *mut CryptexdHandle,
    request: *const CryptexInstallRequestC,
) -> *mut IdeviceFfiError {
    if handle.is_null() || request.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let request = unsafe { &*request };
    let payload = |ptr: *const u8, len: usize| -> Option<Vec<u8>> {
        if ptr.is_null() {
            return None;
        }
        Some(unsafe { std::slice::from_raw_parts(ptr, len) }.to_vec())
    };
    let (Some(image), Some(trustcache), Some(im4m), Some(info), Some(volumehash), false) = (
        payload(request.image, request.image_len),
        payload(request.trustcache, request.trustcache_len),
        payload(request.im4m, request.im4m_len),
        payload(request.info, request.info_len),
        payload(request.volumehash, request.volumehash_len),
        request.cryptex1_properties.is_null(),
    ) else {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    };

    let properties = unsafe { &mut *request.cryptex1_properties }
        .borrow_self()
        .clone();
    let Some(properties) = properties.into_dictionary() else {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    };

    let request = CryptexInstallRequest {
        image,
        trustcache,
        im4m,
        info,
        volumehash,
        cryptex1_properties: to_xpc_dictionary(properties),
        image_type_index: request.image_type_index,
        persistence: request.persistence,
        nonce_persistence: request.nonce_persistence,
        auth: request.auth,
    };

    let client = unsafe { Box::from_raw(handle) }.0;
    match run_sync(async move { client.install(request).await }) {
        Ok(()) => null_mut(),
        Err(e) => ffi_err!(e),
    }
}

/// Extracts the nonce from cryptexd's nonce structure
///
/// # Arguments
/// * [`blob`] - The structure `cryptexd_get_nonce` returned
/// * [`blob_len`] - Its length
/// * [`nonce`] - Pointer to store the nonce, freed with `idevice_data_free`
/// * [`nonce_len`] - Pointer to store the number of bytes
///
/// # Returns
/// An IdeviceFfiError on error, null on success
///
/// # Safety
/// All pointer parameters must be valid, and `blob` must be readable for
/// `blob_len` bytes
#[unsafe(no_mangle)]
pub unsafe extern "C" fn cryptexd_unwrap_nonce(
    blob: *const u8,
    blob_len: usize,
    nonce: *mut *mut u8,
    nonce_len: *mut usize,
) -> *mut IdeviceFfiError {
    if blob.is_null() || nonce.is_null() || nonce_len.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let blob = unsafe { std::slice::from_raw_parts(blob, blob_len) };
    match idevice::cryptexd::unwrap_nonce(blob) {
        Ok(data) => {
            write_data(data, nonce, nonce_len);
            null_mut()
        }
        Err(e) => ffi_err!(e),
    }
}

/// Loads the DeveloperDiskImage payloads from an unpacked DDI `Restore` directory
///
/// # Arguments
/// * [`restore_dir`] - The directory to read
/// * [`handle`] - Pointer to store the newly created handle
///
/// # Returns
/// An IdeviceFfiError on error, null on success
///
/// # Safety
/// All pointer parameters must be valid
#[unsafe(no_mangle)]
pub unsafe extern "C" fn cryptex1_assets_load(
    restore_dir: *const c_char,
    handle: *mut *mut Cryptex1AssetsHandle,
) -> *mut IdeviceFfiError {
    if restore_dir.is_null() || handle.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let restore_dir = match unsafe { CStr::from_ptr(restore_dir) }.to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return ffi_err!(IdeviceError::FfiInvalidString),
    };

    match run_sync(async move { Cryptex1Assets::load(restore_dir).await }) {
        Ok(assets) => {
            unsafe { *handle = Box::into_raw(Box::new(Cryptex1AssetsHandle(assets))) };
            null_mut()
        }
        Err(e) => ffi_err!(e),
    }
}

/// Builds the DeveloperDiskImage payloads from buffers the caller already has
///
/// # Arguments
/// * [`image`] / [`image_len`] - `Cryptex1,GenericDmg`
/// * [`trustcache`] / [`trustcache_len`] - `Cryptex1,GenericTrustCache`
/// * [`info`] / [`info_len`] - `Cryptex1,CryptexInfoPlist`
/// * [`volumehash`] / [`volumehash_len`] - `Cryptex1,GenericVolume`
/// * [`build_identity`] - The build identity the payloads came from
/// * [`handle`] - Pointer to store the newly created handle
///
/// # Returns
/// An IdeviceFfiError on error, null on success
///
/// # Safety
/// All pointer parameters must be valid, and each buffer must be readable for
/// its stated length
#[unsafe(no_mangle)]
pub unsafe extern "C" fn cryptex1_assets_from_parts(
    image: *const u8,
    image_len: usize,
    trustcache: *const u8,
    trustcache_len: usize,
    info: *const u8,
    info_len: usize,
    volumehash: *const u8,
    volumehash_len: usize,
    build_identity: plist_t,
    handle: *mut *mut Cryptex1AssetsHandle,
) -> *mut IdeviceFfiError {
    if image.is_null()
        || trustcache.is_null()
        || info.is_null()
        || volumehash.is_null()
        || build_identity.is_null()
        || handle.is_null()
    {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let build_identity = unsafe { &mut *build_identity }.borrow_self().clone();
    let Some(build_identity) = build_identity.into_dictionary() else {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    };

    let assets = Cryptex1Assets::from_parts(
        unsafe { std::slice::from_raw_parts(image, image_len) }.to_vec(),
        unsafe { std::slice::from_raw_parts(trustcache, trustcache_len) }.to_vec(),
        unsafe { std::slice::from_raw_parts(info, info_len) }.to_vec(),
        unsafe { std::slice::from_raw_parts(volumehash, volumehash_len) }.to_vec(),
        build_identity,
    );
    unsafe { *handle = Box::into_raw(Box::new(Cryptex1AssetsHandle(assets))) };
    null_mut()
}

/// The handle of the nonce domain the assets are personalized against, i.e. the
/// build identity's `Cryptex1,NonceDomain`
///
/// # Arguments
/// * [`handle`] - The assets handle
/// * [`nonce_domain`] - Pointer to store the handle
///
/// # Returns
/// An IdeviceFfiError on error, null on success
///
/// # Safety
/// All pointer parameters must be valid
#[unsafe(no_mangle)]
pub unsafe extern "C" fn cryptex1_assets_nonce_domain(
    handle: *mut Cryptex1AssetsHandle,
    nonce_domain: *mut u64,
) -> *mut IdeviceFfiError {
    if handle.is_null() || nonce_domain.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    match unsafe { &(*handle).0 }.nonce_domain() {
        Ok(domain) => {
            unsafe { *nonce_domain = domain };
            null_mut()
        }
        Err(e) => ffi_err!(e),
    }
}

/// Frees a Cryptex1Assets handle
///
/// # Safety
/// `handle` must be a valid pointer to a handle allocated by this library or NULL
#[unsafe(no_mangle)]
pub unsafe extern "C" fn cryptex1_assets_free(handle: *mut Cryptex1AssetsHandle) {
    if !handle.is_null() {
        let _ = unsafe { Box::from_raw(handle) };
    }
}

/// Personalizes and installs the DeveloperDiskImage cryptex end to end
///
/// The cryptex equivalent of the image mounter's auto-mount: reads the device's
/// personalization identifiers and cryptex nonce, has Apple sign a Cryptex1
/// ticket for them, and installs the assets. Each step opens its own connection
/// off the adapter, since the daemon serves one routine per connection.
///
/// # Arguments
/// * [`provider`] - An adapter created by this library
/// * [`handshake`] - An RSD handshake from the same provider
/// * [`assets`] - The payloads to install
/// * [`installed`] - Pointer to store the installed cryptex, freed with
///   `cryptexd_free_installed_cryptex`. May be NULL to ignore it.
///
/// # Returns
/// An IdeviceFfiError on error, null on success
///
/// # Safety
/// All non-NULL pointer parameters must be valid
#[cfg(all(feature = "core_device_proxy", feature = "tss"))]
#[unsafe(no_mangle)]
pub unsafe extern "C" fn cryptexd_install_ddi(
    provider: *mut AdapterHandle,
    handshake: *mut RsdHandshakeHandle,
    assets: *mut Cryptex1AssetsHandle,
    installed: *mut *mut InstalledCryptexC,
) -> *mut IdeviceFfiError {
    if provider.is_null() || handshake.is_null() || assets.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let res = run_sync_local(async {
        let provider_ref = unsafe { &mut (*provider).0 };
        let handshake_ref = unsafe { &mut (*handshake).0 };
        let assets_ref = unsafe { &(*assets).0 };

        idevice::cryptexd::install_ddi(provider_ref, handshake_ref, assets_ref).await
    });

    match res {
        Ok(cryptex) => {
            if !installed.is_null() {
                match installed_to_c(cryptex) {
                    Ok(c) => unsafe { *installed = Box::into_raw(Box::new(c)) },
                    Err(e) => return ffi_err!(e),
                }
            }
            null_mut()
        }
        Err(e) => ffi_err!(e),
    }
}

/// The installed DeveloperDiskImage cryptex, if there is one
///
/// # Arguments
/// * [`provider`] - An adapter created by this library
/// * [`handshake`] - An RSD handshake from the same provider
/// * [`installed`] - Pointer to store the cryptex, set to NULL when no DDI is
///   installed. Freed with `cryptexd_free_installed_cryptex`.
///
/// # Returns
/// An IdeviceFfiError on error, null on success
///
/// # Safety
/// All pointer parameters must be valid
#[cfg(feature = "core_device_proxy")]
#[unsafe(no_mangle)]
pub unsafe extern "C" fn cryptexd_installed_ddi(
    provider: *mut AdapterHandle,
    handshake: *mut RsdHandshakeHandle,
    installed: *mut *mut InstalledCryptexC,
) -> *mut IdeviceFfiError {
    if provider.is_null() || handshake.is_null() || installed.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let res = run_sync_local(async {
        let provider_ref = unsafe { &mut (*provider).0 };
        let handshake_ref = unsafe { &mut (*handshake).0 };

        idevice::cryptexd::installed_ddi(provider_ref, handshake_ref).await
    });

    match res {
        Ok(Some(cryptex)) => match installed_to_c(cryptex) {
            Ok(c) => {
                unsafe { *installed = Box::into_raw(Box::new(c)) };
                null_mut()
            }
            Err(e) => ffi_err!(e),
        },
        Ok(None) => {
            unsafe { *installed = null_mut() };
            null_mut()
        }
        Err(e) => ffi_err!(e),
    }
}

/// Frees a CryptexdClient handle
///
/// Only needed for a handle no routine was invoked on: every routine consumes
/// the handle it is passed.
///
/// # Safety
/// `handle` must be a valid pointer to a handle allocated by this library or NULL
#[unsafe(no_mangle)]
pub unsafe extern "C" fn cryptexd_free(handle: *mut CryptexdHandle) {
    if !handle.is_null() {
        let _ = unsafe { Box::from_raw(handle) };
    }
}
