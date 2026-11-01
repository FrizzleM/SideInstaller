use crate::error::{CodeSignError, Result};
use crate::signature::{
    CmsSigner, CodeDirectoryParams, ExecutableSegment, SuperblobSizePlan, der_entitlements_blob,
    empty_requirements_blob, encode_embedded_signature, entitlement_exec_flags, entitlements_blob,
    entitlements_xml, planned_superblob_len_from_parts,
};
use byteorder::{BigEndian, ByteOrder, LittleEndian};
use plist::Dictionary;
use rayon::prelude::*;
use std::fs;
use std::path::{Path, PathBuf};

const MH_MAGIC: u32 = 0xfeed_face;
const MH_MAGIC_64: u32 = 0xfeed_facf;
const MH_EXECUTE: u32 = 0x2;

const FAT_MAGIC: u32 = 0xcafe_babe;
const FAT_MAGIC_64: u32 = 0xcafe_babf;

const LC_SEGMENT: u32 = 0x1;
const LC_SEGMENT_64: u32 = 0x19;
const LC_CODE_SIGNATURE: u32 = 0x1d;

const LINKEDIT_DATA_COMMAND_SIZE: usize = 16;
const FAT_HEADER_SIZE: usize = 8;
const FAT_ARCH_SIZE: usize = 20;
const PAGE_SIZE: usize = 16 * 1024;
const CODE_SIGNATURE_ALIGNMENT: usize = 16;
const SECTION_TYPE: u32 = 0xff;
const S_ZEROFILL: u32 = 0x1;
const S_THREAD_LOCAL_ZEROFILL: u32 = 0x11;

pub const DEFAULT_CMS_BLOB_RESERVATION: usize = 16 * 1024;

#[derive(Clone)]
pub struct MachOSigningConfig<'a> {
    pub identifier: &'a str,
    pub team_id: &'a str,
    pub entitlements: &'a Dictionary,
    pub info_plist: Option<&'a [u8]>,
    pub code_resources: Option<&'a [u8]>,
    pub cms_signer: Option<&'a dyn CmsSigner>,
    pub cms_blob_reservation: usize,
}

impl<'a> MachOSigningConfig<'a> {
    pub fn new(
        identifier: &'a str,
        team_id: &'a str,
        entitlements: &'a Dictionary,
        cms_signer: Option<&'a dyn CmsSigner>,
    ) -> Self {
        Self {
            identifier,
            team_id,
            entitlements,
            info_plist: None,
            code_resources: None,
            cms_signer,
            cms_blob_reservation: DEFAULT_CMS_BLOB_RESERVATION,
        }
    }
}

pub fn sign_macho_file(path: &Path, config: &MachOSigningConfig<'_>) -> Result<()> {
    let original = fs::read(path).map_err(|source| CodeSignError::io(path, source))?;
    let signed = sign_macho_owned(path, original, config)?;
    fs::write(path, signed).map_err(|source| CodeSignError::io(path, source))?;
    Ok(())
}

pub fn sign_macho_data(
    path: &Path,
    data: &[u8],
    config: &MachOSigningConfig<'_>,
) -> Result<Vec<u8>> {
    if let Some(fat_arches) = parse_fat_arches(path, data)? {
        sign_fat_macho(path, data, fat_arches, config)
    } else {
        Ok(sign_thin_macho(path, data.to_vec(), config)?.data)
    }
}

fn sign_macho_owned(
    path: &Path,
    data: Vec<u8>,
    config: &MachOSigningConfig<'_>,
) -> Result<Vec<u8>> {
    if let Some(fat_arches) = parse_fat_arches(path, &data)? {
        sign_fat_macho(path, &data, fat_arches, config)
    } else {
        Ok(sign_thin_macho(path, data, config)?.data)
    }
}

// copies
fn sign_fat_macho(
    path: &Path,
    data: &[u8],
    fat_arches: Vec<FatArch>,
    config: &MachOSigningConfig<'_>,
) -> Result<Vec<u8>> {
    let signed_arches = fat_arches
        .par_iter()
        .map(|arch| {
            let bytes = data[arch.offset..arch.offset + arch.size].to_vec();
            let signed = sign_thin_macho(path, bytes, config)?;
            Ok(SignedArch {
                cputype: signed.cputype,
                cpusubtype: signed.cpusubtype,
                align: arch.align,
                data: signed.data,
            })
        })
        .collect::<Result<Vec<_>>>()?;

    rebuild_fat(path, &signed_arches)
}

