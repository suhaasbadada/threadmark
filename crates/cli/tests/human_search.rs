//! Synthetic CLI + daemon + actual SQLite human-overlay retrieval journey.
use serde_json::Value;
use std::io::Write;
use std::path::PathBuf;
use std::process::{Command, Output, Stdio};

struct Fixture(PathBuf);
impl Fixture {
    fn new() -> Self {
        static NEXT: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        let root = std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-cli-human-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
        ));
        std::fs::create_dir(&root).unwrap();
        Self(root)
    }
    fn run(&self, args: &[&str], text: Option<&str>) -> Output {
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
        let out = self.run(args, text);
        assert!(
            out.status.success(),
            "{}",
            String::from_utf8_lossy(&out.stderr)
        );
        serde_json::from_slice(&out.stdout).unwrap()
    }
    fn register(&self, id: &str) {
        let root = self.0.join(id);
        std::fs::create_dir(&root).unwrap();
        std::fs::write(root.join("code.rs"), "// synthetic unchanged source\n").unwrap();
        self.json(
            &["project", "add", id, root.to_str().unwrap(), "code.rs"],
            None,
        );
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        std::fs::remove_dir_all(&self.0).unwrap();
    }
}

#[test]
fn human_search_is_active_latest_scoped_and_distinct_from_source_query() {
    let f = Fixture::new();
    f.register("app");
    f.register("app-copy");
    f.json(
        &["context", "add", "app", "memo", "note"],
        Some("synthetic cobalt policy"),
    );
    f.json(
        &["context", "add", "app-copy", "memo", "decision"],
        Some("synthetic amber policy"),
    );
    let other = f.json(&["context", "show", "app-copy", "memo"], None);
    let reply = f.json(&["context", "search", "app", "cobalt"], None);
    assert_eq!(reply["results"][0]["id"], "memo");
    assert_eq!(reply["results"][0]["revision"], 1);
    assert_eq!(reply["results"][0]["producer"], "human-authored");
    assert!(reply.get("currentness").is_none());
    let project = f.json(&["project", "show", "app"], None);
    assert_eq!(reply["incarnation"], project["incarnation"]);
    assert_eq!(reply["root_identity"], project["root_identity"]);
    assert_eq!(
        f.json(&["context", "search", "app-copy", "cobalt"], None)["matched_entries"],
        0
    );
    f.json(&["index", "app"], None);
    assert!(
        f.json(&["query", "app", "cobalt"], None)["results"]
            .as_array()
            .unwrap()
            .is_empty()
    );
    f.json(
        &["context", "update", "app", "memo", "decision"],
        Some("synthetic amber policy"),
    );
    assert_eq!(
        f.json(&["context", "search", "app", "cobalt"], None)["matched_entries"],
        0
    );
    let edited = f.json(&["context", "search", "app", "amber"], None);
    assert_eq!(edited["results"][0]["revision"], 2);
    assert_eq!(edited["results"][0]["kind"], "decision");
    f.json(&["context", "retire", "app", "memo"], None);
    assert_eq!(
        f.json(&["context", "search", "app", "amber"], None)["matched_entries"],
        0
    );
    f.json(
        &["context", "add", "app", "forgotten", "constraint"],
        Some("synthetic amber rule"),
    );
    f.json(
        &[
            "context",
            "forget",
            "app",
            "forgotten",
            "--confirm-forget-local-history",
        ],
        None,
    );
    f.json(&["index", "app"], None);
    assert_eq!(
        f.json(&["context", "search", "app", "amber"], None)["matched_entries"],
        0
    );
    assert_eq!(
        other,
        f.json(&["context", "show", "app-copy", "memo"], None)
    );
    for project in ["app", "app-copy"] {
        assert_eq!(
            std::fs::read_to_string(f.0.join(project).join("code.rs")).unwrap(),
            "// synthetic unchanged source\n"
        );
    }
}

#[test]
fn cli_unicode_determinism_and_full_json_whole_entry_limits() {
    let f = Fixture::new();
    f.register("app");
    let huge = format!("ÉCLAIR{}", "\u{1}".repeat(4000));
    f.json(&["context", "add", "app", "a-huge", "note"], Some(&huge));
    for n in (0..10).rev() {
        f.json(
            &["context", "add", "app", &format!("b{n:02}"), "correction"],
            Some("éclair"),
        );
    }
    let first = f.run(&["context", "search", "app", "ÉCLAIR"], None);
    assert!(first.status.success());
    assert!(first.stdout.ends_with(b"\n"));
    assert!(first.stdout.len() <= 8192);
    let reply: Value = serde_json::from_slice(&first.stdout).unwrap();
    assert_eq!(reply["matched_entries"], 11);
    assert_eq!(reply["omitted_entries"], 3);
    assert_eq!(reply["truncated"], true);
    assert_eq!(reply["results"].as_array().unwrap().len(), 8);
    assert_eq!(reply["results"][0]["id"], "b00");
    assert!(
        reply["results"]
            .as_array()
            .unwrap()
            .iter()
            .all(|r| r["text"] == "éclair")
    );
    assert_eq!(
        first.stdout,
        f.run(&["context", "search", "app", "ÉCLAIR"], None).stdout
    );
}

#[test]
fn malformed_query_scope_and_cancellation_fail_before_storage_or_content_publication() {
    use std::sync::atomic::AtomicBool;
    use threadmark_daemon::knowledge::{Command as KnowledgeCommand, run};
    let f = Fixture::new();
    for args in [
        vec!["context", "search", "app", ""],
        vec!["context", "search", "app", "   "],
        vec!["context", "search", "app", "x\ny"],
        vec!["context", "search", "../app", "private-query"],
        vec!["context", "search", "app"],
        vec!["context", "search", "app", "private-query", "extra"],
    ] {
        let out = f.run(&args, None);
        assert!(!out.status.success() && out.stdout.is_empty());
        assert!(!String::from_utf8_lossy(&out.stderr).contains("private-query"));
        assert!(!f.0.join("store").exists());
    }
    for query in ["x".repeat(257), "é".repeat(129)] {
        let out = f.run(&["context", "search", "app", &query], None);
        assert!(!out.status.success() && out.stdout.is_empty());
        assert!(!f.0.join("store").exists());
    }
    assert!(
        run(
            &f.0.join("store"),
            KnowledgeCommand::SearchContext("app".into(), "synthetic".into()),
            &AtomicBool::new(true)
        )
        .is_err()
    );
    assert!(!f.0.join("store").exists());
    // Valid reads are existing-store-only too.
    assert!(
        !f.run(&["context", "search", "app", "synthetic"], None)
            .status
            .success()
    );
    assert!(!f.0.join("store").exists());
}
