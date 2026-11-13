//! TM-01–04/07/10, partial P2-A3/A5: synthetic Forget and migration boundaries.
use super::*;

fn v1_fixture() -> (Fixture, Store) {
    let f = Fixture::new();
    let root = f.0.join("private-store");
    std::fs::DirBuilder::new()
        .mode(0o700)
        .create(&root)
        .unwrap();
    let path = root.join("knowledge.sqlite");
    OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(0o600)
        .open(&path)
        .unwrap();
    let db = Connection::open(path).unwrap();
    // Known historical DDL, not a v2 store stripped back into a guessed v1 shape.
    db.execute_batch("PRAGMA application_id=1414351665; PRAGMA user_version=1;
        CREATE TABLE projects(id TEXT PRIMARY KEY, root TEXT NOT NULL UNIQUE, root_identity TEXT NOT NULL, sources TEXT NOT NULL, snapshot TEXT, manifest TEXT);
        CREATE TABLE evidence(project TEXT NOT NULL, path TEXT NOT NULL, line INTEGER NOT NULL, text TEXT NOT NULL, hash TEXT NOT NULL, producer TEXT NOT NULL, PRIMARY KEY(project,path,line));
        CREATE TABLE context(project TEXT NOT NULL, id TEXT NOT NULL, revision INTEGER NOT NULL, kind TEXT NOT NULL, text TEXT NOT NULL, retired INTEGER NOT NULL, PRIMARY KEY(project,id,revision));
        CREATE INDEX context_project ON context(project,id,revision);").unwrap();
    drop(db);
    let mut s = f.registered();
    index(&mut s);
    s.write_context("a", "note", "note", "synthetic original", false)
        .unwrap();
    (f, s)
}

fn marked(s: &Store) -> usize {
    s.forgotten_contexts("a").unwrap()["forgotten"]
        .as_array()
        .unwrap()
        .len()
}

#[test]
fn merged_sql_type_tokens_are_rejected_without_mutating_the_database() {
    let f = Fixture::new();
    let s = f.registered();
    s.db.execute_batch("DROP TABLE forgotten_context;
        CREATE TABLE forgotten_context(project TEXTNOTNULL, id TEXTNOTNULL, PRIMARY KEY(project,id));").unwrap();
    let not_null: i64 =
        s.db.query_row(
            "SELECT \"notnull\" FROM pragma_table_info('forgotten_context') WHERE name='project'",
            [],
            |r| r.get(0),
        )
        .unwrap();
    assert_eq!(not_null, 0); // This is a valid SQLite type, not NOT NULL.
    assert!(schema::validate(&s.db).is_err());
    drop(s);
    let root = f.0.join("private-store");
    let path = root.join("knowledge.sqlite");
    let before = std::fs::read(&path).unwrap();
    assert!(Store::open_existing(&root).is_err());
    assert_eq!(std::fs::read(&path).unwrap(), before);
}

#[test]
fn v1_reads_exports_writes_stay_v1_and_forget_requires_explicit_upgrade() {
    let (f, mut s) = v1_fixture();
    assert_eq!(schema::version(&s.db).unwrap(), 1);
    assert_eq!(s.export_project("a", &token()).unwrap()["version"], 1);
    assert_eq!(
        s.context("a", "note").unwrap()["history"]
            .as_array()
            .unwrap()
            .len(),
        1
    );
    assert!(s.forget_context("a", "note", &token()).is_err());
    assert!(s.forgotten_contexts("a").is_err());
    s.write_context("a", "note", "decision", "synthetic revision", true)
        .unwrap();
    s.retire_context("a", "note").unwrap();
    drop(s);
    let mut s = f.store();
    assert_eq!(schema::version(&s.db).unwrap(), 1);
    let before = s.export_project("a", &token()).unwrap();
    let receipt = s.upgrade(&token()).unwrap();
    assert_eq!(
        receipt,
        json!({"schema_version":2,"upgraded":true,"compatibility":"Older binaries cannot open schema v2; no automatic downgrade."})
    );
    assert_eq!(s.export_project("a", &token()).unwrap(), before);
    assert_eq!(s.upgrade(&token()).unwrap()["upgraded"], false);
    drop(s);
    assert_eq!(schema::validate(&f.store().db).unwrap(), 2);
}

#[test]
fn migration_cancellation_at_each_stage_and_sql_full_restore_v1_and_all_rows() {
    for stage in [UpgradeStage::Validated, UpgradeStage::ReadyToCommit] {
        let (_f, mut s) = v1_fixture();
        let before = s.export_project("a", &token()).unwrap();
        let cancel = token();
        assert_eq!(
            s.upgrade_with_progress(&cancel, |at| {
                if at == stage {
                    cancel.store(true, Ordering::SeqCst);
                }
            }),
            Err(Error::Canceled)
        );
        assert_eq!(schema::validate(&s.db).unwrap(), 1);
        assert_eq!(s.export_project("a", &token()).unwrap(), before);
    }
    let (_f, mut s) = v1_fixture();
    let before = s.export_project("a", &token()).unwrap();
    let pages: i64 =
        s.db.pragma_query_value(None, "page_count", |r| r.get(0))
            .unwrap();
    s.db.pragma_update(None, "max_page_count", pages).unwrap();
    assert!(s.upgrade(&token()).is_err());
    assert_eq!(schema::validate(&s.db).unwrap(), 1);
    assert_eq!(s.export_project("a", &token()).unwrap(), before);
    s.db.pragma_update(None, "max_page_count", 32768).unwrap();
    s.upgrade(&token()).unwrap();
}

#[test]
fn full_history_forget_survives_restart_rebuild_and_policy_without_touching_other_data() {
    let (f, mut s) = removal_fixture();
    let other = Fixture::new();
    s.add_project("b", &other.source(), vec!["code.rs".into()])
        .unwrap();
    s.write_context("b", "note", "note", "synthetic other project", false)
        .unwrap();
    s.write_context("a", "keep", "note", "synthetic survivor", false)
        .unwrap();
    let source = std::fs::read(f.source().join("code.rs")).unwrap();
    let snapshot = s.project("a").unwrap().snapshot;
    let receipt = s.forget_context("a", "note", &token()).unwrap();
    assert_eq!(receipt["removed_revisions"], 3);
    assert_eq!(receipt["retention_limits"], forget::RETENTION);
    assert_eq!(receipt.as_object().unwrap().len(), 5);
    assert_eq!(s.project("a").unwrap().snapshot, snapshot);
    assert_eq!(matches(&s, "blue"), 1);
    drop(s);
    let mut s = f.store();
    assert_eq!(
        s.forget_context("a", "note", &token()).unwrap()["removed_revisions"],
        0
    );
    index(&mut s);
    s.set_sources("a", vec![]).unwrap();
    s.set_sources("a", vec!["code.rs".into()]).unwrap();
    index(&mut s);
    assert!(s.context("a", "note").is_err());
    assert!(
        s.write_context("a", "note", "note", "synthetic denied", false)
            .is_err()
    );
    assert!(
        s.write_context("a", "note", "note", "synthetic denied", true)
            .is_err()
    );
    assert!(s.retire_context("a", "note").is_err());
    assert_eq!(
        s.contexts("a").unwrap()["contexts"]
            .as_array()
            .unwrap()
            .len(),
        1
    );
    let archive = s.export_project("a", &token()).unwrap();
    assert_eq!(archive["human_history"].as_array().unwrap().len(), 1);
    assert_eq!(archive["human_history"][0]["id"], "keep");
    assert!(s.context("b", "note").is_ok());
    assert_eq!(std::fs::read(f.source().join("code.rs")).unwrap(), source);
    assert_eq!(
        s.forgotten_contexts("a").unwrap(),
        json!({"project":"a","forgotten":[{"id":"note"}]})
    );
}

#[test]
fn unknown_cancelled_and_sql_abort_forget_leave_no_marker_or_collateral_loss() {
    let (_f, mut s) = removal_fixture();
    let before = s.export_project("a", &token()).unwrap();
    assert_eq!(
        s.forget_context("a", "note", &AtomicBool::new(true)),
        Err(Error::Canceled)
    );
    assert_eq!(marked(&s), 0);
    assert!(s.forget_context("a", "unknown", &token()).is_err());
    assert_eq!(marked(&s), 0);
    assert_eq!(s.export_project("a", &token()).unwrap(), before);
    for stage in [
        ForgetStage::MarkerStaged,
        ForgetStage::ContentRemoved,
        ForgetStage::ReadyToCommit,
    ] {
        let cancel = token();
        assert_eq!(
            s.forget_context_with_progress("a", "note", &cancel, |at| {
                if at == stage {
                    cancel.store(true, Ordering::SeqCst);
                }
            }),
            Err(Error::Canceled)
        );
        assert_eq!(marked(&s), 0);
        assert_eq!(s.export_project("a", &token()).unwrap(), before);
    }
    s.db.execute_batch("CREATE TRIGGER synthetic_fail BEFORE DELETE ON context BEGIN SELECT RAISE(ABORT,'synthetic'); END").unwrap();
    assert!(s.forget_context("a", "note", &token()).is_err());
    assert_eq!(marked(&s), 0);
    assert_eq!(s.export_project("a", &token()).unwrap(), before);
    s.db.execute_batch("DROP TRIGGER synthetic_fail").unwrap();
    s.forget_context("a", "note", &token()).unwrap();
}

#[test]
fn maximum_history_receipt_removes_exactly_32_revisions() {
    let (_f, mut s) = removal_fixture();
    for _ in 3..32 {
        s.write_context("a", "note", "note", "synthetic bounded history", true)
            .unwrap();
    }
    assert_eq!(
        s.forget_context("a", "note", &token()).unwrap()["removed_revisions"],
        32
    );
    assert_eq!(
        s.forget_context("a", "note", &token()).unwrap()["removed_revisions"],
        0
    );
    assert_eq!(project_rows(&s, "a")[2], 0);
}

#[test]
fn malformed_v1_is_not_migrated_or_repaired() {
    let (f, mut s) = v1_fixture();
    let before = project_rows(&s, "a");
    assert_eq!(s.upgrade(&AtomicBool::new(true)), Err(Error::Canceled));
    assert_eq!(schema::validate(&s.db).unwrap(), 1);
    s.db.execute_batch("CREATE VIEW synthetic_unknown AS SELECT 1")
        .unwrap();
    assert!(s.upgrade(&token()).is_err());
    assert_eq!(schema::version(&s.db).unwrap(), 1);
    assert_eq!(project_rows(&s, "a"), before);
    drop(s);
    let path = f.0.join("private-store/knowledge.sqlite");
    let bytes = std::fs::read(&path).unwrap();
    assert!(Store::open_existing(path.parent().unwrap()).is_err());
    assert_eq!(std::fs::read(path).unwrap(), bytes);
}

#[test]
fn marker_capacity_duplicates_isolation_and_malformed_marker_fail_closed() {
    let (_f, mut s) = removal_fixture();
    let tx = s.db.transaction().unwrap();
    for n in 0..4095 {
        tx.execute(
            "INSERT INTO forgotten_context VALUES('a',?1)",
            [format!("id{n:04}")],
        )
        .unwrap();
    }
    tx.commit().unwrap();
    s.forget_context("a", "note", &token()).unwrap();
    assert_eq!(marked(&s), 4096);
    assert_eq!(
        s.forget_context("a", "note", &token()).unwrap()["removed_revisions"],
        0
    );
    s.write_context("a", "overflow", "note", "synthetic retained", false)
        .unwrap();
    assert!(s.forget_context("a", "overflow", &token()).is_err());
    assert!(s.context("a", "overflow").is_ok());
    let list = s.forgotten_contexts("a").unwrap();
    assert!(serde_json::to_vec(&list).unwrap().len() < MAX_TOTAL);
    assert_eq!(list["forgotten"][0]["id"], "id0000");
    let other = Fixture::new();
    s.add_project("b", &other.source(), vec![]).unwrap();
    s.write_context("b", "note", "note", "synthetic isolated", false)
        .unwrap();
    s.forget_context("b", "note", &token()).unwrap();
    s.db.execute(
        "DELETE FROM forgotten_context WHERE project='a' AND id='id0000'",
        [],
    )
    .unwrap();
    s.db.execute("INSERT INTO forgotten_context VALUES('a','bad/id')", [])
        .unwrap();
    assert!(s.forgotten_contexts("a").is_err());
    assert!(s.context("a", "overflow").is_err());
    assert!(s.contexts("a").is_err());
    assert!(s.export_project("a", &token()).is_err());
}

#[test]
fn corrupt_overlap_never_exposes_or_recreates_marked_history() {
    let (_f, mut s) = removal_fixture();
    // Inserting a marker directly models externally corrupted overlap, without
    // disabling the guards that must still protect subsequent writes.
    s.db.execute("INSERT INTO forgotten_context VALUES('a','note')", [])
        .unwrap();
    assert!(s.context("a", "note").is_err());
    assert!(
        s.contexts("a").unwrap()["contexts"]
            .as_array()
            .unwrap()
            .is_empty()
    );
    assert!(
        s.export_project("a", &token()).unwrap()["human_history"]
            .as_array()
            .unwrap()
            .is_empty()
    );
    assert!(
        s.write_context("a", "note", "note", "synthetic denied", true)
            .is_err()
    );
    assert!(s.retire_context("a", "note").is_err());
    assert_eq!(
        s.forget_context("a", "note", &token()).unwrap()["removed_revisions"],
        3
    );
}

#[test]
fn export_snapshot_serializes_with_forget_without_mixed_history() {
    let (f, s) = removal_fixture();
    let mut writer = f.store();
    writer.db.busy_timeout(std::time::Duration::ZERO).unwrap();
    let archive = s
        .export_project_with_progress("a", &token(), |stage| {
            if stage == ExportStage::Read {
                assert!(writer.forget_context("a", "note", &token()).is_err());
            }
        })
        .unwrap();
    assert_eq!(archive["human_history"].as_array().unwrap().len(), 3);
    assert_eq!(marked(&s), 0);
    writer.forget_context("a", "note", &token()).unwrap();
    assert!(
        s.export_project("a", &token()).unwrap()["human_history"]
            .as_array()
            .unwrap()
            .is_empty()
    );
}

#[test]
fn already_open_legacy_connection_cannot_write_or_orphan_markers_after_upgrade() {
    let (f, mut s) = v1_fixture();
    let mut old = Connection::open(f.0.join("private-store/knowledge.sqlite")).unwrap();
    let stale_core = f.store();
    s.upgrade(&token()).unwrap();
    s.forget_context("a", "note", &token()).unwrap();
    assert!(stale_core.context("a", "note").is_err());
    assert!(
        old.execute(
            "INSERT INTO context VALUES('a','note',1,'note','synthetic old writer',0)",
            []
        )
        .is_err()
    );
    s.write_context("a", "keep", "note", "synthetic keep", false)
        .unwrap();
    assert!(
        old.execute(
            "UPDATE context SET id='note' WHERE project='a' AND id='keep'",
            []
        )
        .is_err()
    );
    let before = s.export_project("a", &token()).unwrap();
    {
        let tx = old.transaction().unwrap();
        tx.execute("DELETE FROM context WHERE project='a'", [])
            .unwrap();
        tx.execute("DELETE FROM evidence WHERE project='a'", [])
            .unwrap();
        assert!(tx.execute("DELETE FROM projects WHERE id='a'", []).is_err());
        // Historical remove returns its error without commit; RAII rolls back.
    }
    assert_eq!(s.export_project("a", &token()).unwrap(), before);
    s.remove_project("a", &token()).unwrap();
    assert_eq!(
        s.db.query_row::<i64, _, _>("SELECT count(*) FROM forgotten_context", [], |r| r.get(0))
            .unwrap(),
        0
    );
    s.add_project("a", &f.source(), vec!["code.rs".into()])
        .unwrap();
    assert!(s.context("a", "keep").is_err());
    s.write_context("a", "note", "note", "synthetic new scope", false)
        .unwrap();
}

#[test]
fn held_old_root_forget_cannot_mutate_replacement_scope() {
    let (_f, mut s) = removal_fixture();
    let old = s.project("a").unwrap();
    s.remove_project("a", &token()).unwrap();
    let replacement = Fixture::new();
    s.add_project("a", &replacement.source(), vec![]).unwrap();
    s.write_context("a", "note", "note", "synthetic replacement", false)
        .unwrap();
    assert_eq!(
        s.forget_for_policy(&old, "note", &token(), |_| {}),
        Err(Error::ScopeMismatch)
    );
    assert_eq!(marked(&s), 0);
    assert!(s.context("a", "note").is_ok());
}

#[test]
fn malformed_v2_definitions_are_rejected_without_repair() {
    for change in [
        "DROP TRIGGER threadmark_context_insert_guard",
        "DROP TRIGGER threadmark_context_update_guard; CREATE TRIGGER threadmark_context_update_guard BEFORE UPDATE ON context BEGIN SELECT 1; END",
        "DROP TRIGGER threadmark_project_delete_guard",
        "DROP TABLE forgotten_context; CREATE TABLE forgotten_context(project TEXT,id TEXT)",
        "CREATE VIEW synthetic_extra AS SELECT 1",
    ] {
        let f = Fixture::new();
        let s = f.registered();
        s.db.execute_batch(change).unwrap();
        drop(s);
        let path = f.0.join("private-store/knowledge.sqlite");
        let before = std::fs::read(&path).unwrap();
        assert!(Store::open_existing(path.parent().unwrap()).is_err());
        assert_eq!(std::fs::read(path).unwrap(), before);
    }
}

#[test]
fn upgrade_child() {
    use std::io::Write;
    let Some(path) = std::env::var_os("THREADMARK_SYNTHETIC_UPGRADE_CHILD") else {
        return;
    };
    let mut s = Store::open_existing(Path::new(&path)).unwrap();
    let result = s.upgrade_with_progress(&token(), |stage| {
        if stage == UpgradeStage::ReadyToCommit {
            println!("upgrade-staged");
            std::io::stdout().flush().unwrap();
            let _ = std::io::stdin().read_exact(&mut [0]);
        }
    });
    assert!(result.is_ok());
}

#[test]
fn killed_migration_rolls_back_schema_and_history_after_hot_journal_recovery() {
    use std::io::BufRead;
    use std::process::{Command, Stdio};
    let (f, s) = v1_fixture();
    let before = s.export_project("a", &token()).unwrap();
    drop(s);
    let mut child = Command::new(std::env::current_exe().unwrap())
        .args([
            "--exact",
            "knowledge::tests::forget_tests::upgrade_child",
            "--nocapture",
        ])
        .env(
            "THREADMARK_SYNTHETIC_UPGRADE_CHILD",
            f.0.join("private-store"),
        )
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    let stdin = child.stdin.take().unwrap();
    let mut reader = std::io::BufReader::new(child.stdout.take().unwrap());
    let mut staged = false;
    for _ in 0..10 {
        let mut line = String::new();
        if reader.read_line(&mut line).unwrap() == 0 {
            break;
        }
        if line.trim() == "upgrade-staged" {
            staged = true;
            break;
        }
    }
    child.kill().unwrap();
    assert!(!child.wait().unwrap().success());
    drop(stdin);
    assert!(staged);
    assert!(f.0.join("private-store/knowledge.sqlite-journal").is_file());
    let mut s = f.store();
    assert_eq!(schema::validate(&s.db).unwrap(), 1);
    assert_eq!(s.export_project("a", &token()).unwrap(), before);
    s.upgrade(&token()).unwrap();
}
