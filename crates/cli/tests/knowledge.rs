//! Real process CLI product journey; all content and roots are synthetic.
use serde_json::Value;
use std::io::Write;
use std::path::PathBuf;
use std::process::{Command, Output, Stdio};
use std::sync::atomic::{AtomicU64, Ordering};

static NEXT_FIXTURE: AtomicU64 = AtomicU64::new(0);

const EXPORT: [&str; 4] = ["project", "export", "a", "--confirm-export-local-content"];
const FORGET: [&str; 5] = [
    "context",
    "forget",
    "a",
    "memo",
    "--confirm-forget-local-history",
];
const UPGRADE: [&str; 3] = ["store", "upgrade", "--confirm-local-schema-upgrade"];

#[test]
fn cached_mutation_bindings_are_complete_and_valid_before_store_creation() {
    let f = Fixture::new();
    let binding = [
        "--expected-root",
        "/synthetic/root",
        "--expected-root-identity",
        "r1",
        "--expected-incarnation",
        "0123456789abcdef0123456789abcdef",
    ];
    for prefix in [
        vec!["project", "sources", "a"],
        vec!["context", "add", "a", "memo", "note"],
        vec!["context", "update", "a", "memo", "note"],
        vec!["context", "retire", "a", "memo"],
    ] {
        for count in 1..binding.len() {
            let mut args = prefix.clone();
            args.extend_from_slice(&binding[..count]);
            let out = f.run(&args, Some(b"Synthetic private note"));
            assert!(!out.status.success() && out.stdout.is_empty());
            assert!(!f.0.join("store").exists());
        }
    }
    for suffix in [
        vec![],
        vec!["--expected-sources"],
        vec!["--expected-sources", "--new-sources", "--new-sources"],
        vec!["--expected-sources", "../bad.rs", "--new-sources"],
        vec!["--expected-sources", "--bad.rs", "--new-sources"],
        vec!["--expected-sources", "--new-sources", "../bad.rs"],
    ] {
        let mut args = vec!["project", "sources", "a"];
        args.extend(binding);
        args.extend(suffix);
        let out = f.run(&args, None);
        assert!(!out.status.success() && out.stdout.is_empty());
        assert!(!f.0.join("store").exists());
    }
}

#[test]
fn source_forget_confirmation_and_complete_bindings_precede_any_store_creation() {
    let f = Fixture::new();
    let prefix = [
        "source",
        "forget",
        "a",
        "code.rs",
        "--confirm-forget-source",
    ];
    for args in [
        vec!["source", "forget", "a", "code.rs"],
        vec![
            "source",
            "forget",
            "../bad",
            "code.rs",
            "--confirm-forget-source",
        ],
        vec![
            "source",
            "forget",
            "a",
            "../bad.rs",
            "--confirm-forget-source",
        ],
        vec![
            "store",
            "upgrade",
            "--to-version",
            "4",
            "--confirm-local-schema-upgrade",
        ],
        vec![
            "store",
            "upgrade",
            "--to-version",
            "4",
            "--confirm-legacy-workers-stopped",
        ],
    ] {
        let out = f.run(&args, None);
        assert!(!out.status.success() && out.stdout.is_empty());
        assert!(!f.0.join("store").exists());
    }
    let pairs = [
        ("--expected-root", "/synthetic"),
        ("--expected-root-identity", "1:2"),
        ("--expected-incarnation", "0123456789abcdef0123456789abcdef"),
        ("--expected-sources", "code.rs"),
    ];
    for mask in 1..16 {
        let mut args = prefix.to_vec();
        for (i, (key, value)) in pairs.iter().enumerate() {
            if mask & (1 << i) != 0 {
                args.extend([*key, *value]);
            }
        }
        let out = f.run(&args, None);
        assert!(!out.status.success() && out.stdout.is_empty());
        assert!(!f.0.join("store").exists());
    }
    for bad in ["", "../bad.rs", "a\u{0}b.rs", "bad.exe"] {
        // NUL cannot be passed through exec; core validation has its own NUL fixture.
        if bad.contains('\0') {
            continue;
        }
        let mut args = prefix.to_vec();
        args[3] = bad;
        let out = f.run(&args, None);
        assert!(!out.status.success() && out.stdout.is_empty());
        assert!(!f.0.join("store").exists());
    }
}

