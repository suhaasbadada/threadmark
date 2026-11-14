//! AD actual CLI -> typed daemon -> core acceptance, synthetic local files only.
use serde_json::Value;
use std::path::PathBuf;
use std::process::{Command, Output, Stdio};

struct Fixture(PathBuf);
impl Fixture {
    fn new(count: usize) -> (Self, Value) {
        static NEXT: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        let f = Self(std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-cli-coverage-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
        )));
        std::fs::create_dir(&f.0).unwrap();
        std::fs::create_dir(f.0.join("source")).unwrap();
        let mut add = words(&["project", "add", "a", f.0.join("source").to_str().unwrap()]);
        for i in 0..count {
            let name = format!("file{i}.rs");
            std::fs::write(
                f.0.join("source").join(&name),
                b"synthetic lexical anchor\n",
            )
            .unwrap();
            add.push(name);
        }
        f.json(&add);
        let p = f.json(&words(&["project", "show", "a"]));
        (f, p)
    }
    fn command(&self, args: &[String]) -> Command {
        let mut c = Command::new(env!("CARGO_BIN_EXE_threadmark"));
        c.arg("--data-dir").arg(self.0.join("store")).args(args);
        c
    }
    fn run(&self, args: &[String]) -> Output {
        self.command(args).stdin(Stdio::null()).output().unwrap()
    }
    fn json(&self, args: &[String]) -> Value {
        let o = self.run(args);
        assert!(o.status.success(), "{}", String::from_utf8_lossy(&o.stderr));
        assert!(o.stdout.len() <= 65536);
        serde_json::from_slice(&o.stdout).unwrap()
    }
    fn db(&self) -> PathBuf {
        self.0.join("store/knowledge.sqlite")
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        std::fs::remove_dir_all(&self.0).unwrap();
    }
}
fn words(a: &[&str]) -> Vec<String> {
    a.iter().map(|s| (*s).into()).collect()
}
fn coverage(p: &Value) -> Vec<String> {
    let mut args = words(&[
        "project",
        "coverage",
        "a",
        "--expected-root",
        p["root"].as_str().unwrap(),
        "--expected-root-identity",
        p["root_identity"].as_str().unwrap(),
        "--expected-incarnation",
        p["incarnation"].as_str().unwrap(),
        "--expected-snapshot",
        p["snapshot"].as_str().unwrap_or("none"),
        "--expected-sources",
    ]);
    args.extend(
        p["sources"]
            .as_array()
            .unwrap()
            .iter()
            .map(|s| s.as_str().unwrap().to_owned()),
    );
    args
}
fn refused(o: Output) {
    assert!(!o.status.success());
    assert!(o.stdout.is_empty());
    let errors = String::from_utf8(o.stderr).unwrap();
    assert!(!errors.contains("synthetic lexical"));
    assert!(!errors.contains("threadmark-cli-coverage-"));
}

#[test]
fn ad_a2_actual_full64_register_unindexed_build_current_mixed_restore_and_preserve() {
    let (f, p) = Fixture::new(64);
    let unindexed = f.json(&coverage(&p));
    assert_eq!(unindexed["files"].as_array().unwrap().len(), 64);
    assert_eq!(unindexed["summary"]["project_snapshot_current"], false);
    assert_eq!(unindexed["summary"]["needs_build"], true);
    f.json(&words(&["index", "a"]));
    refused(f.run(&coverage(&p))); // explicit none must not adopt new snapshot
    let p = f.json(&words(&["project", "show", "a"]));
    let mut s = threadmark_core::knowledge::Store::open_existing(&f.0.join("store")).unwrap();
    s.write_context("a", "draft", "note", "synthetic human history", false)
        .unwrap();
    s.write_context("a", "draft", "note", "synthetic revised history", true)
        .unwrap();
    let db = std::fs::read(f.db()).unwrap();
    let history = s.context("a", "draft").unwrap();
    let current = f.json(&coverage(&p));
    assert_eq!(current["format"], "threadmark-coverage-report");
    assert_eq!(current["version"], 1);
    assert_eq!(current["summary"]["project_snapshot_current"], true);
    assert_eq!(current["summary"]["stored_anchor_record_count"], 64);
    assert!(!current.to_string().contains("synthetic"));
    assert!(!current.to_string().contains(p["root"].as_str().unwrap()));
    let source = f.0.join("source/file0.rs");
    std::fs::write(&source, b"changed\n").unwrap();
    let mixed = f.json(&coverage(&p));
    assert_eq!(mixed["files"][0]["status"], "changed");
    assert_eq!(mixed["files"][1]["status"], "current");
    assert_eq!(mixed["summary"]["matching_file_count"], 63);
    assert_eq!(mixed["summary"]["project_snapshot_current"], false);
    std::fs::write(&source, b"synthetic lexical anchor\n").unwrap();
    assert_eq!(f.json(&coverage(&p)), current); // no implicit Build
    assert_eq!(std::fs::read(f.db()).unwrap(), db);
    assert_eq!(s.context("a", "draft").unwrap(), history);
    let mut extra = coverage(&p);
    extra.push("extra.rs".into());
    refused(f.run(&extra));
}

