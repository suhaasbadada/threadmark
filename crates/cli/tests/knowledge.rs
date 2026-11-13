//! Real process CLI product journey; all content and roots are synthetic.
use serde_json::Value;
use std::io::Write;
use std::path::PathBuf;
use std::process::{Command, Output, Stdio};
use std::sync::atomic::{AtomicU64, Ordering};

static NEXT_FIXTURE: AtomicU64 = AtomicU64::new(0);

struct Fixture(PathBuf);
impl Fixture {
    fn new() -> Self {
        Self::with_timestamp(
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos(),
        )
    }
    fn with_timestamp(timestamp: u128) -> Self {
        let path = std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-cli-{}-{timestamp}-{}",
            std::process::id(),
            NEXT_FIXTURE.fetch_add(1, Ordering::Relaxed)
        ));
        std::fs::create_dir(&path).unwrap();
        std::fs::create_dir(path.join("source")).unwrap();
        std::fs::write(path.join("source/main.rs"), "fn synthetic_blue() {}\n").unwrap();
        Self(path)
    }
    fn run(&self, args: &[&str], input: Option<&[u8]>) -> Output {
        let mut process = Command::new(env!("CARGO_BIN_EXE_threadmark"))
            .arg("--data-dir")
            .arg(self.0.join("store"))
            .args(args)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .unwrap();
        if let Some(bytes) = input {
            process.stdin.take().unwrap().write_all(bytes).unwrap();
        } else {
            drop(process.stdin.take());
        }
        process.wait_with_output().unwrap()
    }
    fn ok(&self, args: &[&str], input: Option<&[u8]>) -> Value {
        let out = self.run(args, input);
        assert!(out.status.success(), "operation failed (redacted)");
        assert!(out.stderr.is_empty());
        serde_json::from_slice(&out.stdout).unwrap()
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        std::fs::remove_dir_all(&self.0).unwrap();
    }
}

#[test]
fn parallel_fixtures_with_identical_timestamps_have_distinct_owned_roots() {
    let barrier = std::sync::Arc::new(std::sync::Barrier::new(16));
    let workers: Vec<_> = (0..16)
        .map(|_| {
            let barrier = barrier.clone();
            std::thread::spawn(move || {
                barrier.wait();
                Fixture::with_timestamp(0)
            })
        })
        .collect();
    let fixtures: Vec<_> = workers.into_iter().map(|w| w.join().unwrap()).collect();
    let roots: std::collections::HashSet<_> = fixtures.iter().map(|f| &f.0).collect();
    assert_eq!(roots.len(), 16);
    assert!(
        fixtures
            .iter()
            .all(|f| f.0.join("source/main.rs").is_file())
    );
}

#[test]
fn p2_manual_cli_persists_across_processes_and_errors_are_content_free() {
    let f = Fixture::new();
    f.ok(
        &[
            "project",
            "add",
            "synthetic",
            f.0.join("source").to_str().unwrap(),
            "main.rs",
        ],
        None,
    );
    assert_eq!(
        f.ok(&["project", "list"], None).as_array().unwrap().len(),
        1
    );
    assert_eq!(
        f.ok(&["project", "show", "synthetic"], None)["sources"][0],
        "main.rs"
    );
    assert_eq!(f.ok(&["index", "synthetic"], None)["anchors"], 1);
    let query = f.ok(&["query", "synthetic", "synthetic_blue"], None);
    assert_eq!(query["results"][0]["line"], 1);
    assert_eq!(query["results"][0]["path"], "main.rs");
    assert_eq!(query["results"][0]["kind"], "observed-source-line");
    f.ok(
        &["context", "add", "synthetic", "rule", "decision"],
        Some(b"synthetic user choice\n"),
    );
    f.ok(
        &["context", "update", "synthetic", "rule", "constraint"],
        Some(b"synthetic revised choice\n"),
    );
    assert_eq!(
        f.ok(&["context", "show", "synthetic", "rule"], None)["history"][1]["text"],
        "synthetic revised choice\n"
    );
    f.ok(&["context", "retire", "synthetic", "rule"], None);
    assert_eq!(
        f.ok(&["context", "list", "synthetic"], None)["contexts"][0]["retired"],
        true
    );
    std::fs::write(f.0.join("source/main.rs"), "fn synthetic_green() {}\n").unwrap();
    assert_eq!(
        f.ok(&["query", "synthetic", "blue"], None)["currentness"],
        "stale-or-unindexed"
    );
    f.ok(&["index", "synthetic"], None);
    assert_eq!(
        f.ok(&["query", "synthetic", "green"], None)["results"][0]["text"],
        "fn synthetic_green() {}"
    );
    f.ok(&["project", "sources", "synthetic"], None);
    assert!(
        f.ok(&["query", "synthetic", "green"], None)["results"]
            .as_array()
            .unwrap()
            .is_empty()
    );
    f.ok(&["index", "synthetic"], None);
    assert_eq!(
        f.ok(&["context", "show", "synthetic", "rule"], None)["history"]
            .as_array()
            .unwrap()
            .len(),
        3
    );
    for (args, input) in [
        (
            vec!["project", "sources", "synthetic", "../private-content.rs"],
            None,
        ),
        (
            vec!["context", "update", "synthetic", "missing", "decision"],
            Some(b"private-content".as_slice()),
        ),
        (vec!["query", "unknown-project", "private-content"], None),
    ] {
        let out = f.run(&args, input);
        assert!(!out.status.success());
        assert!(out.stdout.is_empty());
        let err = String::from_utf8(out.stderr).unwrap();
        assert!(!err.contains("private-content"));
        assert!(!err.contains(f.0.to_str().unwrap()));
    }
    assert!(f.0.join("source/main.rs").is_file());
}

