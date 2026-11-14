//! Synthetic real-process export approval guards, P2-A1/A5/A6.
use serde_json::Value;
use std::path::PathBuf;
use std::process::{Command, Output};

struct Fixture(PathBuf);
impl Fixture {
    fn new() -> Self {
        static NEXT: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        let p = std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-bound-export-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
        ));
        std::fs::create_dir(&p).unwrap();
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
    fn json(&self, args: &[String]) -> Value {
        let out = self.run(args);
        assert!(
            out.status.success(),
            "{}",
            String::from_utf8_lossy(&out.stderr)
        );
        serde_json::from_slice(&out.stdout).unwrap()
    }
    fn project(&self) -> Value {
        self.json(&words(&["project", "show", "app"]))
    }
    fn register(&self, root: &str) {
        let root = self.0.join(root);
        if !root.exists() {
            std::fs::create_dir(&root).unwrap();
        }
        std::fs::write(root.join("code.rs"), "synthetic λ\n").unwrap();
        self.json(&words(&[
            "project",
            "add",
            "app",
            root.to_str().unwrap(),
            "code.rs",
        ]));
    }
    fn reject(&self, args: &[String]) -> Output {
        let out = self.run(args);
        assert!(!out.status.success());
        assert!(out.stdout.is_empty());
        out
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        std::fs::remove_dir_all(&self.0).unwrap();
    }
}
fn words(s: &[&str]) -> Vec<String> {
    s.iter().map(|s| (*s).into()).collect()
}
fn bound(p: &Value) -> Vec<String> {
    let mut args = words(&[
        "project",
        "export",
        "app",
        "--confirm-export-local-content",
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
            .map(|s| s.as_str().unwrap().into()),
    );
    args
}

#[test]
fn confirmed_bound_export_matches_trusted_v1_and_rejects_stale_approvals() {
    for same_root in [true, false] {
        let f = Fixture::new();
        f.register("synthetic-é");
        let unindexed = bound(&f.project());
        let archive = f.json(&unindexed);
        assert_eq!(archive["version"], 1);
        assert!(archive["snapshot"].is_null());
        assert_eq!(archive["evidence"], serde_json::json!([]));
        f.json(&words(&["index", "app"]));
        f.reject(&unindexed); // None is exact, never a wildcard.
        let indexed = bound(&f.project());
        let archive = f.json(&indexed);
        assert_eq!(
            archive,
            f.json(&words(&[
                "project",
                "export",
                "app",
                "--confirm-export-local-content"
            ]))
        );
        assert_eq!(archive["evidence"][0]["text"], "synthetic λ");
        assert!(
            !serde_json::to_string(&archive)
                .unwrap()
                .contains("synthetic-é")
        );
        f.json(&words(&[
            "project",
            "remove",
            "app",
            "--confirm-remove-local-data",
        ]));
        f.register(if same_root {
            "synthetic-é"
        } else {
            "other-root"
        });
        f.json(&words(&["index", "app"]));
        f.reject(&indexed);
        assert!(f.run(&bound(&f.project())).status.success());
        assert_eq!(
            std::fs::read_to_string(f.0.join("synthetic-é/code.rs")).unwrap(),
            "synthetic λ\n"
        );
    }
}

#[test]
fn malformed_partial_repeated_unknown_flags_and_missing_consent_fail_before_store_io() {
    let seed = Fixture::new();
    seed.register("root");
    let valid = bound(&seed.project());
    let absent = Fixture::new();
    let mut cases = Vec::new();
    let mut no_consent = valid.clone();
    no_consent.remove(3);
    cases.push(no_consent);
    for end in 5..13 {
        cases.push(valid[..end].to_vec());
    }
    for pos in [4, 6, 8, 10, 12] {
        let mut repeated = valid.clone();
        repeated.insert(pos, valid[pos].clone());
        cases.push(repeated);
    }
    for (pos, bad) in [
        (5, "relative"),
        (7, ""),
        (7, "--unknown"),
        (9, "legacy"),
        (11, "not-a-hash"),
        (13, "../escape"),
    ] {
        let mut malformed = valid.clone();
        malformed[pos] = bad.into();
        cases.push(malformed);
    }
    let mut unknown = valid.clone();
    unknown.push("--unknown".into());
    cases.push(unknown);
    let mut too_many = valid[..13].to_vec();
    too_many.extend((0..65).map(|n| format!("file{n}.rs")));
    cases.push(too_many);
    let mut long_unicode_root = valid.clone();
    long_unicode_root[5] = format!("/{}", "é".repeat(2048)); // 4097 UTF-8 bytes.
    cases.push(long_unicode_root);
    for args in cases {
        let out = absent.reject(&args);
        assert!(String::from_utf8_lossy(&out.stderr).contains("usage:"));
        assert!(!absent.0.join("store").exists());
        // A non-directory store would fail differently if argument validation
        // reached open_existing. Keep it untouched for each negative request.
        let blocked = Fixture::new();
        std::fs::write(blocked.0.join("store"), "synthetic sentinel").unwrap();
        let out = blocked.reject(&args);
        assert!(String::from_utf8_lossy(&out.stderr).contains("usage:"));
        assert_eq!(
            std::fs::read_to_string(blocked.0.join("store")).unwrap(),
            "synthetic sentinel"
        );
    }
    absent.reject(&valid); // Well-shaped approval still cannot create a store.
    assert!(!absent.0.join("store").exists());
}

#[test]
fn malformed_daemon_binding_is_rejected_before_existing_store_open() {
    use std::sync::atomic::AtomicBool;
    use threadmark_core::knowledge::Project;
    use threadmark_daemon::knowledge::{Command as LocalCommand, run};
    let f = Fixture::new();
    for field in [
        "root",
        "root-bytes",
        "identity-bytes",
        "nonce",
        "snapshot",
        "policy",
        "legacy",
    ] {
        let mut p = Project {
            id: "app".into(),
            root: "/synthetic".into(),
            root_identity: "1:2".into(),
            incarnation: Some("0".repeat(32)),
            sources: vec![],
            snapshot: None,
        };
        match field {
            "root" => p.root = "relative".into(),
            "root-bytes" => p.root = format!("/{}", "é".repeat(2048)),
            "identity-bytes" => p.root_identity = "é".repeat(65),
            "nonce" => p.incarnation = Some("0".repeat(31)),
            "snapshot" => p.snapshot = Some("A".repeat(64)),
            "policy" => p.sources = (0..65).map(|n| format!("file{n}.rs")).collect(),
            "legacy" => p.incarnation = None,
            _ => unreachable!(),
        }
        let result = run(
            &f.0.join("store"),
            LocalCommand::ExportProjectBound(p),
            &AtomicBool::new(false),
        );
        assert!(matches!(
            result,
            Err(threadmark_core::Error::InvalidExtraction | threadmark_core::Error::ScopeMismatch)
        ));
    }
    assert!(!f.0.join("store").exists());
}
