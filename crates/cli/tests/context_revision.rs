//! Synthetic revision-guard v1 CLI/daemon/SQLite acceptance; no native/UI scope.
use serde_json::Value;
use std::io::Write;
use std::path::PathBuf;
use std::process::{Command, Output, Stdio};

struct Fixture(PathBuf);
impl Fixture {
    fn new() -> Self {
        static NEXT: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        let root = std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-revision-cli-{}-{}",
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
            // Invalid metadata can close stdin without consuming it.
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
        serde_json::from_slice(&out.stdout).unwrap()
    }
    fn register(&self) -> Value {
        let root = self.0.join("source");
        std::fs::create_dir(&root).unwrap();
        std::fs::write(root.join("code.rs"), "// synthetic unchanged\n").unwrap();
        self.json(
            &["project", "add", "a", root.to_str().unwrap(), "code.rs"],
            None,
        );
        self.json(&["project", "show", "a"], None)
    }
    fn bound(&self, op: &str, p: &Value, revision: &str, text: Option<&str>) -> Output {
        let mut args = vec!["context", op, "a", "note"];
        if op == "update" {
            args.push("decision");
        }
        args.extend(flags(p, revision));
        self.run(&args, text)
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        std::fs::remove_dir_all(&self.0).unwrap();
    }
}
fn flags<'a>(p: &'a Value, revision: &'a str) -> Vec<&'a str> {
    vec![
        "--expected-root",
        p["root"].as_str().unwrap(),
        "--expected-root-identity",
        p["root_identity"].as_str().unwrap(),
        "--expected-incarnation",
        p["incarnation"].as_str().unwrap(),
        "--expected-revision",
        revision,
    ]
}
fn no_publication(out: Output) {
    assert!(!out.status.success());
    assert!(out.stdout.is_empty());
    let err = String::from_utf8(out.stderr).unwrap();
    assert!(!err.contains("PRIVATE-SYNTHETIC"));
}

#[test]
fn guarded_cli_update_retire_stale_retry_restart_and_trusted_compatibility() {
    let f = Fixture::new();
    let p = f.register();
    f.json(
        &["context", "add", "a", "note", "note"],
        Some("synthetic first"),
    );
    // A separate CLI process is the peer, using an unchanged trusted form.
    f.json(
        &["context", "update", "a", "note", "constraint"],
        Some("synthetic peer"),
    );
    let before = f.json(&["context", "show", "a", "note"], None);
    for op in ["update", "retire"] {
        no_publication(f.bound(op, &p, "1", Some("PRIVATE-SYNTHETIC stale")));
        assert_eq!(f.json(&["context", "show", "a", "note"], None), before);
    }
    assert!(
        f.bound("update", &p, "2", Some("synthetic fresh"))
            .status
            .success()
    );
    assert!(f.bound("retire", &p, "3", None).status.success());
    let after = f.json(&["context", "show", "a", "note"], None);
    assert_eq!(after["history"].as_array().unwrap().len(), 4);
    assert_eq!(after["history"][3]["text"], "synthetic fresh");
    assert_eq!(after["history"][3]["retired"], true);
    f.json(&["index", "a"], None);
    assert_eq!(f.json(&["context", "show", "a", "note"], None), after);
    // Prior namespace-only APIs/grammar remain supported without revision flags.
    let mut old_update = vec!["context", "update", "a", "note", "note"];
    old_update.extend(&flags(&p, "4")[..6]);
    f.json(&old_update, Some("synthetic legacy bound"));
    let mut old_retire = vec!["context", "retire", "a", "note"];
    old_retire.extend(&flags(&p, "5")[..6]);
    f.json(&old_retire, None);
    f.json(&["context", "retire", "a", "note"], None);
    assert_eq!(
        f.json(&["context", "show", "a", "note"], None)["history"]
            .as_array()
            .unwrap()
            .len(),
        7
    );
    let mut add = vec!["context", "add", "a", "note", "note"];
    add.extend(&flags(&p, "7")[..6]);
    no_publication(f.run(&add, Some("PRIVATE-SYNTHETIC duplicate add")));
    // Removal/re-registration can repeat revision one, but not incarnation.
    f.json(
        &["project", "remove", "a", "--confirm-remove-local-data"],
        None,
    );
    f.json(
        &[
            "project",
            "add",
            "a",
            p["root"].as_str().unwrap(),
            "code.rs",
        ],
        None,
    );
    f.json(
        &["context", "add", "a", "note", "note"],
        Some("synthetic replacement"),
    );
    no_publication(f.bound("update", &p, "1", Some("PRIVATE-SYNTHETIC stale namespace")));
    no_publication(f.bound("retire", &p, "1", None));
    assert_eq!(
        f.json(&["context", "show", "a", "note"], None)["history"]
            .as_array()
            .unwrap()
            .len(),
        1
    );
    assert_eq!(
        std::fs::read_to_string(f.0.join("source/code.rs")).unwrap(),
        "// synthetic unchanged\n"
    );
}

