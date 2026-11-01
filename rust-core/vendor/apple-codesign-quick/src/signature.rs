use crate::error::{CodeSignError, Result};
use plist::{Dictionary, Value};
use rayon::prelude::*;
use sha1::Digest as _;
use std::borrow::Cow;

pub const CSSLOT_CODEDIRECTORY: u32 = 0;
pub const CSSLOT_REQUIREMENTS: u32 = 2;
pub const CSSLOT_ENTITLEMENTS: u32 = 5;
pub const CSSLOT_DER_ENTITLEMENTS: u32 = 7;
pub const CSSLOT_ALTERNATE_CODEDIRECTORIES: u32 = 0x1000;
pub const CSSLOT_SIGNATURESLOT: u32 = 0x10000;

pub const CSMAGIC_BLOBWRAPPER: u32 = 0xfade_0b01;
pub const CSMAGIC_REQUIREMENTS: u32 = 0xfade_0c01;
pub const CSMAGIC_CODEDIRECTORY: u32 = 0xfade_0c02;
pub const CSMAGIC_EMBEDDED_SIGNATURE: u32 = 0xfade_0cc0;
pub const CSMAGIC_EMBEDDED_ENTITLEMENTS: u32 = 0xfade_7171;
pub const CSMAGIC_EMBEDDED_DER_ENTITLEMENTS: u32 = 0xfade_7172;

const CODEDIRECTORY_VERSION_EXECSEG: u32 = 0x20400;
const CODEDIRECTORY_HEADER_LEN: usize = 88;
const CODEDIRECTORY_PAGE_SIZE_LOG2: u8 = 12;
const CODEDIRECTORY_PAGE_SIZE: usize = 1 << CODEDIRECTORY_PAGE_SIZE_LOG2;
const CODEDIRECTORY_PARALLEL_HASH_PAGES: usize = 64;

pub const CS_EXECSEG_MAIN_BINARY: u64 = 0x1;
pub const CS_EXECSEG_ALLOW_UNSIGNED: u64 = 0x10;
pub const CS_EXECSEG_DEBUGGER: u64 = 0x20;
pub const CS_EXECSEG_JIT: u64 = 0x40;
pub const CS_EXECSEG_SKIP_LV: u64 = 0x80;
pub const CS_EXECSEG_CAN_LOAD_CDHASH: u64 = 0x100;
pub const CS_EXECSEG_CAN_EXEC_CDHASH: u64 = 0x200;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum HashAlgorithm {
    Sha1,
    Sha256,
}

impl HashAlgorithm {
    pub fn digest(self, bytes: &[u8]) -> Vec<u8> {
        match self {
            Self::Sha1 => sha1::Sha1::digest(bytes).to_vec(),
            Self::Sha256 => sha2::Sha256::digest(bytes).to_vec(),
        }
    }

    fn push_digest(self, out: &mut Vec<u8>, bytes: &[u8]) {
        match self {
            Self::Sha1 => {
                let digest = sha1::Sha1::digest(bytes);
                out.extend_from_slice(&digest);
            }
            Self::Sha256 => {
                let digest = sha2::Sha256::digest(bytes);
                out.extend_from_slice(&digest);
            }
        }
    }

    pub fn digest_len(self) -> usize {
        match self {
            Self::Sha1 => 20,
            Self::Sha256 => 32,
        }
    }

    pub fn code_directory_hash_type(self) -> u8 {
        match self {
            Self::Sha1 => 1,
            Self::Sha256 => 2,
        }
    }
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct ExecutableSegment {
    pub base: u64,
    pub limit: u64,
    pub flags: u64,
}

#[derive(Debug)]
pub struct EncodedCodeDirectory<'a> {
    pub algorithm: HashAlgorithm,
    pub bytes: &'a [u8],
}

#[derive(Debug)]
pub struct CmsSigningRequest<'a> {
    pub code_directories: &'a [EncodedCodeDirectory<'a>],
}

