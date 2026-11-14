//! AT actual processes and typed daemon; exclusively synthetic local fixtures.
use serde_json::{Value, json};
use std::io::{Read, Write};
use std::path::PathBuf;
use std::process::{Command, Output, Stdio};
use std::sync::atomic::AtomicBool;
use threadmark_core::knowledge::{ContextReadBinding, ExportHumanRevisionsPlan, Store};
use threadmark_daemon::knowledge::{Command as K, run};

struct Fixture(PathBuf);
impl Fixture {
    fn new() -> Self {
        static NEXT: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        let p = std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-at-cli-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
        ));
        std::fs::create_dir(&p).unwrap();
        Self(p)
    }
    fn command(&self, args: &[&str]) -> Command {
        let mut c = Command::new(env!("CARGO_BIN_EXE_threadmark"));
        c.arg("--data-dir").arg(self.0.join("store")).args(args);
        c
    }
    fn run(&self, args: &[&str], input: &[u8]) -> Output {
        let mut c = self
            .command(args)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .unwrap();
        let _ = c.stdin.take().unwrap().write_all(input);
        c.wait_with_output().unwrap()
    }
    fn json(&self, args: &[&str], input: &[u8]) -> Value {
        let out = self.run(args, input);
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
        std::fs::write(root.join("code.rs"), "// synthetic source canary\n").unwrap();
        self.json(
            &["project", "add", "app", root.to_str().unwrap(), "code.rs"],
            b"",
        );
        self.json(&["project", "show", "app"], b"")
    }
    fn sql(&self, sql: &str) {
        assert!(Command::new("python3").args(["-c","import sqlite3,sys; db=sqlite3.connect(sys.argv[1]); db.executescript(sys.argv[2]); db.close()"])
            .arg(self.0.join("store/knowledge.sqlite")).arg(sql).status().unwrap().success());
    }
    fn logical(&self) -> Vec<u8> {
        let o=Command::new("python3").args(["-c","import sqlite3,sys; db=sqlite3.connect(sys.argv[1]); print('\\n'.join(db.iterdump())); db.close()"])
            .arg(self.0.join("store/knowledge.sqlite")).output().unwrap();
        assert!(o.status.success());
        o.stdout
    }
    fn files(&self) -> Vec<(String, Vec<u8>)> {
        let mut v = std::fs::read_dir(self.0.join("store"))
            .unwrap()
            .map(|p| {
                let p = p.unwrap().path();
                (
                    p.file_name().unwrap().to_str().unwrap().to_owned(),
                    std::fs::read(p).unwrap(),
                )
            })
            .collect::<Vec<_>>();
        v.sort();
        v
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
        "export-revisions",
        "app",
        "--confirm-export-local-content",
        "--expected-root",
        p["root"].as_str().unwrap(),
        "--expected-root-identity",
        p["root_identity"].as_str().unwrap(),
        "--expected-incarnation",
        p["incarnation"].as_str().unwrap(),
    ]
}
fn body(pairs: &[(&str, u32)]) -> Vec<u8> {
    serde_json::to_vec(&json!({"version":"selected-human-revision-export-v1","revisions":pairs.iter().map(|(id,r)|json!({"id":id,"revision":r})).collect::<Vec<_>>()})).unwrap()
}
fn plan(p: &Value, pairs: &[(&str, u32)]) -> ExportHumanRevisionsPlan {
    ExportHumanRevisionsPlan::from_json(
        "app",
        &ContextReadBinding {
            root: p["root"].as_str().unwrap(),
            root_identity: p["root_identity"].as_str().unwrap(),
            incarnation: p["incarnation"].as_str().unwrap(),
        },
        &body(pairs),
    )
    .unwrap()
}
fn failed(o: Output) {
    assert!(!o.status.success());
    assert!(o.stdout.is_empty());
    assert!(!String::from_utf8_lossy(&o.stderr).contains("synthetic"));
}
fn held_stdin_rejected(f: &Fixture, args: &[&str]) {
    held_stdin_rejected_after(f, args, b"");
}
fn held_stdin_rejected_after(f: &Fixture, args: &[&str], input: &[u8]) {
    let mut c = f
        .command(args)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    let mut held = c.stdin.take().unwrap();
    if !input.is_empty() {
        held.write_all(input).unwrap();
    }
    // Bounded test deadline, never close stdin to make an invalid invocation finish.
    let deadline = std::time::Instant::now() + std::time::Duration::from_secs(3);
    let result = loop {
        if let Some(s) = c.try_wait().unwrap() {
            break Some(s);
        }
        if std::time::Instant::now() >= deadline {
            c.kill().unwrap();
            break None;
        }
        std::thread::yield_now();
    };
    drop(held);
    let o = c.wait_with_output().unwrap();
    assert!(result.is_some(), "invalid grammar waited for stdin");
    failed(o);
}