#[test]
fn invalid_metadata_and_flags_fail_before_waiting_on_stdin_or_creating_storage() {
    use std::io::Read;
    let f = Fixture::new();
    let p = serde_json::json!({"root":"/synthetic", "root_identity":"1:2", "incarnation":"0123456789abcdef0123456789abcdef"});
    let mut cases = Vec::new();
    for rev in [
        "0",
        "33",
        "4294967296",
        "18446744073709551616",
        "-1",
        "+1",
        "1x",
        "",
        " 1",
    ] {
        let mut args = vec!["context", "update", "a", "note", "note"];
        args.extend(flags(&p, rev));
        cases.push(args);
    }
    let flag_list = flags(&p, "1");
    for count in 1..flag_list.len() {
        let mut args = vec!["context", "update", "a", "note", "note"];
        args.extend(&flag_list[..count]);
        // Six flags alone are the intentionally compatible namespace-only form.
        if count != 6 {
            cases.push(args);
        }
    }
    for (index, value) in [(2, "../PRIVATE-SYNTHETIC"), (3, "bad/id"), (4, "authority")] {
        let mut args = vec!["context", "update", "a", "note", "note"];
        args[index] = value;
        args.extend(&flag_list);
        cases.push(args);
    }
    for index in [1, 3, 5] {
        let mut flags = flag_list.clone();
        flags[index] = "PRIVATE-SYNTHETIC-invalid";
        let mut args = vec!["context", "update", "a", "note", "note"];
        args.extend(flags);
        // root identity is opaque, not a fixed numeric encoding.
        if index != 3 {
            cases.push(args);
        }
    }
    for duplicate in [
        vec!["--expected-revision", "1"],
        vec!["--expected-incarnation", "0123456789abcdef0123456789abcdef"],
        vec!["--unknown", "x"],
    ] {
        let mut args = vec!["context", "update", "a", "note", "note"];
        args.extend(&flag_list);
        args.extend(duplicate);
        cases.push(args);
    }
    let mut unbound = vec!["context", "update", "a", "note", "note"];
    unbound.extend(["--expected-revision", "1"]);
    cases.push(unbound);
    let mut add = vec!["context", "add", "a", "note", "note"];
    add.extend(&flag_list);
    cases.push(add);
    for args in cases {
        let mut child = f
            .command(&args)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .spawn()
            .unwrap();
        // Keep stdin open and empty. EOF on stdout proves parsing did not wait
        // for text. This is a bounded channel wait, not process polling.
        let held_stdin = child.stdin.take().unwrap();
        let mut stdout = child.stdout.take().unwrap();
        let (send, receive) = std::sync::mpsc::channel();
        let reader = std::thread::spawn(move || {
            let mut out = Vec::new();
            stdout.read_to_end(&mut out).unwrap();
            send.send(out).unwrap();
        });
        let result = receive.recv_timeout(std::time::Duration::from_secs(5));
        if result.is_err() {
            child.kill().unwrap();
        }
        let status = child.wait().unwrap();
        drop(held_stdin);
        reader.join().unwrap();
        assert!(result.is_ok(), "invalid metadata waited for stdin");
        assert_eq!(status.code(), Some(2));
        assert!(result.unwrap().is_empty());
        assert!(!f.0.join("store").exists());
    }
    // Valid new operations still may not initialize an absent store.
    for op in ["update", "retire"] {
        no_publication(f.bound(op, &p, "1", Some("synthetic")));
        assert!(!f.0.join("store").exists());
    }
}

#[test]
fn invalid_text_and_daemon_commands_never_initialize_storage() {
    use std::sync::atomic::AtomicBool;
    use threadmark_daemon::knowledge::{Command as K, run};
    let f = Fixture::new();
    let p = serde_json::json!({"root":"/synthetic", "root_identity":"1:2", "incarnation":"0123456789abcdef0123456789abcdef"});
    for text in [
        String::new(),
        "x".repeat(4097),
        "界".repeat(1366),
        "synthetic\0text".into(),
    ] {
        no_publication(f.bound("update", &p, "1", Some(&text)));
        assert!(!f.0.join("store").exists());
        assert!(
            run(
                &f.0.join("store"),
                K::UpdateContextRevisionBound(
                    "a".into(),
                    "note".into(),
                    "note".into(),
                    text,
                    "/synthetic".into(),
                    "1:2".into(),
                    p["incarnation"].as_str().unwrap().into(),
                    1
                ),
                &AtomicBool::new(false)
            )
            .is_err()
        );
    }
    for revision in [0, 33, u32::MAX] {
        assert!(
            run(
                &f.0.join("store"),
                K::RetireContextRevisionBound(
                    "a".into(),
                    "note".into(),
                    "/synthetic".into(),
                    "1:2".into(),
                    p["incarnation"].as_str().unwrap().into(),
                    revision
                ),
                &AtomicBool::new(false)
            )
            .is_err()
        );
        assert!(!f.0.join("store").exists());
    }
    assert_eq!(
        run(
            &f.0.join("store"),
            K::RetireContextRevisionBound(
                "a".into(),
                "note".into(),
                "/synthetic".into(),
                "1:2".into(),
                p["incarnation"].as_str().unwrap().into(),
                1
            ),
            &AtomicBool::new(true)
        ),
        Err(threadmark_core::Error::Canceled)
    );
    assert!(!f.0.join("store").exists());
}
