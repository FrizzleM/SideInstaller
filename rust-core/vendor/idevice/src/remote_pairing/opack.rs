// Jackson Coxson

use plist::Value;

pub fn opack_to_plist(bytes: &[u8]) -> Result<Value, String> {
    let mut offset = 0;
    let mut objects = Vec::new();
    let value = opack_to_plist_inner(bytes, &mut offset, &mut objects)?;
    if offset != bytes.len() {
        return Err(format!(
            "unexpected trailing bytes after OPACK payload: {}",
            bytes.len() - offset
        ));
    }
    Ok(value)
}

pub fn plist_to_opack(value: &Value) -> Vec<u8> {
    let mut buf = Vec::new();
    plist_to_opack_inner(value, &mut buf);

    buf
}

fn plist_to_opack_inner(node: &Value, buf: &mut Vec<u8>) {
    match node {
        Value::Dictionary(dict) => {
            let count = dict.len() as u32;
            let blen = if count < 15 {
                (count as u8).wrapping_sub(32)
            } else {
                0xEF
            };
            buf.push(blen);

            for (key, val) in dict {
                plist_to_opack_inner(&Value::String(key.clone()), buf);
                plist_to_opack_inner(val, buf);
            }

            if count > 14 {
                buf.push(0x03);
            }
        }
        Value::Array(array) => {
            let count = array.len() as u32;
            let blen = if count < 15 {
                (count as u8).wrapping_sub(48)
            } else {
                0xDF
            };
            buf.push(blen);

            for val in array {
                plist_to_opack_inner(val, buf);
            }

            if count > 14 {
                buf.push(0x03); // Terminator
            }
        }
        Value::Boolean(b) => {
            let bval = if *b { 1u8 } else { 2u8 };
            buf.push(bval);
        }
        Value::Integer(integer) => {
            let u64val = integer.as_unsigned().unwrap_or(0);

            if u64val <= u8::MAX as u64 {
                let u8val = u64val as u8;
                if u8val > 0x27 {
                    buf.push(0x30);
                    buf.push(u8val);
                } else {
                    buf.push(u8val + 8);
                }
            } else if u64val <= u32::MAX as u64 {
                buf.push(0x32);
                buf.extend_from_slice(&(u64val as u32).to_le_bytes());
            } else {
                buf.push(0x33);
                buf.extend_from_slice(&u64val.to_le_bytes());
            }
        }
        Value::Real(real) => {
            let dval = *real;
            let fval = dval as f32;

            if fval as f64 == dval {
                buf.push(0x35);
                buf.extend_from_slice(&fval.to_bits().swap_bytes().to_ne_bytes());
            } else {
                buf.push(0x36);
                buf.extend_from_slice(&dval.to_bits().swap_bytes().to_ne_bytes());
            }
        }
        Value::String(s) => {
            let bytes = s.as_bytes();
            let len = bytes.len();

            if len > 0x20 {
                if len <= 0xFF {
                    buf.push(0x61);
                    buf.push(len as u8);
                } else if len <= 0xFFFF {
                    buf.push(0x62);
                    buf.extend_from_slice(&(len as u16).to_le_bytes());
                } else if len <= 0xFFFFFFFF {
                    buf.push(0x63);
                    buf.extend_from_slice(&(len as u32).to_le_bytes());
                } else {
                    buf.push(0x64);
                    buf.extend_from_slice(&(len as u64).to_le_bytes());
                }
            } else {
                buf.push(0x40 + len as u8);
            }
            buf.extend_from_slice(bytes);
        }
        Value::Data(data) => {
            let len = data.len();
            if len > 0x20 {
                if len <= 0xFF {
                    buf.push(0x91);
                    buf.push(len as u8);
                } else if len <= 0xFFFF {
                    buf.push(0x92);
                    buf.extend_from_slice(&(len as u16).to_le_bytes());
                } else if len <= 0xFFFFFFFF {
                    buf.push(0x93);
                    buf.extend_from_slice(&(len as u32).to_le_bytes());
                } else {
                    buf.push(0x94);
                    buf.extend_from_slice(&(len as u64).to_le_bytes());
                }
            } else {
                buf.push(0x70 + len as u8);
            }
            buf.extend_from_slice(data);
        }
        _ => {}
    }
}