fn sign_thin_macho(
    path: &Path,
    data: Vec<u8>,
    config: &MachOSigningConfig<'_>,
) -> Result<SignedThin> {
    let mut macho = ThinMachO::parse(path, data)?;

    let requirements = empty_requirements_blob();
    let entitlements_xml = entitlements_xml(config.entitlements)?;
    let entitlements = entitlements_blob(&entitlements_xml);
    let der_entitlements = if macho.is_executable() {
        Some(der_entitlements_blob(config.entitlements)?)
    } else {
        None
    };

    let mut cms_blob_reservation = config.cms_blob_reservation;

    for _ in 0..8 {
        let code_limit = macho.code_signature_offset().unwrap_or(macho.data.len());
        let planned_len = planned_superblob_len_from_parts(SuperblobSizePlan {
            identifier: config.identifier,
            team_id: config.team_id,
            code_limit,
            is_executable: macho.is_executable(),
            requirements_blob_len: requirements.len(),
            entitlements_blob_len: entitlements.len(),
            der_entitlements_blob_len: der_entitlements.as_ref().map(Vec::len),
            has_cms_signature: config.cms_signer.is_some(),
            cms_blob_reservation,
        });

        macho.reserve_code_signature(planned_len)?;

        let code_limit = macho
            .code_signature_offset()
            .ok_or_else(|| CodeSignError::macho(path, "missing LC_CODE_SIGNATURE after reserve"))?;
        let exec_flags = entitlement_exec_flags(config.entitlements, macho.is_executable());
        let params = CodeDirectoryParams {
            identifier: config.identifier,
            team_id: config.team_id,
            macho_data: &macho.data,
            code_limit,
            executable_segment: ExecutableSegment {
                base: macho.exec_segment.base,
                limit: macho.exec_segment.limit,
                flags: exec_flags,
            },
            is_executable: macho.is_executable(),
            requirements_blob: &requirements,
            entitlements_blob: &entitlements,
            der_entitlements_blob: der_entitlements.as_deref(),
            info_plist: config.info_plist,
            code_resources: config.code_resources,
        };

        match encode_embedded_signature(&params, config.cms_signer, cms_blob_reservation) {
            Ok(signature) => {
                macho.write_code_signature(&signature)?;
                return Ok(SignedThin {
                    cputype: macho.cputype,
                    cpusubtype: macho.cpusubtype,
                    data: macho.data,
                });
            }
            Err(CodeSignError::SignatureTooLarge { actual, .. }) => {
                cms_blob_reservation = next_reservation(cms_blob_reservation, actual);
            }
            Err(err) => return Err(err),
        }
    }

    Err(CodeSignError::macho(
        path,
        "CMS signature did not fit after repeated reservation growth",
    ))
}

fn next_reservation(current: usize, actual: usize) -> usize {
    let doubled = current.saturating_mul(2).max(DEFAULT_CMS_BLOB_RESERVATION);
    align_to(doubled.max(actual), 4096)
}

#[derive(Debug)]
struct ThinMachO {
    path: PathBuf,
    data: Vec<u8>,
    cputype: i32,
    cpusubtype: i32,
    filetype: u32,
    ncmds: u32,
    sizeofcmds: u32,
    header_size: usize,
    code_signature_command_offset: Option<usize>,
    linkedit_command_offset: Option<usize>,
    header_pad_limit: usize,
    exec_segment: SegmentBounds,
}

#[derive(Clone, Copy, Debug, Default)]
struct SegmentBounds {
    base: u64,
    limit: u64,
}

impl ThinMachO {
    fn parse(path: &Path, data: Vec<u8>) -> Result<Self> {
        ensure_len(path, &data, 28, "Mach-O header")?;

        let magic = LittleEndian::read_u32(&data[0..4]);
        let is_64 = match magic {
            MH_MAGIC => false,
            MH_MAGIC_64 => true,
            _ => {
                return Err(CodeSignError::macho(
                    path,
                    format!("unsupported Mach-O magic 0x{magic:08x}"),
                ));
            }
        };

        let header_size = if is_64 { 32 } else { 28 };
        ensure_len(path, &data, header_size, "Mach-O header")?;

        let cputype = LittleEndian::read_i32(&data[4..8]);
        let cpusubtype = LittleEndian::read_i32(&data[8..12]);
        let filetype = LittleEndian::read_u32(&data[12..16]);
        let ncmds = LittleEndian::read_u32(&data[16..20]);
        let sizeofcmds = LittleEndian::read_u32(&data[20..24]);
        let commands_end = checked_add(path, header_size, sizeofcmds as usize, "load commands")?;
        ensure_len(path, &data, commands_end, "load commands")?;

        let mut offset = header_size;
        let mut code_signature_command_offset = None;
        let mut linkedit_command_offset = None;
        let mut first_section_offset = None;
        let mut exec_segment = SegmentBounds::default();

        for _ in 0..ncmds {
            ensure_len(path, &data, offset + 8, "load command")?;
            let cmd = LittleEndian::read_u32(&data[offset..offset + 4]);
            let cmdsize = LittleEndian::read_u32(&data[offset + 4..offset + 8]) as usize;
            if cmdsize < 8 {
                return Err(CodeSignError::macho(
                    path,
                    "load command is smaller than 8 bytes",
                ));
            }
            let command_end = checked_add(path, offset, cmdsize, "load command")?;
            if command_end > commands_end {
                return Err(CodeSignError::macho(
                    path,
                    "load command extends beyond sizeofcmds",
                ));
            }

            match cmd {
                LC_SEGMENT => {
                    parse_segment_32(
                        path,
                        &data,
                        offset,
                        cmdsize,
                        &mut linkedit_command_offset,
                        &mut exec_segment,
                        &mut first_section_offset,
                    )?;
                }
                LC_SEGMENT_64 => {
                    parse_segment_64(
                        path,
                        &data,
                        offset,
                        cmdsize,
                        &mut linkedit_command_offset,
                        &mut exec_segment,
                        &mut first_section_offset,
                    )?;
                }
                LC_CODE_SIGNATURE => {
                    if cmdsize < LINKEDIT_DATA_COMMAND_SIZE {
                        return Err(CodeSignError::macho(path, "LC_CODE_SIGNATURE is too small"));
                    }
                    code_signature_command_offset = Some(offset);
                }
                _ => {}
            }

            offset = command_end;
        }

        let header_pad_limit = first_section_offset
            .filter(|offset| *offset > commands_end)
            .unwrap_or(data.len())
            .min(data.len());

        Ok(Self {
            path: path.to_path_buf(),
            data,
            cputype,
            cpusubtype,
            filetype,
            ncmds,
            sizeofcmds,
            header_size,
            code_signature_command_offset,
            linkedit_command_offset,
            header_pad_limit,
            exec_segment,
        })
    }

