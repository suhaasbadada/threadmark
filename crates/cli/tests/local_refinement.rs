//! Actual CLI + synthetic SQLite + owned numeric-loopback HTTP only.
#[path = "local_refinement/ranked_preparation.rs"]
mod ranked_preparation;
use serde_json::{Value, json};
use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::path::PathBuf;
use std::process::{Child, Command, Output, Stdio};
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{Duration, Instant};

static NEXT: AtomicU64 = AtomicU64::new(0);
struct Fixture(PathBuf);
impl Fixture {
    fn new() -> Self {
        let root = std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-local-refine-{}-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos(),
            NEXT.fetch_add(1, Ordering::Relaxed),
        ));
        std::fs::create_dir(&root).unwrap();
        std::fs::create_dir(root.join("source")).unwrap();
        std::fs::write(root.join("source/main.rs"), "fn synthetic_blue() {}\n").unwrap();
        let fixture = Self(root);
        fixture.ok(&[
            "project",
            "add",
            "synthetic",
            fixture.0.join("source").to_str().unwrap(),
            "main.rs",
        ]);
        fixture.ok(&["index", "synthetic"]);
        fixture
    }
    fn command(&self, words: &[&str]) -> Command {
        let mut command = Command::new(env!("CARGO_BIN_EXE_threadmark"));
        command
            .arg("--data-dir")
            .arg(self.0.join("store"))
            .args(words)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());
        command
    }
    fn run(&self, words: &[&str], original: &[u8]) -> Output {
        let mut child = self.command(words).spawn().unwrap();
        let written = child.stdin.take().unwrap().write_all(original);
        let result = child.wait_with_output().unwrap();
        if result.status.success() {
            written.unwrap();
        }
        result
    }
    fn ok(&self, words: &[&str]) -> Value {
        let result = self.run(words, b"");
        assert!(
            result.status.success(),
            "{}",
            String::from_utf8_lossy(&result.stderr)
        );
        serde_json::from_slice(&result.stdout).unwrap()
    }
    fn flags(&self, endpoint: &str) -> Vec<String> {
        // Operator inspection protocol: inspect exact policy, then actual core query.
        let project = self.ok(&["project", "show", "synthetic"]);
        let query = self.ok(&["query", "synthetic", "synthetic_blue"]);
        assert_eq!(query["currentness"], "current-at-read");
        assert_eq!(query["results"].as_array().unwrap().len(), 1);
        [
            "refine",
            "preview",
            "synthetic",
            "synthetic_blue",
            "--profile",
            "synthetic-profile",
            "--model",
            "synthetic-model",
            "--endpoint",
            endpoint,
            "--expected-root",
            project["root"].as_str().unwrap(),
            "--expected-root-identity",
            project["root_identity"].as_str().unwrap(),
            "--expected-incarnation",
            project["incarnation"].as_str().unwrap(),
            "--expected-snapshot",
            query["snapshot"].as_str().unwrap(),
            "--confirm-local-inference",
        ]
        .into_iter()
        .map(str::to_owned)
        .collect()
    }
    fn preview(&self, flags: &[String], original: &[u8]) -> Output {
        self.run(
            &flags.iter().map(String::as_str).collect::<Vec<_>>(),
            original,
        )
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        std::fs::remove_dir_all(&self.0).unwrap();
    }
}

