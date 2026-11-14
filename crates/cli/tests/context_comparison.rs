//! AA-01/02/05/06 actual CLI + actual daemon, synthetic local data only.
use serde_json::{Value, json};
use std::io::{Read, Write};
use std::path::PathBuf;
use std::process::{Command, Output, Stdio};
use std::sync::atomic::AtomicBool;
use threadmark_daemon::knowledge::{Command as K, run};

struct Fixture(PathBuf);
impl Fixture {
    fn new() -> Self {
        static NEXT: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        let root = std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-aa-cli-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
        ));
        std::fs::create_dir(&root).unwrap();
        Self(root)
    }
    fn command(&self, args: &[&str]) -> Command {
        let mut command = Command::new(env!("CARGO_BIN_EXE_threadmark"));
        command
            .arg("--data-dir")
            .arg(self.0.join("store"))
            .args(args);
        command
    }
    fn run(&self, args: &[&str], text: Option<&str>) -> Output {
        let mut child = self
            .command(args)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .unwrap();
        if let Some(text) = text {
            let _ = child.stdin.take().unwrap().write_all(text.as_bytes());
        }
        child.wait_with_output().unwrap()
    }
    fn json(&self, args: &[&str], text: Option<&str>) -> Value {
        let out = self.run(args, text);
        assert!(
            out.status.success(),
            "{}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert!(out.stderr.is_empty());
        serde_json::from_slice(&out.stdout).unwrap()
    }
    fn register(&self) -> Value {
        let root = self.0.join("source");
        std::fs::create_dir(&root).unwrap();
        std::fs::write(root.join("code.rs"), "// synthetic unchanged\n").unwrap();
        self.json(
            &["project", "add", "app", root.to_str().unwrap(), "code.rs"],
            None,
        );
        self.json(&["project", "show", "app"], None)
    }
    fn compare_args<'a>(&self, p: &'a Value, from: &'a str, to: &'a str) -> Vec<&'a str> {
        let mut args = vec!["context", "compare", "app", "memo", from, to];
        args.extend(flags(p));
        args
    }
    fn sql(&self, sql: &str) {
        assert!(Command::new("python3").args(["-c", "import sqlite3,sys; db=sqlite3.connect(sys.argv[1]); db.executescript(sys.argv[2]); db.close()"])
            .arg(self.0.join("store/knowledge.sqlite")).arg(sql).status().unwrap().success());
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        std::fs::remove_dir_all(&self.0).unwrap();
    }
}
fn flags(p: &Value) -> Vec<&str> {
    vec![
        "--expected-root",
        p["root"].as_str().unwrap(),
        "--expected-root-identity",
        p["root_identity"].as_str().unwrap(),
        "--expected-incarnation",
        p["incarnation"].as_str().unwrap(),
    ]
}
fn failed(out: Output) {
    assert!(!out.status.success());
    assert!(out.stdout.is_empty());
    assert!(
        !String::from_utf8(out.stderr)
            .unwrap()
            .contains("PRIVATE-SYNTHETIC")
    );
}
fn reconstruct(v: &Value, which: &str) -> String {
    let d = &v["delta"];
    format!(
        "{}{}{}",
        d["prefix"].as_str().unwrap(),
        d[which].as_str().unwrap(),
        d["suffix"].as_str().unwrap()
    )
}
fn daemon_compare(p: &Value, from: u32, to: u32) -> K {
    K::CompareContextBound(
        "app".into(),
        "memo".into(),
        from,
        to,
        p["root"].as_str().unwrap().into(),
        p["root_identity"].as_str().unwrap().into(),
        p["incarnation"].as_str().unwrap().into(),
    )
}

