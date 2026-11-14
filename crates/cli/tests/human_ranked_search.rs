//! AO actual CLI/daemon/store fixtures; synthetic data only.
use serde_json::{Value, json};
use std::io::Write;
use std::path::PathBuf;
use std::process::{Command, Output, Stdio};

struct Fixture(PathBuf);
impl Fixture {
    fn new() -> Self {
        static NEXT: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        let root = std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-cli-ao-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
        ));
        std::fs::create_dir(&root).unwrap();
        Self(root)
    }
    fn run(&self, args: &[String], text: Option<&str>) -> Output {
        let mut child = Command::new(env!("CARGO_BIN_EXE_threadmark"))
            .arg("--data-dir")
            .arg(self.0.join("store"))
            .args(args)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .unwrap();
        if let Some(text) = text {
            child
                .stdin
                .take()
                .unwrap()
                .write_all(text.as_bytes())
                .unwrap();
        }
        child.wait_with_output().unwrap()
    }
    fn json(&self, args: &[&str], text: Option<&str>) -> Value {
        let out = self.run(&args.iter().map(|s| (*s).into()).collect::<Vec<_>>(), text);
        assert!(
            out.status.success(),
            "{}",
            String::from_utf8_lossy(&out.stderr)
        );
        serde_json::from_slice(&out.stdout).unwrap()
    }
    fn register(&self) -> Value {
        let root = self.0.join("app");
        std::fs::create_dir(&root).unwrap();
        std::fs::write(root.join("code.rs"), "// synthetic source\n").unwrap();
        self.json(
            &["project", "add", "app", root.to_str().unwrap(), "code.rs"],
            None,
        );
        self.json(&["project", "show", "app"], None)
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        std::fs::remove_dir_all(&self.0).unwrap();
    }
}
fn args(p: &Value, query: &str, kinds: &[&str]) -> Vec<String> {
    ["context", "search-terms", "app", query, "--kinds"]
        .into_iter()
        .chain(kinds.iter().copied())
        .chain([
            "--expected-root",
            p["root"].as_str().unwrap(),
            "--expected-root-identity",
            p["root_identity"].as_str().unwrap(),
            "--expected-incarnation",
            p["incarnation"].as_str().unwrap(),
        ])
        .map(String::from)
        .collect()
}

#[test]
fn ao01_02_05_actual_cli_rank_filter_latest_forget_and_closed_wire() {
    let f = Fixture::new();
    let p = f.register();
    for n in 0..12 {
        f.json(
            &["context", "add", "app", &format!("a{n}"), "pitfall"],
            Some("alpha beta alpha beta"),
        );
    }
    f.json(
        &["context", "add", "app", "z-repeat", "note"],
        Some("alpha alpha alpha alpha"),
    );
    f.json(
        &["context", "add", "app", "b", "decision"],
        Some("beta alpha"),
    );
    f.json(&["context", "add", "app", "c", "note"], Some("alpha beta"));
    let out = f.run(&args(&p, "ALPHA beta alpha", &["note", "decision"]), None);
    assert!(out.status.success());
    assert_eq!(out.stdout.last(), Some(&10));
    assert!(out.stdout.len() <= 8192);
    let r: Value = serde_json::from_slice(&out.stdout).unwrap();
    assert_eq!(r["version"], "human-search-ranked-v1");
    assert_eq!(r["terms"], json!(["alpha", "beta"]));
    assert_eq!(r["selected_kinds"], json!(["decision", "note"]));
    assert_eq!(r["matched_entries"], 3);
    assert_eq!(r["results"][0]["id"], "b");
    assert_eq!(r["results"][1]["id"], "c");
    assert_eq!(r["results"][2]["id"], "z-repeat");
    assert_eq!(r["results"][0]["matched_terms"], json!(["alpha", "beta"]));
    assert_eq!(r["results"][0]["occurrences"], 2);
    let mut fields: Vec<_> = r.as_object().unwrap().keys().map(String::as_str).collect();
    fields.sort();
    let mut expected = vec![
        "version",
        "project",
        "root_identity",
        "incarnation",
        "selected_kinds",
        "terms",
        "producer",
        "status",
        "authority",
        "coverage",
        "selection",
        "limitations",
        "matched_entries",
        "omitted_entries",
        "truncated",
        "results",
    ];
    expected.sort();
    assert_eq!(fields, expected);
    let mut fields: Vec<_> = r["results"][0]
        .as_object()
        .unwrap()
        .keys()
        .map(String::as_str)
        .collect();
    fields.sort();
    assert_eq!(
        fields,
        [
            "id",
            "kind",
            "matched_terms",
            "occurrences",
            "producer",
            "revision",
            "status",
            "text"
        ]
    );
    let old = f.run(
        &["context", "search", "app", "alpha"].map(String::from),
        None,
    );
    let mut bound = vec![
        "context".into(),
        "search".into(),
        "app".into(),
        "alpha".into(),
    ];
    bound.extend(args(&p, "alpha", &["note"])[6..].iter().cloned());
    assert_eq!(old.stdout, f.run(&bound, None).stdout);
    assert!(
        serde_json::from_slice::<Value>(&old.stdout)
            .unwrap()
            .get("version")
            .is_none()
    );
    f.json(
        &["context", "update", "app", "b", "note"],
        Some("replacement"),
    );
    f.json(&["context", "retire", "app", "c"], None);
    f.json(
        &[
            "context",
            "forget",
            "app",
            "z-repeat",
            "--confirm-forget-local-history",
        ],
        None,
    );
    f.json(&["index", "app"], None);
    let out = f.run(&args(&p, "alpha beta", &["note", "decision"]), None);
    assert!(out.status.success());
    assert_eq!(
        serde_json::from_slice::<Value>(&out.stdout).unwrap()["matched_entries"],
        0
    );
    assert_eq!(
        f.json(&["context", "show", "app", "b"], None)["history"]
            .as_array()
            .unwrap()
            .len(),
        2
    );
    assert_eq!(
        std::fs::read_to_string(f.0.join("app/code.rs")).unwrap(),
        "// synthetic source\n"
    );
}