    fn is_executable(&self) -> bool {
        self.filetype == MH_EXECUTE
    }

    fn code_signature_offset(&self) -> Option<usize> {
        self.code_signature_command_offset
            .map(|offset| LittleEndian::read_u32(&self.data[offset + 8..offset + 12]) as usize)
    }

    fn reserve_code_signature(&mut self, signature_len: usize) -> Result<()> {
        if self.code_signature_command_offset.is_none() {
            self.install_code_signature_command(signature_len)?;
        }

        let command_offset = self
            .code_signature_command_offset
            .ok_or_else(|| CodeSignError::macho(&self.path, "missing LC_CODE_SIGNATURE"))?;
        let dataoff =
            LittleEndian::read_u32(&self.data[command_offset + 8..command_offset + 12]) as usize;
        let datasize =
            LittleEndian::read_u32(&self.data[command_offset + 12..command_offset + 16]) as usize;

        if datasize == 0 {
            return self.allocate_code_signature(command_offset, signature_len);
        }

        if signature_len <= datasize {
            self.zero_signature_region(dataoff, datasize)?;
            return Ok(());
        }

        let old_end = checked_add(&self.path, dataoff, datasize, "code signature")?;
        if old_end < self.data.len() {
            return Err(CodeSignError::macho(
                &self.path,
                "cannot grow a code signature that is not at the end of the Mach-O slice",
            ));
        }

        let linkedit_offset = self.linkedit_command_offset.ok_or_else(|| {
            CodeSignError::macho(&self.path, "missing __LINKEDIT segment for code signature")
        })?;

        let extra_file_size = signature_len - datasize;
        self.grow_linkedit_segment(linkedit_offset, extra_file_size)?;

        self.data.truncate(dataoff);
        self.data.resize(dataoff + signature_len, 0);
        LittleEndian::write_u32(
            &mut self.data[command_offset + 8..command_offset + 12],
            dataoff.try_into().map_err(|_| {
                CodeSignError::macho(&self.path, "code signature offset exceeds u32")
            })?,
        );
        LittleEndian::write_u32(
            &mut self.data[command_offset + 12..command_offset + 16],
            signature_len
                .try_into()
                .map_err(|_| CodeSignError::macho(&self.path, "code signature size exceeds u32"))?,
        );

        Ok(())
    }

    fn install_code_signature_command(&mut self, signature_len: usize) -> Result<()> {
        let command_offset = self.header_size + self.sizeofcmds as usize;
        let command_end = command_offset + LINKEDIT_DATA_COMMAND_SIZE;

        if command_end > self.header_pad_limit {
            return Err(CodeSignError::NeedsCodeSignatureAllocation {
                path: self.path.clone(),
                signature_len,
            });
        }

        if command_end > self.data.len() {
            return Err(CodeSignError::macho(
                &self.path,
                "Mach-O ended before available load command padding",
            ));
        }

        if self.data[command_offset..command_end]
            .iter()
            .any(|byte| *byte != 0)
        {
            return Err(CodeSignError::NeedsCodeSignatureAllocation {
                path: self.path.clone(),
                signature_len,
            });
        }

        LittleEndian::write_u32(
            &mut self.data[command_offset..command_offset + 4],
            LC_CODE_SIGNATURE,
        );
        LittleEndian::write_u32(
            &mut self.data[command_offset + 4..command_offset + 8],
            LINKEDIT_DATA_COMMAND_SIZE as u32,
        );
        LittleEndian::write_u32(&mut self.data[command_offset + 8..command_offset + 12], 0);
        LittleEndian::write_u32(&mut self.data[command_offset + 12..command_offset + 16], 0);

        self.ncmds += 1;
        self.sizeofcmds += LINKEDIT_DATA_COMMAND_SIZE as u32;
        LittleEndian::write_u32(&mut self.data[16..20], self.ncmds);
        LittleEndian::write_u32(&mut self.data[20..24], self.sizeofcmds);
        self.code_signature_command_offset = Some(command_offset);

        Ok(())
    }

    fn allocate_code_signature(
        &mut self,
        command_offset: usize,
        signature_len: usize,
    ) -> Result<()> {
        let linkedit_offset = self.linkedit_command_offset.ok_or_else(|| {
            CodeSignError::macho(&self.path, "missing __LINKEDIT segment for code signature")
        })?;
        let linkedit_end = self.linkedit_file_end(linkedit_offset)?;
        if linkedit_end > self.data.len() {
            return Err(CodeSignError::macho(
                &self.path,
                "__LINKEDIT extends beyond the Mach-O slice",
            ));
        }

        let dataoff = align_to(linkedit_end, CODE_SIGNATURE_ALIGNMENT);
        let padding = dataoff - linkedit_end;
        self.resize_linkedit_for_new_signature(linkedit_offset, padding, signature_len)?;

        self.data.truncate(linkedit_end);
        self.data.resize(dataoff + signature_len, 0);

        LittleEndian::write_u32(
            &mut self.data[command_offset + 8..command_offset + 12],
            dataoff.try_into().map_err(|_| {
                CodeSignError::macho(&self.path, "code signature offset exceeds u32")
            })?,
        );
        LittleEndian::write_u32(
            &mut self.data[command_offset + 12..command_offset + 16],
            signature_len
                .try_into()
                .map_err(|_| CodeSignError::macho(&self.path, "code signature size exceeds u32"))?,
        );

        Ok(())
    }