#[test]
fn cli_and_daemon_edit_review_stale_cas_fresh_compare_and_preservation() {
    let f = Fixture::new();
    let p = f.register();
    let first = "PRIVATE-SYNTHETIC é\r\nshared\n";
    let second = "PRIVATE-SYNTHETIC e\u{301}\r\nshared\n";
    f.json(&["context", "add", "app", "memo", "note"], Some(first));
    f.json(
        &["context", "update", "app", "memo", "constraint"],
        Some(second),
    );
    f.json(&["context", "retire", "app", "memo"], None);
    let v = f.json(&f.compare_args(&p, "1", "3"), None);
    assert_eq!(reconstruct(&v, "from"), first);
    assert_eq!(reconstruct(&v, "to"), second);
    assert_eq!(
        v["from"],
        json!({"revision":1,"kind":"note","retired":false})
    );
    assert_eq!(
        v["to"],
        json!({"revision":3,"kind":"constraint","retired":true})
    );
    assert_eq!(v["text_changed"], true);
    assert_eq!(v["kind_changed"], true);
    assert_eq!(v["retirement_changed"], true);
    assert_eq!(
        v,
        run(
            &f.0.join("store"),
            daemon_compare(&p, 1, 3),
            &AtomicBool::new(false)
        )
        .unwrap()
    );
    let history = f.json(&["context", "show", "app", "memo"], None);
    let mut stale = vec!["context", "update", "app", "memo", "decision"];
    stale.extend(flags(&p));
    stale.extend(["--expected-revision", "2"]);
    failed(f.run(&stale, Some("PRIVATE-SYNTHETIC stale")));
    assert_eq!(history, f.json(&["context", "show", "app", "memo"], None));
    assert_eq!(v, f.json(&f.compare_args(&p, "1", "3"), None));
    *stale.last_mut().unwrap() = "3";
    f.json(&stale, Some(second)); // explicit fresh edit reactivates
    let fresh = f.json(&f.compare_args(&p, "3", "4"), None);
    assert_eq!(fresh["text_changed"], false);
    assert_eq!(fresh["retirement_changed"], true);
    assert_eq!(fresh["to"]["retired"], false);
    let history = f.json(&["context", "show", "app", "memo"], None);
    f.json(&["index", "app"], None);
    f.json(
        &[
            "source",
            "forget",
            "app",
            "code.rs",
            "--confirm-forget-source",
        ],
        None,
    );
    assert_eq!(fresh, f.json(&f.compare_args(&p, "3", "4"), None));
    assert_eq!(history, f.json(&["context", "show", "app", "memo"], None));
    f.json(
        &[
            "context",
            "forget",
            "app",
            "memo",
            "--confirm-forget-local-history",
        ],
        None,
    );
    failed(f.run(&f.compare_args(&p, "1", "4"), None));
    failed(f.run(
        &["context", "add", "app", "memo", "note"],
        Some("no resurrection"),
    ));
    assert_eq!(
        std::fs::read_to_string(f.0.join("source/code.rs")).unwrap(),
        "// synthetic unchanged\n"
    );
}

// Bounded channel wait, not process polling; stdin remains open and empty.
fn held_stdin(f: &Fixture, args: &[&str], expected_status: i32) -> Vec<u8> {
    let mut child = f
        .command(args)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .unwrap();
    let held = child.stdin.take().unwrap();
    let mut stdout = child.stdout.take().unwrap();
    let (send, receive) = std::sync::mpsc::channel();
    let reader = std::thread::spawn(move || {
        let mut out = Vec::new();
        stdout.read_to_end(&mut out).unwrap();
        let _ = send.send(out);
    });
    let result = receive.recv_timeout(std::time::Duration::from_secs(5));
    if result.is_err() {
        child.kill().unwrap();
    }
    let status = child.wait().unwrap();
    drop(held);
    reader.join().unwrap();
    assert!(result.is_ok(), "comparison waited for stdin");
    assert_eq!(status.code(), Some(expected_status));
    result.unwrap()
}

#[test]
fn closed_cli_grammar_fails_before_held_stdin_or_storage_and_never_creates() {
    let f = Fixture::new();
    let p = json!({"root":"/synthetic", "root_identity":"identity", "incarnation":"0123456789abcdef0123456789abcdef"});
    let good = f.compare_args(&p, "1", "2");
    let mut cases = Vec::new();
    for length in 2..good.len() {
        cases.push(good[..length].to_vec());
    }
    for index in [4, 5] {
        for bad in [
            "",
            "0",
            "33",
            "4294967296",
            "-1",
            "+1",
            " 1",
            "1 ",
            "1\n",
            "１",
            "1.0",
        ] {
            let mut args = good.clone();
            args[index] = bad;
            cases.push(args);
        }
    }
    for (index, bad) in [
        (2, "../PRIVATE-SYNTHETIC"),
        (3, "bad/id"),
        (7, "relative"),
        (9, ""),
        (11, "legacy"),
    ] {
        let mut args = good.clone();
        args[index] = bad;
        cases.push(args);
    }
    let mut reversed = good.clone();
    reversed[4] = "2";
    reversed[5] = "1";
    cases.push(reversed);
    for extra in [
        vec!["--expected-root", "/synthetic"],
        vec!["--expected-root-identity", "identity"],
        vec!["--expected-incarnation", "0123456789abcdef0123456789abcdef"],
        vec!["--expected-revision", "1"],
        vec!["--expected-sources"],
        vec!["extra"],
    ] {
        let mut args = good.clone();
        args.extend(extra);
        cases.push(args);
    }
    let mut reordered = good.clone();
    reordered.swap(6, 8);
    reordered.swap(7, 9);
    cases.push(reordered);
    for args in &cases {
        assert!(held_stdin(&f, args, 2).is_empty());
        assert!(!f.0.join("store").exists());
    }
    assert!(held_stdin(&f, &good, 1).is_empty());
    assert!(!f.0.join("store").exists());
    // Invalid DB is untouched: malformed grammar must not attempt to open it.
    std::fs::create_dir(f.0.join("store")).unwrap();
    std::fs::write(
        f.0.join("store/knowledge.sqlite"),
        b"PRIVATE-SYNTHETIC not sqlite",
    )
    .unwrap();
    for args in &cases {
        assert!(held_stdin(&f, args, 2).is_empty());
    }
    assert_eq!(
        std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap(),
        b"PRIVATE-SYNTHETIC not sqlite"
    );
    failed(f.run(&good, None));
}