pub trait CmsSigner: Sync {
    fn sign(&self, request: CmsSigningRequest<'_>) -> Result<Vec<u8>>;
}

#[derive(Debug)]
pub struct CodeDirectoryParams<'a> {
    pub identifier: &'a str,
    pub team_id: &'a str,
    pub macho_data: &'a [u8],
    pub code_limit: usize,
    pub executable_segment: ExecutableSegment,
    pub is_executable: bool,
    pub requirements_blob: &'a [u8],
    pub entitlements_blob: &'a [u8],
    pub der_entitlements_blob: Option<&'a [u8]>,
    pub info_plist: Option<&'a [u8]>,
    pub code_resources: Option<&'a [u8]>,
}

#[derive(Clone, Copy, Debug, Default)]
struct CodePageHashes {
    sha1: [u8; 20],
    sha256: [u8; 32],
}

impl CodePageHashes {
    fn get(&self, algorithm: HashAlgorithm) -> &[u8] {
        match algorithm {
            HashAlgorithm::Sha1 => &self.sha1,
            HashAlgorithm::Sha256 => &self.sha256,
        }
    }
}

pub fn entitlements_xml(entitlements: &Dictionary) -> Result<Vec<u8>> {
    let mut data = Vec::new();
    plist::to_writer_xml(&mut data, &Value::Dictionary(entitlements.clone()))?;
    Ok(data)
}

pub fn empty_requirements_blob() -> Vec<u8> {
    let mut out = Vec::with_capacity(12);
    push_be_u32(&mut out, CSMAGIC_REQUIREMENTS);
    push_be_u32(&mut out, 12);
    push_be_u32(&mut out, 0);
    out
}

pub fn entitlements_blob(xml: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(8 + xml.len());
    push_be_u32(&mut out, CSMAGIC_EMBEDDED_ENTITLEMENTS);
    push_be_u32(&mut out, (8 + xml.len()) as u32);
    out.extend_from_slice(xml);
    out
}

pub fn der_entitlements_blob(entitlements: &Dictionary) -> Result<Vec<u8>> {
    let der = der_entitlements(entitlements)?;
    let mut out = Vec::with_capacity(8 + der.len());
    push_be_u32(&mut out, CSMAGIC_EMBEDDED_DER_ENTITLEMENTS);
    push_be_u32(&mut out, (8 + der.len()) as u32);
    out.extend_from_slice(&der);
    Ok(out)
}

pub fn entitlement_exec_flags(entitlements: &Dictionary, is_main_binary: bool) -> u64 {
    let mut flags = if is_main_binary {
        CS_EXECSEG_MAIN_BINARY
    } else {
        0
    };

    for (key, flag) in [
        ("get-task-allow", CS_EXECSEG_ALLOW_UNSIGNED),
        ("run-unsigned-code", CS_EXECSEG_ALLOW_UNSIGNED),
        ("com.apple.private.cs.debugger", CS_EXECSEG_DEBUGGER),
        ("dynamic-codesigning", CS_EXECSEG_JIT),
        (
            "com.apple.private.skip-library-validation",
            CS_EXECSEG_SKIP_LV,
        ),
        (
            "com.apple.private.amfi.can-load-cdhash",
            CS_EXECSEG_CAN_LOAD_CDHASH,
        ),
        (
            "com.apple.private.amfi.can-execute-cdhash",
            CS_EXECSEG_CAN_EXEC_CDHASH,
        ),
    ] {
        if matches!(entitlements.get(key), Some(Value::Boolean(true))) {
            flags |= flag;
        }
    }

    flags
}

pub(crate) struct SuperblobSizePlan<'a> {
    pub identifier: &'a str,
    pub team_id: &'a str,
    pub code_limit: usize,
    pub is_executable: bool,
    pub requirements_blob_len: usize,
    pub entitlements_blob_len: usize,
    pub der_entitlements_blob_len: Option<usize>,
    pub has_cms_signature: bool,
    pub cms_blob_reservation: usize,
}

pub(crate) fn planned_superblob_len_from_parts(plan: SuperblobSizePlan<'_>) -> usize {
    let count = 4
        + usize::from(plan.der_entitlements_blob_len.is_some())
        + usize::from(plan.has_cms_signature);
    let mut len = 12 + count * 8;

    len += code_directory_len(
        HashAlgorithm::Sha1,
        plan.identifier,
        plan.team_id,
        plan.code_limit,
        plan.is_executable,
    );
    len += code_directory_len(
        HashAlgorithm::Sha256,
        plan.identifier,
        plan.team_id,
        plan.code_limit,
        plan.is_executable,
    );
    len += plan.requirements_blob_len;
    len += plan.entitlements_blob_len;

    if let Some(der_entitlements_blob_len) = plan.der_entitlements_blob_len {
        len += der_entitlements_blob_len;
    }

    if plan.has_cms_signature {
        len += plan.cms_blob_reservation;
    }

    len
}

