//! Finite daemon diagnostic integration tests.

use std::process::Command;

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
