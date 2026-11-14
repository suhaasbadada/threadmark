//! Synthetic TM-01–04/07/10; partial P2-A1/A3/A5 and P3-A4.
use super::*;

fn accesses() -> usize {
    source_forget::SOURCE_ACCESSES.with(|n| n.get())
}
fn binding(p: &Project) -> SourceForgetBinding<'_> {
    SourceForgetBinding {
        root: &p.root,
        root_identity: &p.root_identity,
        incarnation: p.incarnation.as_deref().unwrap(),
        sources: &p.sources,
    }
}

#[test]
fn bundled_sqlite_canonical_guards_under_untrusted_schema_and_legacy_rollback() {
    let (f, mut s) = removal_fixture();
    let legacy = Connection::open(f.0.join("private-store/knowledge.sqlite")).unwrap();
    legacy.execute_batch("PRAGMA trusted_schema=OFF").unwrap();
    assert_eq!(
        legacy
            .pragma_query_value::<i64, _>(None, "trusted_schema", |r| r.get(0))
            .unwrap(),
        0
    );
    // This exercises bundled SQLite's json_each inside the exact canonical DDL.
    legacy
        .execute(
            "UPDATE projects SET sources='[\"code.rs\"]' WHERE id='a'",
            [],
        )
        .unwrap();
    s.forget_source("a", "code.rs", &token()).unwrap();
    legacy
        .execute("UPDATE projects SET sources='[]' WHERE id='a'", [])
        .unwrap();
    let tx = legacy.unchecked_transaction().unwrap();
    tx.execute("DELETE FROM context WHERE project='a'", [])
        .unwrap();
    assert!(
        tx.execute(
            "UPDATE projects SET sources='[\"code.rs\"]' WHERE id='a'",
            []
        )
        .is_err()
    );
    drop(tx);
    assert_eq!(
        s.context("a", "note").unwrap()["history"]
            .as_array()
            .unwrap()
            .len(),
        3
    );
    assert!(
        legacy
            .execute(
                "INSERT INTO evidence VALUES('a','code.rs',1,'synthetic','hash','lexical')",
                []
            )
            .is_err()
    );
    let tx = legacy.unchecked_transaction().unwrap();
    tx.execute("DELETE FROM context WHERE project='a'", [])
        .unwrap();
    assert!(tx.execute("DELETE FROM projects WHERE id='a'", []).is_err());
    drop(tx);
    assert_eq!(
        s.context("a", "note").unwrap()["history"]
            .as_array()
            .unwrap()
            .len(),
        3
    );
    assert!(s.set_sources("a", vec!["code.rs".into()]).is_err());
    assert_eq!(schema::validate(&s.db).unwrap(), 4);
}

#[test]
fn source_forget_preserves_humans_other_projects_and_files_across_reopen_rebuild() {
    let (f, mut s) = removal_fixture();
    let second = Fixture::new();
    s.add_project("b", &second.source(), vec!["code.rs".into()])
        .unwrap();
    s.index("b", &mut LexicalLines, &token()).unwrap();
    s.write_context("b", "other", "note", "synthetic other history", false)
        .unwrap();
    std::fs::write(f.source().join("remaining.rs"), "fn remaining() {}\n").unwrap();
    s.set_sources("a", vec!["code.rs".into(), "remaining.rs".into()])
        .unwrap();
    index(&mut s);
    let history = s.context("a", "note").unwrap();
    let other = s.export_project("b", &token()).unwrap();
    let bytes = std::fs::read(f.source().join("code.rs")).unwrap();
    let before = accesses();
    let receipt = s.forget_source("a", "code.rs", &token()).unwrap();
    assert_eq!(accesses(), before);
    assert_eq!(
        receipt,
        json!({"project":"a","path":"code.rs","forgotten":true,"source_authorization":"revoked","snapshot":"invalidated","human_context":"unchanged","retention_limits":"Active source-derivative removal and same-scope suppression only; not forensic erasure. Source files and human context are untouched. SQLite free pages, journals, backups, earlier exports and displayed copies may retain bytes."})
    );
    assert_eq!(s.project("a").unwrap().sources, ["remaining.rs"]);
    assert!(s.project("a").unwrap().snapshot.is_none());
    assert_eq!(project_rows(&s, "a")[1], 0);
    assert_eq!(s.context("a", "note").unwrap(), history);
    assert_eq!(s.export_project("b", &token()).unwrap(), other);
    assert!(
        s.query("a", "blue", &token()).unwrap()["results"]
            .as_array()
            .unwrap()
            .is_empty()
    );
    assert!(
        s.export_project("a", &token()).unwrap()["evidence"]
            .as_array()
            .unwrap()
            .is_empty()
    );
    drop(s);
    let mut s = f.store();
    assert_eq!(
        s.forgotten_sources("a").unwrap(),
        json!({"project":"a","forgotten":[{"path":"code.rs"}]})
    );
    index(&mut s);
    let after = s.export_project("a", &token()).unwrap();
    assert!(
        after["evidence"]
            .as_array()
            .unwrap()
            .iter()
            .all(|r| r["path"] == "remaining.rs")
    );
    let mut repeated = receipt;
    repeated["snapshot"] = json!("unchanged");
    assert_eq!(s.forget_source("a", "code.rs", &token()).unwrap(), repeated);
    assert_eq!(s.export_project("a", &token()).unwrap(), after);
    assert_eq!(std::fs::read(f.source().join("code.rs")).unwrap(), bytes);
    assert!(s.forget_source("a", "unknown.rs", &token()).is_err());
}

