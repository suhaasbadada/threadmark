use super::*;

fn bound_args(p: &Value, selected: &[&str]) -> Vec<String> {
    let mut args: Vec<String> = ["context", "search", "app", "needle", "--kinds"]
        .into_iter()
        .chain(selected.iter().copied())
        .map(String::from)
        .collect();
    args.extend(
        [
            "--expected-root",
            p["root"].as_str().unwrap(),
            "--expected-root-identity",
            p["root_identity"].as_str().unwrap(),
            "--expected-incarnation",
            p["incarnation"].as_str().unwrap(),
        ]
        .map(String::from),
    );
    args
}

#[test]
fn ae04_real_cli_filtered_before_limit_canonical_and_old_forms_unchanged() {
    let f = Fixture::new();
    f.register("app");
    for n in 0..12 {
        f.json(
            &["context", "add", "app", &format!("a{n}"), "pitfall"],
            Some("needle needle needle"),
        );
    }
    for id in ["b", "c"] {
        f.json(&["context", "add", "app", id, "note"], Some("needle"));
    }
    let p = f.json(&["project", "show", "app"], None);
    let args = bound_args(&p, &["note", "decision"]);
    let out = f.run(&args.iter().map(String::as_str).collect::<Vec<_>>(), None);
    assert!(out.status.success());
    assert_eq!(out.stdout.last(), Some(&b'\n'));
    assert!(out.stdout.len() <= 8192);
    let result: Value = serde_json::from_slice(&out.stdout).unwrap();
    assert_eq!(
        result["selected_kinds"],
        serde_json::json!(["decision", "note"])
    );
    assert_eq!(result["version"], "human-search-kind-filter-v1");
    assert_eq!(result["matched_entries"], 2);
    assert_eq!(result["results"][0]["id"], "b");
    assert_eq!(result["omitted_entries"], 0);
    let old = f.run(&["context", "search", "app", "needle"], None);
    let mut bound: Vec<&str> = vec!["context", "search", "app", "needle"];
    bound.extend(args[7..].iter().map(String::as_str));
    let trusted: Value = serde_json::from_slice(&old.stdout).unwrap();
    assert!(trusted.get("version").is_none());
    assert_eq!(old.stdout, f.run(&bound, None).stdout);
}

#[test]
fn ae04_closed_grammar_pre_storage_and_held_stdin() {
    let f = Fixture::new();
    let p = serde_json::json!({"root":"/synthetic/root", "root_identity":"synthetic", "incarnation":"0123456789abcdef0123456789abcdef"});
    let base = bound_args(&p, &["note"]);
    let mut cases = Vec::new();
    for selected in [
        vec![],
        vec![""],
        vec!["rule"],
        vec!["note", "note"],
        vec!["note"; 6],
    ] {
        cases.push(bound_args(&p, &selected));
    }
    let mut extra = base.clone();
    extra.push("--unknown".into());
    cases.push(extra);
    let mut extra = base.clone();
    extra.extend(["--kinds".into(), "note".into()]);
    cases.push(extra);
    let mut partial = base.clone();
    partial.pop();
    cases.push(partial);
    let mut duplicate = base.clone();
    duplicate.extend(["--expected-root".into(), "/synthetic/root".into()]);
    cases.push(duplicate);
    let mut reordered = base.clone();
    reordered.swap(6, 8);
    cases.push(reordered);
    for args in cases.into_iter().chain([base]) {
        // Retain stdin open in the parent: these reads must exit without waiting for EOF.
        let mut child = Command::new(env!("CARGO_BIN_EXE_threadmark"))
            .arg("--data-dir")
            .arg(f.0.join("store"))
            .args(&args)
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
                panic!("filtered search consumed stdin");
            }
            std::thread::yield_now();
        }
        drop(held);
        let out = child.wait_with_output().unwrap();
        assert!(!out.status.success());
        assert!(out.stdout.is_empty());
        assert!(!f.0.join("store").exists());
    }
}

#[test]
fn ae04_actual_schema2_fails_without_migration_and_daemon_preflight() {
    let f = Fixture::new();
    f.register("app");
    let p = f.json(&["project", "show", "app"], None);
    let script = "import sqlite3,sys\nc=sqlite3.connect(sys.argv[1])\nc.executescript('DROP TRIGGER threadmark_source_policy_guard; DROP TRIGGER threadmark_source_evidence_guard; DROP TRIGGER threadmark_source_project_delete_guard; DROP TABLE forgotten_sources; DROP TRIGGER threadmark_project_incarnation_insert; DROP TRIGGER threadmark_project_incarnation_delete; DROP TABLE project_incarnations; PRAGMA user_version=2;')\nc.close()";
    let db = f.0.join("store/knowledge.sqlite");
    assert!(
        Command::new("python3")
            .args(["-c", script])
            .arg(&db)
            .status()
            .unwrap()
            .success()
    );
    let args = bound_args(&p, &["note"]);
    let out = f.run(&args.iter().map(String::as_str).collect::<Vec<_>>(), None);
    assert!(!out.status.success() && out.stdout.is_empty());
    assert!(Command::new("python3").args(["-c", "import sqlite3,sys; c=sqlite3.connect(sys.argv[1]); assert c.execute('PRAGMA user_version').fetchone()[0]==2; assert not c.execute(\"SELECT 1 FROM sqlite_master WHERE name='project_incarnations'\").fetchall()"]).arg(&db).status().unwrap().success());
    let absent = f.0.join("absent");
    for kinds in [
        vec![],
        vec!["note".into(), "note".into()],
        vec!["unknown".into()],
    ] {
        assert!(
            threadmark_daemon::knowledge::run(
                &absent,
                threadmark_daemon::knowledge::Command::SearchContextKindsBound(
                    "app".into(),
                    "needle".into(),
                    kinds,
                    "/synthetic".into(),
                    "identity".into(),
                    "0123456789abcdef0123456789abcdef".into()
                ),
                &std::sync::atomic::AtomicBool::new(false)
            )
            .is_err()
        );
        assert!(!absent.exists());
    }
}

#[test]
fn ae01_actual_cli_entire_filtered_frame_exact_8192_with_newline() {
    let f = Fixture::new();
    f.register("app");
    let p = f.json(&["project", "show", "app"], None);
    let args = bound_args(&p, &["note"]);
    let args: Vec<&str> = args.iter().map(String::as_str).collect();
    for id in ["a", "z"] {
        f.json(
            &["context", "add", "app", id, "note"],
            Some(&format!("needle{}", "x".repeat(3400))),
        );
    }
    let first = f.run(&args, None);
    assert!(first.status.success());
    let extra = 8192 - first.stdout.len();
    assert!(extra < 690);
    f.json(
        &["context", "update", "app", "z", "note"],
        Some(&format!("needle{}", "x".repeat(3400 + extra))),
    );
    let exact = f.run(&args, None);
    assert!(exact.status.success());
    assert_eq!(exact.stdout.len(), 8192);
    assert_eq!(exact.stdout.last(), Some(&10));
    let value: Value = serde_json::from_slice(&exact.stdout).unwrap();
    assert_eq!(value["results"].as_array().unwrap().len(), 2);
    f.json(
        &["context", "update", "app", "z", "note"],
        Some(&format!("needle{}", "x".repeat(3401 + extra))),
    );
    let over = f.run(&args, None);
    assert!(over.status.success());
    assert!(over.stdout.len() <= 8192);
    let value: Value = serde_json::from_slice(&over.stdout).unwrap();
    assert_eq!(value["omitted_entries"], 1);
    assert_eq!(value["truncated"], true);
}