#[test]
fn ad_a1_cli_closed_grammar_preopen_missing_store_and_held_stdin() {
    let (f, p) = Fixture::new(1);
    let valid = coverage(&p);
    for flag in [
        "--expected-root",
        "--expected-root-identity",
        "--expected-incarnation",
        "--expected-snapshot",
        "--expected-sources",
    ] {
        let mut bad = valid.clone();
        bad.extend(words(&[flag, "duplicate"]));
        assert_eq!(f.run(&bad).status.code(), Some(2));
        let mut bad = valid.clone();
        let i = bad.iter().position(|s| s == flag).unwrap();
        bad.remove(i);
        assert_eq!(f.run(&bad).status.code(), Some(2));
    }
    let mut unknown = valid.clone();
    unknown.push("--unknown".into());
    assert_eq!(f.run(&unknown).status.code(), Some(2));
    let mut wrong_type = valid.clone();
    let i = wrong_type
        .iter()
        .position(|s| s == "--expected-snapshot")
        .unwrap();
    wrong_type[i + 1] = "true".into();
    assert_eq!(f.run(&wrong_type).status.code(), Some(2));
    let mut unicode = valid.clone();
    unicode[4] = format!("/{}", "λ".repeat(2048));
    assert_eq!(f.run(&unicode).status.code(), Some(2));
    std::fs::rename(f.0.join("store"), f.0.join("saved-store")).unwrap();
    for args in [&valid, &unknown] {
        refused(f.run(args));
        assert!(!f.0.join("store").exists());
    }
    std::fs::rename(f.0.join("saved-store"), f.0.join("store")).unwrap();
    let mut child = f
        .command(&valid)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    let held = child.stdin.take().unwrap();
    let pid = child.id();
    let (send, recv) = std::sync::mpsc::channel();
    let waiter = std::thread::spawn(move || send.send(child.wait_with_output().unwrap()).unwrap());
    let result = recv.recv_timeout(std::time::Duration::from_secs(5));
    if result.is_err() {
        let _ = Command::new("kill")
            .args(["-KILL", &pid.to_string()])
            .status();
    }
    drop(held);
    waiter.join().unwrap();
    assert!(result.unwrap().status.success());
}

#[test]
fn ad_a4_actual_wal_and_legacy_refusal_preserve_bytes_and_directory() {
    for wal in [true, false] {
        let (f, p) = Fixture::new(1);
        assert!(Command::new("python3").args(["-c", if wal {
            "import sqlite3,sys; d=sqlite3.connect(sys.argv[1]); assert d.execute('PRAGMA journal_mode=WAL').fetchone()[0]=='wal'; d.close()"
        } else {
            "import sqlite3,sys; d=sqlite3.connect(sys.argv[1]); d.executescript('DROP TRIGGER threadmark_source_project_delete_guard; DROP TRIGGER threadmark_source_evidence_guard; DROP TRIGGER threadmark_source_policy_guard; DROP TABLE forgotten_sources; DROP TRIGGER threadmark_project_incarnation_insert; DROP TRIGGER threadmark_project_incarnation_delete; DROP TABLE project_incarnations; PRAGMA user_version=2;'); d.close()"
        }]).arg(f.db()).status().unwrap().success());
        let bytes = std::fs::read(f.db()).unwrap();
        let entries = || {
            let mut n: Vec<_> = std::fs::read_dir(f.0.join("store"))
                .unwrap()
                .map(|e| e.unwrap().file_name())
                .collect();
            n.sort();
            n
        };
        let names = entries();
        refused(f.run(&coverage(&p)));
        assert_eq!(std::fs::read(f.db()).unwrap(), bytes);
        assert_eq!(entries(), names);
    }
}

