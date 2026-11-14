use super::*;
use std::io::Read;

fn mark(f: &Fixture, id: &str, path: &str) {
    f.json(
        &["context", "add", "app", id, "note"],
        Some("synthetic private marker text"),
    );
    f.json(
        &[
            "context",
            "forget",
            "app",
            id,
            "--confirm-forget-local-history",
        ],
        None,
    );
    f.json(&["project", "sources", "app", path], None);
    f.json(
        &["source", "forget", "app", path, "--confirm-forget-source"],
        None,
    );
}

#[test]
fn both_marker_cli_forms_preserve_json_and_reject_replacements() {
    for different_root in [false, true] {
        let f = Fixture::new();
        let p = f.register();
        mark(&f, "a-id", "a-path.rs");
        for domain in ["context", "source"] {
            let base = vec![domain, "forgotten", "app"];
            let mut args = base.clone();
            args.extend(flags(&p));
            let result = f.run(&args, None);
            assert!(result.status.success());
            assert_eq!(result.stdout, f.run(&base, None).stdout);
        }
        f.json(
            &["project", "remove", "app", "--confirm-remove-local-data"],
            None,
        );
        let root = f.0.join(if different_root { "different" } else { "app" });
        std::fs::create_dir_all(&root).unwrap();
        f.json(&["project", "add", "app", root.to_str().unwrap()], None);
        mark(&f, "b-private-id", "b-private-path.rs");
        for domain in ["context", "source"] {
            let mut args = vec![domain, "forgotten", "app"];
            args.extend(flags(&p));
            fail(f.run(&args, None)); // No B IDs or paths on stdout.
            let fresh = f.json(&[domain, "forgotten", "app"], None);
            assert!(fresh.to_string().contains("b-private")); // trusted form unchanged
        }
    }
}

#[test]
fn marker_closed_grammar_precedes_held_stdin_and_absent_store_creation() {
    let f = Fixture::new();
    let p = serde_json::json!({"root":"/synthetic", "root_identity":"identity", "incarnation":"0123456789abcdef0123456789abcdef"});
    let good = flags(&p);
    let mut malformed = vec![
        good[..2].to_vec(),
        good[..4].to_vec(),
        good[..5].to_vec(),
        vec![
            "--expected-incarnation",
            good[5],
            "--expected-root",
            good[1],
            "--expected-root-identity",
            good[3],
        ],
    ];
    for extra in [
        vec!["--expected-root", "/synthetic"],
        vec!["--expected-revision", "1"],
        vec!["--expected-sources"],
        vec!["--expected-snapshot", "none"],
        vec!["unknown"],
    ] {
        let mut args = good.clone();
        args.extend(extra);
        malformed.push(args);
    }
    for index in [1, 3, 5] {
        let mut args = good.clone();
        args[index] = if index == 1 {
            "relative"
        } else if index == 3 {
            ""
        } else {
            "legacy"
        };
        malformed.push(args);
    }
    for domain in ["context", "source"] {
        for bad in &malformed {
            let mut child = Command::new(env!("CARGO_BIN_EXE_threadmark"))
                .arg("--data-dir")
                .arg(f.0.join("store"))
                .args([domain, "forgotten", "app"])
                .args(bad)
                .stdin(Stdio::piped())
                .stdout(Stdio::piped())
                .stderr(Stdio::null())
                .spawn()
                .unwrap();
            let stdin = child.stdin.take().unwrap();
            let mut stdout = child.stdout.take().unwrap();
            let (send, receive) = std::sync::mpsc::channel();
            let reader = std::thread::spawn(move || {
                let mut out = Vec::new();
                stdout.read_to_end(&mut out).unwrap();
                send.send(out).unwrap();
            });
            let result = receive.recv_timeout(std::time::Duration::from_secs(5));
            if result.is_err() {
                child.kill().unwrap();
            }
            let status = child.wait().unwrap();
            drop(stdin);
            reader.join().unwrap();
            assert!(result.is_ok(), "metadata parsing waited for stdin");
            assert_eq!(status.code(), Some(2));
            assert!(result.unwrap().is_empty());
            assert!(!f.0.join("store").exists());
        }
        for project in ["app", "../bad"] {
            let mut args = vec![domain, "forgotten", project];
            args.extend(&good);
            fail(f.run(&args, None));
            assert!(!f.0.join("store").exists());
        }
    }
}

