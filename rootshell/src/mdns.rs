//! The pairable host's Bonjour advertisement, as a raw mDNS announcement
//! (RFC 6762 §8.3): what `NetService.publish`
//! have the system send, built by hand.
//!
//! rootshell's App Store build carries Apple's multicast entitlement
//! (`com.apple.developer.networking.multicast`), which lets an app send to
//! 224.0.0.251:5353 without declaring the service type. The iPhone's own
//! mDNSResponder takes the announcement into its cache (macOS's does, from
//! any source port), and Settings › Developer Mode lists it from there.
//!
//! The program can't answer queries: rootshell's sockets have no poll, and it
//! sits in a blocking `accept` while Settings looks. So the records carry a
//! long TTL and are announced in a burst before waiting, and mDNSResponder
//! answers Settings from its cache.

/// What Settings browses for.
pub const PAIRABLE_HOST_TYPE: &str = "_remotepairing-pairable-host._tcp.local";
pub const GROUP: [u8; 4] = [224, 0, 0, 251];
pub const PORT: u16 = 5353;
/// Long enough to cover finding the entry in Settings; the goodbye (TTL 0)
/// withdraws it when pairing ends.
pub const TTL: u32 = 75 * 60;

const PTR: u16 = 12;
const TXT: u16 = 16;
const SRV: u16 = 33;
const A: u16 = 1;

pub struct Advert<'a> {
    /// The DNS-SD service type, `PAIRABLE_HOST_TYPE` but for tests.
    pub service: &'a str,
    /// The instance name: the pairing file's identifier, which the device
    /// checks against the TXT `identifier`.
    pub instance: &'a str,
    /// The host name the SRV record points at, `<label>.local`.
    pub host: &'a str,
    pub ip: [u8; 4],
    pub port: u16,
    pub txt: &'a [(String, String)],
}

fn name(n: &str) -> Vec<u8> {
    let mut out = Vec::new();
    for label in n.trim_end_matches('.').split('.') {
        out.push(label.len() as u8);
        out.extend_from_slice(label.as_bytes());
    }
    out.push(0);
    out
}

fn record(owner: &str, kind: u16, rdata: &[u8], ttl: u32, unique: bool) -> Vec<u8> {
    let mut out = name(owner);
    out.extend_from_slice(&kind.to_be_bytes());
    // Class IN, with the cache-flush bit on records only this host answers.
    out.extend_from_slice(&(1u16 | if unique { 0x8000 } else { 0 }).to_be_bytes());
    out.extend_from_slice(&ttl.to_be_bytes());
    out.extend_from_slice(&(rdata.len() as u16).to_be_bytes());
    out.extend_from_slice(rdata);
    out
}

/// The announcement: PTR, SRV, TXT and the host's A record. `ttl` 0 is the
/// goodbye.
pub fn announcement(ad: &Advert, ttl: u32) -> Vec<u8> {
    let full = format!("{}.{}", ad.instance, ad.service);
    let mut srv = vec![0, 0, 0, 0];
    srv.extend_from_slice(&ad.port.to_be_bytes());
    srv.extend(name(ad.host));
    let mut txt = Vec::new();
    for (k, v) in ad.txt {
        let entry = format!("{k}={v}");
        let bytes = &entry.as_bytes()[..entry.len().min(255)];
        txt.push(bytes.len() as u8);
        txt.extend_from_slice(bytes);
    }
    let records = [
        record(ad.service, PTR, &name(&full), ttl, false),
        record(&full, SRV, &srv, ttl, true),
        record(&full, TXT, &txt, ttl, true),
        record(ad.host, A, &ad.ip, ttl, true),
    ];
    // ID 0, flags: response, authoritative; no questions, four answers.
    let mut out = vec![0, 0, 0x84, 0, 0, 0, 0, records.len() as u8, 0, 0, 0, 0];
    for r in records {
        out.extend(r);
    }
    out
}

#[cfg(test)]
pub mod tests {
    use super::*;

    /// (owner, type, class, ttl, rdata) for each answer.
    pub fn parse(packet: &[u8]) -> Vec<(String, u16, u16, u32, Vec<u8>)> {
        fn read_name(p: &[u8], mut i: usize) -> (String, usize) {
            let mut labels = Vec::new();
            while p[i] != 0 {
                let len = p[i] as usize;
                labels.push(String::from_utf8(p[i + 1..i + 1 + len].to_vec()).unwrap());
                i += 1 + len;
            }
            (labels.join("."), i + 1)
        }
        let count = u16::from_be_bytes([packet[6], packet[7]]) as usize;
        let mut i = 12;
        let mut out = Vec::new();
        for _ in 0..count {
            let (owner, j) = read_name(packet, i);
            let kind = u16::from_be_bytes([packet[j], packet[j + 1]]);
            let class = u16::from_be_bytes([packet[j + 2], packet[j + 3]]);
            let ttl = u32::from_be_bytes(packet[j + 4..j + 8].try_into().unwrap());
            let len = u16::from_be_bytes([packet[j + 8], packet[j + 9]]) as usize;
            out.push((owner, kind, class, ttl, packet[j + 10..j + 10 + len].to_vec()));
            i = j + 10 + len;
        }
        assert_eq!(i, packet.len(), "trailing bytes");
        out
    }

    #[test]
    fn the_announcement_carries_ptr_srv_txt_and_a() {
        let txt = vec![("name".to_string(), "siboot".to_string()), ("ver".to_string(), "26".to_string())];
        let ad = Advert {
            service: PAIRABLE_HOST_TYPE,
            instance: "ABC-123",
            host: "siboot-abc.local",
            ip: [192, 168, 1, 20],
            port: 51234,
            txt: &txt,
        };
        let packet = announcement(&ad, TTL);
        assert_eq!(&packet[2..4], &[0x84, 0], "an authoritative response");
        let records = parse(&packet);
        let full = "ABC-123._remotepairing-pairable-host._tcp.local";
        assert_eq!(records[0].0, "_remotepairing-pairable-host._tcp.local");
        assert_eq!((records[0].1, records[0].2), (PTR, 1), "shared PTR, no cache-flush");
        assert_eq!(records[0].4, name(full));
        assert_eq!((records[1].0.as_str(), records[1].1, records[1].2), (full, SRV, 0x8001));
        assert_eq!(&records[1].4[4..6], &51234u16.to_be_bytes());
        assert_eq!(&records[1].4[6..], name("siboot-abc.local").as_slice());
        assert_eq!(records[2].4, b"\x0bname=siboot\x06ver=26");
        assert_eq!((records[3].0.as_str(), records[3].1), ("siboot-abc.local", A));
        assert_eq!(records[3].4, vec![192, 168, 1, 20]);
        assert!(records.iter().all(|r| r.3 == TTL));
        assert!(parse(&announcement(&ad, 0)).iter().all(|r| r.3 == 0), "goodbye");
    }
}
