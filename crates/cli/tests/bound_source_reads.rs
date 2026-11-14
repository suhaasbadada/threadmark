//! Synthetic cached metadata -> real CLI/SQLite selection. TM-01–04/07/10,
//! P2-A1/A6 and P4-A2. Core private source-boundary tests prove pre-read rejection.
use serde_json::Value;
use std::io::Write;
use std::path::PathBuf;
use std::process::{Command, Output, Stdio};

struct Fixture(PathBuf);
impl Fixture {
    fn new() -> Self {
        static NEXT: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        let path = std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-bound-read-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
        ));
        std::fs::create_dir(&path).unwrap();
        Self(path)
    }
    fn run(&self, args: &[String]) -> Output {
        let mut child = Command::new(env!("CARGO_BIN_EXE_threadmark"))
            .arg("--data-dir")
            .arg(self.0.join("store"))
            .args(args)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .unwrap();
        // Early argument rejection may close stdin; no retry/fallback.
        let _ = child
            .stdin
            .take()
            .unwrap()
            .write_all(b"Synthetic original; do not send.");
        child.wait_with_output().unwrap()
    }
    fn json(&self, args: &[String]) -> Value {
        let out = self.run(args);
        assert!(
            out.status.success(),
            "{}",
            String::from_utf8_lossy(&out.stderr)
        );
        serde_json::from_slice(&out.stdout).unwrap()
    }
    fn register(&self, root: &str, sources: bool) {
        let path = self.0.join(root);
        if !path.exists() {
            std::fs::create_dir(&path).unwrap();
        }
        std::fs::write(path.join("code.rs"), "// synthetic amber source\n").unwrap();
        let mut args = vec![
            "project".into(),
            "add".into(),
            "app".into(),
            path.to_str().unwrap().into(),
        ];
        if sources {
            args.push("code.rs".into());
        }
        self.json(&args);
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
fn bound(p: &Value, context: bool) -> Vec<String> {
    let mut args = if context {
        words(&["context", "prepare", "app", "amber"])
    } else {
        words(&["query", "app", "amber"])
    };
    args.extend(words(&[
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
    args.extend(
        p["sources"]
            .as_array()
            .unwrap()
            .iter()
            .map(|s| s.as_str().unwrap().into()),
    );
    args
}
fn rejected(out: Output) {
    assert!(!out.status.success());
    assert!(out.stdout.is_empty());
    assert!(!String::from_utf8_lossy(&out.stderr).contains("amber"));
}

#[test]
fn cached_query_and_context_reject_peer_replacement_policy_and_snapshot_without_output() {
    for same_root in [false, true] {
        let f = Fixture::new();
        f.register("a", true);
        f.json(&words(&["index", "app"]));
        let captured = f.json(&words(&["project", "show", "app"]));
        for context in [false, true] {
            assert!(f.run(&bound(&captured, context)).status.success());
        }
        f.json(&words(&[
            "project",
            "remove",
            "app",
            "--confirm-remove-local-data",
        ]));
        f.register(if same_root { "a" } else { "b" }, true);
        f.json(&words(&["index", "app"]));
        for context in [false, true] {
            rejected(f.run(&bound(&captured, context)));
        }
        let fresh = f.json(&words(&["project", "show", "app"]));
        f.json(&words(&["project", "sources", "app"]));
        for context in [false, true] {
            rejected(f.run(&bound(&fresh, context)));
        }
    }
}

#[test]
fn absent_snapshot_empty_sources_and_source_edits_are_honest_needs_input() {
    for sources in [false, true] {
        let f = Fixture::new();
        f.register("a", sources);
        let p = f.json(&words(&["project", "show", "app"]));
        let preview = f.json(&bound(&p, true));
        assert_eq!(preview["state"], "needs-input");
        assert_eq!(preview["provider"], "not-invoked");
        f.json(&words(&["index", "app"]));
        let p = f.json(&words(&["project", "show", "app"]));
        std::fs::write(f.0.join("a/code.rs"), "// synthetic edited\n").unwrap();
        let query = f.json(&bound(&p, false));
        assert!(query["results"].as_array().unwrap().is_empty());
        assert_eq!(f.json(&bound(&p, true))["state"], "needs-input");
    }
}

#[test]
fn malformed_or_partial_cached_binding_never_creates_storage() {
    let f = Fixture::new();
    let p = serde_json::json!({"root":"/synthetic/root", "root_identity":"r1", "incarnation":"a".repeat(32), "snapshot":null, "sources":[]});
    for context in [false, true] {
        let full = bound(&p, context);
        for end in (if context { 5 } else { 4 })..full.len() {
            rejected(f.run(&full[..end]));
        }
        for (flag, bad) in [
            ("--expected-incarnation", "legacy"),
            ("--expected-snapshot", "bad"),
            ("--expected-root", "relative"),
        ] {
            let mut args = full.clone();
            let i = args.iter().position(|s| s == flag).unwrap();
            args[i + 1] = bad.into();
            rejected(f.run(&args));
        }
        let mut args = full;
        args.push("../escape.rs".into());
        rejected(f.run(&args));
    }
    assert!(!f.0.join("store").exists());
}

#[test]
fn exact_last_source_list_accepts_64_files_without_flag_ambiguity() {
    let f = Fixture::new();
    let root = f.0.join("many");
    std::fs::create_dir(&root).unwrap();
    let mut add = words(&["project", "add", "app", root.to_str().unwrap()]);
    for i in 0..64 {
        let path = format!("file-{i}.rs");
        std::fs::write(root.join(&path), "// synthetic amber\n").unwrap();
        add.push(path);
    }
    f.json(&add);
    f.json(&words(&["index", "app"]));
    let p = f.json(&words(&["project", "show", "app"]));
    for context in [false, true] {
        let args = bound(&p, context);
        assert!(f.run(&args).status.success());
        let mut too_many = args.clone();
        too_many.push("extra.rs".into());
        rejected(f.run(&too_many));
        let mut ambiguous = args;
        ambiguous.pop();
        ambiguous.push("--unrecognized-option".into());
        rejected(f.run(&ambiguous));
    }
}