#[test]
fn marker_daemon_preflight_is_existing_only_and_cancelable() {
    use std::sync::atomic::AtomicBool;
    use threadmark_daemon::knowledge::{Command as K, run};
    let f = Fixture::new();
    for source in [false, true] {
        for (project, root, nonce) in [
            ("../bad", "/synthetic", "a".repeat(32)),
            ("app", "relative", "a".repeat(32)),
            ("app", "/synthetic", "legacy".into()),
            ("app", "/synthetic", "a".repeat(32)),
        ] {
            let command = if source {
                K::ForgottenSourcesBound(project.into(), root.into(), "identity".into(), nonce)
            } else {
                K::ForgottenContextsBound(project.into(), root.into(), "identity".into(), nonce)
            };
            assert!(run(&f.0.join("store"), command, &AtomicBool::new(false)).is_err());
            assert!(!f.0.join("store").exists());
        }
        let command = if source {
            K::ForgottenSourcesBound(
                "app".into(),
                "/synthetic".into(),
                "identity".into(),
                "a".repeat(32),
            )
        } else {
            K::ForgottenContextsBound(
                "app".into(),
                "/synthetic".into(),
                "identity".into(),
                "a".repeat(32),
            )
        };
        assert!(matches!(
            run(&f.0.join("store"), command, &AtomicBool::new(true)),
            Err(threadmark_core::Error::Canceled)
        ));
        assert!(!f.0.join("store").exists());
    }
}

#[test]
fn marker_cli_compares_unicode_registration_bytes_without_source_io() {
    let f = Fixture::new();
    f.register();
    mark(&f, "a-id", "a.rs");
    assert!(Command::new("python3").args(["-c", "import sqlite3,sys; db=sqlite3.connect(sys.argv[1]); db.execute(\"UPDATE projects SET root='/synthetic/é',root_identity='identity-é' WHERE id='app'\"); db.commit(); db.close()"])
        .arg(f.0.join("store/knowledge.sqlite")).status().unwrap().success());
    let p = f.json(&["project", "show", "app"], None);
    for domain in ["context", "source"] {
        let mut good = vec![domain, "forgotten", "app"];
        good.extend(flags(&p));
        assert!(f.run(&good, None).status.success());
        for (index, value) in [(4, "/synthetic/e\u{301}"), (6, "identity-e\u{301}")] {
            let mut bad = good.clone();
            bad[index] = value;
            fail(f.run(&bad, None));
        }
    }
}

#[test]
fn marker_cli_legacy_v2_v3_preserve_trusted_compatibility_without_upgrade() {
    let f = Fixture::new();
    let p = f.register();
    mark(&f, "a-id", "a.rs");
    let sql3 = "DROP TRIGGER threadmark_source_policy_guard; DROP TRIGGER threadmark_source_evidence_guard; DROP TRIGGER threadmark_source_project_delete_guard; DROP TABLE forgotten_sources; PRAGMA user_version=3;";
    let sql2 = "DROP TRIGGER threadmark_project_incarnation_insert; DROP TRIGGER threadmark_project_incarnation_delete; DROP TABLE project_incarnations; PRAGMA user_version=2;";
    for (version, sql) in [(3, sql3), (2, sql2)] {
        assert!(Command::new("python3").args(["-c", "import sqlite3,sys; db=sqlite3.connect(sys.argv[1]); db.executescript(sys.argv[2]); db.close()"])
            .arg(f.0.join("store/knowledge.sqlite")).arg(sql).status().unwrap().success());
        for domain in ["context", "source"] {
            let mut args = vec![domain, "forgotten", "app"];
            args.extend(flags(&p));
            let out = f.run(&args, None);
            if version == 3 && domain == "context" {
                assert!(out.status.success());
            } else {
                fail(out);
            }
        }
        assert!(
            f.run(&["context", "forgotten", "app"], None)
                .status
                .success()
        );
        fail(f.run(&["source", "forgotten", "app"], None));
        // Reopening did not implicitly upgrade either fixture.
        assert!(Command::new("python3").args(["-c", "import sqlite3,sys; db=sqlite3.connect(sys.argv[1]); assert db.execute('pragma user_version').fetchone()[0]==int(sys.argv[2])"])
            .arg(f.0.join("store/knowledge.sqlite")).arg(version.to_string()).status().unwrap().success());
    }
}
