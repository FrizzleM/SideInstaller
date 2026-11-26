// Jackson Coxson

#[cfg(feature = "tunnel_tcp_stack")]
pub mod adapter;
#[cfg(feature = "afc")]
pub mod afc;
#[cfg(feature = "amfi")]
pub mod amfi;
#[cfg(feature = "bt_packet_logger")]
pub mod bt_packet_logger;
#[cfg(feature = "companion_proxy")]
pub mod companion_proxy;
#[cfg(feature = "core_device")]
pub mod core_device;
#[cfg(feature = "core_device_proxy")]
pub mod core_device_proxy;
#[cfg(feature = "crashreportcopymobile")]
pub mod crashreportcopymobile;
#[cfg(feature = "cryptexd")]
pub mod cryptexd;
#[cfg(feature = "debug_proxy")]
pub mod debug_proxy;
#[cfg(feature = "diagnostics_relay")]
pub mod diagnostics_relay;
#[cfg(feature = "dvt")]
pub mod dvt;
mod errors;
#[cfg(feature = "heartbeat")]
pub mod heartbeat;
#[cfg(feature = "house_arrest")]
pub mod house_arrest;
#[cfg(feature = "installation_proxy")]
pub mod installation_proxy;
#[cfg(feature = "installcoordination_proxy")]
pub mod installcoordination_proxy;
#[cfg(feature = "location_simulation")]
pub mod location_simulation;
pub mod lockdown;
pub mod logging;
#[cfg(feature = "misagent")]
pub mod misagent;
#[cfg(feature = "mobile_image_mounter")]
pub mod mobile_image_mounter;
#[cfg(feature = "mobileactivationd")]
pub mod mobileactivationd;
#[cfg(feature = "mobilebackup2")]
pub mod mobilebackup2;
#[cfg(feature = "notification_proxy")]
pub mod notification_proxy;
#[cfg(feature = "syslog_relay")]
pub mod os_trace_relay;
#[cfg(feature = "remote_pairing")]
pub mod pairable_host;
mod pairing_file;
#[cfg(feature = "pcapd")]
pub mod pcapd;
#[cfg(feature = "preboard_service")]
pub mod preboard_service;
pub mod provider;
#[cfg(feature = "restore_service")]
pub mod restore_service;
#[cfg(feature = "remote_pairing")]
pub mod rp_pairing_file;
#[cfg(feature = "xpc")]
pub mod rsd;
#[cfg(feature = "screenshotr")]
pub mod screenshotr;
#[cfg(feature = "springboardservices")]
pub mod springboardservices;
#[cfg(feature = "syslog_relay")]
pub mod syslog_relay;
#[cfg(feature = "tunnel_tcp_stack")]
pub mod tcp_object_stack;
#[cfg(feature = "tunnel_tcp_stack")]
pub mod tunnel_provider;
#[cfg(feature = "usbmuxd")]
pub mod usbmuxd;
pub mod util;
#[cfg(feature = "wda")]
pub mod wda;
#[cfg(feature = "wda")]
pub mod wda_bridge;

pub use errors::*;
pub use pairing_file::*;

use idevice::{Idevice, IdeviceSocket, ReadWrite};
use once_cell::sync::Lazy;
use plist_ffi::PlistWrapper;
use std::{
    ffi::{CStr, CString, c_char, c_void},
    ptr::null_mut,
};
use tokio::runtime::{self, Runtime};

#[cfg(unix)]
use crate::util::{idevice_sockaddr, idevice_socklen_t};

static GLOBAL_RUNTIME: Lazy<Runtime> = Lazy::new(|| {
    runtime::Builder::new_multi_thread()
        .enable_io()
        .enable_time()
        .build()
        .unwrap()
});

static LOCAL_RUNTIME: Lazy<Runtime> = Lazy::new(|| {
    runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .unwrap()
});