pub fn encode_embedded_signature(
    params: &CodeDirectoryParams<'_>,
    cms_signer: Option<&dyn CmsSigner>,
    cms_blob_reservation: usize,
) -> Result<Vec<u8>> {
    if params.code_limit > params.macho_data.len() {
        return Err(CodeSignError::macho(
            "<memory>",
            format!(
                "code limit {} exceeds Mach-O length {}",
                params.code_limit,
                params.macho_data.len()
            ),
        ));
    }

    let code_hashes = hash_code_pages(&params.macho_data[..params.code_limit]);
    let (primary_code_directory, alternate_code_directory) =
        if should_parallelize_code_directory_encoding(params, code_hashes.len()) {
            let (primary, alternate) = rayon::join(
                || encode_code_directory(params, HashAlgorithm::Sha1, &code_hashes),
                || encode_code_directory(params, HashAlgorithm::Sha256, &code_hashes),
            );
            (primary?, alternate?)
        } else {
            (
                encode_code_directory(params, HashAlgorithm::Sha1, &code_hashes)?,
                encode_code_directory(params, HashAlgorithm::Sha256, &code_hashes)?,
            )
        };

    let signature_blob = if let Some(cms_signer) = cms_signer {
        let directories = [
            EncodedCodeDirectory {
                algorithm: HashAlgorithm::Sha1,
                bytes: &primary_code_directory,
            },
            EncodedCodeDirectory {
                algorithm: HashAlgorithm::Sha256,
                bytes: &alternate_code_directory,
            },
        ];
        let cms = cms_signer.sign(CmsSigningRequest {
            code_directories: &directories,
        })?;
        Some(signature_blob_wrapper(&cms, cms_blob_reservation)?)
    } else {
        None
    };

    let mut blobs: Vec<(u32, Cow<'_, [u8]>)> = vec![
        (CSSLOT_CODEDIRECTORY, Cow::Owned(primary_code_directory)),
        (CSSLOT_REQUIREMENTS, Cow::Borrowed(params.requirements_blob)),
        (CSSLOT_ENTITLEMENTS, Cow::Borrowed(params.entitlements_blob)),
    ];

    if let Some(der_entitlements_blob) = params.der_entitlements_blob {
        blobs.push((
            CSSLOT_DER_ENTITLEMENTS,
            Cow::Borrowed(der_entitlements_blob),
        ));
    }

    blobs.push((
        CSSLOT_ALTERNATE_CODEDIRECTORIES,
        Cow::Owned(alternate_code_directory),
    ));

    if let Some(signature_blob) = signature_blob {
        blobs.push((CSSLOT_SIGNATURESLOT, Cow::Owned(signature_blob)));
    }

    Ok(encode_superblob(blobs))
}

fn code_directory_len(
    algorithm: HashAlgorithm,
    identifier: &str,
    team_id: &str,
    code_limit: usize,
    is_executable: bool,
) -> usize {
    let hash_len = algorithm.digest_len();
    let special_slots = if is_executable { 7 } else { 5 };
    let code_slots = code_limit.div_ceil(CODEDIRECTORY_PAGE_SIZE);

    CODEDIRECTORY_HEADER_LEN
        + identifier.len()
        + 1
        + team_id.len()
        + 1
        + (special_slots + code_slots) * hash_len
}

