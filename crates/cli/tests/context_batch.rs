//! AI-01/06/07: real CLI closed JSON admission and atomic persistence.
use serde_json::{Value, json};
use std::io::Write;
use std::path::PathBuf;
use std::process::{Command, Output, Stdio};

struct Fixture(PathBuf);
impl Fixture {
    fn new() -> Self {
        static NEXT: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        let root = std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-batch-cli-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
        ));
        std::fs::create_dir(&root).unwrap();
        Self(root)
    }
    fn command(&self, args: &[&str]) -> Command {
        let mut c = Command::new(env!("CARGO_BIN_EXE_threadmark"));
        c.arg("--data-dir").arg(self.0.join("store")).args(args);
        c
    }
    fn run(&self, args: &[&str], bytes: &[u8]) -> Output {
        let mut c = self
            .command(args)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .unwrap();
        let _ = c.stdin.take().unwrap().write_all(bytes);
        c.wait_with_output().unwrap()
    }
    fn json(&self, args: &[&str], bytes: &[u8]) -> Value {
        let out = self.run(args, bytes);
        assert!(
            out.status.success(),
            "{}",
            String::from_utf8_lossy(&out.stderr)
        );
        serde_json::from_slice(&out.stdout).unwrap()
    }
    fn setup(&self, n: usize) -> Value {
        std::fs::create_dir(self.0.join("source")).unwrap();
        std::fs::write(self.0.join("source/code.rs"), "// synthetic source\n").unwrap();
        self.json(
            &[
                "project",
                "add",
                "a",
                self.0.join("source").to_str().unwrap(),
                "code.rs",
            ],
            b"",
        );
        for i in 0..n {
            self.json(
                &["context", "add", "a", &format!("n{i}"), "note"],
                b"PRIVATE-SYNTHETIC original",
            );
        }
        self.json(&["project", "show", "a"], b"")
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        std::fs::remove_dir_all(&self.0).unwrap();
    }
}
fn args(p: &Value) -> Vec<&str> {
    vec![
        "context",
        "batch-edit",
        "a",
        "--expected-root",
        p["root"].as_str().unwrap(),
        "--expected-root-identity",
        p["root_identity"].as_str().unwrap(),
        "--expected-incarnation",
        p["incarnation"].as_str().unwrap(),
    ]
}
fn doc(n: usize, revision: u32) -> Value {
    json!({"version":"human-context-batch-edit-v1","actions":(0..n).map(|i|
        if i%2==0 {json!({"operation":"update","id":format!("n{i}"),"expected_revision":revision,"kind":"decision","text":"PRIVATE-SYNTHETIC edited"})}
        else {json!({"operation":"retire","id":format!("n{i}"),"expected_revision":revision})}).collect::<Vec<_>>()})
}
fn fail(out: Output) {
    assert!(!out.status.success());
    assert!(out.stdout.is_empty());
    let err = String::from_utf8(out.stderr).unwrap();
    assert!(!err.contains("PRIVATE-SYNTHETIC"));
}

#[test]
fn cli_two_through_eight_mixed_batches_reopen_and_stale_atomicity() {
    for n in 2..=8 {
        let f = Fixture::new();
        let p = f.setup(n);
        let receipt = f.json(&args(&p), &serde_json::to_vec(&doc(n, 1)).unwrap());
        assert_eq!(receipt["count"], n);
        assert!(!receipt.to_string().contains("PRIVATE-SYNTHETIC"));
        assert!(serde_json::to_vec(&receipt).unwrap().len() < 8192);
        let before: Vec<_> = (0..n)
            .map(|i| f.json(&["context", "show", "a", &format!("n{i}")], b""))
            .collect();
        fail(f.run(&args(&p), &serde_json::to_vec(&doc(n, 1)).unwrap()));
        for (i, h) in before.iter().enumerate() {
            assert_eq!(&f.json(&["context", "show", "a", &format!("n{i}")], b""), h);
        }
        let mut fresh = doc(n, 2);
        fresh["actions"][1] = json!({"operation":"update","id":"n1","expected_revision":2,"kind":"note","text":"synthetic deliberate reactivation"});
        f.json(&args(&p), &serde_json::to_vec(&fresh).unwrap());
        assert_eq!(
            f.json(&["context", "show", "a", "n1"], b"")["history"][2]["retired"],
            false
        );
    }
}

