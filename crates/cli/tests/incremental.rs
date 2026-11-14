//! AG actual CLI -> typed daemon -> core acceptance; synthetic explicit stores.
use serde_json::Value;
use std::path::PathBuf;
use std::process::{Command, Output, Stdio};

struct Fixture(PathBuf);
impl Fixture {
    fn new(count: usize) -> (Self, Value) {
        static NEXT: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        let f = Self(std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-cli-incremental-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
        )));
        std::fs::create_dir(&f.0).unwrap();
        std::fs::create_dir(f.0.join("source")).unwrap();
        let mut add = words(&["project", "add", "a", f.0.join("source").to_str().unwrap()]);
        for i in 0..count {
            let name = format!("file{i}.rs");
            std::fs::write(f.0.join("source").join(&name), "synthetic λ \"quote\"\\\n").unwrap();
            add.push(name);
        }
        f.json(&add);
        let p = f.project();
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
    fn project(&self) -> Value {
        self.json(&words(&["project", "show", "a"]))
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
fn incremental(p: &Value) -> Vec<String> {
    let mut args = words(&[
        "index-incremental",
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
    assert!(!errors.contains("synthetic λ"));
    assert!(!errors.contains("threadmark-cli-incremental-"));
}

#[test]
fn ag_a2_actual_query_build_query_incremental_query_and_full_unchanged_json() {
    let (f, p) = Fixture::new(64);
    assert_eq!(
        f.json(&words(&["query", "a", "λ"]))["currentness"],
        "stale-or-unindexed"
    );
    let r = f.json(&incremental(&p));
    assert_eq!(r["format"], "threadmark-incremental-lexical-index");
    assert_eq!(r["version"], 1);
    assert_eq!(r["written_anchors"], 64);
    assert_eq!(r["reused_anchors"], 0);
    let q = f.json(&words(&["query", "a", "λ"]));
    assert_eq!(q["results"][0]["text"], "synthetic λ \"quote\"\\");
    assert_eq!(q["results"][0]["producer"], "lexical-lines-v1");
    refused(f.run(&incremental(&p))); // none must not silently adopt a snapshot
    let p = f.project();
    let bytes = std::fs::read(f.db()).unwrap();
    let r = f.json(&incremental(&p));
    assert_eq!(r["reused_files"], 64);
    assert_eq!(r["persistent_writes"], false);
    assert_eq!(std::fs::read(f.db()).unwrap(), bytes);
    assert_eq!(f.json(&words(&["query", "a", "λ"])), q);
    std::fs::write(f.0.join("source/file0.rs"), "edited 雪\n").unwrap();
    let r = f.json(&incremental(&p));
    assert_eq!(r["reused_files"], 63);
    assert_eq!(r["reused_anchors"], 63);
    assert_eq!(r["written_anchors"], 1);
    assert_eq!(r["deleted_anchors"], 1);
    let q = f.json(&words(&["query", "a", "雪"]));
    assert_eq!(q["results"][0]["path"], "file0.rs");
    let full = f.json(&words(&["index", "a"]));
    assert_eq!(full.as_object().unwrap().len(), 6);
    assert_eq!(full["anchors"], 64);
    assert_eq!(full["snapshot"], r["snapshot"]);
    assert_eq!(f.json(&words(&["query", "a", "雪"])), q);
    assert!(!r.to_string().contains("synthetic"));
    assert!(!r.to_string().contains(p["root"].as_str().unwrap()));
}

#[test]
fn ag_a1_closed_preopen_grammar_missing_store_and_no_stdin() {
    let (f, p) = Fixture::new(1);
    let valid = incremental(&p);
    let mut invalid = Vec::new();
    for flag in [
        "--expected-root",
        "--expected-root-identity",
        "--expected-incarnation",
        "--expected-snapshot",
        "--expected-sources",
    ] {
        let mut bad = valid.clone();
        bad.extend(words(&[flag, "duplicate"]));
        invalid.push(bad);
        let mut bad = valid.clone();
        let i = bad.iter().position(|s| s == flag).unwrap();
        bad.remove(i);
        invalid.push(bad);
    }
    invalid.push(words(&["index-incremental", "a"]));
    let mut unknown = valid.clone();
    unknown.push("--unknown".into());
    invalid.push(unknown);
    let mut order = valid.clone();
    order.swap(2, 4);
    invalid.push(order);
    let mut unicode = valid.clone();
    unicode[3] = format!("/{}", "λ".repeat(2048));
    invalid.push(unicode);
    let mut duplicate_path = valid.clone();
    duplicate_path.push("file0.rs".into());
    invalid.push(duplicate_path);
    let mut over = valid.clone();
    over.extend((0..64).map(|i| format!("x{i}.rs")));
    invalid.push(over);
    std::fs::rename(f.0.join("store"), f.0.join("saved")).unwrap();
    for bad in &invalid {
        let mut child = f
            .command(bad)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .unwrap();
        let held = child.stdin.take().unwrap();
        let o = child.wait_with_output().unwrap(); // held input must never be read
        drop(held);
        assert_eq!(o.status.code(), Some(2));
        assert!(o.stdout.is_empty());
        assert!(!f.0.join("store").exists());
    }
    refused(f.run(&valid));
    assert!(!f.0.join("store").exists());
    std::fs::rename(f.0.join("saved"), f.0.join("store")).unwrap();
    let mut child = f
        .command(&valid)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    let held = child.stdin.take().unwrap();
    let o = child.wait_with_output().unwrap();
    drop(held);
    assert!(o.status.success());
}

#[test]
fn ag_a1_legacy_schema2_no_implicit_migration_or_creation() {
    let (f, p) = Fixture::new(1);
    assert!(Command::new("python3").args(["-c", "import sqlite3,sys; d=sqlite3.connect(sys.argv[1]); d.executescript('DROP TRIGGER threadmark_source_project_delete_guard; DROP TRIGGER threadmark_source_evidence_guard; DROP TRIGGER threadmark_source_policy_guard; DROP TABLE forgotten_sources; DROP TRIGGER threadmark_project_incarnation_insert; DROP TRIGGER threadmark_project_incarnation_delete; DROP TABLE project_incarnations; PRAGMA user_version=2;'); d.close()"])
        .arg(f.db()).status().unwrap().success());
    let bytes = std::fs::read(f.db()).unwrap();
    refused(f.run(&incremental(&p)));
    assert_eq!(std::fs::read(f.db()).unwrap(), bytes);
}

#[test]
fn ag_a5_empty_policy_and_forget_recapture_none_rebuild() {
    let (f, p) = Fixture::new(0);
    assert_eq!(f.json(&incremental(&p))["anchors"], 0);
    assert_eq!(
        f.json(&incremental(&f.project()))["persistent_writes"],
        false
    );
    let (f, p) = Fixture::new(2);
    std::fs::write(f.0.join("source/file1.rs"), b"").unwrap();
    f.json(&incremental(&p));
    let p = f.project();
    f.json(&words(&[
        "source",
        "forget",
        "a",
        "file0.rs",
        "--confirm-forget-source",
    ]));
    refused(f.run(&incremental(&p)));
    let fresh = f.project();
    assert!(fresh["snapshot"].is_null());
    let r = f.json(&incremental(&fresh));
    assert_eq!(r["files"], 1);
    assert_eq!(r["reused_anchors"], 0);
    assert_eq!(r["anchors"], 0);
    assert_eq!(
        f.json(&words(&["query", "a", "synthetic"]))["results"],
        serde_json::json!([])
    );
    assert_eq!(
        std::fs::read_to_string(f.0.join("source/file0.rs")).unwrap(),
        "synthetic λ \"quote\"\\\n"
    );
}