/// `objects` is the back-reference table: every scalar the encoder is allowed to
/// point at later, in the order it first appeared. See [`remember`].
fn opack_to_plist_inner(
    bytes: &[u8],
    offset: &mut usize,
    objects: &mut Vec<Value>,
) -> Result<Value, String> {
    let tag = read_u8(bytes, offset)?;
    match tag {
        0x01 => Ok(Value::Boolean(true)),
        0x02 => Ok(Value::Boolean(false)),
        0x08..=0x2F => Ok(Value::Integer((tag as u64 - 8).into())),
        0x30 => remember(
            objects,
            Value::Integer((read_u8(bytes, offset)? as u64).into()),
        ),
        0x31 => remember(
            objects,
            Value::Integer((u16::from_le_bytes(read_exact::<2>(bytes, offset)?) as u64).into()),
        ),
        0x32 => remember(
            objects,
            Value::Integer((u32::from_le_bytes(read_exact::<4>(bytes, offset)?) as u64).into()),
        ),
        0x33 => remember(
            objects,
            Value::Integer(u64::from_le_bytes(read_exact::<8>(bytes, offset)?).into()),
        ),
        0x35 => {
            let n = u32::from_ne_bytes(read_exact::<4>(bytes, offset)?).swap_bytes();
            remember(objects, Value::Real(f32::from_bits(n) as f64))
        }
        0x36 => {
            let n = u64::from_ne_bytes(read_exact::<8>(bytes, offset)?).swap_bytes();
            remember(objects, Value::Real(f64::from_bits(n)))
        }
        0x40..=0x64 => {
            let value = parse_string_value(tag, bytes, offset)?;
            remember(objects, value)
        }
        0x70..=0x94 => {
            let value = parse_data_value(tag, bytes, offset)?;
            remember(objects, value)
        }
        // Back-reference to an already-seen scalar, index encoded in the tag.
        0xA0..=0xC0 => lookup(objects, (tag - 0xA0) as usize),
        // Back-reference with an out-of-line index: 1, 2, 4 or 8 little-endian
        // bytes, same size ladder the integer tags use.
        0xC1..=0xC4 => {
            let index = match tag {
                0xC1 => read_u8(bytes, offset)? as u64,
                0xC2 => u16::from_le_bytes(read_exact::<2>(bytes, offset)?) as u64,
                0xC3 => u32::from_le_bytes(read_exact::<4>(bytes, offset)?) as u64,
                _ => u64::from_le_bytes(read_exact::<8>(bytes, offset)?),
            };
            let index = usize::try_from(index)
                .map_err(|_| format!("OPACK back-reference too large for this platform: {index}"))?;
            lookup(objects, index)
        }
        0xD0..=0xDE => parse_array(bytes, offset, objects, Some((tag - 0xD0) as usize)),
        0xDF => parse_array(bytes, offset, objects, None),
        0xE0..=0xEE => parse_dictionary(bytes, offset, objects, Some((tag - 0xE0) as usize)),
        0xEF => parse_dictionary(bytes, offset, objects, None),
        0x03 => Err("unexpected OPACK terminator".into()),
        _ => Err(format!("unsupported OPACK tag: 0x{tag:02x}")),
    }
}

/// Interns `value` in the back-reference table and hands it back unchanged.
///
/// The encoder emits a pointer instead of a literal whenever a scalar repeats,
/// so the decoder has to track the same table to resolve those pointers. Only
/// scalars are interned — collections never are — and a repeat is not appended
/// twice, otherwise every later index would be off by one. A real device sends
/// this for a pair record whose `name` matches its `model`, for instance.
fn remember(objects: &mut Vec<Value>, value: Value) -> Result<Value, String> {
    if !objects.contains(&value) {
        objects.push(value.clone());
    }
    Ok(value)
}

fn lookup(objects: &[Value], index: usize) -> Result<Value, String> {
    objects.get(index).cloned().ok_or_else(|| {
        format!(
            "OPACK back-reference {index} out of range, only {} objects seen",
            objects.len()
        )
    })
}