    fn write_code_signature(&mut self, signature: &[u8]) -> Result<()> {
        let command_offset = self
            .code_signature_command_offset
            .ok_or_else(|| CodeSignError::macho(&self.path, "missing LC_CODE_SIGNATURE"))?;
        let dataoff =
            LittleEndian::read_u32(&self.data[command_offset + 8..command_offset + 12]) as usize;
        let datasize =
            LittleEndian::read_u32(&self.data[command_offset + 12..command_offset + 16]) as usize;

        if signature.len() > datasize {
            return Err(CodeSignError::macho(
                &self.path,
                "encoded signature exceeded reserved LC_CODE_SIGNATURE size",
            ));
        }

        let end = checked_add(&self.path, dataoff, datasize, "code signature")?;
        ensure_len(&self.path, &self.data, end, "code signature")?;
        self.data[dataoff..dataoff + signature.len()].copy_from_slice(signature);
        self.data[dataoff + signature.len()..end].fill(0);
        Ok(())
    }

    fn zero_signature_region(&mut self, dataoff: usize, datasize: usize) -> Result<()> {
        let end = checked_add(&self.path, dataoff, datasize, "code signature")?;
        ensure_len(&self.path, &self.data, end, "code signature")?;
        self.data[dataoff..end].fill(0);
        Ok(())
    }

    fn grow_linkedit_segment(
        &mut self,
        command_offset: usize,
        extra_file_size: usize,
    ) -> Result<()> {
        let cmd = LittleEndian::read_u32(&self.data[command_offset..command_offset + 4]);
        match cmd {
            LC_SEGMENT => {
                let filesize_offset = command_offset + 36;
                let vmsize_offset = command_offset + 28;
                let filesize =
                    LittleEndian::read_u32(&self.data[filesize_offset..filesize_offset + 4])
                        as usize;
                let vmsize =
                    LittleEndian::read_u32(&self.data[vmsize_offset..vmsize_offset + 4]) as usize;
                let new_filesize =
                    checked_add(&self.path, filesize, extra_file_size, "__LINKEDIT filesize")?;
                let new_vmsize = vmsize.max(page_ceil(new_filesize));

                LittleEndian::write_u32(
                    &mut self.data[filesize_offset..filesize_offset + 4],
                    new_filesize.try_into().map_err(|_| {
                        CodeSignError::macho(&self.path, "__LINKEDIT filesize exceeds u32")
                    })?,
                );
                LittleEndian::write_u32(
                    &mut self.data[vmsize_offset..vmsize_offset + 4],
                    new_vmsize.try_into().map_err(|_| {
                        CodeSignError::macho(&self.path, "__LINKEDIT vmsize exceeds u32")
                    })?,
                );
            }
            LC_SEGMENT_64 => {
                let filesize_offset = command_offset + 48;
                let vmsize_offset = command_offset + 32;
                let filesize =
                    LittleEndian::read_u64(&self.data[filesize_offset..filesize_offset + 8]);
                let vmsize = LittleEndian::read_u64(&self.data[vmsize_offset..vmsize_offset + 8]);
                let extra_file_size = u64::try_from(extra_file_size).map_err(|_| {
                    CodeSignError::macho(&self.path, "__LINKEDIT growth exceeds u64")
                })?;
                let new_filesize = filesize.checked_add(extra_file_size).ok_or_else(|| {
                    CodeSignError::macho(&self.path, "__LINKEDIT filesize overflow")
                })?;
                let new_vmsize = vmsize.max(page_ceil_u64(new_filesize));

                LittleEndian::write_u64(
                    &mut self.data[filesize_offset..filesize_offset + 8],
                    new_filesize,
                );
                LittleEndian::write_u64(
                    &mut self.data[vmsize_offset..vmsize_offset + 8],
                    new_vmsize,
                );
            }
            _ => {
                return Err(CodeSignError::macho(
                    &self.path,
                    "__LINKEDIT command was not a segment command",
                ));
            }
        }

        Ok(())
    }

    fn linkedit_file_end(&self, command_offset: usize) -> Result<usize> {
        let cmd = LittleEndian::read_u32(&self.data[command_offset..command_offset + 4]);
        match cmd {
            LC_SEGMENT => {
                let fileoff =
                    LittleEndian::read_u32(&self.data[command_offset + 32..command_offset + 36])
                        as usize;
                let filesize =
                    LittleEndian::read_u32(&self.data[command_offset + 36..command_offset + 40])
                        as usize;
                checked_add(&self.path, fileoff, filesize, "__LINKEDIT end")
            }
            LC_SEGMENT_64 => {
                let fileoff =
                    LittleEndian::read_u64(&self.data[command_offset + 40..command_offset + 48]);
                let filesize =
                    LittleEndian::read_u64(&self.data[command_offset + 48..command_offset + 56]);
                let end = fileoff
                    .checked_add(filesize)
                    .ok_or_else(|| CodeSignError::macho(&self.path, "__LINKEDIT end overflow"))?;
                usize::try_from(end)
                    .map_err(|_| CodeSignError::macho(&self.path, "__LINKEDIT end exceeds usize"))
            }
            _ => Err(CodeSignError::macho(
                &self.path,
                "__LINKEDIT command was not a segment command",
            )),
        }
    }