/// Spawn the future on the global runtime and block current (FFI) thread until result.
/// F and R must be Send + 'static.
pub fn run_sync<F, R>(fut: F) -> R
where
    F: std::future::Future<Output = R> + Send + 'static,
    R: Send + 'static,
{
    let (tx, rx) = std::sync::mpsc::sync_channel(1);

    GLOBAL_RUNTIME.handle().spawn(async move {
        let res = fut.await;
        // best-effort send; ignore if receiver dropped
        let _ = tx.send(res);
    });

    rx.recv().expect("runtime worker panicked")
}

pub fn run_sync_local<F, R>(fut: F) -> R
where
    F: std::future::Future<Output = R>,
    R: 'static,
{
    LOCAL_RUNTIME.block_on(fut)
}

pub const LOCKDOWN_PORT: u16 = 62078;

#[repr(C)]
pub struct ReadWriteOpaque {
    pub inner: Option<Box<dyn ReadWrite>>,
}

/// Opaque C-compatible handle to an Idevice connection
pub struct IdeviceHandle(pub Idevice);
pub struct IdeviceSocketHandle(IdeviceSocket);

/// Stub to avoid header problems
#[allow(non_camel_case_types)]
pub type plist_t = *mut std::ffi::c_void;

// https://github.com/mozilla/cbindgen/issues/539
#[allow(non_camel_case_types, unused)]
struct sockaddr;

/// Creates a new Idevice connection
///
/// # Arguments
/// * [`socket`] - Socket for communication with the device
/// * [`label`] - Label for the connection
/// * [`idevice`] - On success, will be set to point to a newly allocated Idevice handle
///
/// # Returns
/// An IdeviceFfiError on error, null on success
///
/// # Safety
/// `label` must be a valid null-terminated C string
/// `idevice` must be a valid, non-null pointer to a location where the handle will be stored
#[unsafe(no_mangle)]
pub unsafe extern "C" fn idevice_new(
    socket: *mut IdeviceSocketHandle,
    label: *const c_char,
    idevice: *mut *mut IdeviceHandle,
) -> *mut IdeviceFfiError {
    if socket.is_null() || label.is_null() || idevice.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    // Get socket ownership
    let socket_box = unsafe { Box::from_raw(socket) };

    // Convert C string to Rust string
    let c_str = match unsafe { CStr::from_ptr(label).to_str() } {
        Ok(s) => s,
        Err(_) => return ffi_err!(IdeviceError::FfiInvalidString),
    };

    // Create new Idevice instance
    let dev = Idevice::new((*socket_box).0, c_str);
    let boxed = Box::new(IdeviceHandle(dev));
    unsafe { *idevice = Box::into_raw(boxed) };

    null_mut()
}