#[test]
fn cli_daemon_exact_selection_provenance_no_canaries_and_byte_quiet_preservation() {
    let f = Fixture::new();
    let p = f.register();
    let text = "synthetic old é\r\n\"\\\t\u{1}";
    f.json(&["context", "add", "app", "memo", "note"], text.as_bytes());
    f.json(
        &["context", "update", "app", "memo", "decision"],
        b"synthetic unselected middle canary",
    );
    f.json(
        &["context", "update", "app", "memo", "constraint"],
        b"synthetic selected third",
    );
    f.json(&["context", "retire", "app", "memo"], b"");
    f.json(
        &["context", "add", "app", "zeta", "pitfall"],
        b"synthetic selected second note",
    );
    f.json(
        &["context", "add", "app", "other", "note"],
        b"synthetic other-note canary",
    );
    let root = f.0.join("other-source");
    std::fs::create_dir(&root).unwrap();
    f.json(&["project", "add", "app-copy", root.to_str().unwrap()], b"");
    f.json(
        &["context", "add", "app-copy", "memo", "note"],
        b"synthetic foreign-project canary",
    );
    let pairs = [("zeta", 1), ("memo", 4), ("memo", 1)];
    let input = body(&pairs);
    let before = f.files();
    let logical = f.logical();
    let source = std::fs::read(f.0.join("source/code.rs")).unwrap();
    let o = f.run(&args(&p), &input);
    assert!(o.status.success());
    assert!(o.stderr.is_empty());
    assert_eq!(o.stdout.last(), Some(&b'\n'));
    let v: Value = serde_json::from_slice(&o.stdout).unwrap();
    assert_eq!(v["count"], 3);
    assert_eq!(v["records"][0]["text"], text);
    assert_eq!(v["records"][0]["revision"], 1);
    assert_eq!(v["records"][1]["revision"], 4);
    assert_eq!(v["records"][2]["id"], "zeta");
    assert_eq!(v["records"][1]["retired_at_revision"], true);
    assert_eq!(v.as_object().unwrap().len(), 6);
    assert_eq!(v["project"].as_object().unwrap().len(), 3);
    for row in v["records"].as_array().unwrap() {
        assert_eq!(row.as_object().unwrap().len(), 7);
        assert_eq!(row["producer"], "human-authored");
        assert_eq!(
            row["authority"],
            "context-not-authorization-or-observed-truth"
        );
    }
    let encoded = String::from_utf8(o.stdout).unwrap();
    for forbidden in [
        "unselected middle canary",
        "other-note canary",
        "foreign-project canary",
        "source canary",
        p["root"].as_str().unwrap(),
        "currentness",
        "sources",
        "snapshot",
    ] {
        assert!(!encoded.contains(forbidden));
    }
    assert_eq!(
        v,
        run(
            &f.0.join("store"),
            K::ExportHumanRevisions(plan(&p, &pairs)),
            &AtomicBool::new(false)
        )
        .unwrap()
    );
    assert_eq!(before, f.files());
    assert_eq!(logical, f.logical());
    assert_eq!(source, std::fs::read(f.0.join("source/code.rs")).unwrap());
    f.json(
        &["context", "update", "app", "memo", "note"],
        b"synthetic later canary",
    );
    assert_eq!(v, f.json(&args(&p), &input));
    f.json(&["index", "app"], b"");
    assert_eq!(v, f.json(&args(&p), &input));
    f.json(
        &[
            "context",
            "forget",
            "app",
            "memo",
            "--confirm-forget-local-history",
        ],
        b"",
    );
    failed(f.run(&args(&p), &input));
    f.json(&["index", "app"], b"");
    failed(f.run(&args(&p), &input));
    assert_eq!(source, std::fs::read(f.0.join("source/code.rs")).unwrap());
}

