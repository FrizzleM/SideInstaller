//! rootshell's socket ABI (`rootshell_socket_*`, WASM import module
//! `rootshell_socket`), as kitknox/rootshell's `wasm/README.md` documents it.
//!
//! Every call blocks until Network.framework answers. TCP listen/accept is an
//! `NWListener`; a UDP `sendto` opens an `NWConnection` to the destination.
//! There is no poll, no setsockopt, and `getsockname` always says 0.0.0.0.

use std::io;
use std::pin::Pin;
use std::task::{Context, Poll};

use tokio::io::{AsyncRead, AsyncWrite, ReadBuf};

pub const AF_INET: i32 = 2;
pub const SOCK_STREAM: i32 = 1;
pub const SOCK_DGRAM: i32 = 2;

#[cfg(target_arch = "wasm32")]
#[link(wasm_import_module = "rootshell_socket")]
unsafe extern "C" {
    fn rootshell_socket_socket(domain: i32, type_: i32, fd_out: *mut i32) -> i32;
    fn rootshell_socket_bind(fd: i32, addr: *const u8, addrlen: i32) -> i32;
    fn rootshell_socket_listen(fd: i32, backlog: i32) -> i32;
    fn rootshell_socket_accept(fd: i32, fd_out: *mut i32) -> i32;
    fn rootshell_socket_send(fd: i32, buf: *const u8, len: i32, sent_out: *mut u32) -> i32;
    fn rootshell_socket_recv(fd: i32, buf: *mut u8, len: i32, recv_out: *mut u32) -> i32;
    fn rootshell_socket_sendto(
        fd: i32,
        buf: *const u8,
        len: i32,
        addr: *const u8,
        addrlen: i32,
        sent_out: *mut u32,
    ) -> i32;
    fn rootshell_socket_close(fd: i32) -> i32;
}

// Off WASM there is no rootshell. For `cargo test` the same calls run on the
// host's own sockets: TCP on loopback only, and datagrams counted as sent and
// dropped, so a test never announces "Pair with …" to iPhones on the network.
#[cfg(not(target_arch = "wasm32"))]
mod host {
    use std::collections::HashMap;
    use std::io::{Read, Write};
    use std::net::{Ipv4Addr, SocketAddrV4, TcpListener, TcpStream};
    use std::sync::atomic::{AtomicI32, Ordering};
    use std::sync::{Mutex, OnceLock};

    const EADDRINUSE: i32 = 1;
    const EBADF: i32 = 8;
    const EINVAL: i32 = 28;
    const EIO: i32 = 29;

    enum Entry {
        /// A TCP socket and the port it was bound to (0 until then).
        Unbound(u16),
        Listener(TcpListener),
        Stream(TcpStream),
        Datagram,
    }

