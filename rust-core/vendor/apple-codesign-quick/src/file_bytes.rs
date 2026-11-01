use crate::error::{CodeSignError, Result};
use memmap2::{Mmap, MmapOptions};
use std::fs;
use std::path::Path;

pub(crate) enum FileBytes {
    Mapped(Mmap),
    Owned(Vec<u8>),
}

impl FileBytes {
    pub(crate) fn as_slice(&self) -> &[u8] {
        match self {
            Self::Mapped(map) => map,
            Self::Owned(bytes) => bytes,
        }
    }
}

pub(crate) fn read_file_bytes(path: &Path) -> Result<FileBytes> {
    let file = fs::File::open(path).map_err(|source| CodeSignError::io(path, source))?;
    let len = file
        .metadata()
        .map_err(|source| CodeSignError::io(path, source))?
        .len();

    if len == 0 {
        return Ok(FileBytes::Owned(Vec::new()));
    }

    // SAFETY: every mapped read in this crate is created from a file opened for
    // read-only use and is only exposed as an immutable byte slice. During our
    // own signing flow, files are mapped after any planned in-process rewrites
    // for that file and before we write the signed replacement. Concurrent
    // external mutation of the bundle while signing is outside the supported
    // contract, matching the same precondition as the D MmFile implementation.
    let mapped = unsafe { MmapOptions::new().map(&file) };
    match mapped {
        Ok(map) => Ok(FileBytes::Mapped(map)),
        Err(_) => fs::read(path)
            .map(FileBytes::Owned)
            .map_err(|source| CodeSignError::io(path, source)),
    }
}
