//! AK: actual closed CLI grammar, real store/source bytes, explicit local stdout only.
use serde_json::{Value, json};
use std::path::PathBuf;
use std::process::{Command, Output, Stdio};

struct Fixture(PathBuf);
impl Fixture {
    fn new() -> Self {
        static NEXT: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        let p = std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-cli-file-query-{}-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos(),
            NEXT.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
        ));
        std::fs::create_dir(&p).unwrap();
        std::fs::create_dir(p.join("source")).unwrap();
        Self(p)
    }
    fn run(&self, args: &[String]) -> Output {
        Command::new(env!("CARGO_BIN_EXE_threadmark"))
            .arg("--data-dir")
            .arg(self.0.join("store"))
            .args(args)
            .output()
            .unwrap()
    }
    fn ok(&self, args: &[String]) -> Value {
        let o = self.run(args);
        assert!(o.status.success(), "CLI operation failed");
        assert!(o.stderr.is_empty());
        serde_json::from_slice(&o.stdout).unwrap()
    }
    fn write(&self, p: &str, text: &str) {
        std::fs::write(self.0.join("source").join(p), text).unwrap();
    }
    fn register(&self, paths: &[&str], index: bool) -> Value {
        let mut a = words(&[
            "project",
            "add",
            "a",
            self.0.join("source").to_str().unwrap(),
        ]);
        a.extend(words(paths));
        self.ok(&a);
        if index {
            self.ok(&words(&["index", "a"]));
        }
        self.ok(&words(&["project", "show", "a"]))
    }
    fn held_stdin(&self, args: &[String]) -> Output {
        let mut child = Command::new(env!("CARGO_BIN_EXE_threadmark"))
            .arg("--data-dir")
            .arg(self.0.join("store"))
            .args(args)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .unwrap();
        let held = child.stdin.take().unwrap();
        let output = child.wait_with_output().unwrap();
        drop(held);
        output
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
fn args(p: &Value, mode: &str, query: &str, paths: &[&str]) -> Vec<String> {
    let mut a = words(&[
        "query-files",
        "a",
        query,
        "--mode",
        mode,
        "--selected-files",
    ]);
    a.extend(words(paths));
    a.extend(words(&[
        "--expected-root",
        p["root"].as_str().unwrap(),
        "--expected-root-identity",
        p["root_identity"].as_str().unwrap(),
        "--expected-incarnation",
        p["incarnation"].as_str().unwrap(),
        "--expected-snapshot",
        p["snapshot"].as_str().unwrap_or("none"),
        "--expected-sources",
    ]));
    a.extend(
        p["sources"]
            .as_array()
            .unwrap()
            .iter()
            .map(|v| v.as_str().unwrap().into()),
    );
    a
}
fn rejected(o: Output) {
    assert!(!o.status.success());
    assert!(o.stdout.is_empty());
}

#[test]
fn real_modes_filter_before_match_score_result_and_byte_budget_with_held_stdin() {
    let f = Fixture::new();
    f.write(
        "a.rs",
        &(format!("alpha beta beta{}\n", "\"\\".repeat(400))).repeat(12),
    );
    f.write("z.rs", "alpha beta\nalpha beta\n");
    let p = f.register(&["z.rs", "a.rs"], true);
    let old = f.ok(&words(&["query-terms", "a", "alpha beta"]));
    for mode in ["literal", "ranked-any-terms"] {
        let o = f.held_stdin(&args(&p, mode, "alpha", &["z.rs"]));
        assert!(o.status.success());
        assert!(o.stdout.len() <= 8192);
        assert_eq!(o.stdout.last(), Some(&b'\n'));
        let r: Value = serde_json::from_slice(&o.stdout).unwrap();
        assert_eq!(r["format"], "threadmark-file-scoped-retrieval");
        assert_eq!(r["version"], 1);
        assert_eq!(r["mode"], mode);
        assert_eq!(r["selected_paths"], json!(["z.rs"]));
        assert_eq!(r["matching_anchors"], 2);
        assert_eq!(r["results"].as_array().unwrap().len(), 2);
        assert_eq!(r["truncated"], false);
        assert_eq!(r["results"][0]["path"], "z.rs");
        assert!(!String::from_utf8(o.stdout).unwrap().contains("beta beta"));
    }
    assert_eq!(f.ok(&words(&["query-terms", "a", "alpha beta"])), old);
}

#[test]
fn canonical_scope_full_subset_equivalence_and_unicode_algorithms() {
    let f = Fixture::new();
    f.write("a.rs", "ALPHA\nÄ\né\ne\u{301}\n\"\\\n");
    f.write("z.rs", "ALPHA\n");
    let p = f.register(&["z.rs", "a.rs"], true);
    for mode in ["literal", "ranked-any-terms"] {
        for q in ["alpha", "ä", "Ä", "é", "e\u{301}", "\"\\", "absent"] {
            let r = f.ok(&args(&p, mode, q, &["a.rs", "z.rs"]));
            assert_eq!(r["selected_paths"], json!(["z.rs", "a.rs"]));
            let old = f.ok(&words(&[
                if mode == "literal" {
                    "query"
                } else {
                    "query-terms"
                },
                "a",
                q,
            ]));
            assert_eq!(r["results"], old["results"]);
            assert_eq!(r["truncated"], old["truncated"]);
        }
    }
}

#[test]
fn unselected_mutations_remain_full_snapshot_stale_and_forget_invalidates_scope() {
    for mode in ["literal", "ranked-any-terms"] {
        for mutation in 0..3 {
            let f = Fixture::new();
            f.write("a.rs", "alpha\n");
            f.write("z.rs", "alpha\n");
            let p = f.register(&["a.rs", "z.rs"], true);
            match mutation {
                0 => f.write("a.rs", "changed\n"),
                1 => std::fs::remove_file(f.0.join("source/a.rs")).unwrap(),
                _ => {
                    std::fs::remove_file(f.0.join("source/a.rs")).unwrap();
                    std::os::unix::fs::symlink("z.rs", f.0.join("source/a.rs")).unwrap();
                }
            }
            let r = f.ok(&args(&p, mode, "alpha", &["z.rs"]));
            assert_eq!(r["currentness"], "stale-or-unindexed");
            assert_eq!(r["results"], json!([]));
        }
        let f = Fixture::new();
        f.write("a.rs", "alpha\n");
        f.write("z.rs", "alpha\n");
        let p = f.register(&["a.rs", "z.rs"], true);
        f.ok(&words(&[
            "source",
            "forget",
            "a",
            "z.rs",
            "--confirm-forget-source",
        ]));
        rejected(f.run(&args(&p, mode, "alpha", &["z.rs"])));
        let now = f.ok(&words(&["project", "show", "a"]));
        rejected(f.run(&args(&now, mode, "alpha", &["z.rs"])));
        f.ok(&words(&["index", "a"]));
        assert_eq!(
            std::fs::read_to_string(f.0.join("source/z.rs")).unwrap(),
            "alpha\n"
        );
    }
}

#[test]
fn strict_preopen_shapes_existing_only_and_no_stdin() {
    let f = Fixture::new();
    let p = json!({"root":f.0.join("source").to_str().unwrap(),"root_identity":"synthetic-root","incarnation":"0".repeat(32),"snapshot":null,"sources":["a.rs"]});
    let good = args(&p, "literal", "alpha", &["a.rs"]);
    for paths in [
        vec![],
        vec!["a.rs", "a.rs"],
        vec!["unknown.rs"],
        vec!["../a.rs"],
        vec![".git/config"],
        vec!["a.rs"; 65],
    ] {
        rejected(f.held_stdin(&args(&p, "literal", "alpha", &paths)));
        assert!(!f.0.join("store").exists());
    }
    for q in [
        "".to_string(),
        "é".repeat(129),
        "alpha beta gamma delta e f g h i".into(),
    ] {
        rejected(f.held_stdin(&args(&p, "ranked-any-terms", &q, &["a.rs"])));
    }
    for n in 3..good.len() {
        rejected(f.held_stdin(&good[..n]));
        assert!(!f.0.join("store").exists());
    }
    for change in ["unknown-mode", "extra-flag"] {
        let mut a = good.clone();
        if change == "unknown-mode" {
            a[4] = "semantic".into();
        } else {
            a.push("--extra".into());
        }
        rejected(f.held_stdin(&a));
    }
    rejected(f.held_stdin(&good));
    assert!(!f.0.join("store").exists());
}

#[test]
fn exact_binding_mismatch_rejects_and_empty_unindexed_are_honest() {
    let f = Fixture::new();
    f.write("a.rs", "alpha\n");
    let p = f.register(&["a.rs"], false);
    for mode in ["literal", "ranked-any-terms"] {
        let r = f.ok(&args(&p, mode, "alpha", &["a.rs"]));
        assert_eq!(r["results"], json!([]));
        assert_eq!(r["currentness"], "stale-or-unindexed");
    }
    f.ok(&words(&["index", "a"]));
    let p = f.ok(&words(&["project", "show", "a"]));
    for key in [
        "root",
        "root_identity",
        "incarnation",
        "snapshot",
        "sources",
    ] {
        let mut wrong = p.clone();
        match key {
            "root" => wrong[key] = json!(f.0.join("other").to_str().unwrap()),
            "sources" => wrong[key] = json!(["a.rs", "z.rs"]),
            "root_identity" => wrong[key] = json!("other-root"),
            _ => wrong[key] = json!("0".repeat(64)),
        };
        for mode in ["literal", "ranked-any-terms"] {
            rejected(f.run(&args(&wrong, mode, "alpha", &["a.rs"])));
        }
    }
}

#[test]
fn maximum_two_64_file_lists_and_utf8_whole_entry_frame() {
    let f = Fixture::new();
    let paths: Vec<_> = (0..64).map(|i| format!("f{i:02}.rs")).collect();
    for p in &paths {
        f.write(p, "alpha\n");
    }
    let refs: Vec<_> = paths.iter().map(String::as_str).collect();
    let p = f.register(&refs, true);
    for mode in ["literal", "ranked-any-terms"] {
        let r = f.ok(&args(&p, mode, "alpha", &refs));
        assert_eq!(r["selected_paths"].as_array().unwrap().len(), 64);
        assert_eq!(r["matching_anchors"], 64);
        assert_eq!(r["results"].as_array().unwrap().len(), 8);
        assert_eq!(r["truncated"], true);
    }
    let g = Fixture::new();
    let line = format!("alpha{}", "\"\\é".repeat(250));
    g.write("a.rs", &(line.clone() + "\n").repeat(8));
    let p = g.register(&["a.rs"], true);
    for mode in ["literal", "ranked-any-terms"] {
        let o = g.run(&args(&p, mode, "alpha", &["a.rs"]));
        assert!(o.status.success());
        assert!(o.stdout.len() <= 8192);
        let r: Value = serde_json::from_slice(&o.stdout).unwrap();
        assert_eq!(r["matching_anchors"], 8);
        assert_eq!(r["truncated"], true);
        assert!(
            r["results"]
                .as_array()
                .unwrap()
                .iter()
                .all(|r| r["text"] == line)
        );
    }
}

#[test]
fn typed_daemon_preflight_existing_only_and_legacy_no_implicit_upgrade() {
    use std::sync::atomic::AtomicBool;
    use threadmark_core::knowledge::{FileQuery, FileQueryMode, Project};
    use threadmark_daemon::knowledge::{Command as DaemonCommand, run};
    let f = Fixture::new();
    let p = || Project {
        id: "a".into(),
        root: f.0.join("source").to_str().unwrap().into(),
        root_identity: "synthetic-root".into(),
        incarnation: Some("0".repeat(32)),
        sources: vec!["a.rs".into()],
        snapshot: None,
    };
    for paths in [
        vec![],
        vec!["unknown.rs"],
        vec!["a.rs", "a.rs"],
        vec!["a.rs"],
    ] {
        let request = FileQuery {
            query: "alpha".into(),
            mode: FileQueryMode::Literal,
            selected_paths: paths.iter().map(|p| (*p).into()).collect(),
        };
        let result = run(
            &f.0.join("store"),
            DaemonCommand::QueryFilesBound(p(), request),
            &AtomicBool::new(false),
        );
        assert!(result.is_err());
        assert!(!f.0.join("store").exists());
    }
    f.write("a.rs", "alpha\n");
    let p = f.register(&["a.rs"], true);
    let db = f.0.join("store/knowledge.sqlite");
    assert!(Command::new("python3").args(["-c", "import sqlite3,sys; d=sqlite3.connect(sys.argv[1]); d.executescript('DROP TRIGGER threadmark_source_project_delete_guard; DROP TRIGGER threadmark_source_evidence_guard; DROP TRIGGER threadmark_source_policy_guard; DROP TABLE forgotten_sources; DROP TRIGGER threadmark_project_incarnation_insert; DROP TRIGGER threadmark_project_incarnation_delete; DROP TABLE project_incarnations; PRAGMA user_version=2;'); d.close()"])
        .arg(&db).status().unwrap().success());
    let bytes = std::fs::read(&db).unwrap();
    for mode in ["literal", "ranked-any-terms"] {
        rejected(f.run(&args(&p, mode, "alpha", &["a.rs"])));
    }
    assert_eq!(std::fs::read(&db).unwrap(), bytes);
}
