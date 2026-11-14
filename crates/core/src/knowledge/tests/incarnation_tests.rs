//! TM-01–04/07/10; partial P2-A1/A3/A5, P3-A3/A4. All data synthetic.
use super::*;

#[test]
fn v3_upgrade_child() {
    use std::io::Write;
    let Some(path) = std::env::var_os("THREADMARK_SYNTHETIC_V3_CHILD") else {
        return;
    };
    let mut s = Store::open_existing(Path::new(&path)).unwrap();
    s.upgrade_to_with_progress(3, &token(), |stage| {
        if stage == UpgradeStage::ReadyToCommit {
            println!("v3-staged");
            std::io::stdout().flush().unwrap();
            std::io::stdin().read_exact(&mut [0]).unwrap();
        }
    })
    .unwrap();
}

#[test]
fn killed_v3_migration_preserves_both_prior_schemas_and_content() {
    use std::io::BufRead;
    use std::process::{Command, Stdio};
    for old in [1, 2] {
        let (f, mut s) = forget_tests::v1_fixture();
        if old == 2 {
            s.upgrade(&token()).unwrap();
        }
        let before = s.export_project("a", &token()).unwrap();
        drop(s);
        let mut child = Command::new(std::env::current_exe().unwrap())
            .args([
                "--exact",
                "knowledge::tests::incarnation_tests::v3_upgrade_child",
                "--nocapture",
            ])
            .env("THREADMARK_SYNTHETIC_V3_CHILD", f.0.join("private-store"))
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .unwrap();
        let input = child.stdin.take().unwrap();
        let mut output = std::io::BufReader::new(child.stdout.take().unwrap());
        let mut staged = false;
        for _ in 0..10 {
            let mut line = String::new();
            if output.read_line(&mut line).unwrap() == 0 {
                break;
            }
            if line.trim() == "v3-staged" {
                staged = true;
                break;
            }
        }
        child.kill().unwrap();
        assert!(!child.wait().unwrap().success());
        drop(input);
        assert!(staged);
        assert!(f.0.join("private-store/knowledge.sqlite-journal").exists());
        let mut reopened = f.store();
        assert_eq!(schema::validate(&reopened.db).unwrap(), old);
        assert_eq!(reopened.export_project("a", &token()).unwrap(), before);
        reopened.upgrade_to_v3(&token()).unwrap();
    }
}

#[test]
fn fresh_v3_token_persists_edits_and_legacy_insert_delete_renews_it() {
    let (f, mut s) = removal_fixture();
    assert_eq!(schema::validate(&s.db).unwrap(), 4);
    let original = s.project("a").unwrap().incarnation.unwrap();
    validate_incarnation(&original).unwrap();
    index(&mut s);
    s.write_context("a", "note", "note", "synthetic", true)
        .unwrap();
    s.set_sources("a", vec!["code.rs".into()]).unwrap();
    assert_eq!(
        s.project("a").unwrap().incarnation.as_ref(),
        Some(&original)
    );
    let receipt = s.upgrade(&token()).unwrap();
    assert_eq!(
        receipt,
        json!({"schema_version":4,"upgraded":false,"compatibility":"Older binaries cannot open schema v4; no automatic downgrade."})
    );
    let legacy = Connection::open(f.0.join("private-store/knowledge.sqlite")).unwrap();
    legacy
        .execute("DELETE FROM projects WHERE id='a'", [])
        .unwrap();
    assert_eq!(
        legacy
            .query_row("SELECT count(*) FROM project_incarnations", [], |r| r
                .get::<_, i64>(0))
            .unwrap(),
        0
    );
    legacy
        .execute(
            "INSERT INTO projects(id,root,root_identity,sources) VALUES('a',?1,?2,'[\"code.rs\"]')",
            params![
                f.source().to_str().unwrap(),
                file_identity(&directory(&f.source()).unwrap()).unwrap()
            ],
        )
        .unwrap();
    assert_ne!(s.project("a").unwrap().incarnation.unwrap(), original);
    schema::validate(&s.db).unwrap();
}