fn listener() -> (TcpListener, String) {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    listener.set_nonblocking(true).unwrap();
    let endpoint = format!(
        "http://{}/v1/chat/completions",
        listener.local_addr().unwrap()
    );
    (listener, endpoint)
}
fn receive(listener: &TcpListener) -> (TcpStream, Value) {
    let deadline = Instant::now() + Duration::from_secs(5);
    let mut stream = loop {
        match listener.accept() {
            Ok((stream, _)) => break stream,
            Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {
                assert!(Instant::now() < deadline, "owned fixture accept deadline");
                std::thread::sleep(Duration::from_millis(2));
            }
            Err(error) => panic!("owned accept: {error}"),
        }
    };
    // macOS accepted sockets may inherit O_NONBLOCK.
    stream.set_nonblocking(false).unwrap();
    stream
        .set_read_timeout(Some(Duration::from_secs(3)))
        .unwrap();
    stream
        .set_write_timeout(Some(Duration::from_secs(3)))
        .unwrap();
    let mut bytes = Vec::new();
    let (start, length) = loop {
        let mut byte = [0];
        stream.read_exact(&mut byte).unwrap();
        bytes.push(byte[0]);
        assert!(bytes.len() <= 4096);
        if bytes.ends_with(b"\r\n\r\n") {
            let header = String::from_utf8(bytes.clone()).unwrap();
            assert!(header.starts_with("POST /v1/chat/completions HTTP/1.1\r\n"));
            assert!(!header.to_ascii_lowercase().contains("authorization:"));
            assert!(!header.to_ascii_lowercase().contains("cookie:"));
            let length = header
                .lines()
                .find_map(|line| {
                    let (key, value) = line.split_once(':')?;
                    key.eq_ignore_ascii_case("content-length")
                        .then(|| value.trim().parse::<usize>().unwrap())
                })
                .unwrap();
            break (bytes.len(), length);
        }
    };
    assert!(length <= 32768);
    bytes.resize(start + length, 0);
    stream.read_exact(&mut bytes[start..]).unwrap();
    (stream, serde_json::from_slice(&bytes[start..]).unwrap())
}
fn proposal(questions: Value, objective: String) -> String {
    json!({"choices":[{"finish_reason":"stop","message":{"role":"assistant","content":json!({
        "objective":objective,"output_expectations":"Propose checks, do not execute.",
        "unknowns":[],"questions":questions,
    }).to_string()}}]})
    .to_string()
}
fn respond(mut stream: TcpStream, status: &str, body: &str) {
    let response = format!(
        "HTTP/1.1 {status}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
        body.len()
    );
    // Kill/cancel fixtures deliberately close the client socket.
    let _ = stream.write_all(response.as_bytes());
}
fn rejected(result: &Output) {
    assert!(!result.status.success());
    assert!(result.stdout.is_empty());
    let error = String::from_utf8_lossy(&result.stderr);
    assert!(!error.contains("PRIVATE_ORIGINAL"));
    assert!(!error.contains("synthetic_blue()"));
}
fn replace(flags: &mut [String], flag: &str, value: &str) {
    let index = flags.iter().position(|word| word == flag).unwrap();
    flags[index + 1] = value.into();
}

#[test]
fn inspected_actual_core_preview_preserves_original_and_never_approves_or_delivers() {
    for questions in [json!([]), json!(["Which verification is desired?"])] {
        let fixture = Fixture::new();
        let (listener, endpoint) = listener();
        let flags = fixture.flags(&endpoint);
        let original = "PRIVATE_ORIGINAL Do not deploy. 保持\r\n<draft>\"\\\n";
        let expected = original.to_owned();
        let expected_questions = questions.clone();
        let server = std::thread::spawn(move || {
            let (stream, body) = receive(&listener);
            assert_eq!(body["model"], "synthetic-model");
            assert_eq!(body["max_tokens"], 1024);
            assert_eq!(body["stream"], false);
            let payload: Value =
                serde_json::from_str(body["messages"][1]["content"].as_str().unwrap()).unwrap();
            assert_eq!(payload["original"], expected);
            assert_eq!(payload["project"], "synthetic");
            assert_eq!(payload["evidence"].as_array().unwrap().len(), 1);
            assert_eq!(payload["evidence"][0]["path"], "main.rs");
            assert_eq!(payload["evidence"][0]["text"], "fn synthetic_blue() {}");
            respond(
                stream,
                "200 OK",
                &proposal(
                    questions,
                    "Inspect synthetic_blue without deployment.".into(),
                ),
            );
            listener
        });
        let result = fixture.preview(&flags, original.as_bytes());
        assert!(
            result.status.success(),
            "{}",
            String::from_utf8_lossy(&result.stderr)
        );
        assert!(result.stderr.is_empty());
        assert!(result.stdout.len() <= 8192);
        assert_eq!(
            result.stdout.iter().filter(|byte| **byte == b'\n').count(),
            1
        );
        let output: Value = serde_json::from_slice(&result.stdout).unwrap();
        assert_eq!(output["original"], original);
        assert_ne!(output["proposed"], original);
        assert_eq!(output["changed"], true);
        assert_eq!(output["material_questions"], expected_questions);
        assert_eq!(
            output["state"],
            if expected_questions.as_array().unwrap().is_empty() {
                "ready-for-review"
            } else {
                "needs-input"
            }
        );
        assert_eq!(output["approval"], "not-requested");
        assert_eq!(output["delivery"], "not-attempted");
        assert_eq!(output["provider"]["endpoint"], endpoint);
        assert_eq!(output["provider"]["profile"], "synthetic-profile");
        assert_eq!(output["provider"]["model"], "synthetic-model");
        assert_eq!(output["provider"]["locality"], "local");
        assert!(output["coverage"].as_str().unwrap().contains("lexical"));
        let listener = server.join().unwrap();
        assert_eq!(
            listener.accept().unwrap_err().kind(),
            std::io::ErrorKind::WouldBlock
        );
        assert_eq!(
            std::fs::read_to_string(fixture.0.join("source/main.rs")).unwrap(),
            "fn synthetic_blue() {}\n"
        );
        assert!(
            fixture.ok(&["context", "list", "synthetic"])["contexts"]
                .as_array()
                .unwrap()
                .is_empty()
        );
    }
}