fn parse_string_value(bytes_tag: u8, bytes: &[u8], offset: &mut usize) -> Result<Value, String> {
    let len = read_sized_len(
        bytes_tag,
        bytes,
        offset,
        SizedLenTags {
            inline_base: 0x40,
            u8_tag: 0x61,
            u16_tag: 0x62,
            u32_tag: 0x63,
            u64_tag: 0x64,
            kind: "string",
        },
    )?;
    Ok(Value::String(read_string(bytes, offset, len)?))
}

fn parse_data_value(bytes_tag: u8, bytes: &[u8], offset: &mut usize) -> Result<Value, String> {
    let len = read_sized_len(
        bytes_tag,
        bytes,
        offset,
        SizedLenTags {
            inline_base: 0x70,
            u8_tag: 0x91,
            u16_tag: 0x92,
            u32_tag: 0x93,
            u64_tag: 0x94,
            kind: "data",
        },
    )?;
    Ok(Value::Data(read_vec(bytes, offset, len)?))
}

#[derive(Copy, Clone)]
struct SizedLenTags {
    inline_base: u8,
    u8_tag: u8,
    u16_tag: u8,
    u32_tag: u8,
    u64_tag: u8,
    kind: &'static str,
}

fn read_sized_len(
    tag: u8,
    bytes: &[u8],
    offset: &mut usize,
    tags: SizedLenTags,
) -> Result<usize, String> {
    match tag {
        t if (tags.inline_base..tags.u8_tag).contains(&t) => Ok((tag - tags.inline_base) as usize),
        t if t == tags.u8_tag => Ok(read_u8(bytes, offset)? as usize),
        t if t == tags.u16_tag => Ok(u16::from_le_bytes(read_exact::<2>(bytes, offset)?) as usize),
        t if t == tags.u32_tag => Ok(u32::from_le_bytes(read_exact::<4>(bytes, offset)?) as usize),
        t if t == tags.u64_tag => {
            let len_u64 = u64::from_le_bytes(read_exact::<8>(bytes, offset)?);
            usize::try_from(len_u64)
                .map_err(|_| format!("{} too large for this platform: {len_u64}", tags.kind))
        }
        _ => Err(format!("unsupported OPACK {} tag: 0x{tag:02x}", tags.kind)),
    }
}

fn parse_array(
    bytes: &[u8],
    offset: &mut usize,
    objects: &mut Vec<Value>,
    count: Option<usize>,
) -> Result<Value, String> {
    let mut items = Vec::with_capacity(count.unwrap_or(0));

    match count {
        Some(count) => {
            for _ in 0..count {
                items.push(opack_to_plist_inner(bytes, offset, objects)?);
            }
        }
        None => {
            while !peek_is_terminator(bytes, *offset) {
                items.push(opack_to_plist_inner(bytes, offset, objects)?);
            }
            *offset += 1;
        }
    }

    Ok(Value::Array(items))
}

fn parse_dictionary(
    bytes: &[u8],
    offset: &mut usize,
    objects: &mut Vec<Value>,
    count: Option<usize>,
) -> Result<Value, String> {
    let mut dict = plist::Dictionary::new();

    match count {
        Some(count) => {
            for _ in 0..count {
                let key = read_dictionary_key(bytes, offset, objects)?;
                let value = opack_to_plist_inner(bytes, offset, objects)?;
                dict.insert(key, value);
            }
        }
        None => {
            while !peek_is_terminator(bytes, *offset) {
                let key = read_dictionary_key(bytes, offset, objects)?;
                let value = opack_to_plist_inner(bytes, offset, objects)?;
                dict.insert(key, value);
            }
            *offset += 1;
        }
    }

    Ok(Value::Dictionary(dict))
}

fn read_dictionary_key(
    bytes: &[u8],
    offset: &mut usize,
    objects: &mut Vec<Value>,
) -> Result<String, String> {
    opack_to_plist_inner(bytes, offset, objects)?
        .into_string()
        .ok_or_else(|| "dictionary key is not a string".to_string())
}

fn peek_is_terminator(bytes: &[u8], offset: usize) -> bool {
    bytes.get(offset).copied() == Some(0x03)
}

fn read_u8(bytes: &[u8], offset: &mut usize) -> Result<u8, String> {
    let b = bytes
        .get(*offset)
        .copied()
        .ok_or_else(|| "unexpected EOF while reading OPACK tag".to_string())?;
    *offset += 1;
    Ok(b)
}

