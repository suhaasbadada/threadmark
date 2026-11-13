//! Finite daemon diagnostic integration tests.

use std::process::Command;

#[test]
fn malformed_bound_removal_cannot_create_a_store() {
    use std::sync::atomic::AtomicBool;
    use threadmark_daemon::knowledge::{Command as KnowledgeCommand, run};
    let store = std::env::temp_dir().canonicalize().unwrap().join(format!(
        "threadmark-invalid-removal-{}-{}",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    assert!(!store.exists());
    for (root, identity) in [
        ("/synthetic\0".to_owned(), "r1".to_owned()),
        ("/synthetic".to_owned(), "r\0".to_owned()),
        (format!("/{}", "x".repeat(4096)), "r1".to_owned()),
        ("/synthetic".to_owned(), "x".repeat(129)),
    ] {
        assert!(
            run(
                &store,
                KnowledgeCommand::RemoveProjectBound("a".into(), root, identity),
                &AtomicBool::new(false)
            )
            .is_err()
        );
        assert!(!store.exists());
    }
}

#[test]
fn finite_diagnostics_and_no_implicit_service() {
    for arg in ["--version", "--smoke"] {
        let output = Command::new(env!("CARGO_BIN_EXE_threadmark-daemon"))
            .arg(arg)
            .output()
            .unwrap();
        assert!(output.status.success());
        assert!(output.stderr.is_empty());
    }
    let output = Command::new(env!("CARGO_BIN_EXE_threadmark-daemon"))
        .output()
        .unwrap();
    assert_eq!(output.status.code(), Some(2));
    assert!(output.stdout.is_empty());
}