    fn resize_linkedit_for_new_signature(
        &mut self,
        command_offset: usize,
        padding: usize,
        signature_len: usize,
    ) -> Result<()> {
        let extra_file_size = checked_add(
            &self.path,
            padding,
            signature_len,
            "__LINKEDIT code signature growth",
        )?;
        self.grow_linkedit_segment(command_offset, extra_file_size)
    }
}

#[derive(Debug)]
struct SignedThin {
    cputype: i32,
    cpusubtype: i32,
    data: Vec<u8>,
}

#[derive(Clone, Debug)]
struct FatArch {
    offset: usize,
    size: usize,
    align: u32,
}

#[derive(Debug)]
struct SignedArch {
    cputype: i32,
    cpusubtype: i32,
    align: u32,
    data: Vec<u8>,
}

fn parse_fat_arches(path: &Path, data: &[u8]) -> Result<Option<Vec<FatArch>>> {
    if data.len() < 4 {
        return Err(CodeSignError::macho(path, "file is too small"));
    }

    let magic = BigEndian::read_u32(&data[0..4]);
    if magic == FAT_MAGIC_64 {
        return Err(CodeSignError::macho(
            path,
            "64-bit fat Mach-O headers are not supported yet",
        ));
    }
    if magic != FAT_MAGIC {
        return Ok(None);
    }

    ensure_len(path, data, FAT_HEADER_SIZE, "fat header")?;
    let nfat_arch = BigEndian::read_u32(&data[4..8]) as usize;
    let table_len = checked_mul(path, nfat_arch, FAT_ARCH_SIZE, "fat architecture table")?;
    ensure_len(
        path,
        data,
        FAT_HEADER_SIZE + table_len,
        "fat architecture table",
    )?;

    let mut arches = Vec::with_capacity(nfat_arch);
    for index in 0..nfat_arch {
        let offset = FAT_HEADER_SIZE + index * FAT_ARCH_SIZE;
        let arch_offset = BigEndian::read_u32(&data[offset + 8..offset + 12]) as usize;
        let size = BigEndian::read_u32(&data[offset + 12..offset + 16]) as usize;
        let align = BigEndian::read_u32(&data[offset + 16..offset + 20]);
        ensure_len(path, data, arch_offset + size, "fat architecture slice")?;
        arches.push(FatArch {
            offset: arch_offset,
            size,
            align,
        });
    }

    Ok(Some(arches))
}

fn rebuild_fat(path: &Path, arches: &[SignedArch]) -> Result<Vec<u8>> {
    let table_len = checked_mul(path, arches.len(), FAT_ARCH_SIZE, "fat architecture table")?;
    let mut records = Vec::with_capacity(arches.len());
    let mut cursor = FAT_HEADER_SIZE + table_len;

    for arch in arches {
        let alignment = arch_alignment(path, arch.align)?;
        cursor = align_to(cursor, alignment);
        records.push((cursor, arch));
        cursor = checked_add(path, cursor, arch.data.len(), "fat Mach-O data")?;
    }

    if cursor > u32::MAX as usize {
        return Err(CodeSignError::macho(
            path,
            "fat Mach-O exceeds 32-bit offsets",
        ));
    }

    let mut out = vec![0; FAT_HEADER_SIZE + table_len];
    BigEndian::write_u32(&mut out[0..4], FAT_MAGIC);
    BigEndian::write_u32(&mut out[4..8], arches.len() as u32);

    for (index, (offset, arch)) in records.iter().enumerate() {
        let record_offset = FAT_HEADER_SIZE + index * FAT_ARCH_SIZE;
        BigEndian::write_i32(&mut out[record_offset..record_offset + 4], arch.cputype);
        BigEndian::write_i32(
            &mut out[record_offset + 4..record_offset + 8],
            arch.cpusubtype,
        );
        BigEndian::write_u32(
            &mut out[record_offset + 8..record_offset + 12],
            *offset as u32,
        );
        BigEndian::write_u32(
            &mut out[record_offset + 12..record_offset + 16],
            arch.data.len() as u32,
        );
        BigEndian::write_u32(&mut out[record_offset + 16..record_offset + 20], arch.align);
    }

    for (offset, arch) in records {
        out.resize(offset, 0);
        out.extend_from_slice(&arch.data);
    }

    Ok(out)
}

fn parse_segment_32(
    path: &Path,
    data: &[u8],
    offset: usize,
    cmdsize: usize,
    linkedit_command_offset: &mut Option<usize>,
    exec_segment: &mut SegmentBounds,
    first_section_offset: &mut Option<usize>,
) -> Result<()> {
    if cmdsize < 56 {
        return Err(CodeSignError::macho(path, "LC_SEGMENT is too small"));
    }

    let name = segment_name(&data[offset + 8..offset + 24]);
    let fileoff = LittleEndian::read_u32(&data[offset + 32..offset + 36]) as u64;
    let filesize = LittleEndian::read_u32(&data[offset + 36..offset + 40]) as u64;
    let nsects = LittleEndian::read_u32(&data[offset + 48..offset + 52]) as usize;
    if name == "__TEXT" {
        exec_segment.base = fileoff;
        exec_segment.limit = fileoff + filesize;
    } else if name == "__LINKEDIT" {
        *linkedit_command_offset = Some(offset);
    }

    let sections_offset = offset + 56;
    let sections_size = checked_mul(path, nsects, 68, "LC_SEGMENT sections")?;
    if sections_offset + sections_size > offset + cmdsize {
        return Err(CodeSignError::macho(
            path,
            "LC_SEGMENT sections exceed cmdsize",
        ));
    }

    if nsects == 0 {
        if fileoff != 0 && filesize != 0 {
            record_first_section_offset(first_section_offset, fileoff as usize);
        }
    } else {
        for index in 0..nsects {
            let section_offset = sections_offset + index * 68;
            let size = LittleEndian::read_u32(&data[section_offset + 36..section_offset + 40]);
            let file_offset =
                LittleEndian::read_u32(&data[section_offset + 40..section_offset + 44]) as usize;
            let flags = LittleEndian::read_u32(&data[section_offset + 56..section_offset + 60]);
            if section_has_file_contents(size as u64, flags) {
                record_first_section_offset(first_section_offset, file_offset);
            }
        }
    }

    Ok(())
}