fn read_exact<const N: usize>(bytes: &[u8], offset: &mut usize) -> Result<[u8; N], String> {
    let end = offset.saturating_add(N);
    let slice = bytes
        .get(*offset..end)
        .ok_or_else(|| format!("unexpected EOF while reading {N} bytes"))?;
    let mut out = [0u8; N];
    out.copy_from_slice(slice);
    *offset = end;
    Ok(out)
}

fn read_vec(bytes: &[u8], offset: &mut usize, len: usize) -> Result<Vec<u8>, String> {
    let end = offset.saturating_add(len);
    let slice = bytes
        .get(*offset..end)
        .ok_or_else(|| format!("unexpected EOF while reading {len} bytes"))?;
    *offset = end;
    Ok(slice.to_vec())
}

fn read_string(bytes: &[u8], offset: &mut usize, len: usize) -> Result<String, String> {
    let data = read_vec(bytes, offset, len)?;
    String::from_utf8(data).map_err(|e| format!("invalid UTF-8 string in OPACK payload: {e}"))
}

#[cfg(test)]
mod tests {
    #[test]
    fn t1() {
        let v = crate::plist!({
            "altIRK": b"\xe9\xe8-\xc0jIykVoT\x00\x19\xb1\xc7{".to_vec(),
            "btAddr": "11:22:33:44:55:66",
            "mac": b"\x11\x22\x33\x44\x55\x66".to_vec(),
            "remotepairing_serial_number": "AAAAAAAAAAAA",
            "accountID": "lolsssss",
            "model": "computer-model",
            "name": "reeeee",
        });

        let res = super::plist_to_opack(&v);

        let expected = [
            0xe7, 0x46, 0x61, 0x6c, 0x74, 0x49, 0x52, 0x4b, 0x80, 0xe9, 0xe8, 0x2d, 0xc0, 0x6a,
            0x49, 0x79, 0x6b, 0x56, 0x6f, 0x54, 0x00, 0x19, 0xb1, 0xc7, 0x7b, 0x46, 0x62, 0x74,
            0x41, 0x64, 0x64, 0x72, 0x51, 0x31, 0x31, 0x3a, 0x32, 0x32, 0x3a, 0x33, 0x33, 0x3a,
            0x34, 0x34, 0x3a, 0x35, 0x35, 0x3a, 0x36, 0x36, 0x43, 0x6d, 0x61, 0x63, 0x76, 0x11,
            0x22, 0x33, 0x44, 0x55, 0x66, 0x5b, 0x72, 0x65, 0x6d, 0x6f, 0x74, 0x65, 0x70, 0x61,
            0x69, 0x72, 0x69, 0x6e, 0x67, 0x5f, 0x73, 0x65, 0x72, 0x69, 0x61, 0x6c, 0x5f, 0x6e,
            0x75, 0x6d, 0x62, 0x65, 0x72, 0x4c, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
            0x41, 0x41, 0x41, 0x41, 0x49, 0x61, 0x63, 0x63, 0x6f, 0x75, 0x6e, 0x74, 0x49, 0x44,
            0x48, 0x6c, 0x6f, 0x6c, 0x73, 0x73, 0x73, 0x73, 0x73, 0x45, 0x6d, 0x6f, 0x64, 0x65,
            0x6c, 0x4e, 0x63, 0x6f, 0x6d, 0x70, 0x75, 0x74, 0x65, 0x72, 0x2d, 0x6d, 0x6f, 0x64,
            0x65, 0x6c, 0x44, 0x6e, 0x61, 0x6d, 0x65, 0x46, 0x72, 0x65, 0x65, 0x65, 0x65, 0x65,
        ];

        println!("{res:02X?}");
        assert_eq!(res, expected);
    }