#[test]
fn missing_unreadable_sources_forget_never_accesses_source_files() {
    for missing in [false, true] {
        let (f, mut s) = removal_fixture();
        let file = f.source().join("code.rs");
        if missing {
            std::fs::remove_file(&file).unwrap();
        } else {
            std::fs::set_permissions(&file, std::fs::Permissions::from_mode(0o0)).unwrap();
        }
        let before = accesses();
        let p = s.project("a").unwrap();
        s.forget_source_with_progress("a", "code.rs", Some(&binding(&p)), &token(), |_| {})
            .unwrap();
        assert_eq!(accesses(), before);
        if !missing {
            assert_eq!(std::fs::metadata(file).unwrap().mode() & 0o777, 0);
        }
    }
}

#[test]
fn bound_policy_marked_and_same_root_reregistration_fail_without_collateral_changes() {
    let (f, mut s) = removal_fixture();
    let old = s.project("a").unwrap();
    s.set_sources("a", vec![]).unwrap();
    let before = s.export_project("a", &token()).unwrap();
    assert!(
        s.forget_source_with_progress("a", "code.rs", Some(&binding(&old)), &token(), |_| {})
            .is_err()
    );
    assert_eq!(s.export_project("a", &token()).unwrap(), before);
    s.set_sources("a", vec!["code.rs".into()]).unwrap();
    s.forget_source("a", "code.rs", &token()).unwrap();
    assert!(
        s.forget_source_with_progress("a", "code.rs", Some(&binding(&old)), &token(), |_| {})
            .is_err()
    );
    s.remove_project("a", &token()).unwrap();
    s.add_project("a", &f.source(), vec!["code.rs".into()])
        .unwrap();
    assert_ne!(s.project("a").unwrap().incarnation, old.incarnation);
    assert!(
        s.forgotten_sources("a").unwrap()["forgotten"]
            .as_array()
            .unwrap()
            .is_empty()
    );
    assert!(s.context("a", "note").is_err());
    assert!(
        s.forget_source_with_progress("a", "code.rs", Some(&binding(&old)), &token(), |_| {})
            .is_err()
    );
    assert_eq!(project_rows(&s, "a"), [1, 0, 0]);
    index(&mut s);
}

#[test]
fn all_cancellation_stages_rollback_entire_source_operation() {
    for at in [
        SourceForgetStage::PolicyRevoked,
        SourceForgetStage::MarkerStaged,
        SourceForgetStage::EvidenceRemoved,
        SourceForgetStage::ReadyToCommit,
    ] {
        let (_f, mut s) = removal_fixture();
        let before = s.export_project("a", &token()).unwrap();
        let cancel = token();
        assert_eq!(
            s.forget_source_with_progress("a", "code.rs", None, &cancel, |stage| {
                if stage == at {
                    cancel.store(true, Ordering::SeqCst);
                }
            }),
            Err(Error::Canceled)
        );
        assert_eq!(s.export_project("a", &token()).unwrap(), before);
        assert_eq!(s.forgotten_sources("a").unwrap()["forgotten"], json!([]));
    }
}