#[test]
fn ao05_closed_grammar_before_storage_or_stdin_eof_and_daemon_admission() {
    let f = Fixture::new();
    let p = json!({"root":"/synthetic/root", "root_identity":"identity", "incarnation":"0123456789abcdef0123456789abcdef"});
    let base = args(&p, "alpha beta", &["note"]);
    let mut cases = Vec::new();
    for kinds in [
        vec![],
        vec![""],
        vec!["unknown"],
        vec!["note", "note"],
        vec!["note"; 6],
    ] {
        cases.push(args(&p, "alpha", &kinds));
    }
    for query in [
        "".into(),
        " ".into(),
        "a\tb".into(),
        "x".repeat(65),
        "a b c d e f g h i".into(),
        "x ".repeat(129),
    ] {
        cases.push(args(&p, &query, &["note"]));
    }
    for extra in [
        vec!["--kinds", "note"],
        vec!["--unknown"],
        vec!["--expected-root", "/synthetic/root"],
        vec!["--terms"],
    ] {
        let mut c = base.clone();
        c.extend(extra.into_iter().map(String::from));
        cases.push(c);
    }
    let mut c = base.clone();
    c.pop();
    cases.push(c);
    let mut c = base.clone();
    c.swap(6, 8);
    cases.push(c);
    cases.push(
        ["context", "search-terms", "app", "alpha"]
            .map(String::from)
            .to_vec(),
    );
    cases.push(base); // valid request to absent store must also avoid stdin/create
    for args in cases {
        let mut child = Command::new(env!("CARGO_BIN_EXE_threadmark"))
            .arg("--data-dir")
            .arg(f.0.join("store"))
            .args(args)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .unwrap();
        let held = child.stdin.take().unwrap();
        let deadline = std::time::Instant::now() + std::time::Duration::from_secs(3);
        loop {
            if child.try_wait().unwrap().is_some() {
                break;
            }
            if std::time::Instant::now() >= deadline {
                child.kill().unwrap();
                panic!("ranked read waited for stdin EOF");
            }
            std::thread::yield_now();
        }
        drop(held);
        let out = child.wait_with_output().unwrap();
        assert!(!out.status.success());
        assert!(out.stdout.is_empty());
        assert!(!f.0.join("store").exists());
    }
    use threadmark_daemon::knowledge::{Command as D, run};
    for (project, root, identity, nonce) in [
        (
            "bad/id",
            "/synthetic",
            "identity",
            "0123456789abcdef0123456789abcdef",
        ),
        ("app", "", "identity", "0123456789abcdef0123456789abcdef"),
        ("app", "/synthetic", "identity", "bad"),
    ] {
        assert!(
            run(
                &f.0.join("store"),
                D::SearchContextTermsBound(
                    project.into(),
                    threadmark_core::knowledge::HumanRankedQuery::new("alpha", &["note".into()])
                        .unwrap(),
                    root.into(),
                    identity.into(),
                    nonce.into()
                ),
                &std::sync::atomic::AtomicBool::new(false)
            )
            .is_err()
        );
        assert!(!f.0.join("store").exists());
    }
}