    fn table() -> &'static Mutex<HashMap<i32, Entry>> {
        static TABLE: OnceLock<Mutex<HashMap<i32, Entry>>> = OnceLock::new();
        TABLE.get_or_init(Default::default)
    }

    fn insert(entry: Entry) -> i32 {
        static NEXT: AtomicI32 = AtomicI32::new(3);
        let fd = NEXT.fetch_add(1, Ordering::Relaxed);
        table().lock().unwrap().insert(fd, entry);
        fd
    }

    fn errno(e: &std::io::Error) -> i32 {
        if e.kind() == std::io::ErrorKind::AddrInUse {
            EADDRINUSE
        } else {
            EIO
        }
    }

    /// A handle to the connection, so blocking I/O doesn't hold the table.
    fn stream(fd: i32) -> Result<TcpStream, i32> {
        match table().lock().unwrap().get(&fd) {
            Some(Entry::Stream(s)) => s.try_clone().map_err(|e| errno(&e)),
            _ => Err(EBADF),
        }
    }

    /// The port a listener got: tests listen on port 0.
    #[cfg(test)]
    pub fn local_port(fd: i32) -> u16 {
        match table().lock().unwrap().get(&fd) {
            Some(Entry::Listener(l)) => l.local_addr().map(|a| a.port()).unwrap_or(0),
            _ => 0,
        }
    }

    pub unsafe fn rootshell_socket_socket(_domain: i32, kind: i32, fd_out: *mut i32) -> i32 {
        let entry = if kind == super::SOCK_STREAM { Entry::Unbound(0) } else { Entry::Datagram };
        unsafe { *fd_out = insert(entry) };
        0
    }

    pub unsafe fn rootshell_socket_bind(fd: i32, addr: *const u8, addrlen: i32) -> i32 {
        if addrlen < 4 {
            return EINVAL;
        }
        let port = unsafe { u16::from_be_bytes([*addr.add(2), *addr.add(3)]) };
        match table().lock().unwrap().get_mut(&fd) {
            Some(Entry::Unbound(bound)) => {
                *bound = port;
                0
            }
            Some(_) => EINVAL,
            None => EBADF,
        }
    }

    pub unsafe fn rootshell_socket_listen(fd: i32, _backlog: i32) -> i32 {
        let mut table = table().lock().unwrap();
        let port = match table.get(&fd) {
            Some(Entry::Unbound(port)) => *port,
            Some(_) => return EINVAL,
            None => return EBADF,
        };
        match TcpListener::bind(SocketAddrV4::new(Ipv4Addr::LOCALHOST, port)) {
            Ok(listener) => {
                table.insert(fd, Entry::Listener(listener));
                0
            }
            Err(e) => errno(&e),
        }
    }

    pub unsafe fn rootshell_socket_accept(fd: i32, fd_out: *mut i32) -> i32 {
        let listener = match table().lock().unwrap().get(&fd) {
            Some(Entry::Listener(l)) => l.try_clone(),
            _ => return EBADF,
        };
        match listener.and_then(|l| l.accept()) {
            Ok((connection, _)) => {
                unsafe { *fd_out = insert(Entry::Stream(connection)) };
                0
            }
            Err(e) => errno(&e),
        }
    }

    pub unsafe fn rootshell_socket_send(fd: i32, buf: *const u8, len: i32, sent_out: *mut u32) -> i32 {
        let data = unsafe { std::slice::from_raw_parts(buf, len as usize) };
        match stream(fd).and_then(|mut s| s.write(data).map_err(|e| errno(&e))) {
            Ok(n) => {
                unsafe { *sent_out = n as u32 };
                0
            }
            Err(e) => e,
        }
    }

    pub unsafe fn rootshell_socket_recv(fd: i32, buf: *mut u8, len: i32, recv_out: *mut u32) -> i32 {
        let room = unsafe { std::slice::from_raw_parts_mut(buf, len as usize) };
        match stream(fd).and_then(|mut s| s.read(room).map_err(|e| errno(&e))) {
            Ok(n) => {
                unsafe { *recv_out = n as u32 };
                0
            }
            Err(e) => e,
        }
    }

    pub unsafe fn rootshell_socket_sendto(
        fd: i32,
        _buf: *const u8,
        len: i32,
        _addr: *const u8,
        _addrlen: i32,
        sent_out: *mut u32,
    ) -> i32 {
        match table().lock().unwrap().get(&fd) {
            Some(Entry::Datagram) => {
                unsafe { *sent_out = len as u32 };
                0
            }
            _ => EBADF,
        }
    }

    pub unsafe fn rootshell_socket_close(fd: i32) -> i32 {
        match table().lock().unwrap().remove(&fd) {
            Some(_) => 0,
            None => EBADF,
        }
    }
}
#[cfg(not(target_arch = "wasm32"))]
use host::*;

/// The ABI's errno values (WASI's numbering).
pub fn errno_text(e: i32) -> String {
    let name = match e {
        1 => "EADDRINUSE",
        2 => "EACCES",
        8 => "EBADF",
        14 => "ECONNREFUSED",
        27 => "EINTR",
        28 => "EINVAL",
        29 => "EIO",
        44 => "ENOENT",
        50 => "ENETUNREACH",
        52 => "ENOSYS",
        73 => "ETIMEDOUT",
        _ => "errno",
    };
    format!("{name} ({e})")
}

fn check(what: &str, e: i32) -> io::Result<()> {
    if e == 0 {
        Ok(())
    } else {
        Err(io::Error::other(format!("{what}: {}", errno_text(e))))
    }
}

/// A 16-byte `sockaddr_in`, family in the first byte (the ABI's layout).
pub fn sockaddr_in(ip: [u8; 4], port: u16) -> [u8; 16] {
    let mut out = [0u8; 16];
    out[0] = AF_INET as u8;
    out[2..4].copy_from_slice(&port.to_be_bytes());
    out[4..8].copy_from_slice(&ip);
    out
}

/// A socket fd in the ABI's own fd space, closed on drop.
#[derive(Debug)]
pub struct Socket {
    fd: i32,
}

impl Socket {
    pub fn new(kind: i32) -> io::Result<Self> {
        let mut fd = -1;
        check("socket", unsafe { rootshell_socket_socket(AF_INET, kind, &mut fd) })?;
        Ok(Self { fd })
    }