#[test]
fn flags_confirmation_endpoint_and_input_reject_without_creating_or_opening_store() {
    let fixture = Fixture::new();
    let (listener, endpoint) = listener();
    let valid = fixture.flags(&endpoint);
    let missing = fixture.0.join("never-create");
    let mut cases = Vec::new();
    let mut flags = valid.clone();
    flags.pop();
    cases.push(flags);
    for flag in [
        "--profile",
        "--model",
        "--endpoint",
        "--expected-root",
        "--expected-root-identity",
        "--expected-incarnation",
        "--expected-snapshot",
    ] {
        let mut flags = valid.clone();
        let index = flags.iter().position(|word| word == flag).unwrap();
        flags.drain(index..index + 2);
        cases.push(flags);
    }
    for (flag, value) in [
        ("--endpoint", "https://remote.invalid/v1/chat/completions"),
        ("--endpoint", "http://localhost/v1/chat/completions"),
        (
            "--endpoint",
            "http://user:password@127.0.0.1/v1/chat/completions",
        ),
        ("--expected-root", "relative"),
        ("--expected-incarnation", "bad"),
        ("--expected-snapshot", "bad"),
        ("--profile", "bad profile"),
        ("--model", "bad model"),
        ("--expected-root-identity", ""),
    ] {
        let mut flags = valid.clone();
        replace(&mut flags, flag, value);
        cases.push(flags);
    }
    for extra in [
        vec!["--profile", "duplicate"],
        vec!["--confirm-local-inference"],
        vec!["--unknown"],
        vec!["PRIVATE_ORIGINAL"],
    ] {
        let mut flags = valid.clone();
        flags.extend(extra.into_iter().map(str::to_owned));
        cases.push(flags);
    }
    let mut flags = valid.clone();
    flags[3] = "x".repeat(257);
    cases.push(flags);
    for flags in cases {
        // Keep stdin open: parser must reject without blocking on content or store.
        let result = Command::new(env!("CARGO_BIN_EXE_threadmark"))
            .arg("--data-dir")
            .arg(&missing)
            .args(&flags)
            .stdin(Stdio::null())
            .output()
            .unwrap();
        rejected(&result);
        assert_eq!(result.status.code(), Some(2));
        assert!(!missing.exists());
    }
    for input in [vec![], vec![b'x'; 4097], vec![0xff]] {
        let mut child = Command::new(env!("CARGO_BIN_EXE_threadmark"))
            .arg("--data-dir")
            .arg(&missing)
            .args(&valid)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .unwrap();
        let _ = child.stdin.take().unwrap().write_all(&input);
        rejected(&child.wait_with_output().unwrap());
        assert!(!missing.exists());
    }
    assert_eq!(
        listener.accept().unwrap_err().kind(),
        std::io::ErrorKind::WouldBlock
    );
}

#[test]
fn expected_namespace_snapshot_stale_source_and_replacement_reject_before_provider() {
    for scenario in [
        "root",
        "identity",
        "incarnation",
        "snapshot",
        "project",
        "stale",
        "replace-registration",
        "replace-root",
        "unindexed",
    ] {
        let fixture = Fixture::new();
        let (listener, endpoint) = listener();
        let mut flags = fixture.flags(&endpoint);
        match scenario {
            "root" => replace(&mut flags, "--expected-root", "/synthetic-other"),
            "identity" => replace(&mut flags, "--expected-root-identity", "synthetic-other"),
            "incarnation" => replace(&mut flags, "--expected-incarnation", &"0".repeat(32)),
            "snapshot" => replace(&mut flags, "--expected-snapshot", &"0".repeat(64)),
            "project" => flags[2] = "other".into(),
            "stale" => std::fs::write(
                fixture.0.join("source/main.rs"),
                "fn synthetic_changed() {}\n",
            )
            .unwrap(),
            "unindexed" => {
                fixture.ok(&["project", "sources", "synthetic", "main.rs"]);
            }
            "replace-root" => {
                std::fs::rename(fixture.0.join("source"), fixture.0.join("old-source")).unwrap();
                std::fs::create_dir(fixture.0.join("source")).unwrap();
                std::fs::write(fixture.0.join("source/main.rs"), "fn synthetic_blue() {}\n")
                    .unwrap();
            }
            "replace-registration" => {
                fixture.ok(&[
                    "project",
                    "remove",
                    "synthetic",
                    "--confirm-remove-local-data",
                ]);
                fixture.ok(&[
                    "project",
                    "add",
                    "synthetic",
                    fixture.0.join("source").to_str().unwrap(),
                    "main.rs",
                ]);
                fixture.ok(&["index", "synthetic"]);
            }
            _ => unreachable!(),
        }
        rejected(&fixture.preview(&flags, b"PRIVATE_ORIGINAL do not deploy"));
        assert_eq!(
            listener.accept().unwrap_err().kind(),
            std::io::ErrorKind::WouldBlock
        );
    }
}