#[test]
fn cli_closed_duplicate_rejecting_document_and_action_validation() {
    let f = Fixture::new();
    let p = f.setup(2);
    let good = doc(2, 1).to_string();
    let mut bad = vec![
        good.replace("\"actions\":", "\"unknown\":0,\"actions\":"),
        good.replace(
            "\"version\":",
            "\"version\":\"human-context-batch-edit-v1\",\"version\":",
        ),
        good.replace("\"id\":\"n0\"", "\"id\":\"n0\",\"id\":\"n0\""),
        good.replace(
            "\"operation\":\"update\"",
            "\"operation\":\"retire\",\"operation\":\"update\"",
        ),
        good.replace("\"id\":\"n1\"", "\"id\":\"n0\""),
        good.replace("\"id\":\"n1\"", "\"id\":\"missing\""),
        good.replace("\"operation\":\"update\"", "\"operation\":\"add\""),
        good.replace(
            "\"operation\":\"retire\"",
            "\"text\":\"PRIVATE-SYNTHETIC\",\"operation\":\"retire\"",
        ),
        good.replace("\"id\":\"n0\"", "\"project\":\"b\",\"id\":\"n0\""),
        good.replace("decision", "source"),
        good.replace("PRIVATE-SYNTHETIC edited", ""),
        good.replace("PRIVATE-SYNTHETIC edited", "\\u0000"),
        format!("{good} {good}"),
        good[..good.len() - 1].into(),
    ];
    for rev in [
        "0",
        "33",
        "01",
        "1.0",
        "1e0",
        "-1",
        "+1",
        "\"1\"",
        "4294967296",
        "null",
    ] {
        bad.push(good.replace(
            "\"expected_revision\":1",
            &format!("\"expected_revision\":{rev}"),
        ));
    }
    for n in [0, 1, 9] {
        bad.push(doc(n, 1).to_string());
    }
    for size in [4097, 32769, 65537] {
        bad.push(good.replace("PRIVATE-SYNTHETIC edited", &"x".repeat(size)));
    }
    let before = f.json(&["context", "show", "a", "n0"], b"");
    for bytes in bad
        .iter()
        .map(String::as_bytes)
        .chain([&[0xff][..], &[0][..]])
    {
        fail(f.run(&args(&p), bytes));
    }
    assert_eq!(f.json(&["context", "show", "a", "n0"], b""), before);
}

#[test]
fn encoded_bound_and_utf8_text_byte_bound_apply_to_cli_and_typed_core() {
    let f = Fixture::new();
    let p = f.setup(8);
    // Eight valid 4096-byte fields, with JSON escaping pushing encoded size >65536.
    let mut d = doc(8, 1);
    for i in 0..8 {
        d["actions"][i] = json!({"operation":"update","id":format!("n{i}"),"expected_revision":1,"kind":"note","text":"\n".repeat(4096)});
    }
    assert!(d.to_string().len() > 65536);
    fail(f.run(&args(&p), d.to_string().as_bytes()));
    let typed: threadmark_core::knowledge::ContextBatchEdit = serde_json::from_value(d).unwrap();
    assert!(
        typed
            .validate(
                "a",
                &threadmark_core::knowledge::ContextReadBinding {
                    root: p["root"].as_str().unwrap(),
                    root_identity: p["root_identity"].as_str().unwrap(),
                    incarnation: p["incarnation"].as_str().unwrap(),
                }
            )
            .is_err()
    );
    let mut d = doc(2, 1);
    d["actions"][0]["text"] = json!("é".repeat(2049));
    fail(f.run(&args(&p), d.to_string().as_bytes()));
    d["actions"][0]["text"] = json!("é".repeat(2048));
    f.json(&args(&p), d.to_string().as_bytes());
}