#[test]
fn ao03_real_cli_exact_lf_budget_escaped_whole_entries_and_counts() {
    let f = Fixture::new();
    let p = f.register();
    let a = args(&p, "needle", &["note"]);
    for id in ["a", "z"] {
        f.json(
            &["context", "add", "app", id, "note"],
            Some(&format!("needle{}", "x".repeat(3000))),
        );
    }
    let before = f.run(&a, None);
    assert!(before.status.success());
    let extra = 8192 - before.stdout.len();
    assert!(extra < 1090);
    f.json(
        &["context", "update", "app", "z", "note"],
        Some(&format!("needle{}", "x".repeat(3000 + extra))),
    );
    let exact = f.run(&a, None);
    assert!(exact.status.success());
    assert_eq!(exact.stdout.len(), 8192);
    assert_eq!(exact.stdout.last(), Some(&10));
    f.json(
        &["context", "update", "app", "z", "note"],
        Some(&format!("needle{}", "x".repeat(3001 + extra))),
    );
    let over = f.run(&a, None);
    assert!(over.status.success());
    assert!(over.stdout.len() <= 8192);
    assert_eq!(
        serde_json::from_slice::<Value>(&over.stdout).unwrap()["omitted_entries"],
        1
    );
    f.json(
        &["context", "update", "app", "a", "note"],
        Some(&format!("needle{}", "\u{1}".repeat(4000))),
    );
    f.json(&["context", "add", "app", "b", "note"], Some("needle"));
    let r: Value = serde_json::from_slice(&f.run(&a, None).stdout).unwrap();
    assert_eq!(r["matched_entries"], 3);
    assert_eq!(r["omitted_entries"], 1);
    assert_eq!(r["results"][0]["id"], "b");
}

#[test]
fn ao05_06_legacy_no_upgrade_and_v3_v4_read_bytes_preserved() {
    let f = Fixture::new();
    let p = f.register();
    f.json(&["context", "add", "app", "memo", "note"], Some("needle"));
    let db = f.0.join("store/knowledge.sqlite");
    let before = std::fs::read(&db).unwrap();
    assert!(f.run(&args(&p, "needle", &["note"]), None).status.success());
    assert_eq!(std::fs::read(&db).unwrap(), before);
    let mut wrong = p.clone();
    wrong["incarnation"] = json!("ffffffffffffffffffffffffffffffff");
    let out = f.run(&args(&wrong, "needle", &["note"]), None);
    assert!(!out.status.success());
    assert!(out.stdout.is_empty());
    assert_eq!(std::fs::read(&db).unwrap(), before);
    let strip4 = "DROP TRIGGER threadmark_source_policy_guard; DROP TRIGGER threadmark_source_evidence_guard; DROP TRIGGER threadmark_source_project_delete_guard; DROP TABLE forgotten_sources; PRAGMA user_version=3;";
    let strip3 = "DROP TRIGGER threadmark_project_incarnation_insert; DROP TRIGGER threadmark_project_incarnation_delete; DROP TABLE project_incarnations; PRAGMA user_version=2;";
    for (script, supported) in [(strip4, true), (strip3, false)] {
        assert!(Command::new("python3").args(["-c", "import sqlite3,sys; c=sqlite3.connect(sys.argv[1]); c.executescript(sys.argv[2]); c.close()"]).arg(&db).arg(script).status().unwrap().success());
        let before = std::fs::read(&db).unwrap();
        let out = f.run(&args(&p, "needle", &["note"]), None);
        assert_eq!(out.status.success(), supported);
        if !supported {
            assert!(out.stdout.is_empty());
        }
        assert_eq!(std::fs::read(&db).unwrap(), before);
    }
}