fn parse_segment_64(
    path: &Path,
    data: &[u8],
    offset: usize,
    cmdsize: usize,
    linkedit_command_offset: &mut Option<usize>,
    exec_segment: &mut SegmentBounds,
    first_section_offset: &mut Option<usize>,
) -> Result<()> {
    if cmdsize < 72 {
        return Err(CodeSignError::macho(path, "LC_SEGMENT_64 is too small"));
    }

    let name = segment_name(&data[offset + 8..offset + 24]);
    let fileoff = LittleEndian::read_u64(&data[offset + 40..offset + 48]);
    let filesize = LittleEndian::read_u64(&data[offset + 48..offset + 56]);
    let nsects = LittleEndian::read_u32(&data[offset + 64..offset + 68]) as usize;

    if name == "__TEXT" {
        exec_segment.base = fileoff;
        exec_segment.limit = fileoff + filesize;
    } else if name == "__LINKEDIT" {
        *linkedit_command_offset = Some(offset);
    }

    let sections_offset = offset + 72;
    let sections_size = checked_mul(path, nsects, 80, "LC_SEGMENT_64 sections")?;
    if sections_offset + sections_size > offset + cmdsize {
        return Err(CodeSignError::macho(
            path,
            "LC_SEGMENT_64 sections exceed cmdsize",
        ));
    }

    if nsects == 0 {
        if fileoff != 0 && filesize != 0 {
            record_first_section_offset(
                first_section_offset,
                usize::try_from(fileoff)
                    .map_err(|_| CodeSignError::macho(path, "segment file offset exceeds usize"))?,
            );
        }
    } else {
        for index in 0..nsects {
            let section_offset = sections_offset + index * 80;
            let size = LittleEndian::read_u64(&data[section_offset + 40..section_offset + 48]);
            let file_offset =
                LittleEndian::read_u32(&data[section_offset + 48..section_offset + 52]) as usize;
            let flags = LittleEndian::read_u32(&data[section_offset + 68..section_offset + 72]);
            if section_has_file_contents(size, flags) {
                record_first_section_offset(first_section_offset, file_offset);
            }
        }
    }

    Ok(())
}

fn section_has_file_contents(size: u64, flags: u32) -> bool {
    let section_type = flags & SECTION_TYPE;
    size != 0 && section_type != S_ZEROFILL && section_type != S_THREAD_LOCAL_ZEROFILL
}

fn record_first_section_offset(first_section_offset: &mut Option<usize>, file_offset: usize) {
    if file_offset == 0 {
        return;
    }

    match first_section_offset {
        Some(existing) if *existing <= file_offset => {}
        _ => *first_section_offset = Some(file_offset),
    }
}

fn segment_name(bytes: &[u8]) -> &str {
    let end = bytes
        .iter()
        .position(|byte| *byte == 0)
        .unwrap_or(bytes.len());
    std::str::from_utf8(&bytes[..end]).unwrap_or("")
}

fn ensure_len(path: &Path, data: &[u8], required: usize, what: &str) -> Result<()> {
    if data.len() < required {
        return Err(CodeSignError::macho(
            path,
            format!(
                "{what} requires {required} bytes, file only has {}",
                data.len()
            ),
        ));
    }
    Ok(())
}

fn checked_add(path: &Path, a: usize, b: usize, what: &str) -> Result<usize> {
    a.checked_add(b)
        .ok_or_else(|| CodeSignError::macho(path, format!("{what} offset overflow")))
}

fn checked_mul(path: &Path, a: usize, b: usize, what: &str) -> Result<usize> {
    a.checked_mul(b)
        .ok_or_else(|| CodeSignError::macho(path, format!("{what} size overflow")))
}

fn page_ceil(value: usize) -> usize {
    align_to(value, PAGE_SIZE)
}

fn page_ceil_u64(value: u64) -> u64 {
    let alignment = PAGE_SIZE as u64;
    value.saturating_add(alignment - 1) & !(alignment - 1)
}

fn align_to(value: usize, alignment: usize) -> usize {
    debug_assert!(alignment.is_power_of_two());
    (value + alignment - 1) & !(alignment - 1)
}

fn arch_alignment(path: &Path, align: u32) -> Result<usize> {
    1usize
        .checked_shl(align)
        .filter(|alignment| *alignment > 0)
        .ok_or_else(|| CodeSignError::macho(path, format!("invalid fat arch alignment {align}")))
}

// SideInstaller, 2026-11-01: `tests` and `minimal_macho_with_empty_signature`
// are visible to the crate, for a test in bundle.rs.
#[cfg(test)]
pub(crate) mod tests {
    use super::*;
    use crate::signature::{CSMAGIC_EMBEDDED_SIGNATURE, CmsSigningRequest};