#[test]
fn ad_a2_actual_empty_policy_and_empty_unindexed_then_indexed_zero_records() {
    let (f, p) = Fixture::new(0);
    let r = f.json(&coverage(&p));
    assert_eq!(r["summary"]["approved_file_count"], 0);
    assert_eq!(r["summary"]["project_snapshot_current"], false);
    let (f, p) = Fixture::new(1);
    std::fs::write(f.0.join("source/file0.rs"), b"").unwrap();
    assert_eq!(
        f.json(&coverage(&p))["files"][0]["status"],
        "readable-empty"
    );
    f.json(&words(&["index", "a"]));
    let p = f.json(&words(&["project", "show", "a"]));
    let r = f.json(&coverage(&p));
    assert_eq!(r["summary"]["stored_anchor_record_count"], 0);
    assert_eq!(r["summary"]["project_snapshot_current"], true);
    assert_eq!(r["files"][0]["baseline_exists"], true);
}

#[test]
fn ad_a2_cli_missing_unsafe_replaced_and_forget_rebuild_are_explicit() {
    let (f, _) = Fixture::new(2);
    f.json(&words(&["index", "a"]));
    let p = f.json(&words(&["project", "show", "a"]));
    let db = std::fs::read(f.db()).unwrap();
    let source = f.0.join("source/file0.rs");
    let saved = f.0.join("source/saved.rs");
    std::fs::rename(&source, &saved).unwrap();
    let r = f.json(&coverage(&p));
    assert_eq!(r["files"][0]["status"], "unavailable-or-unsafe");
    assert_eq!(r["files"][1]["status"], "current");
    assert!(r["summary"]["needs_build"].is_null());
    assert_eq!(r["summary"]["project_snapshot_current"], false);
    std::os::unix::fs::symlink(&saved, &source).unwrap();
    assert_eq!(
        f.json(&coverage(&p))["files"][0]["status"],
        "unavailable-or-unsafe"
    );
    std::fs::remove_file(&source).unwrap();
    std::fs::write(&source, b"synthetic lexical anchor\n").unwrap();
    assert_eq!(f.json(&coverage(&p))["files"][0]["status"], "replaced");
    std::fs::remove_file(&source).unwrap();
    std::fs::rename(&saved, &source).unwrap();
    assert_eq!(
        f.json(&coverage(&p))["summary"]["project_snapshot_current"],
        true
    );
    assert_eq!(std::fs::read(f.db()).unwrap(), db);
    f.json(&words(&[
        "source",
        "forget",
        "a",
        "file0.rs",
        "--confirm-forget-source",
    ]));
    refused(f.run(&coverage(&p)));
    f.json(&words(&["index", "a"]));
    let p = f.json(&words(&["project", "show", "a"]));
    let r = f.json(&coverage(&p));
    assert_eq!(r["files"].as_array().unwrap().len(), 1);
    assert_eq!(r["files"][0]["path"], "file1.rs");
    assert_eq!(
        std::fs::read(&source).unwrap(),
        b"synthetic lexical anchor\n"
    );
}

#[test]
fn ad_a3_cli_failed_read_aggregate_and_line_budgets_fail_without_partial_json() {
    let (f, p) = Fixture::new(17);
    let db = std::fs::read(f.db()).unwrap();
    for i in 0..17 {
        std::fs::write(f.0.join(format!("source/file{i}.rs")), vec![0xff; 65536]).unwrap();
    }
    refused(f.run(&coverage(&p)));
    assert_eq!(std::fs::read(f.db()).unwrap(), db);
    let (f, p) = Fixture::new(1);
    let db = std::fs::read(f.db()).unwrap();
    for content in [vec![b'x'; 65537], vec![b'\n'; 4097]] {
        std::fs::write(f.0.join("source/file0.rs"), content).unwrap();
        refused(f.run(&coverage(&p)));
    }
    for invalid in [0, 0xff] {
        for count in [4096, 4097] {
            let mut bytes = vec![b'\n'; count];
            bytes.push(invalid);
            std::fs::write(f.0.join("source/file0.rs"), bytes).unwrap();
            refused(f.run(&coverage(&p)));
            assert_eq!(std::fs::read(f.db()).unwrap(), db);
        }
        let mut bytes = vec![b'\n'; 4095];
        bytes.push(invalid);
        std::fs::write(f.0.join("source/file0.rs"), bytes).unwrap();
        assert_eq!(
            f.json(&coverage(&p))["files"][0]["status"],
            "unavailable-or-unsafe"
        );
    }
    std::fs::write(f.0.join("source/file0.rs"), b"restored\n").unwrap();
    assert_eq!(f.json(&coverage(&p))["files"][0]["status"], "unindexed");
}