    /// A TCP listener on `port`, on every interface.
    pub fn listen(port: u16) -> io::Result<Self> {
        let s = Self::new(SOCK_STREAM)?;
        let addr = sockaddr_in([0, 0, 0, 0], port);
        check("bind", unsafe { rootshell_socket_bind(s.fd, addr.as_ptr(), 16) })?;
        check("listen", unsafe { rootshell_socket_listen(s.fd, 4) })?;
        Ok(s)
    }

    /// Blocks until a connection arrives.
    pub fn accept(&self) -> io::Result<Stream> {
        let mut fd = -1;
        check("accept", unsafe { rootshell_socket_accept(self.fd, &mut fd) })?;
        Ok(Stream { socket: Socket { fd } })
    }

    /// One UDP datagram on a socket of its own, then closed: a flow
    /// Network.framework has had for a few seconds can stop completing sends
    /// to a multicast address, so none is kept.
    pub fn send_datagram(data: &[u8], ip: [u8; 4], port: u16) -> io::Result<()> {
        let s = Self::new(SOCK_DGRAM)?;
        let addr = sockaddr_in(ip, port);
        let mut sent = 0u32;
        check("sendto", unsafe {
            rootshell_socket_sendto(s.fd, data.as_ptr(), data.len() as i32, addr.as_ptr(), 16, &mut sent)
        })?;
        if sent as usize != data.len() {
            return Err(io::Error::other(format!("sendto sent {sent} of {} bytes", data.len())));
        }
        Ok(())
    }
}

#[cfg(test)]
impl Socket {
    /// The port a listener got (tests listen on port 0).
    pub fn local_port(&self) -> u16 {
        host::local_port(self.fd)
    }
}

impl Drop for Socket {
    fn drop(&mut self) {
        if self.fd >= 0 {
            unsafe { rootshell_socket_close(self.fd) };
        }
    }
}

/// A connected TCP socket as tokio's async traits, for idevice. Every call
/// blocks and is then ready, which is fine under a one-task executor: the
/// pairing conversation is strictly one message after another.
#[derive(Debug)]
pub struct Stream {
    socket: Socket,
}

impl Stream {
    /// One line, without its `\n`, of at most `max` bytes.
    pub fn read_line(&self, max: usize) -> io::Result<String> {
        let mut line = Vec::new();
        let mut byte = [0u8; 1];
        while line.len() < max {
            let mut got = 0u32;
            check("recv", unsafe { rootshell_socket_recv(self.socket.fd, byte.as_mut_ptr(), 1, &mut got) })?;
            if got == 0 || byte[0] == b'\n' {
                break;
            }
            line.push(byte[0]);
        }
        Ok(String::from_utf8_lossy(&line).trim().to_string())
    }

    pub fn write_all(&self, mut data: &[u8]) -> io::Result<()> {
        while !data.is_empty() {
            let mut sent = 0u32;
            check("send", unsafe {
                rootshell_socket_send(self.socket.fd, data.as_ptr(), data.len() as i32, &mut sent)
            })?;
            if sent == 0 {
                return Err(io::Error::other("send made no progress"));
            }
            data = &data[sent as usize..];
        }
        Ok(())
    }
}

impl AsyncRead for Stream {
    fn poll_read(self: Pin<&mut Self>, _: &mut Context<'_>, buf: &mut ReadBuf<'_>) -> Poll<io::Result<()>> {
        let room = buf.initialize_unfilled();
        let mut got = 0u32;
        let e = unsafe { rootshell_socket_recv(self.socket.fd, room.as_mut_ptr(), room.len() as i32, &mut got) };
        if let Err(err) = check("recv", e) {
            return Poll::Ready(Err(err));
        }
        // Zero bytes: the peer closed.
        buf.advance(got as usize);
        Poll::Ready(Ok(()))
    }
}

impl AsyncWrite for Stream {
    fn poll_write(self: Pin<&mut Self>, _: &mut Context<'_>, data: &[u8]) -> Poll<io::Result<usize>> {
        let mut sent = 0u32;
        let e = unsafe { rootshell_socket_send(self.socket.fd, data.as_ptr(), data.len() as i32, &mut sent) };
        Poll::Ready(check("send", e).map(|()| sent as usize))
    }

    fn poll_flush(self: Pin<&mut Self>, _: &mut Context<'_>) -> Poll<io::Result<()>> {
        Poll::Ready(Ok(()))
    }

    fn poll_shutdown(self: Pin<&mut Self>, _: &mut Context<'_>) -> Poll<io::Result<()>> {
        Poll::Ready(Ok(()))
    }
}
