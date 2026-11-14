//! Synthetic actual CLI + SQLite + one owned loopback server, never a live model.
use serde_json::{Value, json};
use std::io::{BufRead, BufReader, Read, Write};
use std::net::{TcpListener, TcpStream};
use std::path::PathBuf;
use std::process::{Child, ChildStdin, Command, Stdio};
use std::sync::{
    atomic::{AtomicU64, Ordering},
    mpsc,
};
use std::time::{Duration, Instant};

static NEXT: AtomicU64 = AtomicU64::new(0);
struct Fixture(PathBuf);
impl Fixture {
    fn new() -> Self {
        let root = std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-review-{}-{}-{}",
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
    fn command(&self, args: &[String]) -> Command {
        let mut command = Command::new(env!("CARGO_BIN_EXE_threadmark"));
        command
            .arg("--data-dir")
            .arg(self.0.join("store"))
            .args(args)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());
        command
    }
    fn ok(&self, args: &[&str]) -> Value {
        let output = self
            .command(&args.iter().map(|s| (*s).into()).collect::<Vec<_>>())
            .output()
            .unwrap();
        assert!(
            output.status.success(),
            "{}",
            String::from_utf8_lossy(&output.stderr)
        );
        serde_json::from_slice(&output.stdout).unwrap()
    }
    fn flags(&self, endpoint: &str) -> Vec<String> {
        let project = self.ok(&["project", "show", "synthetic"]);
        let query = self.ok(&["query", "synthetic", "synthetic_blue"]);
        [
            "refine",
            "review",
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
    fn child(&self, flags: &[String]) -> Session {
        Session::new(self.command(flags).spawn().unwrap())
    }
    fn unchanged(&self) {
        assert_eq!(
            std::fs::read_to_string(self.0.join("source/main.rs")).unwrap(),
            "fn synthetic_blue() {}\n"
        );
        assert!(
            self.ok(&["context", "list", "synthetic"])["contexts"]
                .as_array()
                .unwrap()
                .is_empty()
        );
        // Scan owned SQLite/WAL data: no prompt, edit, or provider plaintext persisted.
        for entry in std::fs::read_dir(self.0.join("store")).unwrap() {
            let entry = entry.unwrap();
            if entry.file_type().unwrap().is_file() {
                let bytes = std::fs::read(entry.path()).unwrap();
                for marker in ["PRIVATE_ORIGINAL", "PRIVATE_EDIT", "PRIVATE_PROVIDER"] {
                    assert!(
                        !bytes
                            .windows(marker.len())
                            .any(|part| part == marker.as_bytes())
                    );
                }
            }
        }
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        std::fs::remove_dir_all(&self.0).unwrap();
    }
}

struct Session {
    child: Child,
    input: Option<ChildStdin>,
    events: mpsc::Receiver<Option<Value>>,
    reader: Option<std::thread::JoinHandle<()>>,
}
impl Session {
    fn new(mut child: Child) -> Self {
        let input = child.stdin.take();
        let stdout = child.stdout.take().unwrap();
        let (tx, events) = mpsc::sync_channel(8);
        let reader = std::thread::spawn(move || {
            let mut reader = BufReader::new(stdout);
            loop {
                let mut line = Vec::new();
                let read = reader
                    .by_ref()
                    .take(8193)
                    .read_until(b'\n', &mut line)
                    .unwrap();
                if read == 0 {
                    let _ = tx.send(None);
                    break;
                }
                assert!(line.len() <= 8192 && line.ends_with(b"\n"));
                if tx
                    .send(Some(serde_json::from_slice(&line).unwrap()))
                    .is_err()
                {
                    break;
                }
            }
        });
        Self {
            child,
            input,
            events,
            reader: Some(reader),
        }
    }
    fn bytes(&mut self, bytes: &[u8]) {
        self.input.as_mut().unwrap().write_all(bytes).unwrap();
    }
    fn send(&mut self, value: Value) {
        self.bytes(format!("{value}\n").as_bytes());
    }
    fn capture(&mut self) {
        self.send(
            json!({"version":1,"original":"PRIVATE_ORIGINAL Do not deploy.\n{\"cancel\":{}} 保持"}),
        );
    }
    fn event(&self) -> Value {
        let event = self
            .events
            .recv_timeout(Duration::from_secs(6))
            .expect("bounded event wait")
            .expect("event before EOF");
        assert_eq!(event["version"], 1);
        assert_eq!(event["delivery"], "DeliveryNotAttempted");
        event
    }
    fn finish(mut self, success: bool) {
        let deadline = Instant::now() + Duration::from_secs(4);
        loop {
            if let Some(status) = self.child.try_wait().unwrap() {
                assert_eq!(status.success(), success);
                break;
            }
            assert!(Instant::now() < deadline, "child failed to terminate/reap");
            std::thread::sleep(Duration::from_millis(2));
        }
        assert_eq!(
            self.events.recv_timeout(Duration::from_secs(2)).unwrap(),
            None,
            "stdout closed, no independent worker retains pipe"
        );
        self.reader.take().unwrap().join().unwrap();
        let mut stderr = String::new();
        self.child
            .stderr
            .take()
            .unwrap()
            .read_to_string(&mut stderr)
            .unwrap();
        assert!(
            stderr.is_empty(),
            "no diagnostics/content logging: {stderr}"
        );
    }
}
impl Drop for Session {
    fn drop(&mut self) {
        if self.child.try_wait().unwrap().is_none() {
            let _ = self.child.kill();
            let _ = self.child.wait();
        }
    }
}
fn choose(name: &str, event: &Value) -> Value {
    json!({name:{"revision":event["revision"],"digest":event["digest"]}})
}
fn edit(event: &Value, text: &str) -> Value {
    json!({"edit":{"revision":event["revision"],"digest":event["digest"],"objective":text,"output_expectations":"Only propose verification."}})
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
            Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                assert!(Instant::now() < deadline);
                std::thread::sleep(Duration::from_millis(2));
            }
            Err(e) => panic!("owned accept: {e}"),
        }
    };
    stream.set_nonblocking(false).unwrap(); // required on macOS accepted sockets
    stream
        .set_read_timeout(Some(Duration::from_secs(3)))
        .unwrap();
    stream
        .set_write_timeout(Some(Duration::from_secs(3)))
        .unwrap();
    let mut header = Vec::new();
    while !header.ends_with(b"\r\n\r\n") {
        assert!(header.len() < 4096);
        let mut byte = [0];
        stream.read_exact(&mut byte).unwrap();
        header.push(byte[0]);
    }
    let header = String::from_utf8(header).unwrap();
    assert!(!header.to_ascii_lowercase().contains("authorization:"));
    let length = header
        .lines()
        .find_map(|line| {
            let (key, value) = line.split_once(':')?;
            key.eq_ignore_ascii_case("content-length")
                .then(|| value.trim().parse::<usize>().unwrap())
        })
        .unwrap();
    assert!(length <= 32768);
    let mut body = vec![0; length];
    stream.read_exact(&mut body).unwrap();
    (stream, serde_json::from_slice(&body).unwrap())
}
fn respond(mut stream: TcpStream, fail: bool, questions: bool) {
    let body = if fail {
        "PRIVATE_PROVIDER_ERROR".into()
    } else {
        json!({"choices":[{"finish_reason":"stop","message":{"role":"assistant","content":json!({
            "objective":"PRIVATE_PROVIDER Candidate", "output_expectations":"Propose checks only.",
            "unknowns":[], "questions":if questions {vec!["Which policy?"]} else {vec![]},
        }).to_string()}}]})
        .to_string()
    };
    let status = if fail { "500 Error" } else { "200 OK" };
    let _ = stream.write_all(format!("HTTP/1.1 {status}\r\nContent-Type: application/json\r\nContent-Length: {}\r\n\r\n{body}", body.len()).as_bytes());
}
fn server(
    listener: TcpListener,
    fail: bool,
    questions: bool,
) -> std::thread::JoinHandle<TcpListener> {
    std::thread::spawn(move || {
        let (stream, body) = receive(&listener);
        assert_eq!(body["max_tokens"], 1024);
        let context: Value =
            serde_json::from_str(body["messages"][1]["content"].as_str().unwrap()).unwrap();
        assert!(
            context["original"]
                .as_str()
                .unwrap()
                .contains("PRIVATE_ORIGINAL")
        );
        assert_eq!(context["evidence"].as_array().unwrap().len(), 1);
        respond(stream, fail, questions);
        listener
    })
}
fn one_call(server: std::thread::JoinHandle<TcpListener>) {
    assert_eq!(
        server.join().unwrap().accept().unwrap_err().kind(),
        std::io::ErrorKind::WouldBlock
    );
}