fn encode_code_directory(
    params: &CodeDirectoryParams<'_>,
    algorithm: HashAlgorithm,
    code_hashes: &[CodePageHashes],
) -> Result<Vec<u8>> {
    let hash_len = algorithm.digest_len();
    let special_slot_count = if params.is_executable { 7 } else { 5 };
    let code_slot_count = code_hashes.len();
    let dynamic_len = params.identifier.len()
        + 1
        + params.team_id.len()
        + 1
        + special_slot_count * hash_len
        + code_slot_count * hash_len;
    let ident_offset = CODEDIRECTORY_HEADER_LEN;
    let team_offset = ident_offset + params.identifier.len() + 1;
    let hash_offset = team_offset + params.team_id.len() + 1 + special_slot_count * hash_len;
    let length = CODEDIRECTORY_HEADER_LEN + dynamic_len;

    let mut out = Vec::with_capacity(length);
    push_be_u32(&mut out, CSMAGIC_CODEDIRECTORY);
    push_be_u32(&mut out, length as u32);
    push_be_u32(&mut out, CODEDIRECTORY_VERSION_EXECSEG);
    push_be_u32(&mut out, 0);
    push_be_u32(&mut out, hash_offset as u32);
    push_be_u32(&mut out, ident_offset as u32);
    push_be_u32(&mut out, special_slot_count as u32);
    push_be_u32(&mut out, code_slot_count as u32);
    push_be_u32(&mut out, u32::try_from(params.code_limit).unwrap_or(0));
    out.push(hash_len as u8);
    out.push(algorithm.code_directory_hash_type());
    out.push(0);
    out.push(CODEDIRECTORY_PAGE_SIZE_LOG2);
    push_be_u32(&mut out, 0);
    push_be_u32(&mut out, 0);
    push_be_u32(&mut out, team_offset as u32);
    push_be_u32(&mut out, 0);
    push_be_u64(
        &mut out,
        if params.code_limit > u32::MAX as usize {
            params.code_limit as u64
        } else {
            0
        },
    );
    push_be_u64(&mut out, params.executable_segment.base);
    push_be_u64(&mut out, params.executable_segment.limit);
    push_be_u64(&mut out, params.executable_segment.flags);

    out.extend_from_slice(params.identifier.as_bytes());
    out.push(0);
    out.extend_from_slice(params.team_id.as_bytes());
    out.push(0);

    if params.is_executable {
        let der = params.der_entitlements_blob.ok_or_else(|| {
            CodeSignError::macho("<memory>", "executable signatures require DER entitlements")
        })?;
        algorithm.push_digest(&mut out, der);
        push_zero_hash(&mut out, hash_len);
    }

    algorithm.push_digest(&mut out, params.entitlements_blob);
    push_zero_hash(&mut out, hash_len);

    if let Some(code_resources) = params.code_resources {
        algorithm.push_digest(&mut out, code_resources);
    } else {
        push_zero_hash(&mut out, hash_len);
    }

    algorithm.push_digest(&mut out, params.requirements_blob);

    if let Some(info_plist) = params.info_plist {
        algorithm.push_digest(&mut out, info_plist);
    } else {
        push_zero_hash(&mut out, hash_len);
    }

    for slot in code_hashes {
        out.extend_from_slice(slot.get(algorithm));
    }

    debug_assert_eq!(out.len(), length);

    Ok(out)
}

fn hash_code_pages(code: &[u8]) -> Vec<CodePageHashes> {
    let pages = code.len().div_ceil(CODEDIRECTORY_PAGE_SIZE);
    let mut hashes = vec![CodePageHashes::default(); pages];

    if pages < 8 {
        for (hash, page) in hashes.iter_mut().zip(code.chunks(CODEDIRECTORY_PAGE_SIZE)) {
            *hash = hash_code_page(page);
        }
        return hashes;
    }

    hashes
        .par_chunks_mut(CODEDIRECTORY_PARALLEL_HASH_PAGES)
        .enumerate()
        .for_each(|(chunk_index, out)| {
            let start_page = chunk_index * CODEDIRECTORY_PARALLEL_HASH_PAGES;
            let start = start_page * CODEDIRECTORY_PAGE_SIZE;
            let end = (start + out.len() * CODEDIRECTORY_PAGE_SIZE).min(code.len());

            for (hash, page) in out
                .iter_mut()
                .zip(code[start..end].chunks(CODEDIRECTORY_PAGE_SIZE))
            {
                *hash = hash_code_page(page);
            }
        });

    hashes
}

fn hash_code_page(page: &[u8]) -> CodePageHashes {
    CodePageHashes {
        sha1: sha1::Sha1::digest(page).into(),
        sha256: sha2::Sha256::digest(page).into(),
    }
}

