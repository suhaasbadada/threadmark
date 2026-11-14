//! Z-A2/Z-A5 actual CLI -> daemon -> core synthetic journey, no native UI.
use serde_json::{Value, json};
use std::path::PathBuf;
use std::process::{Command, Output, Stdio};

struct Fixture(PathBuf);
impl Fixture {
    fn new() -> Self {
        static NEXT: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        let root = std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-cli-inspect-{}-{}",
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
    fn run(&self, args: &[String]) -> Output {
        self.command(args).stdin(Stdio::null()).output().unwrap()
    }
    fn json(&self, args: &[String]) -> Value {
        let o = self.run(args);
        assert!(o.status.success(), "{}", String::from_utf8_lossy(&o.stderr));
        serde_json::from_slice(&o.stdout).unwrap()
    }
    fn indexed(&self) -> (Value, Value) {
        std::fs::create_dir(self.0.join("source")).unwrap();
        std::fs::write(self.0.join("source/code.rs"), CODE).unwrap();
        self.json(&words(&[
            "project",
            "add",
            "app",
            self.0.join("source").to_str().unwrap(),
            "code.rs",
        ]));
        self.json(&words(&["index", "app"]));
        let p = self.json(&words(&["project", "show", "app"]));
        let q = self.json(&words(&["query", "app", "center"]));
        (p, q["results"][0].clone())
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        std::fs::remove_dir_all(&self.0).unwrap();
    }
}
const CODE: &str =
    "fn wrapper() {\n    before();\n\n    center(\"λ\\\");\n    after();\n}\n// end\n";
fn words(args: &[&str]) -> Vec<String> {
    args.iter().map(|s| (*s).into()).collect()
}
fn inspect(p: &Value, anchor: &Value) -> Vec<String> {
    let mut args = words(&[
        "source",
        "inspect",
        "app",
        anchor["path"].as_str().unwrap(),
        &anchor["line"].to_string(),
        "--radius",
        "3",
        "--expected-source-hash",
        anchor["source_hash"].as_str().unwrap(),
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
            .map(|p| p.as_str().unwrap().into()),
    );
    args
}
fn refused(o: Output) {
    assert!(!o.status.success());
    assert!(o.stdout.is_empty());
}
fn replace(args: &[String], flag: &str, value: &str) -> Vec<String> {
    let mut args = args.to_vec();
    let i = args.iter().position(|s| s == flag).unwrap();
    args[i + 1] = value.into();
    args
}

#[test]
fn z_a2_real_query_to_inspection_includes_surrounding_code_and_preserves_notes() {
    let f = Fixture::new();
    let (p, a) = f.indexed();
    let args = inspect(&p, &a);
    let mut store = threadmark_core::knowledge::Store::open_existing(&f.0.join("store")).unwrap();
    store
        .write_context("app", "draft", "note", "synthetic human note", false)
        .unwrap();
    let before = std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap();
    let o = f.run(&args);
    assert!(o.status.success());
    assert!(o.stdout.len() <= 8192);
    let reply: Value = serde_json::from_slice(&o.stdout).unwrap();
    assert_eq!(reply["format"], "threadmark-source-anchor-inspection");
    assert_eq!(reply["version"], 1);
    for key in ["project", "path", "source_hash", "producer"] {
        assert_eq!(reply[key], a[key]);
    }
    assert_eq!(reply["snapshot"], p["snapshot"]);
    for (i, text) in CODE.lines().enumerate() {
        assert_eq!(reply["lines"][i]["text"], text);
        assert_eq!(reply["lines"][i]["line"], i + 1);
        assert_eq!(reply["lines"][i]["is_anchor"], i == 3);
    }
    assert_eq!(reply["lines"][2]["kind"], "observed-source-text");
    assert_eq!(
        std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap(),
        before
    );
    assert_eq!(
        std::fs::read_to_string(f.0.join("source/code.rs")).unwrap(),
        CODE
    );
    assert_eq!(
        store.context("app", "draft").unwrap()["history"][0]["text"],
        "synthetic human note"
    );
    // Held stdin must not be consumed by this source-only command.
    let mut child = f
        .command(&args)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    let held = child.stdin.take().unwrap();
    let (send, recv) = std::sync::mpsc::channel();
    let pid = child.id();
    let waiter = std::thread::spawn(move || send.send(child.wait_with_output().unwrap()).unwrap());
    let result = recv.recv_timeout(std::time::Duration::from_secs(5));
    if result.is_err() {
        // Exact owned process only, bounded failure cleanup, not deadline polling.
        let _ = Command::new("kill")
            .args(["-KILL", &pid.to_string()])
            .status();
    }
    drop(held);
    waiter.join().unwrap();
    assert!(result.unwrap().status.success());
}

#[test]
fn z_a4_actual_cli_rejects_wal_before_open_without_normalizing_or_source_output() {
    let f = Fixture::new();
    let (p, a) = f.indexed();
    let database = f.0.join("store/knowledge.sqlite");
    assert!(Command::new("python3")
        .args(["-c", "import sqlite3,sys; db=sqlite3.connect(sys.argv[1]); assert db.execute('PRAGMA journal_mode=WAL').fetchone()[0]=='wal'; db.close()"])
        .arg(&database).status().unwrap().success());
    let before = std::fs::read(&database).unwrap();
    assert_eq!(&before[18..20], &[2, 2]);
    let entries = || {
        let mut names: Vec<_> = std::fs::read_dir(f.0.join("store"))
            .unwrap()
            .map(|entry| entry.unwrap().file_name())
            .collect();
        names.sort();
        names
    };
    let names = entries();
    refused(f.run(&inspect(&p, &a)));
    assert_eq!(std::fs::read(&database).unwrap(), before);
    assert_eq!(entries(), names);
    assert_eq!(
        std::fs::read_to_string(f.0.join("source/code.rs")).unwrap(),
        CODE
    );
    assert!(Command::new("python3")
        .args(["-c", "import sqlite3,sys; db=sqlite3.connect(sys.argv[1]); assert db.execute('PRAGMA journal_mode').fetchone()[0]=='wal'; db.close()"])
        .arg(&database).status().unwrap().success());
}

#[test]
fn z_a5_actual_cli_inspects_complete_policies_at_61_and_64_source_capacity() {
    for count in [61, 64] {
        let f = Fixture::new();
        std::fs::create_dir(f.0.join("source")).unwrap();
        let sources: Vec<_> = (0..count).map(|i| format!("code{i:02}.rs")).collect();
        for source in &sources {
            std::fs::write(f.0.join("source").join(source), CODE).unwrap();
        }
        let mut add = words(&[
            "project",
            "add",
            "app",
            f.0.join("source").to_str().unwrap(),
        ]);
        add.extend(sources.clone());
        f.json(&add);
        f.json(&words(&["index", "app"]));
        let p = f.json(&words(&["project", "show", "app"]));
        let q = f.json(&words(&["query", "app", "center"]));
        let anchor = &q["results"][0];
        let args = inspect(&p, anchor);
        assert_eq!(args.len() + 2, count + 20);
        let output = f.run(&args);
        assert!(output.status.success());
        let reply: Value = serde_json::from_slice(&output.stdout).unwrap();
        assert_eq!(reply["path"], anchor["path"]);
        assert_eq!(reply["lines"][3]["text"], "    center(\"λ\\\");");
        let mut extra = args;
        extra.extend((count..65).map(|i| format!("code{i:02}.rs")));
        refused(f.run(&extra));
    }
}

#[test]
fn z_a5_typed_daemon_preflight_and_held_stdin_invalid_request_are_side_effect_free() {
    use threadmark_core::knowledge::{Project, SourceAnchorInspection};
    use threadmark_daemon::knowledge::{Command as KnowledgeCommand, run};
    let f = Fixture::new();
    let p = Project {
        id: "app".into(),
        root: "/synthetic/root".into(),
        root_identity: "1:2".into(),
        incarnation: Some("a".repeat(32)),
        snapshot: Some("b".repeat(64)),
        sources: vec!["code.rs".into()],
    };
    let cancel = std::sync::atomic::AtomicBool::new(false);
    let a = || SourceAnchorInspection {
        path: "code.rs".into(),
        line: 1,
        radius: 4,
        source_hash: "c".repeat(64),
    };
    let error = run(
        &f.0.join("store"),
        KnowledgeCommand::InspectSourceAnchor(p, a()),
        &cancel,
    )
    .unwrap_err();
    assert_eq!(error, threadmark_core::Error::InvalidExtraction);
    assert!(!f.0.join("store").exists());
    let args = words(&[
        "source",
        "inspect",
        "app",
        "code.rs",
        "1",
        "--radius",
        "0",
        "--expected-source-hash",
        &"c".repeat(64),
    ]);
    let mut child = f
        .command(&args)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    let held = child.stdin.take().unwrap();
    let (send, recv) = std::sync::mpsc::channel();
    let pid = child.id();
    let waiter = std::thread::spawn(move || send.send(child.wait_with_output().unwrap()).unwrap());
    let result = recv.recv_timeout(std::time::Duration::from_secs(5));
    if result.is_err() {
        let _ = Command::new("kill")
            .args(["-KILL", &pid.to_string()])
            .status();
    }
    drop(held);
    waiter.join().unwrap();
    refused(result.unwrap());
    assert!(!f.0.join("store").exists());
}

#[test]
fn z_a5_closed_grammar_and_missing_store_never_create_storage_or_read_stdin() {
    let f = Fixture::new();
    let p = json!({"root":"/synthetic/root","root_identity":"1:2","incarnation":"a".repeat(32),"snapshot":"b".repeat(64),"sources":["code.rs"]});
    let a = json!({"path":"code.rs","line":4,"source_hash":"c".repeat(64)});
    let full = inspect(&p, &a);
    refused(f.run(&full)); // Well-formed request still requires existing storage.
    for end in 2..full.len() {
        refused(f.run(&full[..end]));
    }
    for (flag, bad) in [
        ("--radius", "4"),
        ("--radius", "-1"),
        ("--radius", "03"),
        ("--radius", "999999999999999999"),
        ("--expected-source-hash", "BAD"),
        ("--expected-incarnation", "legacy"),
        ("--expected-root", "relative"),
        ("--expected-snapshot", "none"),
        ("--expected-snapshot", "bad"),
    ] {
        refused(f.run(&replace(&full, flag, bad)));
    }
    for bad in ["0", "4097", "04", "+4", "4.0", "-1", "999999999999"] {
        let mut args = full.clone();
        args[4] = bad.into();
        refused(f.run(&args));
    }
    for extra in ["--radius", "--unknown", "code.rs", "../escape.rs"] {
        let mut args = full.clone();
        args.push(extra.into());
        refused(f.run(&args));
    }
    for flag in [
        "--radius",
        "--expected-root",
        "--expected-source-hash",
        "--expected-snapshot",
    ] {
        let i = full.iter().position(|s| s == flag).unwrap();
        let mut args = full.clone();
        args.splice(i..i, full[i..i + 2].iter().cloned());
        refused(f.run(&args));
    }
    let mut args = full.clone();
    args[3] = "other.rs".into();
    refused(f.run(&args));
    let mut args = full.clone();
    args.extend((0..64).map(|i| format!("file-{i}.rs")));
    refused(f.run(&args));
    let mut args = full;
    let i = args.iter().position(|s| s == "--expected-root").unwrap();
    args[i + 1] = format!("/{}", "λ".repeat(2048));
    refused(f.run(&args));
    assert!(!f.0.join("store").exists());
}

#[test]
fn z_a1_a3_a4_real_cli_stale_binding_source_edits_and_forget_refuse_all_content() {
    let f = Fixture::new();
    let (p, a) = f.indexed();
    let args = inspect(&p, &a);
    for (flag, value) in [
        ("--expected-incarnation", "0".repeat(32)),
        ("--expected-snapshot", "0".repeat(64)),
        ("--expected-source-hash", "0".repeat(64)),
        ("--expected-root-identity", "1:2".into()),
    ] {
        refused(f.run(&replace(&args, flag, &value)));
    }
    let mut wrong_line = args.clone();
    wrong_line[4] = "3".into();
    refused(f.run(&wrong_line));
    std::fs::write(f.0.join("source/code.rs"), "// center edited\n").unwrap();
    refused(f.run(&args));
    std::fs::write(f.0.join("source/code.rs"), CODE).unwrap();
    assert!(f.run(&args).status.success());
    f.json(&words(&[
        "source",
        "forget",
        "app",
        "code.rs",
        "--confirm-forget-source",
    ]));
    refused(f.run(&args));
    f.json(&words(&["index", "app"]));
    let fresh = f.json(&words(&["project", "show", "app"]));
    refused(f.run(&inspect(&fresh, &a)));
    assert_eq!(
        std::fs::read_to_string(f.0.join("source/code.rs")).unwrap(),
        CODE
    );
    f.json(&words(&[
        "project",
        "remove",
        "app",
        "--confirm-remove-local-data",
    ]));
    f.json(&words(&[
        "project",
        "add",
        "app",
        p["root"].as_str().unwrap(),
        "code.rs",
    ]));
    f.json(&words(&["index", "app"]));
    refused(f.run(&args)); // Same ID/root/content/policy, new incarnation.
}