    #[test]
    fn t2() {
        let v = [
            0xe7, 0x46, 0x61, 0x6c, 0x74, 0x49, 0x52, 0x4b, 0x80, 0xe9, 0xe8, 0x2d, 0xc0, 0x6a,
            0x49, 0x79, 0x6b, 0x56, 0x6f, 0x54, 0x00, 0x19, 0xb1, 0xc7, 0x7b, 0x46, 0x62, 0x74,
            0x41, 0x64, 0x64, 0x72, 0x51, 0x31, 0x31, 0x3a, 0x32, 0x32, 0x3a, 0x33, 0x33, 0x3a,
            0x34, 0x34, 0x3a, 0x35, 0x35, 0x3a, 0x36, 0x36, 0x43, 0x6d, 0x61, 0x63, 0x76, 0x11,
            0x22, 0x33, 0x44, 0x55, 0x66, 0x5b, 0x72, 0x65, 0x6d, 0x6f, 0x74, 0x65, 0x70, 0x61,
            0x69, 0x72, 0x69, 0x6e, 0x67, 0x5f, 0x73, 0x65, 0x72, 0x69, 0x61, 0x6c, 0x5f, 0x6e,
            0x75, 0x6d, 0x62, 0x65, 0x72, 0x4c, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
            0x41, 0x41, 0x41, 0x41, 0x49, 0x61, 0x63, 0x63, 0x6f, 0x75, 0x6e, 0x74, 0x49, 0x44,
            0x48, 0x6c, 0x6f, 0x6c, 0x73, 0x73, 0x73, 0x73, 0x73, 0x45, 0x6d, 0x6f, 0x64, 0x65,
            0x6c, 0x4e, 0x63, 0x6f, 0x6d, 0x70, 0x75, 0x74, 0x65, 0x72, 0x2d, 0x6d, 0x6f, 0x64,
            0x65, 0x6c, 0x44, 0x6e, 0x61, 0x6d, 0x65, 0x46, 0x72, 0x65, 0x65, 0x65, 0x65, 0x65,
        ];

        let expected = crate::plist!({
            "altIRK": b"\xe9\xe8-\xc0jIykVoT\x00\x19\xb1\xc7{".to_vec(),
            "btAddr": "11:22:33:44:55:66",
            "mac": b"\x11\x22\x33\x44\x55\x66".to_vec(),
            "remotepairing_serial_number": "AAAAAAAAAAAA",
            "accountID": "lolsssss",
            "model": "computer-model",
            "name": "reeeee",
        });

        let res = super::opack_to_plist(&v).unwrap();

        println!("{res:02X?}");
        assert_eq!(res, expected);
    }

    /// Back-references resolve against the scalars seen so far, keys included,
    /// and collections never take up a slot.
    #[test]
    fn back_references_resolve_against_earlier_scalars() {
        // {"a": "b", "c": {"d": "a"}, "d": true} — 0xA0 points at "a", 0xA3 at "d".
        let v = [
            0xe3, 0x41, 0x61, 0x41, 0x62, 0x41, 0x63, 0xe1, 0x41, 0x64, 0xa0, 0xa3, 0x01,
        ];

        let expected = crate::plist!({
            "a": "b",
            "c": {
                "d": "a"
            },
            "d": true,
        });

        assert_eq!(super::opack_to_plist(&v).unwrap(), expected);
    }

    /// A repeated scalar is interned once, so the indices after it don't shift.
    #[test]
    fn repeated_scalars_do_not_take_a_second_slot() {
        // ["x", "x", "y", <ref 1>] — "x" is only interned once, so slot 1 is "y".
        let v = [0xd4, 0x41, 0x78, 0x41, 0x78, 0x41, 0x79, 0xa1];

        let expected = crate::plist!(["x", "x", "y", "y"]);

        assert_eq!(super::opack_to_plist(&v).unwrap(), expected);
    }

    #[test]
    fn out_of_range_back_reference_is_an_error() {
        // ["a", <ref 4>] — nothing has been interned at index 4.
        let err = super::opack_to_plist(&[0xd2, 0x41, 0x61, 0xa4]).unwrap_err();

        assert!(err.contains("out of range"), "unexpected error: {err}");
    }