#[test]
fn flags_fail_before_held_stdin_and_absent_store_is_not_created() {
    let f = Fixture::new();
    let p = json!({"root":"/synthetic","root_identity":"synthetic","incarnation":"0123456789abcdef0123456789abcdef"});
    let valid = args(&p);
    let mut cases = vec![vec!["context", "batch-edit", "a"], valid[..7].to_vec()];
    for extra in [
        "--unknown",
        "--expected-revision",
        "--expected-sources",
        "--expected-root",
    ] {
        let mut a = valid.clone();
        a.push(extra);
        cases.push(a);
    }
    let mut swapped = valid.clone();
    swapped.swap(3, 5);
    cases.push(swapped);
    for a in cases {
        let mut child = f
            .command(&a)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .unwrap();
        let held = child.stdin.take().unwrap();
        // Event-driven wait with a bounded deadline, not a polling fixture.
        let (tx, rx) = std::sync::mpsc::channel();
        let pid = child.id();
        let join = std::thread::spawn(move || {
            let out = child.wait_with_output().unwrap();
            tx.send(out).unwrap();
        });
        match rx.recv_timeout(std::time::Duration::from_secs(5)) {
            Ok(out) => fail(out),
            Err(e) => {
                drop(held);
                join.join().unwrap();
                panic!("held-stdin rejection deadline failed for owned child {pid}: {e}");
            }
        }
        drop(held);
        join.join().unwrap();
    }
    fail(f.run(&valid, doc(2, 1).to_string().as_bytes()));
    assert!(!f.0.join("store").exists());
}

#[test]
fn legacy_cli_failure_does_not_upgrade_and_typed_daemon_invalid_request_does_not_create() {
    let f = Fixture::new();
    let p = f.setup(2);
    let db = f.0.join("store/knowledge.sqlite");
    assert!(Command::new("python3").args(["-c","import sqlite3,sys; d=sqlite3.connect(sys.argv[1]); d.executescript('DROP TRIGGER threadmark_project_incarnation_insert; DROP TRIGGER threadmark_project_incarnation_delete; DROP TABLE project_incarnations; PRAGMA user_version=2;'); d.close()"])
        .arg(&db).status().unwrap().success());
    let before = std::fs::read(&db).unwrap();
    fail(f.run(&args(&p), doc(2, 1).to_string().as_bytes()));
    assert_eq!(std::fs::read(&db).unwrap(), before);
    let missing = Fixture::new();
    let mut d: threadmark_core::knowledge::ContextBatchEdit =
        serde_json::from_value(doc(2, 1)).unwrap();
    d.actions.push(d.actions[0].clone());
    assert!(
        threadmark_daemon::knowledge::run(
            &missing.0.join("store"),
            threadmark_daemon::knowledge::Command::EditContextBatchBound(
                "a".into(),
                d,
                p["root"].as_str().unwrap().into(),
                p["root_identity"].as_str().unwrap().into(),
                p["incarnation"].as_str().unwrap().into()
            ),
            &std::sync::atomic::AtomicBool::new(false)
        )
        .is_err()
    );
    assert!(!missing.0.join("store").exists());
}

#[test]
fn encoded_limit_accepts_exact_document_bytes_rejects_one_more() {
    let f = Fixture::new();
    let p = f.setup(2);
    let mut bytes = doc(2, 1).to_string().into_bytes();
    bytes.resize(65536, b' ');
    let mut oversize = bytes.clone();
    oversize.push(b' ');
    fail(f.run(&args(&p), &oversize));
    f.json(&args(&p), &bytes);
}