#[test]
fn identical_reregistration_rejects_all_captured_mutations_without_changing_replacement() {
    for action in ["write", "sources", "retire", "remove", "forget"] {
        let (_f, mut s) = removal_fixture();
        let captured = s.project("a").unwrap();
        s.remove_project("a", &token()).unwrap();
        s.add_project("a", Path::new(&captured.root), captured.sources.clone())
            .unwrap();
        s.write_context("a", "note", "note", "synthetic revision one", false)
            .unwrap();
        index(&mut s);
        let before = s.export_project("a", &token()).unwrap();
        assert_eq!(s.context("a", "note").unwrap()["history"][0]["revision"], 1);
        let result = match action {
            "write" => s.write_context_for_policy(&captured, "note", "note", "stale", true),
            "sources" => s.set_sources_for_policy(&captured, vec![]),
            "retire" => s.retire_context_for_policy(&captured, "note"),
            "remove" => s
                .remove_project_for_policy(&captured, &token(), |_| {})
                .map(|_| ()),
            _ => s
                .forget_for_policy(&captured, "note", &token(), |_| {})
                .map(|_| ()),
        };
        assert_eq!(result, Err(Error::ScopeMismatch), "{action}");
        assert_eq!(s.export_project("a", &token()).unwrap(), before);
        assert!(
            s.forgotten_contexts("a").unwrap()["forgotten"]
                .as_array()
                .unwrap()
                .is_empty()
        );
        let old = captured.incarnation.as_deref().unwrap();
        // Missing source proves the binding is rejected before trying to read it.
        std::fs::remove_file(Path::new(&captured.root).join("code.rs")).unwrap();
        assert_eq!(
            s.index_incarnation_bound(
                "a",
                &captured.root,
                &captured.root_identity,
                &captured.sources,
                old,
                &token()
            ),
            Err(Error::ScopeMismatch)
        );
        assert_eq!(
            s.remove_project_incarnation_bound(
                "a",
                &captured.root,
                &captured.root_identity,
                old,
                &token()
            ),
            Err(Error::ScopeMismatch)
        );
        assert!(s.project("a").is_ok());
    }
}

#[test]
fn same_root_same_content_index_publication_is_fenced_after_capture() {
    for at in [IndexStage::Read, IndexStage::Extracted] {
        let (f, mut worker) = removal_fixture();
        let captured = worker.project("a").unwrap();
        let mut owner = f.store();
        let result = worker.index_scoped_incarnation(
            "a",
            Some((&captured.root, &captured.root_identity, &captured.sources)),
            captured.incarnation.as_deref(),
            &mut LexicalLines,
            &token(),
            |stage| {
                if stage == at {
                    owner.remove_project("a", &token()).unwrap();
                    owner
                        .add_project("a", &f.source(), captured.sources.clone())
                        .unwrap();
                    owner
                        .write_context("a", "note", "note", "synthetic", false)
                        .unwrap();
                }
            },
        );
        assert_eq!(result, Err(Error::ScopeMismatch));
        assert!(owner.project("a").unwrap().snapshot.is_none());
        assert_eq!(project_rows(&owner, "a"), [1, 0, 1]);
    }
}

#[test]
fn explicit_v3_from_both_legacy_versions_preserves_export_and_invalidates_preflight() {
    for old in [1, 2] {
        let (f, mut s) = forget_tests::v1_fixture();
        let other = Fixture::new();
        s.add_project("b", &other.source(), vec!["code.rs".into()])
            .unwrap();
        if old == 2 {
            s.upgrade(&token()).unwrap();
        }
        let captured = s.project("a").unwrap();
        assert!(captured.incarnation.is_none());
        let before = s.export_project("a", &token()).unwrap();
        drop(s);
        let mut s = f.store();
        assert_eq!(schema::validate(&s.db).unwrap(), old);
        let legacy = Connection::open(f.0.join("private-store/knowledge.sqlite")).unwrap();
        assert_eq!(s.upgrade_to_v3(&token()).unwrap()["upgraded"], true);
        assert_eq!(schema::validate(&s.db).unwrap(), 3);
        let distinct: i64 =
            s.db.query_row(
                "SELECT count(DISTINCT incarnation) FROM project_incarnations",
                [],
                |r| r.get(0),
            )
            .unwrap();
        assert_eq!(distinct, 2);
        assert_eq!(s.export_project("a", &token()).unwrap(), before);
        assert_eq!(
            s.write_context_for_policy(&captured, "note", "note", "stale", true),
            Err(Error::ScopeMismatch)
        );
        legacy
            .execute("DELETE FROM projects WHERE id='a'", [])
            .unwrap();
        assert!(schema::incarnation(&s.db, "a").is_err());
        legacy
            .execute(
                "INSERT INTO projects(id,root,root_identity,sources) VALUES('a',?1,?2,'[]')",
                params![captured.root, captured.root_identity],
            )
            .unwrap();
        assert!(s.project("a").unwrap().incarnation.is_some());
        assert_eq!(s.upgrade_to_v3(&token()).unwrap()["upgraded"], false);
    }
}