#[test]
fn provider_failure_duplicates_auth_redirect_bounds_and_source_race_have_empty_stdout() {
    let duplicate = r#"{"choices":[{"finish_reason":"stop","message":{"role":"assistant","content":"{\"objective\":\"Candidate\",\"output_expectations\":\"Review\",\"unknowns\":[],\"questions\":[\"Material?\"],\"questions\":[]}"}}]}"#;
    let cases = [
        ("200 OK", "not JSON".into(), false),
        ("200 OK", duplicate.into(), false),
        ("401 Unauthorized", "PRIVATE_PROVIDER_ERROR".into(), false),
        ("403 Forbidden", "PRIVATE_PROVIDER_ERROR".into(), false),
        ("302 Found", "PRIVATE_PROVIDER_ERROR".into(), false),
        ("500 Server Error", "PRIVATE_PROVIDER_ERROR".into(), false),
        ("200 OK", "x".repeat(16385), false),
        ("200 OK", proposal(json!([]), "x".repeat(8000)), false),
        ("200 OK", proposal(json!([]), "Candidate".into()), true),
    ];
    for (status, body, change_source) in cases {
        let fixture = Fixture::new();
        let (listener, endpoint) = listener();
        let flags = fixture.flags(&endpoint);
        let source = fixture.0.join("source/main.rs");
        let server = std::thread::spawn(move || {
            let (stream, _) = receive(&listener);
            if change_source {
                std::fs::write(source, "fn synthetic_changed_during_inference() {}\n").unwrap();
            }
            respond(stream, status, &body);
            listener
        });
        let result = fixture.preview(&flags, b"PRIVATE_ORIGINAL do not deploy");
        rejected(&result);
        assert!(!String::from_utf8_lossy(&result.stderr).contains("PRIVATE_PROVIDER_ERROR"));
        let listener = server.join().unwrap();
        assert_eq!(
            listener.accept().unwrap_err().kind(),
            std::io::ErrorKind::WouldBlock
        );
    }
}

#[test]
fn whole_json_line_overflow_rejects_without_truncation_even_when_engine_output_fits() {
    let fixture = Fixture::new();
    let (listener, endpoint) = listener();
    let flags = fixture.flags(&endpoint);
    // Conservative engine Debug envelope fits, but repeated original/proposed plus
    // actual JSON metadata does not. The CLI must reject the entire JSON line.
    let original = format!("PRIVATE_ORIGINAL {}", "x".repeat(2900));
    let server = std::thread::spawn(move || {
        let (stream, _) = receive(&listener);
        respond(stream, "200 OK", &proposal(json!([]), "y".repeat(1800)));
    });
    rejected(&fixture.preview(&flags, original.as_bytes()));
    server.join().unwrap();
}

#[test]
fn parent_kill_during_owned_http_has_no_preview_or_late_delivery() {
    let fixture = Fixture::new();
    let (listener, endpoint) = listener();
    let flags = fixture.flags(&endpoint);
    let (sent, received) = std::sync::mpsc::sync_channel(1);
    let (release, released) = std::sync::mpsc::sync_channel(1);
    let server = std::thread::spawn(move || {
        let (stream, _) = receive(&listener);
        sent.send(()).unwrap();
        released.recv_timeout(Duration::from_secs(5)).unwrap();
        respond(
            stream,
            "200 OK",
            &proposal(json!([]), "Late candidate".into()),
        );
    });
    let mut child: Child = fixture
        .command(&flags.iter().map(String::as_str).collect::<Vec<_>>())
        .spawn()
        .unwrap();
    child
        .stdin
        .take()
        .unwrap()
        .write_all(b"PRIVATE_ORIGINAL do not deploy")
        .unwrap();
    received.recv_timeout(Duration::from_secs(5)).unwrap();
    child.kill().unwrap();
    let result = child.wait_with_output().unwrap();
    assert!(!result.status.success());
    assert!(result.stdout.is_empty());
    release.send(()).unwrap();
    server.join().unwrap();
    assert_eq!(
        std::fs::read_to_string(fixture.0.join("source/main.rs")).unwrap(),
        "fn synthetic_blue() {}\n"
    );
}