    const CPU_TYPE_ARM64_TEST: i32 = 0x0100_000c;

    struct TestCmsSigner;

    impl CmsSigner for TestCmsSigner {
        fn sign(&self, _: CmsSigningRequest<'_>) -> Result<Vec<u8>> {
            Ok(vec![0x30, 0x00])
        }
    }

    #[test]
    fn signs_thin_macho_by_growing_existing_code_signature() {
        let macho = minimal_macho_with_empty_signature();
        let entitlements = Dictionary::new();
        let config = MachOSigningConfig::new("com.example.test", "TEAMID", &entitlements, None);

        let signed = sign_macho_data(Path::new("TestBinary"), &macho, &config).unwrap();

        let code_sig_cmd = 32 + 72 + 72;
        let dataoff = LittleEndian::read_u32(&signed[code_sig_cmd + 8..code_sig_cmd + 12]) as usize;
        let datasize =
            LittleEndian::read_u32(&signed[code_sig_cmd + 12..code_sig_cmd + 16]) as usize;

        assert!(datasize > 0);
        assert_eq!(signed.len(), dataoff + datasize);
        assert_eq!(
            BigEndian::read_u32(&signed[dataoff..dataoff + 4]),
            CSMAGIC_EMBEDDED_SIGNATURE
        );
    }

    #[test]
    fn signature_growth_keeps_linkedit_vmsize_large_enough() {
        let mut macho = minimal_macho_with_empty_signature();
        let linkedit_cmd = 32 + 72;
        let code_sig_cmd = linkedit_cmd + 72;
        let linkedit_fileoff = 512usize;
        let old_signature_size = 1usize;
        let dataoff = linkedit_fileoff + PAGE_SIZE - old_signature_size;

        macho.resize(dataoff + old_signature_size, 0);
        write_segment_64(
            &mut macho,
            linkedit_cmd,
            "__LINKEDIT",
            linkedit_fileoff as u64,
            PAGE_SIZE as u64,
        );
        LittleEndian::write_u32(
            &mut macho[code_sig_cmd + 8..code_sig_cmd + 12],
            dataoff as u32,
        );
        LittleEndian::write_u32(
            &mut macho[code_sig_cmd + 12..code_sig_cmd + 16],
            old_signature_size as u32,
        );

        let entitlements = Dictionary::new();
        let config = MachOSigningConfig::new("com.example.test", "TEAMID", &entitlements, None);
        let signed = sign_macho_data(Path::new("PageBoundaryBinary"), &macho, &config).unwrap();

        let filesize = LittleEndian::read_u64(&signed[linkedit_cmd + 48..linkedit_cmd + 56]);
        let vmsize = LittleEndian::read_u64(&signed[linkedit_cmd + 32..linkedit_cmd + 40]);

        assert!(filesize > PAGE_SIZE as u64);
        assert!(vmsize >= filesize);
        assert_eq!(vmsize, page_ceil_u64(filesize));
    }

    #[test]
    fn cms_reservation_is_zero_padding_after_superblob() {
        let macho = minimal_macho_with_empty_signature();
        let entitlements = Dictionary::new();
        let signer = TestCmsSigner;
        let mut config =
            MachOSigningConfig::new("com.example.test", "TEAMID", &entitlements, Some(&signer));
        config.cms_blob_reservation = 1024;

        let signed = sign_macho_data(Path::new("TestBinary"), &macho, &config).unwrap();
        let code_sig_cmd = 32 + 72 + 72;
        let dataoff = LittleEndian::read_u32(&signed[code_sig_cmd + 8..code_sig_cmd + 12]) as usize;
        let datasize =
            LittleEndian::read_u32(&signed[code_sig_cmd + 12..code_sig_cmd + 16]) as usize;
        let superblob_len = BigEndian::read_u32(&signed[dataoff + 4..dataoff + 8]) as usize;

        assert!(superblob_len < datasize);
        assert!(
            signed[dataoff + superblob_len..dataoff + datasize]
                .iter()
                .all(|byte| *byte == 0)
        );
    }

    #[test]
    fn allocates_code_signature_command_when_headerpad_exists() {
        let macho = minimal_macho_without_signature(128);
        let entitlements = Dictionary::new();
        let config = MachOSigningConfig::new("com.example.test", "TEAMID", &entitlements, None);

        let signed = sign_macho_data(Path::new("HeaderPaddedBinary"), &macho, &config).unwrap();

        let code_sig_cmd = 32 + 152 + 72;
        assert_eq!(
            LittleEndian::read_u32(&signed[code_sig_cmd..code_sig_cmd + 4]),
            LC_CODE_SIGNATURE
        );

        let dataoff = LittleEndian::read_u32(&signed[code_sig_cmd + 8..code_sig_cmd + 12]) as usize;
        let datasize =
            LittleEndian::read_u32(&signed[code_sig_cmd + 12..code_sig_cmd + 16]) as usize;
        let linkedit_cmd = 32 + 152;
        let linkedit_filesize =
            LittleEndian::read_u64(&signed[linkedit_cmd + 48..linkedit_cmd + 56]);

        assert_eq!(dataoff % CODE_SIGNATURE_ALIGNMENT, 0);
        assert!(datasize > 0);
        assert_eq!(signed.len(), dataoff + datasize);
        assert_eq!(linkedit_filesize as usize, signed.len() - 512);
        assert_eq!(
            BigEndian::read_u32(&signed[dataoff..dataoff + 4]),
            CSMAGIC_EMBEDDED_SIGNATURE
        );
    }