#[test]
fn source_forget_real_cli_suppresses_rebuild_query_prepare_export_and_native_stale_approval() {
    let f = Fixture::new();
    let source = f.0.join("source");
    std::fs::write(source.join("code.rs"), "fn alpha() {} // synthetic\n").unwrap();
    f.ok(
        &["project", "add", "a", source.to_str().unwrap(), "code.rs"],
        None,
    );
    f.ok(&["index", "a"], None);
    f.ok(
        &["context", "add", "a", "memo", "note"],
        Some(b"synthetic human code.rs mention"),
    );
    let p = f.ok(&["project", "show", "a"], None);
    let args = [
        "source",
        "forget",
        "a",
        "code.rs",
        "--confirm-forget-source",
        "--expected-root",
        p["root"].as_str().unwrap(),
        "--expected-root-identity",
        p["root_identity"].as_str().unwrap(),
        "--expected-incarnation",
        p["incarnation"].as_str().unwrap(),
        "--expected-sources",
        "code.rs",
    ];
    let receipt = f.ok(&args, None);
    assert_eq!(receipt["human_context"], "unchanged");
    assert_eq!(receipt["snapshot"], "invalidated");
    assert!(!f.run(&args, None).status.success());
    assert!(
        !f.run(&["project", "sources", "a", "code.rs"], None)
            .status
            .success()
    );
    assert_eq!(
        f.ok(&["source", "forgotten", "a"], None)["forgotten"][0]["path"],
        "code.rs"
    );
    let mut repeated = receipt;
    repeated["snapshot"] = serde_json::json!("unchanged");
    assert_eq!(
        f.ok(
            &[
                "source",
                "forget",
                "a",
                "code.rs",
                "--confirm-forget-source"
            ],
            None
        ),
        repeated
    );
    f.ok(&["index", "a"], None);
    assert_eq!(
        f.ok(&["query", "a", "synthetic"], None)["results"],
        serde_json::json!([])
    );
    let preview = f.ok(
        &["context", "prepare", "a", "synthetic"],
        Some(b"synthetic original"),
    );
    assert!(
        !serde_json::to_string(&preview)
            .unwrap()
            .contains("fn alpha")
    );
    let archive = f.ok(&EXPORT, None);
    assert_eq!(archive["evidence"], serde_json::json!([]));
    assert_eq!(
        archive["human_history"][0]["text"],
        "synthetic human code.rs mention"
    );
    assert!(source.join("code.rs").is_file());
}

#[test]
fn bound_forget_binding_shapes_and_revisions_fail_before_store_creation() {
    let f = Fixture::new();
    let pairs = [
        ("--expected-root", "/synthetic"),
        ("--expected-root-identity", "1:2"),
        ("--expected-incarnation", "0123456789abcdef0123456789abcdef"),
        ("--expected-revision", "1"),
    ];
    for mask in 1..16 {
        let mut args = FORGET.to_vec();
        for (i, (key, value)) in pairs.iter().enumerate() {
            if mask & (1 << i) != 0 {
                args.extend([*key, *value]);
            }
        }
        let out = f.run(&args, None);
        assert!(!out.status.success() && out.stdout.is_empty());
        assert!(!f.0.join("store").exists());
    }
    for (field, values) in [
        (0, vec!["", "relative"]),
        (1, vec![""]),
        (2, vec!["", "bad", "0123456789ABCDEF0123456789abcdef"]),
        (3, vec!["", "0", "33", "-1", "1.0", "NaN", "4294967296"]),
    ] {
        for bad in values {
            let mut args = FORGET.to_vec();
            for (i, (key, value)) in pairs.iter().enumerate() {
                args.extend([*key, if i == field { bad } else { *value }]);
            }
            let out = f.run(&args, None);
            assert!(!out.status.success() && out.stdout.is_empty());
            assert!(!f.0.join("store").exists());
        }
    }
    for field in [2, 3] {
        let mut args = FORGET.to_vec();
        args[field] = "../invalid";
        for (key, value) in pairs {
            args.extend([key, value]);
        }
        let out = f.run(&args, None);
        assert!(!out.status.success() && out.stdout.is_empty());
        assert!(!f.0.join("store").exists());
    }
}
const UPGRADE_V3: [&str; 6] = [
    "store",
    "upgrade",
    "--to-version",
    "3",
    "--confirm-local-schema-upgrade",
    "--confirm-legacy-workers-stopped",
];