    /// Regression: a real iPad's pair record reports `name` as a back-reference
    /// to `model`, which used to fail with "unsupported OPACK tag: 0xab".
    #[test]
    fn parses_pair_record_info_with_back_referenced_name() {
        let v = [
            0xe9, 0x46, 0x61, 0x6c, 0x74, 0x49, 0x52, 0x4b, 0x80, 0xeb, 0x52, 0x31, 0xc5, 0x45,
            0x75, 0xca, 0x46, 0x9f, 0xd2, 0x3c, 0xa5, 0x9e, 0x2f, 0x08, 0x0e, 0x52, 0x72, 0x65,
            0x6d, 0x6f, 0x74, 0x65, 0x70, 0x61, 0x69, 0x72, 0x69, 0x6e, 0x67, 0x5f, 0x65, 0x63,
            0x69, 0x64, 0x33, 0x1c, 0x00, 0x85, 0x3e, 0x36, 0x11, 0x12, 0x00, 0x46, 0x62, 0x74,
            0x41, 0x64, 0x64, 0x72, 0x51, 0x33, 0x34, 0x3a, 0x32, 0x62, 0x3a, 0x36, 0x65, 0x3a,
            0x32, 0x32, 0x3a, 0x36, 0x36, 0x3a, 0x38, 0x61, 0x5b, 0x72, 0x65, 0x6d, 0x6f, 0x74,
            0x65, 0x70, 0x61, 0x69, 0x72, 0x69, 0x6e, 0x67, 0x5f, 0x73, 0x65, 0x72, 0x69, 0x61,
            0x6c, 0x5f, 0x6e, 0x75, 0x6d, 0x62, 0x65, 0x72, 0x4a, 0x52, 0x32, 0x43, 0x51, 0x48,
            0x51, 0x33, 0x36, 0x59, 0x36, 0x49, 0x61, 0x63, 0x63, 0x6f, 0x75, 0x6e, 0x74, 0x49,
            0x44, 0x61, 0x24, 0x39, 0x39, 0x30, 0x31, 0x46, 0x35, 0x34, 0x42, 0x2d, 0x44, 0x33,
            0x36, 0x30, 0x2d, 0x34, 0x45, 0x44, 0x38, 0x2d, 0x42, 0x34, 0x44, 0x39, 0x2d, 0x38,
            0x30, 0x43, 0x35, 0x35, 0x35, 0x35, 0x31, 0x35, 0x35, 0x33, 0x37, 0x45, 0x6d, 0x6f,
            0x64, 0x65, 0x6c, 0x48, 0x69, 0x50, 0x61, 0x64, 0x31, 0x36, 0x2c, 0x33, 0x52, 0x72,
            0x65, 0x6d, 0x6f, 0x74, 0x65, 0x70, 0x61, 0x69, 0x72, 0x69, 0x6e, 0x67, 0x5f, 0x75,
            0x64, 0x69, 0x64, 0x59, 0x30, 0x30, 0x30, 0x30, 0x38, 0x31, 0x33, 0x32, 0x2d, 0x30,
            0x30, 0x31, 0x32, 0x31, 0x31, 0x33, 0x36, 0x33, 0x45, 0x38, 0x35, 0x30, 0x30, 0x31,
            0x43, 0x44, 0x6e, 0x61, 0x6d, 0x65, 0xab, 0x5b, 0x6c, 0x61, 0x73, 0x74, 0x53, 0x65,
            0x65, 0x6e, 0x57, 0x69, 0x72, 0x65, 0x50, 0x72, 0x6f, 0x74, 0x6f, 0x63, 0x6f, 0x6c,
            0x56, 0x65, 0x72, 0x73, 0x69, 0x6f, 0x6e, 0x22,
        ];

        let res = super::opack_to_plist(&v).unwrap();
        let dict = res.as_dictionary().unwrap();

        assert_eq!(dict.get("model").unwrap().as_string(), Some("iPad16,3"));
        assert_eq!(dict.get("name").unwrap().as_string(), Some("iPad16,3"));
        assert_eq!(
            dict.get("remotepairing_udid").unwrap().as_string(),
            Some("00008132-001211363E85001C")
        );
        assert_eq!(
            dict.get("remotepairing_ecid").unwrap().as_unsigned_integer(),
            Some(5085474255601692)
        );
        assert_eq!(dict.get("altIRK").unwrap().as_data().unwrap().len(), 16);
        assert_eq!(
            dict.get("lastSeenWireProtocolVersion")
                .unwrap()
                .as_unsigned_integer(),
            Some(26)
        );
    }
}