    #[test]
    fn refuses_to_add_code_signature_command_without_headerpad() {
        let macho = minimal_macho_without_signature(0);
        let entitlements = Dictionary::new();
        let config = MachOSigningConfig::new("com.example.test", "TEAMID", &entitlements, None);

        let err = sign_macho_data(Path::new("TightBinary"), &macho, &config).unwrap_err();

        assert!(matches!(
            err,
            CodeSignError::NeedsCodeSignatureAllocation { .. }
        ));
    }

    pub(crate) fn minimal_macho_with_empty_signature() -> Vec<u8> {
        let sizeofcmds = 72 + 72 + 16;
        let dataoff = 512usize;
        let mut data = vec![0; dataoff];

        LittleEndian::write_u32(&mut data[0..4], MH_MAGIC_64);
        LittleEndian::write_i32(&mut data[4..8], CPU_TYPE_ARM64_TEST);
        LittleEndian::write_i32(&mut data[8..12], 0);
        LittleEndian::write_u32(&mut data[12..16], MH_EXECUTE);
        LittleEndian::write_u32(&mut data[16..20], 3);
        LittleEndian::write_u32(&mut data[20..24], sizeofcmds as u32);

        write_segment_64(&mut data, 32, "__TEXT", 0, dataoff as u64);
        write_segment_64(&mut data, 32 + 72, "__LINKEDIT", dataoff as u64, 0);

        let code_sig_cmd = 32 + 72 + 72;
        LittleEndian::write_u32(&mut data[code_sig_cmd..code_sig_cmd + 4], LC_CODE_SIGNATURE);
        LittleEndian::write_u32(
            &mut data[code_sig_cmd + 4..code_sig_cmd + 8],
            LINKEDIT_DATA_COMMAND_SIZE as u32,
        );
        LittleEndian::write_u32(
            &mut data[code_sig_cmd + 8..code_sig_cmd + 12],
            dataoff as u32,
        );
        LittleEndian::write_u32(&mut data[code_sig_cmd + 12..code_sig_cmd + 16], 0);

        data
    }

    fn minimal_macho_without_signature(headerpad: usize) -> Vec<u8> {
        let sizeofcmds = 152 + 72;
        let content_offset = 32 + sizeofcmds + headerpad;
        let linkedit_offset = 512usize;
        let mut data = vec![0; linkedit_offset + 33];

        LittleEndian::write_u32(&mut data[0..4], MH_MAGIC_64);
        LittleEndian::write_i32(&mut data[4..8], CPU_TYPE_ARM64_TEST);
        LittleEndian::write_i32(&mut data[8..12], 0);
        LittleEndian::write_u32(&mut data[12..16], MH_EXECUTE);
        LittleEndian::write_u32(&mut data[16..20], 2);
        LittleEndian::write_u32(&mut data[20..24], sizeofcmds as u32);

        write_segment_64_with_section(
            &mut data,
            32,
            "__TEXT",
            0,
            linkedit_offset as u64,
            content_offset as u32,
            1,
        );
        write_segment_64(
            &mut data,
            32 + 152,
            "__LINKEDIT",
            linkedit_offset as u64,
            33,
        );

        data[content_offset] = 0xaa;
        data[linkedit_offset] = 0xbb;
        data
    }

    fn write_segment_64(data: &mut [u8], offset: usize, name: &str, fileoff: u64, filesize: u64) {
        LittleEndian::write_u32(&mut data[offset..offset + 4], LC_SEGMENT_64);
        LittleEndian::write_u32(&mut data[offset + 4..offset + 8], 72);
        data[offset + 8..offset + 8 + name.len()].copy_from_slice(name.as_bytes());
        LittleEndian::write_u64(&mut data[offset + 24..offset + 32], 0);
        LittleEndian::write_u64(
            &mut data[offset + 32..offset + 40],
            page_ceil(filesize as usize) as u64,
        );
        LittleEndian::write_u64(&mut data[offset + 40..offset + 48], fileoff);
        LittleEndian::write_u64(&mut data[offset + 48..offset + 56], filesize);
        LittleEndian::write_u32(&mut data[offset + 64..offset + 68], 0);
    }

    fn write_segment_64_with_section(
        data: &mut [u8],
        offset: usize,
        name: &str,
        fileoff: u64,
        filesize: u64,
        section_offset: u32,
        section_size: u64,
    ) {
        LittleEndian::write_u32(&mut data[offset..offset + 4], LC_SEGMENT_64);
        LittleEndian::write_u32(&mut data[offset + 4..offset + 8], 152);
        data[offset + 8..offset + 8 + name.len()].copy_from_slice(name.as_bytes());
        LittleEndian::write_u64(&mut data[offset + 24..offset + 32], 0);
        LittleEndian::write_u64(
            &mut data[offset + 32..offset + 40],
            page_ceil(filesize as usize) as u64,
        );
        LittleEndian::write_u64(&mut data[offset + 40..offset + 48], fileoff);
        LittleEndian::write_u64(&mut data[offset + 48..offset + 56], filesize);
        LittleEndian::write_u32(&mut data[offset + 64..offset + 68], 1);

        let section = offset + 72;
        LittleEndian::write_u64(&mut data[section + 32..section + 40], 0);
        LittleEndian::write_u64(&mut data[section + 40..section + 48], section_size);
        LittleEndian::write_u32(&mut data[section + 48..section + 52], section_offset);
        LittleEndian::write_u32(&mut data[section + 68..section + 72], 0);
    }
}
