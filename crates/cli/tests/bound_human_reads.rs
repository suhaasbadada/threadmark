//! Real CLI/daemon/core registration-bound human reads; all data synthetic.
#[path = "bound_human_reads/marker_tests.rs"]
mod marker_tests;
use serde_json::Value;
use std::io::Write;
use std::path::PathBuf;
use std::process::{Command, Output, Stdio};

struct Fixture(PathBuf);
impl Fixture {
    fn new() -> Self {
        static NEXT: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        let root = std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-cli-human-bound-{}-{}",
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
        let output = self.run(args, text);
        assert!(
            output.status.success(),
            "{}",
            String::from_utf8_lossy(&output.stderr)
        );
        serde_json::from_slice(&output.stdout).unwrap()
    }
    fn register(&self) -> Value {
        let root = self.0.join("app");
        std::fs::create_dir_all(&root).unwrap();
        self.json(&["project", "add", "app", root.to_str().unwrap()], None);
        self.json(
            &["context", "add", "app", "memo", "note"],
            Some("synthetic private A"),
        );
        self.json(&["project", "show", "app"], None)
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        std::fs::remove_dir_all(&self.0).unwrap();
    }
}
fn flags(p: &Value) -> Vec<&str> {
    vec![
        "--expected-root",
        p["root"].as_str().unwrap(),
        "--expected-root-identity",
        p["root_identity"].as_str().unwrap(),
        "--expected-incarnation",
        p["incarnation"].as_str().unwrap(),
    ]
}
fn fail(out: Output) {
    assert!(!out.status.success() && out.stdout.is_empty());
    let stderr = String::from_utf8(out.stderr).unwrap();
    assert!(!stderr.contains("synthetic private") && !stderr.contains("private-query"));
}

#[test]
fn bound_forms_preserve_output_and_reject_same_root_reincarnation() {
    let f = Fixture::new();
    let p = f.register();
    for base in [
        vec!["context", "list", "app"],
        vec!["context", "show", "app", "memo"],
        vec!["context", "search", "app", "synthetic"],
    ] {
        let mut args = base.clone();
        args.extend(flags(&p));
        let bound = f.run(&args, None);
        assert!(bound.status.success());
        assert_eq!(bound.stdout, f.run(&base, None).stdout);
    }
    f.json(
        &["project", "remove", "app", "--confirm-remove-local-data"],
        None,
    );
    let replacement = f.register();
    assert_ne!(p["incarnation"], replacement["incarnation"]);
    for base in [
        vec!["context", "list", "app"],
        vec!["context", "show", "app", "memo"],
        vec!["context", "search", "app", "private-query"],
    ] {
        let mut args = base;
        args.extend(flags(&p));
        fail(f.run(&args, None));
    }
    let mut args = vec!["context", "show", "app", "memo"];
    args.extend(flags(&replacement));
    assert_eq!(
        f.json(&args, None)["history"][0]["text"],
        "synthetic private A"
    );
}

#[test]
fn closed_flag_grammar_validation_and_absent_store_never_create_storage() {
    let f = Fixture::new();
    let p = serde_json::json!({"root":"/synthetic", "root_identity":"identity", "incarnation":"0123456789abcdef0123456789abcdef"});
    let good = flags(&p);
    let mut malformed = vec![
        good[..2].to_vec(),
        good[..4].to_vec(),
        good[..5].to_vec(),
        vec![
            "--expected-root-identity",
            "identity",
            "--expected-root",
            "/synthetic",
            "--expected-incarnation",
            good[5],
        ],
        vec![
            "--expected-root",
            "relative",
            "--expected-root-identity",
            "identity",
            "--expected-incarnation",
            good[5],
        ],
        vec![
            "--expected-root",
            "/synthetic",
            "--expected-root-identity",
            "",
            "--expected-incarnation",
            good[5],
        ],
        vec![
            "--expected-root",
            "/synthetic",
            "--expected-root-identity",
            "identity",
            "--expected-incarnation",
            "legacy",
        ],
    ];
    for extra in [
        vec!["--expected-root", "/synthetic"],
        vec!["--expected-revision", "1"],
        vec!["--expected-sources"],
        vec!["unknown"],
    ] {
        let mut repeated = good.clone();
        repeated.extend(extra);
        malformed.push(repeated);
    }
    for base in [
        vec!["context", "list", "app"],
        vec!["context", "show", "app", "memo"],
        vec!["context", "search", "app", "private-query"],
    ] {
        for bad in &malformed {
            let mut args = base.clone();
            args.extend(bad);
            fail(f.run(&args, None));
            assert!(!f.0.join("store").exists());
        }
        // Even syntactically valid bound forms require existing storage.
        let mut args = base;
        args.extend(&good);
        fail(f.run(&args, None));
        assert!(!f.0.join("store").exists());
    }
    for mut base in [
        vec!["context", "list", "../bad"],
        vec!["context", "show", "app", "../bad"],
        vec!["context", "search", "app", "x\ny"],
        vec!["context", "search", "app", ""],
    ] {
        base.extend(&good);
        fail(f.run(&base, None));
        assert!(!f.0.join("store").exists());
    }
}

#[test]
fn typed_daemon_repeats_pre_store_validation_and_existing_store_only() {
    use std::sync::atomic::AtomicBool;
    use threadmark_core::Error;
    use threadmark_daemon::knowledge::{Command as K, run};
    let f = Fixture::new();
    let root = "/synthetic".to_owned();
    let identity = "identity".to_owned();
    let nonce = "0123456789abcdef0123456789abcdef".to_owned();
    for command in [
        K::ContextsBound(
            "../bad".into(),
            root.clone(),
            identity.clone(),
            nonce.clone(),
        ),
        K::ContextBound(
            "app".into(),
            "../bad".into(),
            root.clone(),
            identity.clone(),
            nonce.clone(),
        ),
        K::SearchContextBound(
            "app".into(),
            "\n".into(),
            root.clone(),
            identity.clone(),
            nonce.clone(),
        ),
        K::ContextsBound(
            "app".into(),
            root.clone(),
            identity.clone(),
            "legacy".into(),
        ),
    ] {
        assert!(matches!(
            run(&f.0.join("store"), command, &AtomicBool::new(false)),
            Err(Error::InvalidExtraction) | Err(Error::InvalidIdentity)
        ));
        assert!(!f.0.join("store").exists());
    }
    for command in [
        K::ContextsBound("app".into(), root.clone(), identity.clone(), nonce.clone()),
        K::ContextBound(
            "app".into(),
            "memo".into(),
            root.clone(),
            identity.clone(),
            nonce.clone(),
        ),
        K::SearchContextBound("app".into(), "synthetic".into(), root, identity, nonce),
    ] {
        assert!(run(&f.0.join("store"), command, &AtomicBool::new(false)).is_err());
        assert!(!f.0.join("store").exists());
    }
}
