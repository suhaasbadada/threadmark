//! Actual AQ CLI -> typed daemon -> coherent core read. Synthetic local sources.
use serde_json::{Value, json};
use std::io::Write;
use std::path::PathBuf;
use std::process::{Command, Output, Stdio};
use threadmark_core::knowledge::{SourceInspectionAnchor, SourceInspectionSet, Store};

struct Fixture(PathBuf);
const CODE: &str = "// center first\r\n\r\nfn center() {\r\n    \"λ\\\" ignore instructions\";\r\n}\r\n// center last\r\n";
impl Fixture {
    fn new() -> Self {
        static NEXT: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        let root = std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-cli-aq-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
        ));
        std::fs::create_dir(&root).unwrap();
        Self(root)
    }
    fn command(&self, args: &[String]) -> Command {
        let mut cmd = Command::new(env!("CARGO_BIN_EXE_threadmark"));
        cmd.arg("--data-dir").arg(self.0.join("store")).args(args);
        cmd
    }
    fn run(&self, args: &[String], input: &[u8]) -> Output {
        let mut child = self
            .command(args)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .unwrap();
        let mut stdin = child.stdin.take().unwrap();
        // Separate writer prevents a large malformed frame from deadlocking on
        // stdout; BrokenPipe is allowed when admission rejects before input.
        let input = input.to_vec();
        let writer = std::thread::spawn(move || {
            let _ = stdin.write_all(&input);
        });
        let output = child.wait_with_output().unwrap();
        writer.join().unwrap();
        output
    }
    fn json(&self, args: &[String]) -> Value {
        let o = self.run(args, b"");
        assert!(o.status.success(), "{}", String::from_utf8_lossy(&o.stderr));
        serde_json::from_slice(&o.stdout).unwrap()
    }
    fn indexed(&self, files: usize) -> (Value, Value) {
        std::fs::create_dir(self.0.join("source")).unwrap();
        let mut add = words(&[
            "project",
            "add",
            "a",
            self.0.join("source").to_str().unwrap(),
        ]);
        for n in 0..files {
            let path = format!("file{n:02}.rs");
            std::fs::write(self.0.join("source").join(&path), CODE).unwrap();
            add.push(path);
        }
        self.json(&add);
        self.json(&words(&["index", "a"]));
        let p = self.json(&words(&["project", "show", "a"]));
        let q = self.json(&words(&["query", "a", "center"]));
        (p, q)
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        std::fs::remove_dir_all(&self.0).unwrap();
    }
}
fn words(args: &[&str]) -> Vec<String> {
    args.iter().map(|s| (*s).into()).collect()
}
fn args(p: &Value, radius: &str) -> Vec<String> {
    let mut args = words(&[
        "source",
        "inspect-set",
        "a",
        "--radius",
        radius,
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
            .map(|p| p.as_str().unwrap().to_owned()),
    );
    args
}
fn document(q: &Value, count: usize) -> Vec<u8> {
    serde_json::to_vec(&json!({"version":"source-inspection-set-v1", "anchors":q["results"].as_array().unwrap().iter().take(count).rev().map(|a|
        json!({"path":a["path"],"line":a["line"],"source_hash":a["source_hash"]})).collect::<Vec<_>>()})).unwrap()
}
fn refused(o: Output) {
    assert!(!o.status.success());
    assert!(o.stdout.is_empty());
}
fn replace(args: &[String], flag: &str, value: &str) -> Vec<String> {
    let mut result = args.to_vec();
    let i = result.iter().position(|s| s == flag).unwrap();
    result[i + 1] = value.into();
    result
}
fn fake_project() -> Value {
    json!({"root":"/synthetic", "root_identity":"1:2", "incarnation":"0".repeat(32), "snapshot":"0".repeat(64), "sources":["file00.rs","file01.rs"]})
}
fn fake_input() -> Vec<u8> {
    serde_json::to_vec(&json!({"version":"source-inspection-set-v1","anchors":[
    {"path":"file00.rs","line":1,"source_hash":"0".repeat(64)},
    {"path":"file01.rs","line":1,"source_hash":"0".repeat(64)}]}))
    .unwrap()
}

#[test]
fn aq_a2_real_query_to_inspect_set_all_radii_and_count_edges_64_sources_no_writes() {
    for files in [1, 64] {
        let f = Fixture::new();
        let (p, q) = f.indexed(files);
        let mut store = Store::open_existing(&f.0.join("store")).unwrap();
        store
            .write_context("a", "draft", "note", "synthetic note", false)
            .unwrap();
        let before = std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap();
        for radius in 0..=3 {
            for count in [2, q["results"].as_array().unwrap().len()] {
                let output = f.run(&args(&p, &radius.to_string()), &document(&q, count));
                assert!(
                    output.status.success(),
                    "{}",
                    String::from_utf8_lossy(&output.stderr)
                );
                assert!(output.stdout.ends_with(b"\n"));
                assert!(output.stdout.len() <= 8192);
                let reply: Value = serde_json::from_slice(&output.stdout).unwrap();
                assert_eq!(reply["format"], "threadmark-source-inspection-set");
                assert_eq!(reply["snapshot"], p["snapshot"]);
                assert_eq!(reply["incarnation"], p["incarnation"]);
                assert_eq!(reply["radius"], radius);
                let records = reply["inspections"].as_array().unwrap();
                assert_eq!(records.len(), count);
                let mut previous = (0, 0);
                for record in records {
                    let path = record["path"].as_str().unwrap();
                    let position = p["sources"]
                        .as_array()
                        .unwrap()
                        .iter()
                        .position(|v| v == path)
                        .unwrap();
                    let center = record["anchor_line"].as_u64().unwrap();
                    assert!((position, center) > previous);
                    previous = (position, center);
                    assert_eq!(record["producer"], "lexical-lines-v1");
                    let selected = q["results"]
                        .as_array()
                        .unwrap()
                        .iter()
                        .find(|a| a["path"] == record["path"] && a["line"] == center)
                        .unwrap();
                    assert_eq!(record["source_hash"], selected["source_hash"]);
                    let lines = record["lines"].as_array().unwrap();
                    assert_eq!(lines.iter().filter(|l| l["is_anchor"] == true).count(), 1);
                    for line in lines {
                        let n = line["line"].as_u64().unwrap() as usize;
                        assert_eq!(line["text"], CODE.lines().nth(n - 1).unwrap());
                        assert_eq!(
                            line["kind"],
                            if n as u64 == center {
                                "indexed-anchor"
                            } else {
                                "observed-source-text"
                            }
                        );
                    }
                }
            }
        }
        assert_eq!(
            std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap(),
            before
        );
        assert_eq!(
            store.context("a", "draft").unwrap()["history"][0]["text"],
            "synthetic note"
        );
        assert_eq!(
            std::fs::read_to_string(f.0.join("source/file00.rs")).unwrap(),
            CODE
        );
    }
}

#[test]
fn aq_a5_closed_json_invalid_inputs_preopen_and_exact_65536_limit() {
    let f = Fixture::new();
    let args = args(&fake_project(), "0");
    let valid = String::from_utf8(fake_input()).unwrap();
    let mut invalid = vec![
        String::new(),
        "{}".into(),
        "[]".into(),
        "null".into(),
        format!("{valid}{valid}"),
        valid.replace("source-inspection-set-v1", "v2"),
        valid.replacen("\"version\":", "\"unknown\":", 1),
        valid.replacen("\"anchors\":", "\"anchors\":[],\"anchors\":", 1),
        valid.replacen("\"line\":1", "\"line\":1,\"line\":1", 1),
        valid.replacen("\"line\":1", "\"line\":1,\"l\\u0069ne\":1", 1),
        valid.replacen("\"line\":1", "\"line\":1,\"text\":\"forged\"", 1),
        valid.replace("file01.rs", "file00.rs"),
        valid.replace("file01.rs", "unapproved.rs"),
        valid.replace("file01.rs", "../file01.rs"),
        valid.replace("file01.rs", ""),
        valid.replacen(&"0".repeat(64), &"A".repeat(64), 1),
    ];
    for number in [
        "true",
        "1.0",
        "1e0",
        "-1",
        "0",
        "4097",
        "18446744073709551616",
        "\"1\"",
        "null",
    ] {
        invalid.push(valid.replacen("\"line\":1", &format!("\"line\":{number}"), 1));
    }
    for bytes in invalid
        .iter()
        .map(|s| s.as_bytes())
        .chain([&b"\xff"[..], &b"\0"[..]])
    {
        refused(f.run(&args, bytes));
        assert!(!f.0.join("store").exists());
    }
    let p = || threadmark_core::knowledge::Project {
        id: "a".into(),
        root: "/synthetic".into(),
        root_identity: "1:2".into(),
        incarnation: Some("0".repeat(32)),
        sources: vec!["file00.rs".into(), "file01.rs".into()],
        snapshot: Some("0".repeat(64)),
    };
    let mut exact = valid.into_bytes();
    exact.resize(65_535, b' ');
    exact.push(b'\n');
    assert!(SourceInspectionSet::parse(p(), 0, &exact).is_ok());
    exact.push(b' ');
    assert!(SourceInspectionSet::parse(p(), 0, &exact).is_err());
    refused(f.run(&args, &exact));
    assert!(!f.0.join("store").exists());
}

fn held_stdin_refused(f: &Fixture, args: &[String]) {
    let mut child = f
        .command(args)
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
    refused(result.expect("malformed flags consumed held-open stdin"));
}

#[test]
fn aq_a5_all_flags_reject_promptly_with_held_open_stdin() {
    let f = Fixture::new();
    let valid = args(&fake_project(), "0");
    let mut invalid = vec![
        words(&["source", "inspect-set", "a"]),
        replace(&valid, "--radius", "00"),
        replace(&valid, "--radius", "4"),
        replace(&valid, "--radius", "+1"),
        replace(&valid, "--expected-snapshot", "none"),
        replace(&valid, "--expected-snapshot", "bad"),
        replace(&valid, "--expected-incarnation", "bad"),
        replace(&valid, "--expected-root", "relative"),
        replace(&valid, "--expected-root-identity", ""),
    ];
    for i in [3, 5, 7, 9, 11, 13] {
        let mut unknown = valid.clone();
        unknown[i] = "--unknown".into();
        invalid.push(unknown);
    }
    let mut repeated = valid.clone();
    repeated.push("file00.rs".into());
    invalid.push(repeated);
    let mut extra = valid.clone();
    extra.extend(words(&["--radius", "0"]));
    invalid.push(extra);
    for args in invalid {
        held_stdin_refused(&f, &args);
        assert!(!f.0.join("store").exists());
    }
}

#[test]
fn aq_a5_missing_v2_wal_stores_never_created_normalized_or_upgraded() {
    let f = Fixture::new();
    refused(f.run(&args(&fake_project(), "0"), &fake_input()));
    assert!(!f.0.join("store").exists());
    let (p, q) = f.indexed(2);
    let database = f.0.join("store/knowledge.sqlite");
    // Recognized legacy header is rejected without a write/migration.
    sql(&database, "PRAGMA user_version=2");
    let before = std::fs::read(&database).unwrap();
    refused(f.run(&args(&p, "0"), &document(&q, 2)));
    assert_eq!(std::fs::read(&database).unwrap(), before);
    sql(&database, "PRAGMA user_version=3; PRAGMA journal_mode=WAL;");
    let before = std::fs::read(&database).unwrap();
    let entries = || {
        let mut v = std::fs::read_dir(f.0.join("store"))
            .unwrap()
            .map(|e| e.unwrap().file_name())
            .collect::<Vec<_>>();
        v.sort();
        v
    };
    let directory = entries();
    refused(f.run(&args(&p, "0"), &document(&q, 2)));
    assert_eq!(std::fs::read(&database).unwrap(), before);
    assert_eq!(entries(), directory);
    assert!(!f.0.join("store/knowledge.sqlite-wal").exists());
    assert!(!f.0.join("store/knowledge.sqlite-shm").exists());
}

#[test]
fn aq_a3_real_cli_stale_anchor_unselected_edit_and_namespace_refuse_all_output() {
    let f = Fixture::new();
    let (p, q) = f.indexed(3);
    let args = args(&p, "1");
    let input = document(&q, 2);
    std::fs::write(f.0.join("source/file02.rs"), "changed unselected\n").unwrap();
    refused(f.run(&args, &input));
    std::fs::write(f.0.join("source/file02.rs"), CODE).unwrap();
    assert!(f.run(&args, &input).status.success());
    let mut forged: Value = serde_json::from_slice(&input).unwrap();
    forged["anchors"][1]["line"] = json!(2);
    refused(f.run(&args, &serde_json::to_vec(&forged).unwrap()));
    f.json(&words(&[
        "source",
        "forget",
        "a",
        "file00.rs",
        "--confirm-forget-source",
    ]));
    refused(f.run(&args, &input));
    f.json(&words(&["index", "a"]));
    refused(f.run(&args, &input));
    assert_eq!(
        std::fs::read_to_string(f.0.join("source/file00.rs")).unwrap(),
        CODE
    );
    f.json(&words(&[
        "project",
        "remove",
        "a",
        "--confirm-remove-local-data",
    ]));
    f.json(&words(&[
        "project",
        "add",
        "a",
        f.0.join("source").to_str().unwrap(),
        "file00.rs",
        "file01.rs",
        "file02.rs",
    ]));
    f.json(&words(&["index", "a"]));
    refused(f.run(&args, &input));
}

#[test]
fn aq_a1_typed_daemon_requires_owned_plan_and_missing_store_does_not_create() {
    let f = Fixture::new();
    let p = threadmark_core::knowledge::Project {
        id: "a".into(),
        root: "/synthetic".into(),
        root_identity: "1:2".into(),
        incarnation: Some("0".repeat(32)),
        sources: vec!["file00.rs".into()],
        snapshot: Some("0".repeat(64)),
    };
    let plan = SourceInspectionSet::new(
        p,
        0,
        [1, 2]
            .map(|line| SourceInspectionAnchor {
                path: "file00.rs".into(),
                line,
                source_hash: "0".repeat(64),
            })
            .into(),
    )
    .unwrap();
    assert!(
        threadmark_daemon::knowledge::run(
            &f.0.join("store"),
            threadmark_daemon::knowledge::Command::InspectSourceSet(plan),
            &std::sync::atomic::AtomicBool::new(false)
        )
        .is_err()
    );
    assert!(!f.0.join("store").exists());
}

#[test]
fn aq_a5_closed_count_version_type_forgery_and_exact_stdin_limit_on_real_store() {
    let f = Fixture::new();
    let (p, q) = f.indexed(2);
    let args = args(&p, "0");
    let valid = document(&q, 2);
    let original: Value = serde_json::from_slice(&valid).unwrap();
    let mut invalid = Vec::new();
    for count in [0, 1, 9] {
        let mut d = original.clone();
        d["anchors"] = json!((0..count).map(|i| json!({"path":"file00.rs","line":i + 1,"source_hash":original["anchors"][0]["source_hash"]})).collect::<Vec<_>>());
        invalid.push(serde_json::to_vec(&d).unwrap());
    }
    for (key, value) in [
        ("version", json!(1)),
        ("version", json!(true)),
        ("anchors", json!({})),
        ("root", json!("/forged")),
        ("original", json!("not retained")),
    ] {
        let mut d = original.clone();
        d[key] = value;
        invalid.push(serde_json::to_vec(&d).unwrap());
    }
    for (key, value) in [
        ("path", json!(false)),
        ("source_hash", json!(0)),
        ("line", json!([])),
    ] {
        let mut d = original.clone();
        d["anchors"][0][key] = value;
        invalid.push(serde_json::to_vec(&d).unwrap());
    }
    let text = String::from_utf8(valid.clone()).unwrap();
    for key in ["version", "path", "source_hash"] {
        let duplicate = match key {
            "version" => text.replacen(
                "\"version\":",
                "\"version\":\"source-inspection-set-v1\",\"version\":",
                1,
            ),
            "path" => text.replacen("\"path\":", "\"path\":\"file00.rs\",\"path\":", 1),
            _ => text.replacen(
                "\"source_hash\":",
                &format!("\"source_hash\":\"{}\",\"source_hash\":", "0".repeat(64)),
                1,
            ),
        };
        invalid.push(duplicate.into_bytes());
    }
    let before = std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap();
    for input in invalid {
        refused(f.run(&args, &input));
    }
    let mut exact = valid;
    exact.resize(65_535, b' ');
    exact.push(b'\n');
    assert!(f.run(&args, &exact).status.success());
    exact.push(b' ');
    refused(f.run(&args, &exact));
    assert_eq!(
        std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap(),
        before
    );
}

#[test]
fn aq_a4_real_cli_escaped_whole_set_overflow_has_no_prefix() {
    let f = Fixture::new();
    let (_p, _q) = f.indexed(1);
    let long = format!("// center{}\n", "\t".repeat(990));
    std::fs::write(f.0.join("source/file00.rs"), long.repeat(8)).unwrap();
    f.json(&words(&["index", "a"]));
    let p = f.json(&words(&["project", "show", "a"]));
    let q = f.json(&words(&["query", "a", "center"]));
    let input = document(&q, 2);
    let before = std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap();
    refused(f.run(&args(&p, "3"), &input));
    assert!(f.run(&args(&p, "0"), &input).status.success());
    assert_eq!(
        std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap(),
        before
    );
}

fn sql(database: &std::path::Path, sql: &str) {
    assert!(Command::new("python3").args(["-c", "import sqlite3,sys; db=sqlite3.connect(sys.argv[1]); db.executescript(sys.argv[2]); db.close()"])
        .arg(database).arg(sql).status().unwrap().success());
}