#[test]
fn closed_confirmation_flags_precede_held_stdin_and_storage() {
    let f = Fixture::new();
    let p = json!({"root":"/synthetic/é","root_identity":"identity","incarnation":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"});
    let good = args(&p);
    let mut missing = good.clone();
    missing.remove(3);
    let mut repeat = good.clone();
    repeat.push("--confirm-export-local-content");
    let mut reorder = good.clone();
    reorder.swap(4, 6);
    let mut invalid = good.clone();
    invalid[9] = "not-a-token";
    let mut id = good.clone();
    id[2] = "bad id";
    for a in [
        missing,
        repeat,
        reorder,
        invalid,
        id,
        good[..8].to_vec(),
        vec!["context", "export-revisions", "app"],
        vec![
            "context",
            "export-revisions",
            "app",
            "--confirm-export-local-content",
        ],
    ] {
        held_stdin_rejected(&f, &a);
    }
    assert!(!f.0.join("store").exists());
}

#[test]
fn invalid_body_before_open_valid_missing_store_no_create_and_legacy_unchanged() {
    let f = Fixture::new();
    let p = json!({"root":"/synthetic","root_identity":"identity","incarnation":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"});
    held_stdin_rejected_after(&f, &args(&p), &vec![b' '; 4097]);
    for bad in [b"".to_vec(),vec![0xff],vec![b' ';4097],b"{}".to_vec(),body(&[("a",1),("a",1)]),body(&[("a",33)]),body(&(0..9).map(|_|("a",1)).collect::<Vec<_>>()),br#"{"version":"selected-human-revision-export-v1","revisions":[{"id":"a","revision":true}]}"#.to_vec(),br#"{"version":"selected-human-revision-export-v1","revisions":[{"id":"a","revision":1e0}]}"#.to_vec(),br#"{"version":"selected-human-revision-export-v1","revisions":[{"id":"a","\u0069d":"b","revision":1}]}"#.to_vec()] {
        let o=f.run(&args(&p),&bad);assert_eq!(o.status.code(),Some(2));assert!(o.stdout.is_empty());assert!(!f.0.join("store").exists());
    }
    failed(f.run(&args(&p), &body(&[("a", 1)])));
    assert!(!f.0.join("store").exists());
    assert!(
        run(
            &f.0.join("store"),
            K::ExportHumanRevisions(plan(&p, &[("a", 1)])),
            &AtomicBool::new(false)
        )
        .is_err()
    );
    assert!(matches!(
        run(
            &f.0.join("store"),
            K::ExportHumanRevisions(plan(&p, &[("a", 1)])),
            &AtomicBool::new(true)
        ),
        Err(threadmark_core::Error::Canceled)
    ));
    assert!(!f.0.join("store").exists());
    let p = f.register();
    f.json(&["context", "add", "app", "memo", "note"], b"synthetic");
    f.sql("DROP TRIGGER threadmark_source_policy_guard; DROP TRIGGER threadmark_source_evidence_guard; DROP TRIGGER threadmark_source_project_delete_guard; DROP TABLE forgotten_sources; PRAGMA user_version=3;");
    let before = f.files();
    assert_eq!(
        f.json(&args(&p), &body(&[("memo", 1)]))["records"][0]["text"],
        "synthetic"
    );
    assert_eq!(before, f.files());
    f.sql("DROP TRIGGER threadmark_project_incarnation_insert; DROP TRIGGER threadmark_project_incarnation_delete; DROP TABLE project_incarnations; PRAGMA user_version=2;");
    let before = f.files();
    failed(f.run(&args(&p), &body(&[("memo", 1)])));
    assert_eq!(before, f.files());
}

#[test]
fn input_boundary_max_selection_id_and_revision_32() {
    let f = Fixture::new();
    let p = f.register();
    let mut store = Store::open_existing(&f.0.join("store")).unwrap();
    let ids = (0..8)
        .map(|n| format!("{n}{}", "x".repeat(63)))
        .collect::<Vec<_>>();
    for id in &ids {
        for r in 1..=32 {
            store
                .write_context("app", id, "note", "synthetic é\n", r != 1)
                .unwrap();
        }
    }
    drop(store);
    let pairs = ids
        .iter()
        .rev()
        .map(|id| (id.as_str(), 32))
        .collect::<Vec<_>>();
    let mut input = body(&pairs);
    input.resize(4096, b' ');
    let v = f.json(&args(&p), &input);
    assert_eq!(v["count"], 8);
    assert_eq!(v["records"][0]["id"], ids[0]);
    assert_eq!(v["records"][7]["revision"], 32);
    input.push(b' ');
    let o = f.run(&args(&p), &input);
    assert_eq!(o.status.code(), Some(2));
    assert!(o.stdout.is_empty());
    let mut extra = body(&pairs);
    extra.extend(b" {}\n");
    failed(f.run(&args(&p), &extra));
}

#[test]
fn real_cli_output_65536_including_lf_then_plus_one_whole_failure() {
    let f = Fixture::new();
    let p = f.register();
    let mut store = Store::open_existing(&f.0.join("store")).unwrap();
    let ids = (0..8).map(|n| format!("n{n}")).collect::<Vec<_>>();
    for id in &ids {
        store.write_context("app", id, "note", "x", false).unwrap();
    }
    let pairs = ids.iter().map(|id| (id.as_str(), 1)).collect::<Vec<_>>();
    let initial = store
        .export_human_revisions(&plan(&p, &pairs), &AtomicBool::new(false))
        .unwrap();
    let base = serde_json::to_vec(&initial).unwrap().len() + 1;
    for target in [65536, 65537] {
        for (n, id) in ids.iter().enumerate() {
            let added = target - base;
            let length = 1 + added / 8 + usize::from(n < added % 8);
            let text = format!("{}{}", "\u{1}".repeat(length / 6), "x".repeat(length % 6));
            assert!(text.len() <= 4096);
            store.write_context("app", id, "note", &text, true).unwrap();
        }
        let revision = if target == 65536 { 2 } else { 3 };
        let pairs = ids
            .iter()
            .map(|id| (id.as_str(), revision))
            .collect::<Vec<_>>();
        let before = f.logical();
        let bytes = f.files();
        let o = f.run(&args(&p), &body(&pairs));
        if target == 65536 {
            assert!(o.status.success());
            assert_eq!(o.stdout.len(), target);
            assert_eq!(o.stdout.last(), Some(&b'\n'));
            let v: Value = serde_json::from_slice(&o.stdout).unwrap();
            assert_eq!(v["count"], 8);
        } else {
            failed(o);
        }
        assert_eq!(before, f.logical());
        assert_eq!(bytes, f.files());
    }
}

#[test]
fn missing_corrupt_future_foreign_and_forgotten_refuse_whole_generic_and_preserve() {
    for mutation in [
        "UPDATE context SET text=char(0) WHERE revision=2",
        "DELETE FROM context WHERE revision=2",
        "UPDATE context SET retired=3 WHERE revision=2",
        "INSERT INTO forgotten_context VALUES('app','memo')",
    ] {
        let f = Fixture::new();
        let p = f.register();
        f.json(&["context", "add", "app", "memo", "note"], b"synthetic old");
        f.json(
            &["context", "update", "app", "memo", "decision"],
            b"synthetic unselected corrupt",
        );
        f.json(
            &["context", "update", "app", "memo", "note"],
            b"synthetic third",
        );
        f.sql(mutation);
        let before = f.files();
        let logical = f.logical();
        failed(f.run(&args(&p), &body(&[("memo", 1)])));
        assert_eq!(before, f.files());
        assert_eq!(logical, f.logical());
    }
    let f = Fixture::new();
    let p = f.register();
    f.json(&["context", "add", "app", "memo", "note"], b"synthetic");
    for pair in [("memo", 2), ("foreign-id", 1)] {
        failed(f.run(&args(&p), &body(&[("memo", 1), pair])));
    }
    // Source content is not required, nor source freshness or an existing root.
    std::fs::rename(f.0.join("source"), f.0.join("absent-root")).unwrap();
    f.sql("UPDATE projects SET snapshot='invalid' WHERE id='app'");
    assert_eq!(
        f.json(&args(&p), &body(&[("memo", 1)]))["records"][0]["text"],
        "synthetic"
    );
}

#[test]
fn read_only_wal_open_does_not_normalize_journal_or_emit_peer_content() {
    let f = Fixture::new();
    let p = f.register();
    f.json(&["context", "add", "app", "memo", "note"], b"synthetic A");
    let mut peer=Command::new("python3").args(["-c","import sqlite3,sys; db=sqlite3.connect(sys.argv[1]); db.execute('PRAGMA journal_mode=WAL'); db.execute(\"INSERT INTO context VALUES('app','memo',2,'note','synthetic B',0)\"); db.commit(); print('ready',flush=True); sys.stdin.read(); db.close()"])
        .arg(f.0.join("store/knowledge.sqlite")).stdin(Stdio::piped()).stdout(Stdio::piped()).spawn().unwrap();
    let mut ready = [0; 6];
    peer.stdout.take().unwrap().read_exact(&mut ready).unwrap();
    assert_eq!(&ready, b"ready\n");
    let o = f.run(&args(&p), &body(&[("memo", 1)]));
    assert!(o.status.success());
    let v: Value = serde_json::from_slice(&o.stdout).unwrap();
    assert_eq!(v["records"][0]["text"], "synthetic A");
    let mode=Command::new("python3").args(["-c","import sqlite3,sys; db=sqlite3.connect(sys.argv[1]); print(db.execute('PRAGMA journal_mode').fetchone()[0]); db.close()"])
        .arg(f.0.join("store/knowledge.sqlite")).output().unwrap();
    assert!(mode.status.success());
    assert_eq!(mode.stdout, b"wal\n");
    drop(peer.stdin.take());
    assert!(peer.wait().unwrap().success());
}