#[test]
fn core_backed_context_preview_preserves_original_without_inference_or_delivery() {
    let f = Fixture::new();
    f.ok(
        &[
            "project",
            "add",
            "synthetic",
            f.0.join("source").to_str().unwrap(),
            "main.rs",
        ],
        None,
    );
    let original =
        "Locate synthetic_blue. Do not deploy or change permissions. 保持 exact intent.\n";
    let absent = f.ok(
        &["context", "prepare", "synthetic", "synthetic_blue"],
        Some(original.as_bytes()),
    );
    assert_eq!(absent["state"], "needs-input");
    assert_eq!(absent["original"], original);
    f.ok(&["index", "synthetic"], None);
    let preview = f.ok(
        &["context", "prepare", "synthetic", "synthetic_blue"],
        Some(original.as_bytes()),
    );
    assert_eq!(preview["state"], "ready-for-review");
    assert_eq!(preview["original"], original);
    assert!(preview["proposed"].as_str().unwrap().starts_with(original));
    assert!(
        preview["proposed"]
            .as_str()
            .unwrap()
            .contains("fn synthetic_blue() {}")
    );
    assert!(
        preview["proposed"]
            .as_str()
            .unwrap()
            .contains("quoted untrusted data")
    );
    assert_eq!(preview["provider"], "not-invoked");
    assert_eq!(preview["approval"], "not-requested");
    assert_eq!(preview["delivery"], "not-attempted");
    assert!(serde_json::to_vec(&preview).unwrap().len() <= 8192);
    // The original fits 4 KiB, but the complete original-plus-proposed JSON
    // does not. Reject rather than truncate intent or evidence.
    let envelope_overflow = f.run(
        &["context", "prepare", "synthetic", "synthetic_blue"],
        Some(&vec![b'x'; 4096]),
    );
    assert!(!envelope_overflow.status.success() && envelope_overflow.stdout.is_empty());
    assert!(
        f.ok(&["context", "list", "synthetic"], None)["contexts"]
            .as_array()
            .unwrap()
            .is_empty()
    );

    f.ok(
        &["context", "add", "synthetic", "memo", "note"],
        Some(b"Synthetic human note"),
    );
    std::fs::write(f.0.join("source/main.rs"), "fn synthetic_green() {}\n").unwrap();
    let stale = f.ok(
        &["context", "prepare", "synthetic", "synthetic_blue"],
        Some(original.as_bytes()),
    );
    assert_eq!(stale["state"], "needs-input");
    assert!(
        !stale["proposed"]
            .as_str()
            .unwrap()
            .contains("fn synthetic_blue() {}")
    );
    assert_eq!(
        f.ok(&["context", "show", "synthetic", "memo"], None)["history"][0]["text"],
        "Synthetic human note"
    );
    let denied = f.run(
        &["context", "prepare", "unregistered", "synthetic_blue"],
        Some(original.as_bytes()),
    );
    assert!(!denied.status.success() && denied.stdout.is_empty());
    assert!(!String::from_utf8(denied.stderr).unwrap().contains(original));
    let oversized = f.run(
        &["context", "prepare", "synthetic", "synthetic_blue"],
        Some(&vec![b'x'; 4097]),
    );
    assert!(!oversized.status.success() && oversized.stdout.is_empty());
}