#[test]
fn v3_attestation_and_binding_validation_precede_open_and_creation() {
    let f = Fixture::new();
    for args in [
        vec![
            "store",
            "upgrade",
            "--to-version",
            "3",
            "--confirm-local-schema-upgrade",
        ],
        vec![
            "store",
            "upgrade",
            "--to-version",
            "3",
            "--confirm-legacy-workers-stopped",
        ],
        vec![
            "store",
            "upgrade",
            "--to-version",
            "4",
            "--confirm-local-schema-upgrade",
            "--confirm-legacy-workers-stopped",
        ],
        UPGRADE_V3.to_vec(),
        vec![
            "project",
            "remove",
            "a",
            "--confirm-remove-local-data",
            "--expected-root",
            "/synthetic",
            "--expected-root-identity",
            "1:2",
            "--expected-incarnation",
            "bad",
        ],
        vec![
            "index",
            "a",
            "--expected-root",
            "/synthetic",
            "--expected-root-identity",
            "1:2",
            "--expected-incarnation",
            "0123456789ABCDEF0123456789abcdef",
            "--expected-sources",
            "main.rs",
        ],
    ] {
        let out = f.run(&args, None);
        assert!(!out.status.success() && out.stdout.is_empty());
        assert!(!f.0.join("store").exists());
    }
}

#[test]
fn cli_same_directory_reregistration_rejects_native_old_bindings() {
    let f = Fixture::new();
    let root = f.0.join("source");
    f.ok(
        &["project", "add", "a", root.to_str().unwrap(), "main.rs"],
        None,
    );
    let old = f.ok(&["project", "show", "a"], None);
    let root = old["root"].as_str().unwrap();
    let identity = old["root_identity"].as_str().unwrap();
    let token = old["incarnation"].as_str().unwrap();
    let bound_index = [
        "index",
        "a",
        "--expected-root",
        root,
        "--expected-root-identity",
        identity,
        "--expected-incarnation",
        token,
        "--expected-sources",
        "main.rs",
    ];
    f.ok(&bound_index, None);
    let bound_remove = [
        "project",
        "remove",
        "a",
        "--confirm-remove-local-data",
        "--expected-root",
        root,
        "--expected-root-identity",
        identity,
        "--expected-incarnation",
        token,
    ];
    f.ok(&bound_remove, None);
    f.ok(&["project", "add", "a", root, "main.rs"], None);
    f.ok(
        &["context", "add", "a", "memo", "note"],
        Some(b"synthetic replacement"),
    );
    let current = f.ok(&["project", "show", "a"], None);
    assert_ne!(current["incarnation"], old["incarnation"]);
    let db = f.0.join("store/knowledge.sqlite");
    let before = std::fs::read(&db).unwrap();
    std::fs::remove_file(f.0.join("source/main.rs")).unwrap();
    for args in [&bound_index[..], &bound_remove[..]] {
        let out = f.run(args, None);
        assert!(!out.status.success() && out.stdout.is_empty());
        assert_eq!(std::fs::read(&db).unwrap(), before);
    }
    assert_eq!(f.ok(&UPGRADE_V3, None)["schema_version"], 4);
    assert_eq!(f.ok(&UPGRADE, None)["schema_version"], 4);
    assert_eq!(
        f.ok(&["context", "show", "a", "memo"], None)["history"][0]["revision"],
        1
    );
}

#[test]
fn forget_and_upgrade_exact_confirmation_required_before_open_or_creation() {
    let f = Fixture::new();
    for args in [
        vec!["context", "forget", "a", "memo"],
        vec!["context", "forget", "a", "memo", "--confirm"],
        vec![
            "context",
            "forget",
            "a",
            "memo",
            "--confirm-forget-local-history",
            "extra",
        ],
        vec!["store", "upgrade"],
        vec!["store", "upgrade", "--confirm"],
        vec![
            "store",
            "upgrade",
            "--confirm-local-schema-upgrade",
            "extra",
        ],
        FORGET.to_vec(),
        UPGRADE.to_vec(),
        vec!["context", "forgotten", "a"],
    ] {
        let out = f.run(&args, None);
        assert!(!out.status.success() && out.stdout.is_empty());
        assert!(!f.0.join("store").exists());
    }
}