fn should_parallelize_code_directory_encoding(
    params: &CodeDirectoryParams<'_>,
    code_page_count: usize,
) -> bool {
    code_page_count >= 8
        || params
            .code_resources
            .is_some_and(|data| data.len() >= 64 * 1024)
}

fn push_zero_hash(out: &mut Vec<u8>, hash_len: usize) {
    out.resize(out.len() + hash_len, 0);
}

fn signature_blob_wrapper(cms: &[u8], reserved_len: usize) -> Result<Vec<u8>> {
    let actual_len = 8 + cms.len();
    if actual_len > reserved_len {
        return Err(CodeSignError::SignatureTooLarge {
            actual: actual_len,
            reserved: reserved_len,
        });
    }

    let mut out = Vec::with_capacity(actual_len);
    push_be_u32(&mut out, CSMAGIC_BLOBWRAPPER);
    push_be_u32(&mut out, actual_len as u32);
    out.extend_from_slice(cms);
    Ok(out)
}

fn encode_superblob(mut blobs: Vec<(u32, Cow<'_, [u8]>)>) -> Vec<u8> {
    if let Some(primary_index) = blobs
        .iter()
        .position(|(slot, _)| *slot == CSSLOT_CODEDIRECTORY)
    {
        blobs.swap(0, primary_index);
    }

    let index_len = blobs.len() * 8;
    let data_len: usize = blobs.iter().map(|(_, data)| data.as_ref().len()).sum();
    let total_len = 12 + index_len + data_len;

    let mut out = Vec::with_capacity(total_len);
    push_be_u32(&mut out, CSMAGIC_EMBEDDED_SIGNATURE);
    push_be_u32(&mut out, total_len as u32);
    push_be_u32(&mut out, blobs.len() as u32);

    let mut offset = 12 + index_len;
    for (slot, data) in &blobs {
        push_be_u32(&mut out, *slot);
        push_be_u32(&mut out, offset as u32);
        offset += data.as_ref().len();
    }

    for (_, data) in blobs {
        out.extend_from_slice(data.as_ref());
    }

    out
}

pub fn der_entitlements(entitlements: &Dictionary) -> Result<Vec<u8>> {
    let dictionary = der_dictionary_body(entitlements, "$")?;
    let mut body = der_tlv(0x02, &[1]);
    body.extend_from_slice(&der_tlv(0xb0, &dictionary));
    Ok(der_tlv(0x70, &body))
}

fn der_value(value: &Value, path: &str) -> Result<Vec<u8>> {
    match value {
        Value::Boolean(value) => Ok(der_tlv(0x01, &[if *value { 0xff } else { 0x00 }])),
        Value::Integer(value) => {
            if let Some(unsigned) = value.as_unsigned() {
                Ok(der_unsigned_integer(unsigned))
            } else if let Some(signed) = value.as_signed() {
                if signed >= 0 {
                    Ok(der_unsigned_integer(signed as u64))
                } else {
                    Err(CodeSignError::UnsupportedEntitlement(path.to_string()))
                }
            } else {
                Err(CodeSignError::UnsupportedEntitlement(path.to_string()))
            }
        }
        Value::String(value) => Ok(der_tlv(0x0c, value.as_bytes())),
        Value::Array(values) => {
            let mut body = Vec::new();
            for (index, value) in values.iter().enumerate() {
                body.extend_from_slice(&der_value(value, &format!("{path}[{index}]"))?);
            }
            Ok(der_tlv(0x30, &body))
        }
        Value::Dictionary(value) => der_dictionary(value, path),
        _ => Err(CodeSignError::UnsupportedEntitlement(path.to_string())),
    }
}

fn der_dictionary(dict: &Dictionary, path: &str) -> Result<Vec<u8>> {
    Ok(der_tlv(0x31, &der_dictionary_body(dict, path)?))
}

fn der_dictionary_body(dict: &Dictionary, path: &str) -> Result<Vec<u8>> {
    let mut entries = Vec::with_capacity(dict.len());

    for (key, value) in dict {
        let mut entry_body = der_tlv(0x0c, key.as_bytes());
        entry_body.extend_from_slice(&der_value(value, &format!("{path}.{key}"))?);
        entries.push((key.as_str(), der_tlv(0x30, &entry_body)));
    }

    entries.sort_by(|(left, _), (right, _)| left.as_bytes().cmp(right.as_bytes()));

    let body_len = entries.iter().map(|(_, entry)| entry.len()).sum();
    let mut body = Vec::with_capacity(body_len);
    for (_, entry) in entries {
        body.extend_from_slice(&entry);
    }

    Ok(body)
}

fn der_unsigned_integer(value: u64) -> Vec<u8> {
    let bytes = value.to_be_bytes();
    let first_non_zero = bytes
        .iter()
        .position(|byte| *byte != 0)
        .unwrap_or(bytes.len() - 1);
    let significant = &bytes[first_non_zero..];

    let mut body = Vec::with_capacity(significant.len() + 1);
    if significant[0] & 0x80 != 0 {
        body.push(0);
    }
    body.extend_from_slice(significant);
    der_tlv(0x02, &body)
}

fn der_tlv(tag: u8, body: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(1 + 5 + body.len());
    out.push(tag);
    write_der_len(&mut out, body.len());
    out.extend_from_slice(body);
    out
}

fn write_der_len(out: &mut Vec<u8>, len: usize) {
    if len < 128 {
        out.push(len as u8);
        return;
    }

    let bytes = len.to_be_bytes();
    let first = bytes
        .iter()
        .position(|byte| *byte != 0)
        .unwrap_or(bytes.len() - 1);
    let significant = &bytes[first..];
    out.push(0x80 | significant.len() as u8);
    out.extend_from_slice(significant);
}

fn push_be_u32(out: &mut Vec<u8>, value: u32) {
    out.extend_from_slice(&value.to_be_bytes());
}

fn push_be_u64(out: &mut Vec<u8>, value: u64) {
    out.extend_from_slice(&value.to_be_bytes());
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn der_entitlements_use_apple_versioned_application_envelope() {
        assert_eq!(
            der_entitlements(&Dictionary::new()).unwrap(),
            [0x70, 0x05, 0x02, 0x01, 0x01, 0xb0, 0x00]
        );
    }

    #[test]
    fn der_entitlements_blob_reports_the_wrapped_length() {
        let blob = der_entitlements_blob(&Dictionary::new()).unwrap();

        assert_eq!(&blob[..4], &CSMAGIC_EMBEDDED_DER_ENTITLEMENTS.to_be_bytes());
        assert_eq!(
            u32::from_be_bytes(blob[4..8].try_into().unwrap()) as usize,
            blob.len()
        );
        assert_eq!(&blob[8..], &[0x70, 0x05, 0x02, 0x01, 0x01, 0xb0, 0x00]);
    }

    #[test]
    fn entitlement_dictionary_entries_are_sorted_by_key() {
        let mut entitlements = Dictionary::new();
        entitlements.insert("z".to_string(), Value::Boolean(true));
        entitlements.insert(
            "application-identifier".to_string(),
            Value::String("TEAM.com.example.App".to_string()),
        );
        let body = der_dictionary_body(&entitlements, "$").unwrap();
        let expected_first = der_tlv(
            0x30,
            &[
                der_tlv(0x0c, b"application-identifier"),
                der_tlv(0x0c, b"TEAM.com.example.App"),
            ]
            .concat(),
        );

        assert!(body.starts_with(&expected_first));
    }

    #[test]
    fn cms_reservation_is_not_encoded_inside_blob_wrapper() {
        let cms = [0x30, 0x00];
        let blob = signature_blob_wrapper(&cms, 32).unwrap();

        assert_eq!(blob.len(), 10);
        assert_eq!(u32::from_be_bytes(blob[4..8].try_into().unwrap()), 10);
        assert_eq!(&blob[8..10], &cms);
    }

    #[test]
    fn cms_reservation_is_not_counted_in_outer_superblob_length() {
        let cms = signature_blob_wrapper(&[0x30, 0x00], 32).unwrap();
        let superblob = encode_superblob(vec![
            (CSSLOT_CODEDIRECTORY, Cow::Owned(vec![0; 8])),
            (CSSLOT_SIGNATURESLOT, Cow::Owned(cms)),
        ]);

        assert_eq!(
            u32::from_be_bytes(superblob[4..8].try_into().unwrap()) as usize,
            superblob.len()
        );
        assert_eq!(superblob.len(), 46);
    }
}