#[test]
fn retained_preview_edit_stale_reject_fresh_exact_handoff() {
    let fixture = Fixture::new();
    let (listener, endpoint) = listener();
    let mut child = fixture.child(&fixture.flags(&endpoint));
    let server = server(listener, false, false);
    child.capture();
    let preview = child.event();
    assert_eq!(preview["event"], "preview");
    assert_eq!(preview["revision"], 1);
    assert_eq!(preview["digest"].as_str().unwrap().len(), 64);
    child.send(edit(
        &preview,
        "PRIVATE_EDIT Do not deploy.\n{\"use-original\":{}}",
    ));
    let edited = child.event();
    assert_eq!(edited["event"], "preview");
    assert_eq!(edited["revision"], 2);
    assert_ne!(edited["digest"], preview["digest"]);
    assert!(
        edited["proposed"]
            .as_str()
            .unwrap()
            .contains("PRIVATE_EDIT")
    );
    child.send(choose("use-prepared", &preview));
    let stale = child.event();
    assert_eq!(stale["code"], "ReviewRequired");
    child.send(choose("use-prepared", &edited));
    let handoff = child.event();
    assert_eq!(handoff["event"], "handoff");
    assert_eq!(handoff["text"], edited["proposed"]);
    child.finish(true);
    one_call(server);
    fixture.unchanged();
}