#[test]
fn held_index_revocation_rejects_before_any_late_source_access_or_publish() {
    for at in [IndexStage::Read, IndexStage::Extracted] {
        let (f, mut s) = removal_fixture();
        let mut owner = f.store();
        let mut after_forget = 0;
        assert!(
            s.index_with_progress("a", &mut LexicalLines, &token(), |stage| {
                if stage == at {
                    owner.forget_source("a", "code.rs", &token()).unwrap();
                    after_forget = accesses();
                }
            })
            .is_err()
        );
        assert_eq!(accesses(), after_forget);
        assert_eq!(project_rows(&s, "a")[1], 0);
        assert!(s.project("a").unwrap().snapshot.is_none());
    }
}

#[test]
fn malformed_marker_and_corrupt_policy_or_evidence_overlap_fail_before_source_access() {
    for value in [
        "'../bad.rs'",
        "'bad'",
        "'a'||char(0)||'.rs'",
        "x'636f64652e7273'",
        "'code.rs'",
        "'missing.rs'",
    ] {
        let (f, mut s) = removal_fixture();
        let project = if value == "'missing.rs'" {
            "orphan"
        } else {
            "a"
        };
        s.db.execute_batch(&format!(
            "INSERT INTO forgotten_sources VALUES('{project}',{value})"
        ))
        .unwrap();
        let before = accesses();
        assert!(s.index("a", &mut LexicalLines, &token()).is_err());
        assert!(s.query("a", "blue", &token()).is_err());
        assert!(s.export_project("a", &token()).is_err());
        assert_eq!(accesses(), before);
        drop(s);
        assert!(Store::open_existing(&f.0.join("private-store")).is_err());
    }
    let (_f, s) = removal_fixture();
    s.db.execute("UPDATE projects SET sources='[]' WHERE id='a'", [])
        .unwrap();
    s.db.execute("INSERT INTO forgotten_sources VALUES('a','code.rs')", [])
        .unwrap();
    let before = accesses();
    assert!(s.export_project("a", &token()).is_err());
    assert_eq!(accesses(), before);
}

#[test]
fn marker_capacity_and_sorted_duplicates_are_bounded_atomic_and_project_local() {
    let (_f, mut s) = removal_fixture();
    let second = Fixture::new();
    s.add_project("b", &second.source(), vec!["code.rs".into()])
        .unwrap();
    for i in (0..64).rev() {
        s.db.execute(
            "INSERT INTO forgotten_sources VALUES('a',?1)",
            [format!("f{i:02}.rs")],
        )
        .unwrap();
    }
    let before = s.export_project("a", &token()).unwrap();
    assert!(s.forget_source("a", "code.rs", &token()).is_err());
    assert_eq!(s.export_project("a", &token()).unwrap(), before);
    let list = s.forgotten_sources("a").unwrap();
    assert_eq!(list["forgotten"].as_array().unwrap().len(), 64);
    assert_eq!(list["forgotten"][0]["path"], "f00.rs");
    s.forget_source("a", "f00.rs", &token()).unwrap();
    assert_eq!(s.forgotten_sources("a").unwrap(), list);
    assert_eq!(s.forgotten_sources("b").unwrap()["forgotten"], json!([]));
    s.db.execute(
        "INSERT INTO forgotten_sources VALUES('a','overflow.rs')",
        [],
    )
    .unwrap();
    assert!(s.project("a").is_err());
}