#[test]
fn forget_real_process_history_removal_suppression_receipt_bounds_and_new_scope() {
    let f = Fixture::new();
    let root = f.0.join("source");
    f.ok(
        &["project", "add", "a", root.to_str().unwrap(), "main.rs"],
        None,
    );
    f.ok(&["index", "a"], None);
    let private = b"synthetic private human history must not appear in receipt";
    f.ok(&["context", "add", "a", "memo", "note"], Some(private));
    f.ok(
        &["context", "update", "a", "memo", "decision"],
        Some(private),
    );
    f.ok(&["context", "retire", "a", "memo"], None);
    f.ok(
        &["context", "add", "a", "keep", "note"],
        Some(b"synthetic survivor"),
    );
    let before = f.ok(&EXPORT, None);
    let db_path = f.0.join("store/knowledge.sqlite");
    let bytes = std::fs::read(&db_path).unwrap();
    let missing_confirmation = f.run(&["context", "forget", "a", "memo"], None);
    assert!(!missing_confirmation.status.success() && missing_confirmation.stdout.is_empty());
    assert_eq!(std::fs::read(&db_path).unwrap(), bytes);
    let receipt = f.ok(&FORGET, None);
    assert_eq!(receipt["removed_revisions"], 3);
    assert_eq!(receipt["forgotten"], true);
    assert_eq!(receipt.as_object().unwrap().len(), 5);
    assert_eq!(
        receipt["retention_limits"],
        "Active human-history removal and same-scope suppression only; not forensic erasure. SQLite free pages, journals, backups, earlier exports and displayed copies may retain bytes. Source files are untouched."
    );
    let encoded = serde_json::to_string(&receipt).unwrap();
    assert!(
        !encoded.contains(root.to_str().unwrap()) && !encoded.contains("private human history")
    );
    assert_eq!(f.ok(&FORGET, None)["removed_revisions"], 0);
    for args in [
        vec!["context", "show", "a", "memo"],
        vec!["context", "add", "a", "memo", "note"],
        vec!["context", "update", "a", "memo", "note"],
        vec!["context", "retire", "a", "memo"],
        vec![
            "context",
            "forget",
            "a",
            "unknown",
            "--confirm-forget-local-history",
        ],
    ] {
        let out = f.run(&args, Some(private));
        assert!(!out.status.success() && out.stdout.is_empty());
        assert_eq!(
            out.stderr,
            b"local knowledge operation failed; no content published\n"
        );
    }
    f.ok(&["index", "a"], None);
    f.ok(&["project", "sources", "a"], None);
    f.ok(&["project", "sources", "a", "main.rs"], None);
    f.ok(&["index", "a"], None);
    let after = f.ok(&EXPORT, None);
    assert_eq!(after["evidence"], before["evidence"]);
    assert_eq!(after["human_history"].as_array().unwrap().len(), 1);
    assert_eq!(after["human_history"][0]["id"], "keep");
    assert_eq!(
        f.ok(&["context", "list", "a"], None)["contexts"]
            .as_array()
            .unwrap()
            .len(),
        1
    );
    let markers = f.run(&["context", "forgotten", "a"], None);
    assert!(
        markers.status.success()
            && markers.stdout.len() <= 1_048_576
            && markers.stdout.ends_with(b"\n")
    );
    assert_eq!(
        serde_json::from_slice::<Value>(&markers.stdout).unwrap(),
        serde_json::json!({"project":"a","forgotten":[{"id":"memo"}]})
    );
    assert_eq!(f.ok(&UPGRADE, None)["upgraded"], false);
    f.ok(
        &["project", "remove", "a", "--confirm-remove-local-data"],
        None,
    );
    f.ok(
        &["project", "add", "a", root.to_str().unwrap(), "main.rs"],
        None,
    );
    assert_eq!(
        f.ok(&["context", "forgotten", "a"], None)["forgotten"],
        serde_json::json!([])
    );
    f.ok(
        &["context", "add", "a", "memo", "note"],
        Some(b"synthetic new authorization scope"),
    );
}

