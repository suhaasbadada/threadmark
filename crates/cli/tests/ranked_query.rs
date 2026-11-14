//! Explicit ranked retrieval through real subprocesses and SQLite; synthetic only.
use serde_json::{Value, json};
use std::path::PathBuf;
use std::process::{Command, Output};
use std::sync::atomic::{AtomicU64, Ordering};

struct Fixture(PathBuf);
impl Fixture {
    fn new() -> Self {
        static NEXT: AtomicU64 = AtomicU64::new(0);
        let path = std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-cli-ranked-{}-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        std::fs::create_dir(&path).unwrap();
        std::fs::create_dir(path.join("source")).unwrap();
        Self(path)
    }
    fn run(&self, args: &[&str]) -> Output {
        Command::new(env!("CARGO_BIN_EXE_threadmark"))
            .arg("--data-dir")
            .arg(self.0.join("store"))
            .args(args)
            .env("CARGO_NET_OFFLINE", "true")
            .output()
            .unwrap()
    }
    fn ok(&self, args: &[&str]) -> Value {
        let o = self.run(args);
        assert!(o.status.success(), "operation failed");
        assert!(o.stderr.is_empty());
        serde_json::from_slice(&o.stdout).unwrap()
    }
    fn register(&self) {
        self.ok(&[
            "project",
            "add",
            "a",
            self.0.join("source").to_str().unwrap(),
            "a.rs",
        ]);
        self.ok(&["index", "a"]);
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        std::fs::remove_dir_all(&self.0).unwrap();
    }
}

#[test]
fn real_sqlite_multiterm_journey_preserves_literal_query_and_recovers_after_stale() {
    let f = Fixture::new();
    std::fs::write(
        f.0.join("source/a.rs"),
        format!(
            "{}{}alpha gap beta beta\nÄLPHA blue\n",
            "alpha\n".repeat(9),
            "beta\n".repeat(9)
        ),
    )
    .unwrap();
    f.register();
    let before = f.ok(&["query", "a", "alpha beta"]);
    assert_eq!(before["results"], json!([]));
    let r = f.ok(&["query-terms", "a", "alpha beta"]);
    assert_eq!(r["results"][0]["line"], 19);
    assert_eq!(r["results"][0]["matched_terms"], 2);
    assert_eq!(r["truncated"], true);
    assert_eq!(f.ok(&["query", "a", "alpha beta"]), before);
    assert_eq!(
        f.ok(&["query-terms", "a", "älpha ÄLPHA blue"])["terms"],
        json!(["älpha", "blue"])
    );
    std::fs::write(f.0.join("source/unapproved.rs"), "synthetic-unapproved\n").unwrap();
    assert_eq!(
        f.ok(&["query-terms", "a", "synthetic-unapproved"])["results"],
        json!([])
    );
    std::fs::write(f.0.join("source/a.rs"), "changed alpha gap beta\n").unwrap();
    assert_eq!(
        f.ok(&["query-terms", "a", "alpha beta"])["currentness"],
        "stale-or-unindexed"
    );
    f.ok(&["index", "a"]);
    assert_eq!(
        f.ok(&["query-terms", "a", "alpha beta"])["results"][0]["text"],
        "changed alpha gap beta"
    );
    std::fs::remove_file(f.0.join("source/a.rs")).unwrap();
    assert_eq!(
        f.ok(&["query-terms", "a", "alpha beta"])["results"],
        json!([])
    );
    f.ok(&["project", "sources", "a"]);
    assert_eq!(
        f.ok(&["query-terms", "a", "alpha beta"])["results"],
        json!([])
    );
}

#[test]
fn parser_and_daemon_preflight_never_create_storage_or_echo_invalid_queries() {
    let f = Fixture::new();
    for args in [
        vec!["query-terms", "a"],
        vec!["query-terms", "a", "alpha", "beta"],
        vec!["query-terms", "../bad", "alpha"],
        vec!["query-terms", "a", ""],
        vec!["query-terms", "a", "a\tb"],
        vec!["query-terms", "a", "a b c d e f g h i"],
    ] {
        let out = f.run(&args);
        assert!(!out.status.success() && out.stdout.is_empty());
        assert!(!f.0.join("store").exists());
    }
    for q in ["x".repeat(65), "é".repeat(33), "a ".repeat(129)] {
        let out = f.run(&["query-terms", "a", &q]);
        assert!(!out.status.success() && out.stdout.is_empty());
        assert!(!String::from_utf8_lossy(&out.stderr).contains(&q));
        assert!(!f.0.join("store").exists());
    }
    let out = f.run(&["query-terms", "a", "valid"]);
    assert!(!out.status.success() && out.stdout.is_empty());
    assert!(!f.0.join("store").exists()); // read-only command requires existing storage
}

#[test]
fn stdout_envelope_including_newline_is_bounded_and_entries_are_complete() {
    let f = Fixture::new();
    let line = format!("alpha{}", "\"\\".repeat(500));
    std::fs::write(f.0.join("source/a.rs"), (line.clone() + "\n").repeat(8)).unwrap();
    f.register();
    let out = f.run(&["query-terms", "a", "alpha"]);
    assert!(out.status.success() && out.stdout.len() <= 8192 && out.stdout.ends_with(b"\n"));
    let r: Value = serde_json::from_slice(&out.stdout).unwrap();
    assert_eq!(r["truncated"], true);
    let results = r["results"].as_array().unwrap();
    assert!(!results.is_empty() && results.len() < 8);
    assert!(results.iter().all(|r| r["text"] == line));
}