#[test]
fn provider_failure_requires_explicit_original_and_questions_block_prepared() {
    for fail in [true, false] {
        let fixture = Fixture::new();
        let (listener, endpoint) = listener();
        let mut child = fixture.child(&fixture.flags(&endpoint));
        let server = server(listener, fail, !fail);
        child.capture();
        let review = child.event();
        assert_eq!(review["event"], if fail { "failure" } else { "needsinput" });
        if fail {
            assert!(!review.to_string().contains("PRIVATE_ORIGINAL"));
        }
        child.send(choose("use-prepared", &review));
        assert_eq!(child.event()["code"], "ReviewRequired");
        // An edit cannot clear questions or trigger a second inference.
        let review = if !fail {
            child.send(edit(&review, "PRIVATE_EDIT"));
            let next = child.event();
            assert_eq!(next["event"], "needsinput");
            child.send(choose("use-prepared", &next));
            assert_eq!(child.event()["code"], "ReviewRequired");
            next
        } else {
            review
        };
        child.send(choose("use-original", &review));
        let handoff = child.event();
        assert_eq!(handoff["event"], "handoff");
        assert_eq!(
            handoff["text"],
            "PRIVATE_ORIGINAL Do not deploy.\n{\"cancel\":{}} 保持"
        );
        child.finish(true);
        one_call(server);
        fixture.unchanged();
    }
}