#[test]
fn explicit_v4_all_legacy_versions_no_implicit_upgrade_and_atomic_cancel_full() {
    for old in [1, 2, 3] {
        let (f, mut s) = forget_tests::v1_fixture();
        if old >= 2 {
            s.upgrade(&token()).unwrap();
        }
        if old == 3 {
            s.upgrade_to_v3(&token()).unwrap();
        }
        let before = s.export_project("a", &token()).unwrap();
        index(&mut s);
        assert!(s.forget_source("a", "code.rs", &token()).is_err());
        assert_eq!(schema::version(&s.db).unwrap(), old);
        for at in [UpgradeStage::Validated, UpgradeStage::ReadyToCommit] {
            let cancel = token();
            assert_eq!(
                s.upgrade_to_with_progress(4, &cancel, |stage| {
                    if stage == at {
                        cancel.store(true, Ordering::SeqCst);
                    }
                }),
                Err(Error::Canceled)
            );
            assert_eq!(schema::validate(&s.db).unwrap(), old);
            assert_eq!(s.export_project("a", &token()).unwrap(), before);
        }
        let pages: i64 =
            s.db.pragma_query_value(None, "page_count", |r| r.get(0))
                .unwrap();
        s.db.pragma_update(None, "max_page_count", pages).unwrap();
        assert!(s.upgrade_to_with_progress(4, &token(), |_| {}).is_err());
        assert_eq!(schema::validate(&s.db).unwrap(), old);
        assert_eq!(s.export_project("a", &token()).unwrap(), before);
        s.db.pragma_update(None, "max_page_count", 32768).unwrap();
        assert_eq!(
            s.upgrade_to_with_progress(4, &token(), |_| {}).unwrap()["schema_version"],
            4
        );
        assert_eq!(s.export_project("a", &token()).unwrap(), before);
        for target in [2, 3, 4] {
            assert_eq!(
                s.upgrade_to_with_progress(target, &token(), |_| {})
                    .unwrap()["upgraded"],
                false
            );
        }
        drop(s);
        assert_eq!(schema::validate(&f.store().db).unwrap(), 4);
    }
}

#[test]
fn source_sql_abort_and_disk_full_rollback_policy_markers_evidence_and_humans() {
    for trigger in [
        "CREATE TRIGGER synthetic_abort BEFORE INSERT ON forgotten_sources BEGIN SELECT RAISE(ABORT,'synthetic'); END",
        "CREATE TRIGGER synthetic_abort BEFORE DELETE ON evidence BEGIN SELECT RAISE(ABORT,'synthetic'); END",
        "CREATE TRIGGER synthetic_abort BEFORE UPDATE OF snapshot ON projects BEGIN SELECT RAISE(ABORT,'synthetic'); END",
    ] {
        let (_f, mut s) = removal_fixture();
        let before = s.export_project("a", &token()).unwrap();
        s.db.execute_batch(trigger).unwrap();
        let mut stages = Vec::new();
        assert!(
            s.forget_source_with_progress("a", "code.rs", None, &token(), |stage| stages
                .push(stage))
                .is_err()
        );
        assert!(stages.contains(&SourceForgetStage::PolicyRevoked));
        assert_eq!(s.export_project("a", &token()).unwrap(), before);
        assert_eq!(s.forgotten_sources("a").unwrap()["forgotten"], json!([]));
    }
    let (_f, mut s) = removal_fixture();
    // Fill marker-table pages to their current allocation; ensure one of these
    // inserts actually hits SQLITE_FULL after the policy update has been staged.
    let second = Fixture::new();
    s.add_project("b", &second.source(), vec![]).unwrap();
    let mut hit_full = false;
    for i in 0..64 {
        let path = format!("{}f{i:02}.rs", "a".repeat(225));
        s.set_sources("a", vec![path.clone()]).unwrap();
        let before = s.export_project("a", &token()).unwrap();
        let pages: i64 =
            s.db.pragma_query_value(None, "page_count", |r| r.get(0))
                .unwrap();
        s.db.pragma_update(None, "max_page_count", pages).unwrap();
        let mut staged = false;
        let result = s.forget_source_with_progress("a", &path, None, &token(), |stage| {
            staged |= stage == SourceForgetStage::PolicyRevoked;
        });
        if result.is_err() {
            assert!(staged);
            assert_eq!(s.export_project("a", &token()).unwrap(), before);
            hit_full = true;
            break;
        }
    }
    assert!(
        hit_full,
        "synthetic fixture must exercise an actual bounded SQL-full failure"
    );
}