/// Creates an Idevice object from a socket file descriptor
///
/// # Safety
/// The socket FD must be valid.
/// The pointers must be valid and non-null.
#[cfg(unix)]
#[unsafe(no_mangle)]
pub unsafe extern "C" fn idevice_from_fd(
    fd: i32,
    label: *const c_char,
    idevice: *mut *mut IdeviceHandle,
) -> *mut IdeviceFfiError {
    if label.is_null() || idevice.is_null() || fd == 0 {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    // Get socket ownership
    let fd = unsafe { libc::dup(fd) };
    let socket = unsafe { <std::net::TcpStream as std::os::fd::FromRawFd>::from_raw_fd(fd) };
    if let Err(e) = socket.set_nonblocking(true) {
        return ffi_err!(e);
    }
    let socket = match run_sync(async move { tokio::net::TcpStream::from_std(socket) }) {
        Ok(s) => s,
        Err(e) => return ffi_err!(e),
    };

    // Convert C string to Rust string
    let c_str = match unsafe { CStr::from_ptr(label).to_str() } {
        Ok(s) => s,
        Err(_) => return ffi_err!(IdeviceError::FfiInvalidString),
    };

    // Create new Idevice instance
    let dev = Idevice::new(Box::new(socket), c_str);
    let boxed = Box::new(IdeviceHandle(dev));
    unsafe { *idevice = Box::into_raw(boxed) };

    null_mut()
}

/// Creates a new Idevice connection
///
/// # Arguments
/// * [`addr`] - The socket address to connect to
/// * [`addr_len`] - Length of the socket
/// * [`label`] - Label for the connection
/// * [`idevice`] - On success, will be set to point to a newly allocated Idevice handle
///
/// # Returns
/// An IdeviceFfiError on error, null on success
///
/// # Safety
/// `addr` must be a valid sockaddr
/// `label` must be a valid null-terminated C string
/// `idevice` must be a valid, non-null pointer to a location where the handle will be stored
#[cfg(unix)]
#[unsafe(no_mangle)]
pub unsafe extern "C" fn idevice_new_tcp_socket(
    addr: *const idevice_sockaddr,
    addr_len: idevice_socklen_t,
    label: *const c_char,
    idevice: *mut *mut IdeviceHandle,
) -> *mut IdeviceFfiError {
    use crate::util::SockAddr;

    if addr.is_null() || label.is_null() || idevice.is_null() {
        tracing::error!("null pointer(s) to idevice_new_tcp_socket");
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let addr = addr as *const SockAddr;

    let label = match unsafe { CStr::from_ptr(label).to_str() } {
        Ok(s) => s,
        Err(_) => return ffi_err!(IdeviceError::FfiInvalidString),
    };

    let addr = match util::c_socket_to_rust(addr, addr_len) {
        Ok(a) => a,
        Err(e) => return ffi_err!(e),
    };

    let device = run_sync(async move {
        let stream = tokio::net::TcpStream::connect(addr).await?;
        Ok::<idevice::Idevice, idevice::IdeviceError>(idevice::Idevice::new(
            Box::new(stream),
            label,
        ))
    });

    match device {
        Ok(dev) => {
            let boxed = Box::new(IdeviceHandle(dev));
            unsafe { *idevice = Box::into_raw(boxed) };
            std::ptr::null_mut()
        }
        Err(e) => ffi_err!(e),
    }
}

/// Gets the device type
///
/// # Arguments
/// * [`idevice`] - The Idevice handle
/// * [`device_type`] - On success, will be set to point to a newly allocated string containing the device type
///
/// # Returns
/// An IdeviceFfiError on error, null on success
///
/// # Safety
/// `idevice` must be a valid, non-null pointer to an Idevice handle
/// `device_type` must be a valid, non-null pointer to a location where the string pointer will be stored
#[unsafe(no_mangle)]
pub unsafe extern "C" fn idevice_get_type(
    idevice: *mut IdeviceHandle,
    device_type: *mut *mut c_char,
) -> *mut IdeviceFfiError {
    if idevice.is_null() || device_type.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    // Get the Idevice reference
    let dev = unsafe { &mut (*idevice).0 };

    // Run the get_type method in the runtime
    let result = run_sync(async { dev.get_type().await });

    match result {
        Ok(type_str) => match CString::new(type_str) {
            Ok(c_string) => {
                unsafe { *device_type = c_string.into_raw() };
                null_mut()
            }
            Err(_) => ffi_err!(IdeviceError::FfiInvalidString),
        },
        Err(e) => ffi_err!(e),
    }
}

/// Performs RSD checkin
///
/// # Arguments
/// * [`idevice`] - The Idevice handle
///
/// # Returns
/// An IdeviceFfiError on error, null on success
///
/// # Safety
/// `idevice` must be a valid, non-null pointer to an Idevice handle
#[unsafe(no_mangle)]
pub unsafe extern "C" fn idevice_rsd_checkin(idevice: *mut IdeviceHandle) -> *mut IdeviceFfiError {
    if idevice.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    // Get the Idevice reference
    let dev = unsafe { &mut (*idevice).0 };

    // Run the rsd_checkin method in the runtime
    let result = run_sync(async { dev.rsd_checkin().await });

    match result {
        Ok(_) => null_mut(),
        Err(e) => ffi_err!(e),
    }
}

/// Starts a TLS session
///
/// # Arguments
/// * [`idevice`] - The Idevice handle
/// * [`pairing_file`] - The pairing file to use for TLS
///
/// # Returns
/// An IdeviceFfiError on error, null on success
///
/// # Safety
/// `idevice` must be a valid, non-null pointer to an Idevice handle
/// `pairing_file` must be a valid, non-null pointer to a pairing file handle
#[unsafe(no_mangle)]
pub unsafe extern "C" fn idevice_start_session(
    idevice: *mut IdeviceHandle,
    pairing_file: *const IdevicePairingFile,
    legacy: bool,
) -> *mut IdeviceFfiError {
    if idevice.is_null() || pairing_file.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    // Get the Idevice reference
    let dev = unsafe { &mut (*idevice).0 };

    // Get the pairing file reference
    let pf = unsafe { &(*pairing_file).0 };

    // Run the start_session method in the runtime
    let result = run_sync(async move { dev.start_session(pf, legacy).await });

    match result {
        Ok(_) => null_mut(),
        Err(e) => ffi_err!(e),
    }
}

/// Frees an Idevice handle
///
/// # Arguments
/// * [`idevice`] - The Idevice handle to free
///
/// # Safety
/// `idevice` must be a valid pointer to an Idevice handle that was allocated by this library,
/// or NULL (in which case this function does nothing)
#[unsafe(no_mangle)]
pub unsafe extern "C" fn idevice_free(idevice: *mut IdeviceHandle) {
    if !idevice.is_null() {
        let _ = unsafe { Box::from_raw(idevice) };
    }
}

/// Frees a stream handle
///
/// # Safety
/// Pass a valid handle allocated by this library
#[unsafe(no_mangle)]
pub unsafe extern "C" fn idevice_stream_free(stream_handle: *mut ReadWriteOpaque) {
    if !stream_handle.is_null() {
        let _ = unsafe { Box::from_raw(stream_handle) };
    }
}

/// Frees a string allocated by this library
///
/// # Arguments
/// * [`string`] - The string to free
///
/// # Safety
/// `string` must be a valid pointer to a string that was allocated by this library,
/// or NULL (in which case this function does nothing)
#[unsafe(no_mangle)]
pub unsafe extern "C" fn idevice_string_free(string: *mut c_char) {
    if !string.is_null() {
        let _ = unsafe { CString::from_raw(string) };
    }
}

/// Frees data allocated by this library
///
/// # Arguments
/// * [`data`] - The data to free
///
/// # Safety
/// `data` must be a valid pointer to data that was allocated by this library,
/// or NULL (in which case this function does nothing)
#[unsafe(no_mangle)]
pub unsafe extern "C" fn idevice_data_free(data: *mut u8, len: usize) {
    if !data.is_null() {
        let _ = unsafe { Vec::from_raw_parts(data, len, len) };
    }
}

/// Frees an array of plists allocated by this library
///
/// # Safety
/// `data` must be a pointer to data allocated by this library,
/// NOT data allocated by libplist.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn idevice_plist_array_free(plists: *mut plist_t, len: usize) {
    if !plists.is_null() {
        let data = unsafe { std::slice::from_raw_parts(plists, len) };
        for x in data {
            unsafe { plist_ffi::creation::plist_free((*x) as *mut PlistWrapper) };
        }
    }
}

/// Frees a slice of pointers allocated by this library that had an underlying
/// vec creation.
///
/// The following functions use an underlying vec and are safe to use:
/// - idevice_usbmuxd_get_devices
///
/// # Safety
/// Pass a valid pointer passed by the Vec creating functions
#[unsafe(no_mangle)]
pub unsafe extern "C" fn idevice_outer_slice_free(slice: *mut c_void, len: usize) {
    if !slice.is_null() {
        let _ = unsafe { Vec::from_raw_parts(slice, len, len) };
    }
}
