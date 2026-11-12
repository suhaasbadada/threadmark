//! Real-process CLI diagnostic and redaction integration tests.

use std::process::Command;

#[test]
fn p0_a1_real_commands() {
    for (arg, expected) in [
        ("--version", "threadmark 0.1.0"),
        ("status", "service=not-connected"),
        ("smoke", "synthetic_items=1; no host delivery"),
    ] {
        let output = Command::new(env!("CARGO_BIN_EXE_threadmark"))
            .arg(arg)
            .output()
            .unwrap();
        assert!(output.status.success());
        assert!(String::from_utf8(output.stdout).unwrap().contains(expected));
        assert!(output.stderr.is_empty());
    }
}

#[test]
fn invalid_commands_fail_without_echoing_content() {
    for args in [
        vec![],
        vec!["private-input"],
        vec!["status", "private-input"],
    ] {
        let output = Command::new(env!("CARGO_BIN_EXE_threadmark"))
            .args(args)
            .output()
            .unwrap();
        assert_eq!(output.status.code(), Some(2));
        assert!(output.stdout.is_empty());
        assert!(
            !String::from_utf8(output.stderr)
                .unwrap()
                .contains("private-input")
        );
    }
}