#[test]
fn changes_after_edit_invalidate_prepared_and_original_including_failure() {
    for scenario in [
        "source",
        "policy",
        "incarnation",
        "root",
        "snapshot",
        "failure-source",
    ] {
        let fixture = Fixture::new();
        let (listener, endpoint) = listener();
        let mut child = fixture.child(&fixture.flags(&endpoint));
        let server = server(listener, scenario == "failure-source", false);
        child.capture();
        let review = child.event();
        let review = if scenario != "failure-source" {
            child.send(edit(&review, "PRIVATE_EDIT"));
            child.event()
        } else {
            review
        };
        match scenario {
            "source" | "failure-source" => std::fs::write(
                fixture.0.join("source/main.rs"),
                "fn synthetic_changed() {}\n",
            )
            .unwrap(),
            "policy" => {
                fixture.ok(&["project", "sources", "synthetic", "main.rs"]);
            }
            "snapshot" => {
                std::fs::write(
                    fixture.0.join("source/main.rs"),
                    "fn synthetic_blue_changed() {}\n",
                )
                .unwrap();
                fixture.ok(&["index", "synthetic"]);
            }
            "incarnation" => {
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
            "root" => {
                std::fs::rename(fixture.0.join("source"), fixture.0.join("old")).unwrap();
                std::fs::create_dir(fixture.0.join("source")).unwrap();
                std::fs::write(fixture.0.join("source/main.rs"), "fn synthetic_blue() {}\n")
                    .unwrap();
            }
            _ => unreachable!(),
        }
        child.send(choose(
            if scenario == "source" {
                "use-prepared"
            } else {
                "use-original"
            },
            &review,
        ));
        let failure = child.event();
        assert_eq!(failure["event"], "failure");
        assert!(failure.get("text").is_none());
        assert_ne!(failure["code"], "ReviewRequired");
        child.finish(false);
        one_call(server);
    }
}

#[test]
fn cancel_and_eof_during_provider_or_idle_close_and_reap_without_late_results() {
    for during_call in [true, false] {
        for cancel in [true, false] {
            let fixture = Fixture::new();
            let (listener, endpoint) = listener();
            let mut child = fixture.child(&fixture.flags(&endpoint));
            child.capture();
            let (stream, _) = receive(&listener);
            if !during_call {
                respond(stream.try_clone().unwrap(), false, false);
                assert_eq!(child.event()["event"], "preview");
            }
            let start = Instant::now();
            if cancel {
                child.send(json!({"cancel":{}}));
            } else {
                drop(child.input.take());
            }
            let canceled = child.event();
            assert_eq!(canceled["event"], "canceled");
            child.finish(false);
            assert!(
                start.elapsed() < Duration::from_secs(3),
                "did not wait for provider 30s deadline"
            );
            if during_call {
                respond(stream, false, false);
            }
            fixture.unchanged();
        }
    }
}

#[test]
fn strict_first_frames_reject_without_provider_or_plaintext_output() {
    let fixture = Fixture::new();
    let (listener, endpoint) = listener();
    let flags = fixture.flags(&endpoint);
    let cases = [
        b"{\"version\":1,\"original\":\"PRIVATE_ORIGINAL\",\"original\":\"x\"}\n".to_vec(),
        b"{\"version\":1,\"version\":1,\"original\":\"PRIVATE_ORIGINAL\"}\n".to_vec(),
        b"{\"version\":1,\"original\":\"PRIVATE_ORIGINAL\",\"evidence\":[]}\n".to_vec(),
        b"{\"version\":1,\"original\":\"PRIVATE_ORIGINAL\"} {}\n".to_vec(),
        b"{\"version\":2,\"original\":\"PRIVATE_ORIGINAL\"}\n".to_vec(),
        b"{\"cancel\":{}}\n".to_vec(),
        b"[1,\"PRIVATE_ORIGINAL\"]\n".to_vec(),
        b"not json\n".to_vec(),
        b"{\"version\":1,\"original\":\"\xff\"}\n".to_vec(),
        format!("{}\n", json!({"version":1,"original":"x".repeat(4097)})).into_bytes(),
        vec![b'x'; 8192],
    ];
    for bytes in cases {
        let mut child = fixture.child(&flags);
        child.bytes(&bytes);
        let failed = child.event();
        assert_eq!(failed["event"], "failure");
        assert!(!failed.to_string().contains("PRIVATE_ORIGINAL"));
        child.finish(false);
    }
    let mut child = fixture.child(&flags);
    child.bytes(b"{\"version\":1");
    drop(child.input.take());
    assert_eq!(child.event()["event"], "failure");
    child.finish(false);
    assert_eq!(
        listener.accept().unwrap_err().kind(),
        std::io::ErrorKind::WouldBlock
    );
    fixture.unchanged();
}

#[test]
fn strict_actions_premature_commands_and_frame_exhaustion_close() {
    for bytes in [
        b"{\"use-original\":{\"revision\":1,\"digest\":\"x\",\"digest\":\"y\"}}\n".as_slice(),
        b"{\"cancel\":{\"extra\":true}}\n",
        b"{\"cancel\":[]}\n",
        b"{\"use-original\":[1,\"x\"]}\n",
        b"{\"cancel\":{},\"cancel\":{}}\n",
        b"{\"edit\":{\"revision\":1,\"digest\":\"x\",\"objective\":\"x\",\"output_expectations\":\"x\",\"original\":\"changed\"}}\n",
        b"{\"execute\":\"touch something\"}\n", b"{} {}\n",
    ] {
        let fixture = Fixture::new(); let (listener, endpoint) = listener();
        let mut child = fixture.child(&fixture.flags(&endpoint)); let server = server(listener, false, false);
        child.capture(); child.event(); child.bytes(bytes);
        assert_eq!(child.event()["event"], "failure"); child.finish(false); one_call(server);
    }
    let fixture = Fixture::new();
    let (waiting_listener, endpoint) = listener();
    let mut child = fixture.child(&fixture.flags(&endpoint));
    child.capture();
    let (stream, _) = receive(&waiting_listener);
    child.send(json!({"use-original":{"revision":1,"digest":"guessed"}}));
    assert_eq!(child.event()["code"], "Invalid");
    child.finish(false);
    drop(stream);

    let fixture = Fixture::new();
    let (listener, endpoint) = listener();
    let mut child = fixture.child(&fixture.flags(&endpoint));
    let server = server(listener, false, false);
    child.capture();
    let preview = child.event();
    let mut stale = choose("use-prepared", &preview);
    stale["use-prepared"]["revision"] = json!(0);
    // First capture + six recoverable failures + seventh action = eight inputs.
    for _ in 0..6 {
        child.send(stale.clone());
        assert_eq!(child.event()["code"], "ReviewRequired");
    }
    child.send(stale);
    assert_eq!(child.event()["code"], "Overflow");
    child.finish(false);
    one_call(server);
}

#[test]
fn parent_kill_with_stdin_open_leaves_no_worker_holding_stdout() {
    for during_call in [true, false] {
        let fixture = Fixture::new();
        let (listener, endpoint) = listener();
        let mut child = fixture.child(&fixture.flags(&endpoint));
        child.capture();
        let (stream, _) = receive(&listener);
        if !during_call {
            respond(stream.try_clone().unwrap(), false, false);
            child.event();
        }
        child.child.kill().unwrap();
        child.finish(false);
        if during_call {
            respond(stream, false, false);
        }
        fixture.unchanged();
    }
}

#[test]
fn expected_capture_mismatch_and_missing_consent_never_contact_provider() {
    let fixture = Fixture::new();
    let (listener, endpoint) = listener();
    for flag in [
        "--expected-root",
        "--expected-root-identity",
        "--expected-incarnation",
        "--expected-snapshot",
    ] {
        let mut flags = fixture.flags(&endpoint);
        let index = flags.iter().position(|word| word == flag).unwrap();
        flags[index + 1] = match flag {
            "--expected-root" => "/synthetic-other".into(),
            "--expected-root-identity" => "synthetic-other".into(),
            "--expected-incarnation" => "0".repeat(32),
            _ => "0".repeat(64),
        };
        let mut child = fixture.child(&flags);
        child.capture();
        assert_eq!(child.event()["code"], "ScopeMismatch");
        child.finish(false);
    }
    let mut flags = fixture.flags(&endpoint);
    flags.pop();
    let output = fixture.command(&flags).output().unwrap();
    assert_eq!(output.status.code(), Some(2));
    assert_eq!(
        serde_json::from_slice::<Value>(&output.stdout).unwrap()["code"],
        "Invalid"
    );
    assert!(output.stderr.is_empty());
    assert_eq!(
        listener.accept().unwrap_err().kind(),
        std::io::ErrorKind::WouldBlock
    );
}

#[test]
fn human_note_history_preserved_and_queue_cannot_approve_an_edited_preview() {
    let fixture = Fixture::new();
    for (verb, note) in [
        ("add", "Synthetic human note one"),
        ("update", "Synthetic human note two"),
    ] {
        let words = ["context", verb, "synthetic", "memo", "note"].map(str::to_owned);
        let mut child = fixture.command(&words).spawn().unwrap();
        child
            .stdin
            .take()
            .unwrap()
            .write_all(note.as_bytes())
            .unwrap();
        assert!(child.wait_with_output().unwrap().status.success());
    }
    let before = fixture.ok(&["context", "show", "synthetic", "memo"]);
    let (listener, endpoint) = listener();
    let mut child = fixture.child(&fixture.flags(&endpoint));
    let server = server(listener, false, false);
    child.capture();
    let preview = child.event();
    child.bytes(
        format!(
            "{}\n{}\n",
            edit(&preview, "PRIVATE_EDIT"),
            choose("use-prepared", &preview)
        )
        .as_bytes(),
    );
    // Depending on scheduling the bounded single slot either rejects the burst,
    // or publishes the edit then rejects the queued old equality challenge.
    let event = child.event();
    if event["event"] == "preview" {
        let rejected = child.event();
        assert_eq!(rejected["event"], "failure");
        if rejected["code"] == "ReviewRequired" {
            child.send(json!({"cancel":{}}));
            assert_eq!(child.event()["event"], "canceled");
        }
    } else {
        assert_eq!(event["event"], "failure");
    }
    child.finish(false);
    one_call(server);
    assert_eq!(
        fixture.ok(&["context", "show", "synthetic", "memo"]),
        before
    );
    assert_eq!(
        std::fs::read_to_string(fixture.0.join("source/main.rs")).unwrap(),
        "fn synthetic_blue() {}\n"
    );
}

#[test]
#[ignore = "real production 300-second process deadline; run explicitly"]
fn actual_cli_idle_deadline_terminates_with_stdin_open() {
    let fixture = Fixture::new();
    let (listener, endpoint) = listener();
    let mut child = fixture.child(&fixture.flags(&endpoint));
    // No first frame, and stdin intentionally remains open. The watchdog must
    // end the whole process and close stdout, not strand a reader worker.
    let start = Instant::now();
    if let Some(event) = child.events.recv_timeout(Duration::from_secs(310)).unwrap() {
        // The ordinary receive timeout can win the watchdog race and publish
        // closed metadata. Neither a final event nor its absence is acceptance.
        assert_eq!(event["event"], "failure");
        assert_eq!(event["code"], "Deadline");
        assert_eq!(
            child.events.recv_timeout(Duration::from_secs(2)).unwrap(),
            None
        );
    }
    assert!(start.elapsed() >= Duration::from_secs(299));
    assert!(start.elapsed() < Duration::from_secs(310));
    assert!(!child.child.wait().unwrap().success());
    child.reader.take().unwrap().join().unwrap();
    assert_eq!(
        listener.accept().unwrap_err().kind(),
        std::io::ErrorKind::WouldBlock
    );
    fixture.unchanged();
}

#[test]
#[ignore = "real production 30-second provider deadline; run explicitly"]
fn actual_cli_provider_deadline_closes_instead_of_original_fallback() {
    let fixture = Fixture::new();
    let (listener, endpoint) = listener();
    let mut child = fixture.child(&fixture.flags(&endpoint));
    child.capture();
    let (stream, _) = receive(&listener);
    let start = Instant::now();
    let event = child
        .events
        .recv_timeout(Duration::from_secs(35))
        .unwrap()
        .unwrap();
    assert_eq!(event["event"], "failure");
    assert_eq!(event["code"], "Deadline");
    assert!(!event.to_string().contains("PRIVATE_ORIGINAL"));
    assert!(start.elapsed() >= Duration::from_secs(29));
    assert!(start.elapsed() < Duration::from_secs(35));
    child.finish(false);
    respond(stream, false, false);
    fixture.unchanged();
}