#[test]
fn explicit_project_removal_is_local_content_free_and_persistent_across_processes() {
    let f = Fixture::new();
    // Confirmation is parsed before any store is opened or created.
    for args in [
        vec!["project", "remove", "synthetic"],
        vec!["project", "remove", "synthetic", "--confirm"],
    ] {
        let out = f.run(&args, None);
        assert!(!out.status.success() && out.stdout.is_empty());
        assert!(!f.0.join("store").exists());
    }
    let other = Fixture::new();
    for (id, root) in [
        ("synthetic", f.0.join("source")),
        ("other", other.0.join("source")),
    ] {
        f.ok(
            &["project", "add", id, root.to_str().unwrap(), "main.rs"],
            None,
        );
        f.ok(&["index", id], None);
        f.ok(
            &["context", "add", id, "note", "note"],
            Some(b"synthetic private note"),
        );
    }
    f.ok(
        &["context", "update", "synthetic", "note", "decision"],
        Some(b"synthetic revised note"),
    );
    f.ok(&["context", "retire", "synthetic", "note"], None);
    let source = std::fs::read(f.0.join("source/main.rs")).unwrap();
    let other_source = std::fs::read(other.0.join("source/main.rs")).unwrap();
    let other_project = f.ok(&["project", "show", "other"], None);
    let other_query = f.ok(&["query", "other", "synthetic_blue"], None);
    let other_context = f.ok(&["context", "show", "other", "note"], None);
    // Missing confirmation against an existing store must leave it untouched too.
    assert!(
        !f.run(&["project", "remove", "synthetic"], None)
            .status
            .success()
    );
    assert_eq!(
        f.ok(&["context", "show", "synthetic", "note"], None)["history"]
            .as_array()
            .unwrap()
            .len(),
        3
    );
    let receipt = f.ok(
        &[
            "project",
            "remove",
            "synthetic",
            "--confirm-remove-local-data",
        ],
        None,
    );
    assert_eq!(receipt["project"], "synthetic");
    assert_eq!(receipt["removed"], true);
    let encoded = serde_json::to_string(&receipt).unwrap();
    assert!(encoded.len() < 1024 && receipt["retention_limits"].is_string());
    for private in [
        f.0.to_str().unwrap(),
        "synthetic private note",
        "synthetic revised note",
        "fn synthetic_blue",
    ] {
        assert!(!encoded.contains(private));
    }
    for args in [
        vec!["project", "show", "synthetic"],
        vec!["query", "synthetic", "synthetic_blue"],
        vec!["context", "list", "synthetic"],
        vec!["context", "show", "synthetic", "note"],
        vec!["index", "synthetic"],
        vec![
            "project",
            "remove",
            "unknown",
            "--confirm-remove-local-data",
        ],
        vec![
            "project",
            "remove",
            "../private-note",
            "--confirm-remove-local-data",
        ],
    ] {
        let out = f.run(&args, None);
        assert!(!out.status.success() && out.stdout.is_empty());
        assert_eq!(
            String::from_utf8(out.stderr).unwrap(),
            "local knowledge operation failed; no content published\n"
        );
    }
    assert_eq!(
        f.ok(&["project", "list"], None).as_array().unwrap().len(),
        1
    );
    assert_eq!(f.ok(&["project", "show", "other"], None), other_project);
    assert_eq!(
        f.ok(&["query", "other", "synthetic_blue"], None),
        other_query
    );
    assert_eq!(
        f.ok(&["context", "show", "other", "note"], None),
        other_context
    );
    assert_eq!(std::fs::read(f.0.join("source/main.rs")).unwrap(), source);
    assert_eq!(
        std::fs::read(other.0.join("source/main.rs")).unwrap(),
        other_source
    );
    f.ok(
        &[
            "project",
            "add",
            "synthetic",
            f.0.join("source").to_str().unwrap(),
            "main.rs",
        ],
        None,
    );
    assert!(
        f.ok(&["context", "list", "synthetic"], None)["contexts"]
            .as_array()
            .unwrap()
            .is_empty()
    );
    assert!(
        !f.run(&["context", "show", "synthetic", "note"], None)
            .status
            .success()
    );
    assert!(
        f.ok(&["query", "synthetic", "blue"], None)["results"]
            .as_array()
            .unwrap()
            .is_empty()
    );
    f.ok(&["index", "synthetic"], None);
    assert_eq!(
        f.ok(&["query", "synthetic", "blue"], None)["results"]
            .as_array()
            .unwrap()
            .len(),
        1
    );
    assert!(
        f.ok(&["context", "list", "synthetic"], None)["contexts"]
            .as_array()
            .unwrap()
            .is_empty()
    );
}