#[test]
fn v4_owned_child() {
    use std::io::Write;
    let Some(path) = std::env::var_os("THREADMARK_SYNTHETIC_V4_CHILD") else {
        return;
    };
    let mut s = Store::open_existing(Path::new(&path)).unwrap();
    let stop = || {
        println!("v4-staged");
        std::io::stdout().flush().unwrap();
        std::io::stdin().read_exact(&mut [0]).unwrap();
    };
    if std::env::var_os("THREADMARK_SYNTHETIC_V4_FORGET").is_some() {
        s.forget_source_with_progress("a", "code.rs", None, &token(), |stage| {
            if stage == SourceForgetStage::ReadyToCommit {
                stop();
            }
        })
        .unwrap();
    } else {
        s.upgrade_to_with_progress(4, &token(), |stage| {
            if stage == UpgradeStage::ReadyToCommit {
                stop();
            }
        })
        .unwrap();
    }
}

#[test]
fn killed_v4_upgrade_and_forget_restore_complete_previous_schema_and_content() {
    use std::io::BufRead;
    use std::process::{Command, Stdio};
    for old in [1, 2, 3, 4] {
        let (f, mut s) = forget_tests::v1_fixture();
        if old >= 2 {
            s.upgrade(&token()).unwrap();
        }
        if old >= 3 {
            s.upgrade_to_v3(&token()).unwrap();
        }
        if old == 4 {
            s.upgrade_to_with_progress(4, &token(), |_| {}).unwrap();
        }
        let before = s.export_project("a", &token()).unwrap();
        drop(s);
        let mut command = Command::new(std::env::current_exe().unwrap());
        command
            .args([
                "--exact",
                "knowledge::tests::source_forget_tests::v4_owned_child",
                "--nocapture",
            ])
            .env("THREADMARK_SYNTHETIC_V4_CHILD", f.0.join("private-store"))
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());
        if old == 4 {
            command.env("THREADMARK_SYNTHETIC_V4_FORGET", "1");
        }
        let mut child = command.spawn().unwrap();
        let input = child.stdin.take().unwrap();
        let mut output = std::io::BufReader::new(child.stdout.take().unwrap());
        let mut staged = false;
        for _ in 0..10 {
            let mut line = String::new();
            if output.read_line(&mut line).unwrap() == 0 {
                break;
            }
            if line.trim() == "v4-staged" {
                staged = true;
                break;
            }
        }
        child.kill().unwrap();
        assert!(!child.wait().unwrap().success());
        drop(input);
        assert!(staged);
        assert!(f.0.join("private-store/knowledge.sqlite-journal").exists());
        let s = f.store();
        assert_eq!(schema::validate(&s.db).unwrap(), old);
        assert_eq!(s.export_project("a", &token()).unwrap(), before);
    }
}

#[test]
fn v4_rejects_noncanonical_shapes_types_and_incarnations_without_repair() {
    for sql in [
        "DROP TRIGGER threadmark_source_policy_guard",
        "DROP TRIGGER threadmark_source_evidence_guard; CREATE TRIGGER threadmark_source_evidence_guard BEFORE INSERT ON evidence BEGIN SELECT 1; END",
        "DROP TABLE forgotten_sources; CREATE TABLE forgotten_sources(project TEXTNOTNULL,path TEXTNOTNULL,PRIMARY KEY(project,path))",
        "UPDATE project_incarnations SET incarnation=x'3031323334353637383961626364656630313233343536373839616263646566' WHERE project='a'",
        "UPDATE project_incarnations SET incarnation='0123456789abcdef0123456789abcde'||char(0) WHERE project='a'",
        "UPDATE projects SET sources=x'5b5d' WHERE id='a'",
    ] {
        let (f, s) = removal_fixture();
        s.db.execute_batch(sql).unwrap();
        drop(s);
        let path = f.0.join("private-store/knowledge.sqlite");
        let before = std::fs::read(&path).unwrap();
        assert!(Store::open_existing(path.parent().unwrap()).is_err());
        assert_eq!(std::fs::read(path).unwrap(), before);
    }
}
