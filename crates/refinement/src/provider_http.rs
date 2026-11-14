//! Deliberately restricted local HTTP transport. No DNS, TLS, auth or redirects.
use crate::*;
use std::io::{Read, Write};
use std::net::{IpAddr, Ipv4Addr, Ipv6Addr, SocketAddr, TcpStream};
use std::time::{Duration, Instant};

/// Local numeric loopback HTTP only. Remote profiles are configurable but require
/// injection of a separately reviewed TLS/auth transport; never downgrade HTTPS.
pub struct LoopbackHttp;

fn io<T>(result: std::io::Result<T>) -> Result<Option<T>, Error> {
    match result {
        Ok(value) => Ok(Some(value)),
        Err(error)
            if matches!(
                error.kind(),
                std::io::ErrorKind::TimedOut
                    | std::io::ErrorKind::WouldBlock
                    | std::io::ErrorKind::Interrupted
            ) =>
        {
            Ok(None)
        }
        Err(_) => Err(Error::ProviderFailed),
    }
}

fn read(stream: &mut TcpStream, buffer: &mut [u8], control: &Control) -> Result<(), Error> {
    let mut offset = 0;
    while offset < buffer.len() {
        control.checkpoint()?;
        match io(stream.read(&mut buffer[offset..]))? {
            Some(0) => return Err(Error::ProviderFailed),
            Some(n) => offset += n,
            None => (),
        }
    }
    control.checkpoint()
}

impl JsonTransport for LoopbackHttp {
    fn post(
        &self,
        endpoint: &Endpoint,
        body: &[u8],
        control: &Control,
        limit: usize,
    ) -> Result<Vec<u8>, Error> {
        control.checkpoint()?;
        if body.len() > MAX_PROVIDER_INPUT || limit > MAX_PROVIDER_RESPONSE {
            return Err(Error::Overflow);
        }
        let ip = match (endpoint.identity().locality, endpoint.host.as_str()) {
            (Locality::Local, "127.0.0.1") => IpAddr::V4(Ipv4Addr::LOCALHOST),
            (Locality::Local, "[::1]") => IpAddr::V6(Ipv6Addr::LOCALHOST),
            _ => return Err(Error::InferenceNotAuthorized),
        };
        let timeout = control
            .deadline()
            .saturating_duration_since(Instant::now())
            .min(Duration::from_millis(100));
        if timeout.is_zero() {
            return Err(Error::Deadline);
        }
        let mut stream = TcpStream::connect_timeout(&SocketAddr::new(ip, endpoint.port), timeout)
            .map_err(|_| Error::ProviderFailed)?;
        stream
            .set_read_timeout(Some(Duration::from_millis(25)))
            .map_err(|_| Error::ProviderFailed)?;
        stream
            .set_write_timeout(Some(Duration::from_millis(25)))
            .map_err(|_| Error::ProviderFailed)?;
        let header = format!(
            "POST {} HTTP/1.1\r\nHost: {}:{}\r\nContent-Type: application/json\r\nAccept: application/json\r\nConnection: close\r\nContent-Length: {}\r\n\r\n",
            endpoint.path,
            endpoint.host,
            endpoint.port,
            body.len()
        );
        for bytes in [header.as_bytes(), body] {
            let mut offset = 0;
            while offset < bytes.len() {
                control.checkpoint()?;
                match io(stream.write(&bytes[offset..]))? {
                    Some(0) => return Err(Error::ProviderFailed),
                    Some(n) => offset += n,
                    None => (),
                }
            }
        }
        let mut headers = Vec::new();
        while !headers.ends_with(b"\r\n\r\n") {
            if headers.len() >= 4096 {
                return Err(Error::Overflow);
            }
            let mut byte = [0];
            read(&mut stream, &mut byte, control)?;
            headers.push(byte[0]);
        }
        let headers = std::str::from_utf8(&headers).map_err(|_| Error::ProviderFailed)?;
        let mut lines = headers.split("\r\n");
        let status = lines.next().ok_or(Error::ProviderFailed)?;
        if !status.starts_with("HTTP/1.1 200 ") && !status.starts_with("HTTP/1.0 200 ") {
            return Err(Error::ProviderFailed);
        }
        let mut length = None;
        let mut json_type = false;
        for line in lines.filter(|line| !line.is_empty()) {
            let (name, value) = line.split_once(':').ok_or(Error::ProviderFailed)?;
            let value = value.trim();
            match name.to_ascii_lowercase().as_str() {
                "content-length" => {
                    if length.is_some() || !value.bytes().all(|b| b.is_ascii_digit()) {
                        return Err(Error::ProviderFailed);
                    }
                    length = Some(value.parse::<usize>().map_err(|_| Error::Overflow)?);
                }
                "content-type" => {
                    if json_type || value != "application/json" {
                        return Err(Error::ProviderFailed);
                    }
                    json_type = true;
                }
                "transfer-encoding" | "content-encoding" => return Err(Error::ProviderFailed),
                _ => (),
            }
        }
        let length = length.filter(|n| *n > 0).ok_or(Error::ProviderFailed)?;
        if !json_type {
            return Err(Error::ProviderFailed);
        }
        if length > limit {
            return Err(Error::Overflow);
        }
        let mut response = vec![0; length];
        read(&mut stream, &mut response, control)?;
        Ok(response)
    }
}