#[test]
fn valid_comparison_never_consumes_stdin_and_same_revision_has_empty_delta() {
    let f = Fixture::new();
    let p = f.register();
    let text = "PRIVATE-SYNTHETIC \"\\\t\r\n最後\n";
    f.json(&["context", "add", "app", "memo", "note"], Some(text));
    let output = held_stdin(&f, &f.compare_args(&p, "01", "001"), 0);
    let v: Value = serde_json::from_slice(&output).unwrap();
    assert_eq!(v["text_changed"], false);
    assert_eq!(v["kind_changed"], false);
    assert_eq!(v["retirement_changed"], false);
    assert_eq!(v["delta"]["from"], "");
    assert_eq!(v["delta"]["to"], "");
    assert_eq!(reconstruct(&v, "from"), text);
    assert!(output.len() <= 65536);
    assert_eq!(*output.last().unwrap(), b'\n');
    assert_eq!(
        output,
        f.run(
            &f.compare_args(&p, "1", "1"),
            Some("ignored PRIVATE-SYNTHETIC stdin")
        )
        .stdout
    );
}

#[test]
fn actual_daemon_validation_existing_store_cancel_and_missing_revision() {
    use threadmark_core::Error;
    let f = Fixture::new();
    let good = json!({"root":"/synthetic", "root_identity":"identity", "incarnation":"0123456789abcdef0123456789abcdef"});
    for (from, to) in [(0, 1), (1, 0), (2, 1), (1, 33), (u32::MAX, u32::MAX)] {
        assert!(matches!(
            run(
                &f.0.join("store"),
                daemon_compare(&good, from, to),
                &AtomicBool::new(false)
            ),
            Err(Error::InvalidExtraction)
        ));
    }
    for (project, note, root, identity, nonce) in [
        (
            "../bad",
            "memo",
            "/synthetic",
            "identity",
            "0123456789abcdef0123456789abcdef",
        ),
        (
            "app",
            "../bad",
            "/synthetic",
            "identity",
            "0123456789abcdef0123456789abcdef",
        ),
        (
            "app",
            "memo",
            "relative",
            "identity",
            "0123456789abcdef0123456789abcdef",
        ),
        (
            "app",
            "memo",
            "/synthetic",
            "",
            "0123456789abcdef0123456789abcdef",
        ),
        ("app", "memo", "/synthetic", "identity", "legacy"),
    ] {
        let command = K::CompareContextBound(
            project.into(),
            note.into(),
            1,
            1,
            root.into(),
            identity.into(),
            nonce.into(),
        );
        assert!(matches!(
            run(&f.0.join("store"), command, &AtomicBool::new(false)),
            Err(Error::InvalidExtraction) | Err(Error::InvalidIdentity)
        ));
    }
    assert!(
        run(
            &f.0.join("store"),
            daemon_compare(&good, 1, 1),
            &AtomicBool::new(false)
        )
        .is_err()
    );
    assert!(matches!(
        run(
            &f.0.join("store"),
            daemon_compare(&good, 1, 1),
            &AtomicBool::new(true)
        ),
        Err(Error::Canceled)
    ));
    assert!(!f.0.join("store").exists());
    let p = f.register();
    f.json(
        &["context", "add", "app", "memo", "note"],
        Some("PRIVATE-SYNTHETIC"),
    );
    let before = std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap();
    assert!(
        run(
            &f.0.join("store"),
            daemon_compare(&p, 1, 2),
            &AtomicBool::new(false)
        )
        .is_err()
    );
    failed(f.run(&f.compare_args(&p, "1", "2"), None));
    assert_eq!(
        before,
        std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap()
    );
}

#[test]
fn schema_v3_supported_v2_fails_without_migration_trusted_history_unchanged() {
    let f = Fixture::new();
    let p = f.register();
    f.json(
        &["context", "add", "app", "memo", "note"],
        Some("PRIVATE-SYNTHETIC"),
    );
    let history = f.json(&["context", "show", "app", "memo"], None);
    let v4 = f.json(&f.compare_args(&p, "1", "1"), None);
    f.sql("DROP TRIGGER threadmark_source_policy_guard; DROP TRIGGER threadmark_source_evidence_guard; DROP TRIGGER threadmark_source_project_delete_guard; DROP TABLE forgotten_sources; PRAGMA user_version=3;");
    assert_eq!(v4, f.json(&f.compare_args(&p, "1", "1"), None));
    f.sql("DROP TRIGGER threadmark_project_incarnation_insert; DROP TRIGGER threadmark_project_incarnation_delete; DROP TABLE project_incarnations; PRAGMA user_version=2;");
    let before = std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap();
    failed(f.run(&f.compare_args(&p, "1", "1"), None));
    assert!(
        run(
            &f.0.join("store"),
            daemon_compare(&p, 1, 1),
            &AtomicBool::new(false)
        )
        .is_err()
    );
    assert_eq!(history, f.json(&["context", "show", "app", "memo"], None));
    assert_eq!(
        before,
        std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap()
    );
    f.sql("CREATE TABLE malformed_dependency(x);");
    let before = std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap();
    failed(f.run(&f.compare_args(&p, "1", "1"), None));
    assert_eq!(
        before,
        std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap()
    );
}