#[test]
fn v3_cancellation_and_disk_full_rollback_entire_legacy_schema() {
    for old in [1, 2] {
        for at in [UpgradeStage::Validated, UpgradeStage::ReadyToCommit] {
            let (_f, mut s) = forget_tests::v1_fixture();
            if old == 2 {
                s.upgrade(&token()).unwrap();
            }
            let before = s.export_project("a", &token()).unwrap();
            let cancel = token();
            assert_eq!(
                s.upgrade_to_with_progress(3, &cancel, |stage| {
                    if stage == at {
                        cancel.store(true, Ordering::SeqCst);
                    }
                }),
                Err(Error::Canceled)
            );
            assert_eq!(schema::validate(&s.db).unwrap(), old);
            assert_eq!(s.export_project("a", &token()).unwrap(), before);
        }
        let (_f, mut s) = forget_tests::v1_fixture();
        if old == 2 {
            s.upgrade(&token()).unwrap();
        }
        let before = s.export_project("a", &token()).unwrap();
        let pages: i64 =
            s.db.pragma_query_value(None, "page_count", |r| r.get(0))
                .unwrap();
        s.db.pragma_update(None, "max_page_count", pages).unwrap();
        assert!(s.upgrade_to_v3(&token()).is_err());
        assert_eq!(schema::validate(&s.db).unwrap(), old);
        assert_eq!(s.export_project("a", &token()).unwrap(), before);
    }
}

#[test]
fn migration_between_index_preflight_and_publication_does_not_infer_authority() {
    for old in [1, 2] {
        let (f, mut worker) = forget_tests::v1_fixture();
        if old == 2 {
            worker.upgrade(&token()).unwrap();
        }
        let before = worker.export_project("a", &token()).unwrap();
        let mut owner = f.store();
        let result = worker.index_with_progress("a", &mut LexicalLines, &token(), |stage| {
            if stage == IndexStage::Read {
                owner.upgrade_to_v3(&token()).unwrap();
            }
        });
        assert_eq!(result, Err(Error::ScopeMismatch));
        assert_eq!(worker.export_project("a", &token()).unwrap(), before);
    }
}

#[test]
fn failed_schema_install_rolls_back_all_staged_objects() {
    for old in [1, 2] {
        let (_f, mut s) = forget_tests::v1_fixture();
        if old == 2 {
            s.upgrade(&token()).unwrap();
        }
        let before = s.export_project("a", &token()).unwrap();
        {
            let tx = s.db.transaction().unwrap();
            assert_eq!(schema::validate(&tx).unwrap(), old);
            if old == 1 {
                schema::install_v2(&tx).unwrap();
            }
            // Deterministic SQL failure after staging v2, before v3 backfill.
            tx.execute_batch("CREATE TABLE project_incarnations(collision TEXT)")
                .unwrap();
            assert!(schema::install_v3(&tx).is_err());
        }
        assert_eq!(schema::validate(&s.db).unwrap(), old);
        assert_eq!(s.export_project("a", &token()).unwrap(), before);
    }
}

#[test]
fn malformed_incarnation_rows_and_noncanonical_objects_fail_closed() {
    for sql in [
        "UPDATE project_incarnations SET incarnation='0123456789ABCDEF0123456789abcdef'",
        "UPDATE project_incarnations SET incarnation='bad'",
        "UPDATE project_incarnations SET incarnation='0123456789abcdef0123456789abcdef'||char(0)||'invalid'",
        "UPDATE project_incarnations SET incarnation=CAST('0123456789abcdef0123456789abcdef' AS BLOB)",
        "UPDATE project_incarnations SET incarnation='0123456789abcdef0123456789abcde'||char(0)",
        "UPDATE project_incarnations SET incarnation='0123456789abcdef'||char(0)||'invalidinvalidx'",
        "DELETE FROM project_incarnations",
        "INSERT INTO project_incarnations VALUES('orphan','0123456789abcdef0123456789abcdef')",
        "DROP TRIGGER threadmark_project_incarnation_insert",
        "DROP TRIGGER threadmark_project_incarnation_delete; CREATE TRIGGER threadmark_project_incarnation_delete AFTER DELETE ON projects BEGIN SELECT 1; END",
        "DROP TABLE project_incarnations; CREATE TABLE project_incarnations(project TEXT PRIMARY KEY, incarnation TEXTNOTNULL UNIQUE)",
        "CREATE TABLE extra(id TEXT)",
    ] {
        let (f, s) = removal_fixture();
        s.db.execute_batch(sql).unwrap();
        assert!(schema::validate(&s.db).is_err());
        drop(s);
        let db = f.0.join("private-store/knowledge.sqlite");
        let before = std::fs::read(&db).unwrap();
        assert!(Store::open_existing(db.parent().unwrap()).is_err());
        assert_eq!(std::fs::read(db).unwrap(), before);
    }
}