#[test]
fn real_cli_explicit_upgrade_preserves_known_v1_until_confirmation() {
    use std::os::unix::fs::{DirBuilderExt, OpenOptionsExt};
    let f = Fixture::new();
    let store = f.0.join("store");
    std::fs::DirBuilder::new()
        .mode(0o700)
        .create(&store)
        .unwrap();
    let path = store.join("knowledge.sqlite");
    std::fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(0o600)
        .open(&path)
        .unwrap();
    // Python's standard-library SQLite builds a historical fixture independently
    // of the product initializer. No shell, dependency install or real data.
    let result = Command::new("python3").args(["-c", r#"
import sqlite3, sys
db = sqlite3.connect(sys.argv[1])
db.executescript('''PRAGMA application_id=1414351665; PRAGMA user_version=1;
CREATE TABLE projects(id TEXT PRIMARY KEY, root TEXT NOT NULL UNIQUE, root_identity TEXT NOT NULL, sources TEXT NOT NULL, snapshot TEXT, manifest TEXT);
CREATE TABLE evidence(project TEXT NOT NULL, path TEXT NOT NULL, line INTEGER NOT NULL, text TEXT NOT NULL, hash TEXT NOT NULL, producer TEXT NOT NULL, PRIMARY KEY(project,path,line));
CREATE TABLE context(project TEXT NOT NULL, id TEXT NOT NULL, revision INTEGER NOT NULL, kind TEXT NOT NULL, text TEXT NOT NULL, retired INTEGER NOT NULL, PRIMARY KEY(project,id,revision));
CREATE INDEX context_project ON context(project,id,revision);''')
db.close()
"#]).arg(&path).output().unwrap();
    assert!(result.status.success());
    f.ok(
        &[
            "project",
            "add",
            "a",
            f.0.join("source").to_str().unwrap(),
            "main.rs",
        ],
        None,
    );
    f.ok(&["index", "a"], None);
    f.ok(
        &["context", "add", "a", "memo", "note"],
        Some(b"synthetic v1 preserved history"),
    );
    let before = f.ok(&EXPORT, None);
    f.ok(&["context", "list", "a"], None);
    let bytes = std::fs::read(&path).unwrap();
    assert_eq!(u32::from_be_bytes(bytes[60..64].try_into().unwrap()), 1);
    for args in [FORGET.to_vec(), vec!["store", "upgrade"]] {
        let out = f.run(&args, None);
        assert!(!out.status.success() && out.stdout.is_empty());
        assert_eq!(std::fs::read(&path).unwrap(), bytes);
    }
    assert_eq!(
        f.ok(&UPGRADE, None),
        serde_json::json!({"schema_version":2,"upgraded":true,"compatibility":"Older binaries cannot open schema v2; no automatic downgrade."})
    );
    assert_eq!(f.ok(&EXPORT, None), before);
    assert_eq!(f.ok(&UPGRADE, None)["upgraded"], false);
    assert_eq!(f.ok(&FORGET, None)["removed_revisions"], 1);
    let source_forget = [
        "source",
        "forget",
        "a",
        "main.rs",
        "--confirm-forget-source",
    ];
    assert!(!f.run(&source_forget, None).status.success());
    assert_eq!(
        f.ok(
            &[
                "store",
                "upgrade",
                "--to-version",
                "4",
                "--confirm-local-schema-upgrade",
                "--confirm-legacy-workers-stopped"
            ],
            None
        ),
        serde_json::json!({"schema_version":4,"upgraded":true,"compatibility":"Older binaries cannot open schema v4; no automatic downgrade."})
    );
    assert_eq!(
        f.ok(&["context", "forgotten", "a"], None)["forgotten"][0]["id"],
        "memo"
    );
    assert_eq!(f.ok(&source_forget, None)["forgotten"], true);
    assert_eq!(f.ok(&UPGRADE, None)["schema_version"], 4);
}

#[test]
fn bound_index_rejects_malformed_scope_before_store_creation() {
    let f = Fixture::new();
    for (id, root, identity, sources) in [
        ("bad/id", "/synthetic", "r1", vec!["main.rs"]),
        ("a", "relative", "r1", vec!["main.rs"]),
        ("a", "/synthetic", "", vec!["main.rs"]),
        ("a", "/synthetic", "r1", vec![]),
        ("a", "/synthetic", "r1", vec!["../outside.rs"]),
        ("a", "/synthetic", "r1", vec!["main.rs", "main.rs"]),
    ] {
        let mut args = vec![
            "index",
            id,
            "--expected-root",
            root,
            "--expected-root-identity",
            identity,
            "--expected-sources",
        ];
        args.extend(sources);
        let out = f.run(&args, None);
        assert!(!out.status.success() && out.stdout.is_empty());
        assert!(!f.0.join("store").exists());
    }
    // Missing a paired binding flag cannot fall back to unbound indexing.
    assert!(
        !f.run(&["index", "a", "--expected-root", "/synthetic"], None)
            .status
            .success()
    );
    assert!(!f.0.join("store").exists());
}

#[test]
fn bound_index_requires_exact_registered_root_identity_and_files() {
    let f = Fixture::new();
    let root = f.0.join("source");
    let root = root.to_str().unwrap();
    assert!(
        !f.run(
            &[
                "index",
                "a",
                "--expected-root",
                root,
                "--expected-root-identity",
                "synthetic",
                "--expected-sources",
                "main.rs"
            ],
            None
        )
        .status
        .success()
    );
    assert!(!f.0.join("store").exists()); // Even valid-shaped ticks cannot create storage.
    f.ok(&["project", "add", "a", root, "main.rs"], None);
    let project = f.ok(&["project", "show", "a"], None);
    let identity = project["root_identity"].as_str().unwrap();
    for (expected_root, expected_identity, file) in [
        ("/synthetic/wrong", identity, "main.rs"),
        (root, "wrong", "main.rs"),
        (root, identity, "other.rs"),
    ] {
        let out = f.run(
            &[
                "index",
                "a",
                "--expected-root",
                expected_root,
                "--expected-root-identity",
                expected_identity,
                "--expected-sources",
                file,
            ],
            None,
        );
        assert!(!out.status.success() && out.stdout.is_empty());
        assert!(f.ok(&["project", "show", "a"], None)["snapshot"].is_null());
    }
    let args = [
        "index",
        "a",
        "--expected-root",
        root,
        "--expected-root-identity",
        identity,
        "--expected-sources",
        "main.rs",
    ];
    let initial = f.ok(&args, None);
    std::fs::write(f.0.join("source/main.rs"), "synthetic_changed\n").unwrap();
    let updated = f.ok(&args, None);
    assert_ne!(initial["snapshot"], updated["snapshot"]);
    f.ok(&["project", "sources", "a"], None);
    assert!(!f.run(&args, None).status.success());
    assert!(f.ok(&["project", "show", "a"], None)["snapshot"].is_null());
    f.ok(
        &["project", "remove", "a", "--confirm-remove-local-data"],
        None,
    );
    let replacement = Fixture::new();
    f.ok(
        &[
            "project",
            "add",
            "a",
            replacement.0.join("source").to_str().unwrap(),
            "main.rs",
        ],
        None,
    );
    assert!(!f.run(&args, None).status.success());
    assert!(f.ok(&["project", "show", "a"], None)["snapshot"].is_null());
}

#[test]
fn export_requires_exact_confirmation_existing_recognized_store_and_project() {
    let f = Fixture::new();
    for args in [
        vec!["project", "export", "a"],
        vec!["project", "export", "a", "--confirm"],
        vec![
            "project",
            "export",
            "a",
            "--confirm-export-local-content",
            "extra",
        ],
        vec![
            "project",
            "export",
            "bad/id",
            "--confirm-export-local-content",
        ],
        EXPORT.to_vec(),
    ] {
        let out = f.run(&args, None);
        assert!(!out.status.success() && out.stdout.is_empty());
        assert!(!f.0.join("store").exists());
        assert!(
            !String::from_utf8(out.stderr)
                .unwrap()
                .contains(f.0.to_str().unwrap())
        );
    }
    std::fs::create_dir(f.0.join("store")).unwrap();
    assert!(!f.run(&EXPORT, None).status.success());
    assert!(!f.0.join("store/knowledge.sqlite").exists());
    // A foreign file is not adopted or modified.
    std::fs::write(
        f.0.join("store/knowledge.sqlite"),
        b"synthetic unknown database",
    )
    .unwrap();
    let before = std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap();
    let out = f.run(&EXPORT, None);
    assert!(!out.status.success() && out.stdout.is_empty());
    assert_eq!(
        std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap(),
        before
    );
}

#[test]
fn export_real_process_full_evidence_history_isolation_stale_revocation_and_reopen() {
    let f = Fixture::new();
    let other = Fixture::new();
    let source = (0..12)
        .map(|n| format!("synthetic blue {n}\n"))
        .collect::<String>();
    std::fs::write(f.0.join("source/main.rs"), &source).unwrap();
    for (id, fixture) in [("a", &f), ("b", &other)] {
        f.ok(
            &[
                "project",
                "add",
                id,
                fixture.0.join("source").to_str().unwrap(),
                "main.rs",
            ],
            None,
        );
        f.ok(&["index", id], None);
    }
    for (id, text) in [
        ("a", "synthetic chosen note"),
        ("b", "synthetic foreign note"),
    ] {
        f.ok(
            &["context", "add", id, "memo", "note"],
            Some(text.as_bytes()),
        );
    }
    f.ok(
        &["context", "update", "a", "memo", "decision"],
        Some(b"synthetic revised note\n"),
    );
    f.ok(&["context", "retire", "a", "memo"], None);
    let original = "synthetic request never stored";
    f.ok(
        &["context", "prepare", "a", "blue"],
        Some(original.as_bytes()),
    );
    let project = f.ok(&["project", "show", "a"], None);
    let history = f.ok(&["context", "show", "a", "memo"], None);
    let other_before = f.ok(&["query", "b", "blue"], None);
    let db_before = std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap();
    let archive = f.ok(&EXPORT, None);
    assert_eq!(archive["format"], "threadmark-project-export");
    assert_eq!(archive["version"], 1);
    assert_eq!(archive["project"]["id"], "a");
    assert_eq!(
        archive["project"]["root_identity"],
        project["root_identity"]
    );
    assert_eq!(archive["snapshot"], project["snapshot"]);
    assert_eq!(archive["currentness"], "current-at-read");
    assert_eq!(archive["evidence"].as_array().unwrap().len(), 12);
    for (n, row) in archive["evidence"].as_array().unwrap().iter().enumerate() {
        assert_eq!(row["line"], n + 1);
        assert_eq!(row["project"], "a");
        assert_eq!(row["path"], "main.rs");
        assert_eq!(row["producer"], "lexical-lines-v1");
        assert_eq!(row["source_hash"].as_str().unwrap().len(), 64);
    }
    assert_eq!(archive["human_history"].as_array().unwrap().len(), 3);
    for (n, row) in archive["human_history"]
        .as_array()
        .unwrap()
        .iter()
        .enumerate()
    {
        assert_eq!(row["revision"], n + 1);
        assert_eq!(row["text"], history["history"][n]["text"]);
        assert_eq!(row["retired"], n == 2);
        assert_eq!(row["producer"], "human-authored");
        assert_eq!(
            row["authority"],
            "context-not-authorization-or-observed-truth"
        );
    }
    assert_eq!(f.ok(&EXPORT, None), archive);
    assert_eq!(
        std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap(),
        db_before
    );
    assert_eq!(f.ok(&["project", "show", "a"], None), project);
    assert_eq!(f.ok(&["context", "show", "a", "memo"], None), history);
    assert_eq!(f.ok(&["query", "b", "blue"], None), other_before);
    let encoded = serde_json::to_string(&archive).unwrap();
    for excluded in [
        f.0.to_str().unwrap(),
        other.0.to_str().unwrap(),
        "synthetic foreign note",
        original,
        "knowledge.sqlite",
    ] {
        assert!(!encoded.contains(excluded));
    }
    assert_eq!(archive.as_object().unwrap().len(), 8);
    assert_eq!(archive["project"].as_object().unwrap().len(), 3);
    let out = f.run(
        &[
            "project",
            "export",
            "unregistered",
            "--confirm-export-local-content",
        ],
        None,
    );
    assert!(!out.status.success() && out.stdout.is_empty());
    assert_eq!(
        std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap(),
        db_before
    );
    assert_eq!(
        std::fs::read_to_string(f.0.join("source/main.rs")).unwrap(),
        source
    );
    std::fs::write(f.0.join("source/main.rs"), "synthetic changed\n").unwrap();
    let stale = f.ok(&EXPORT, None);
    assert_eq!(stale["currentness"], "stale-or-unindexed");
    assert_eq!(stale["evidence"], serde_json::json!([]));
    assert_eq!(stale["human_history"], archive["human_history"]);
    f.ok(&["project", "sources", "a"], None);
    let revoked = f.ok(&EXPORT, None);
    assert_eq!(revoked["project"]["sources"], serde_json::json!([]));
    assert!(revoked["snapshot"].is_null());
    assert_eq!(revoked["evidence"], serde_json::json!([]));
    assert_eq!(revoked["human_history"], archive["human_history"]);
    f.ok(&["index", "a"], None);
    let empty = f.ok(&EXPORT, None);
    assert_eq!(empty["currentness"], "current-at-read");
    assert_eq!(empty["evidence"], serde_json::json!([]));
}

#[test]
fn export_process_escaped_whole_envelope_overflow_has_no_stdout_or_mutation() {
    let f = Fixture::new();
    f.ok(
        &[
            "project",
            "add",
            "a",
            f.0.join("source").to_str().unwrap(),
            "main.rs",
        ],
        None,
    );
    // Raw history fits 1 MiB; JSON escaping plus provenance crosses the bound.
    let text = "\t".repeat(4096);
    for n in 0..120 {
        f.ok(
            &["context", "add", "a", &format!("n{n:03}"), "note"],
            Some(text.as_bytes()),
        );
    }
    let within = f.run(&EXPORT, None);
    assert!(within.status.success() && within.stdout.len() <= 1_048_576);
    assert!(within.stdout.ends_with(b"\n"));
    for n in 120..130 {
        f.ok(
            &["context", "add", "a", &format!("n{n:03}"), "note"],
            Some(text.as_bytes()),
        );
    }
    let db_before = std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap();
    let source_before = std::fs::read(f.0.join("source/main.rs")).unwrap();
    let overflow = f.run(&EXPORT, None);
    assert!(!overflow.status.success() && overflow.stdout.is_empty());
    assert_eq!(
        overflow.stderr,
        b"local knowledge operation failed; no content published\n"
    );
    assert_eq!(
        std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap(),
        db_before
    );
    assert_eq!(
        std::fs::read(f.0.join("source/main.rs")).unwrap(),
        source_before
    );
    assert_eq!(
        f.ok(&["context", "list", "a"], None)["contexts"]
            .as_array()
            .unwrap()
            .len(),
        130
    );
}

#[test]
fn bound_removal_validates_before_store_creation_and_rejects_replacement() {
    let f = Fixture::new();
    for (id, root, identity) in [
        ("bad/id", "/synthetic", "r1"),
        ("a", "", "r1"),
        ("a", "/synthetic", ""),
        ("a", "/synthetic", &"x".repeat(129)),
    ] {
        assert!(
            !f.run(
                &[
                    "project",
                    "remove",
                    id,
                    "--confirm-remove-local-data",
                    "--expected-root",
                    root,
                    "--expected-root-identity",
                    identity
                ],
                None
            )
            .status
            .success()
        );
        assert!(!f.0.join("store").exists());
    }
    let root = f.0.join("source");
    f.ok(
        &["project", "add", "a", root.to_str().unwrap(), "main.rs"],
        None,
    );
    let old = f.ok(&["project", "show", "a"], None);
    f.ok(
        &["project", "remove", "a", "--confirm-remove-local-data"],
        None,
    );
    let replacement = f.0.join("replacement");
    std::fs::create_dir(&replacement).unwrap();
    std::fs::write(replacement.join("main.rs"), "fn replacement_blue() {}\n").unwrap();
    f.ok(
        &[
            "project",
            "add",
            "a",
            replacement.to_str().unwrap(),
            "main.rs",
        ],
        None,
    );
    f.ok(&["index", "a"], None);
    f.ok(
        &["context", "add", "a", "memo", "note"],
        Some(b"synthetic replacement note"),
    );
    let before = f.ok(&["query", "a", "blue"], None);
    let history = f.ok(&["context", "show", "a", "memo"], None);
    assert!(
        !f.run(
            &[
                "project",
                "remove",
                "a",
                "--confirm-remove-local-data",
                "--expected-root",
                old["root"].as_str().unwrap(),
                "--expected-root-identity",
                old["root_identity"].as_str().unwrap()
            ],
            None
        )
        .status
        .success()
    );
    assert_eq!(f.ok(&["query", "a", "blue"], None), before);
    assert_eq!(f.ok(&["context", "show", "a", "memo"], None), history);
    let current = f.ok(&["project", "show", "a"], None);
    let receipt = f.ok(
        &[
            "project",
            "remove",
            "a",
            "--confirm-remove-local-data",
            "--expected-root",
            current["root"].as_str().unwrap(),
            "--expected-root-identity",
            current["root_identity"].as_str().unwrap(),
        ],
        None,
    );
    assert_eq!(receipt["removed"], true);
    assert_eq!(f.ok(&["project", "list"], None), serde_json::json!([]));
    assert!(replacement.join("main.rs").is_file());
}

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
        let process = Command::new(env!("CARGO_BIN_EXE_threadmark"))
            .arg("--data-dir")
            .arg(self.0.join("store"))
            .args(args)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .unwrap();
        Self::finish(process, input)
    }
    fn finish(mut process: std::process::Child, input: Option<&[u8]>) -> Output {
        let input_closed_early = if let Some(bytes) = input {
            match process.stdin.take().unwrap().write_all(bytes) {
                Ok(()) => false,
                Err(error) if error.kind() == std::io::ErrorKind::BrokenPipe => true,
                Err(error) => panic!("stdin write failed: {:?}", error.kind()),
            }
        } else {
            drop(process.stdin.take());
            false
        };
        let output = process.wait_with_output().unwrap();
        // Early argument rejection intentionally need not consume stdin. Never
        // hide a successful child that failed to receive the supplied input.
        assert!(!input_closed_early || !output.status.success());
        output
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
fn rejected_child_may_close_stdin_before_the_fixture_writes() {
    let f = Fixture::new();
    let mut child = Command::new(env!("CARGO_BIN_EXE_threadmark"))
        .arg("--data-dir")
        .arg(f.0.join("store"))
        .arg("--invalid-command")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    // Retain our pipe while waiting for known finite argument rejection. This
    // forces the early-close ordering without timing or platform assumptions.
    let input = child.stdin.take();
    assert!(!child.wait().unwrap().success());
    child.stdin = input;
    assert_eq!(
        child
            .stdin
            .as_mut()
            .unwrap()
            .write_all(b"synthetic")
            .unwrap_err()
            .kind(),
        std::io::ErrorKind::BrokenPipe
    );
    let result = Fixture::finish(child, Some(b"synthetic"));
    assert!(!result.status.success() && result.stdout.is_empty());
    assert!(!f.0.join("store").exists());
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
