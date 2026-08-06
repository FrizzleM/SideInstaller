//! Shared C-string helpers for the FFI boundary.

use std::ffi::{c_char, CStr, CString};

/// Allocate a C string the caller frees with `si_string_free`; an interior NUL
/// collapses to an empty string rather than panicking.
pub fn cstr(s: impl Into<Vec<u8>>) -> *mut c_char {
    CString::new(s).unwrap_or_default().into_raw()
}

/// Read a C string, falling back to `default` when null, empty or not UTF-8.
///
/// # Safety
/// `p` must be null or point to a valid NUL-terminated C string.
#[allow(dead_code)]
pub unsafe fn opt_str(p: *const c_char, default: &str) -> String {
    if p.is_null() {
        return default.to_string();
    }
    match CStr::from_ptr(p).to_str() {
        Ok(s) if !s.is_empty() => s.to_string(),
        _ => default.to_string(),
    }
}

/// Read a required C string, returning `None` when null or invalid.
///
/// # Safety
/// `p` must be null or point to a valid NUL-terminated C string.
#[allow(dead_code)]
pub unsafe fn req_str(p: *const c_char) -> Option<String> {
    if p.is_null() {
        return None;
    }
    CStr::from_ptr(p).to_str().ok().map(|s| s.to_string())
}

/// Free a heap C string previously produced by `cstr`.
///
/// # Safety
/// `p` must be null or a pointer returned by `cstr`/`into_raw`.
pub unsafe fn string_free(p: *mut c_char) {
    if !p.is_null() {
        drop(CString::from_raw(p));
    }
}
