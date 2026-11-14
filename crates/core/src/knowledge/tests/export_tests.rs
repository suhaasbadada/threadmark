//! P2-A1/A3/A4/A5/A6: synthetic project-export-v1 contract fixtures.
use super::*;

mod bound;

#[test]
fn export_all_anchors_and_human_revisions_are_separate_isolated_and_read_only() {
    let f = Fixture::new();
    let other = Fixture::new();
    let mut s = f.registered();
    let source = (0..12)
        .map(|n| format!("synthetic line {n}\n"))
        .collect::<String>();
    std::fs::write(f.source().join("code.rs"), &source).unwrap();
    s.add_project("b", &other.source(), vec!["code.rs".into()])
        .unwrap();
    s.index("a", &mut LexicalLines, &token()).unwrap();
    s.index("b", &mut LexicalLines, &token()).unwrap();
    s.write_context("a", "z", "note", "synthetic first", false)
        .unwrap();
    s.write_context("a", "z", "decision", "synthetic second", true)
        .unwrap();
    s.retire_context("a", "z").unwrap();
    s.write_context("a", "a", "pitfall", "synthetic ordered first", false)
        .unwrap();
    s.write_context("b", "foreign", "note", "synthetic foreign text", false)
        .unwrap();
    let before = dump(&s);
    let archive = s.export_project("a", &token()).unwrap();
    assert_eq!(dump(&s), before);
    assert_eq!(archive["format"], "threadmark-project-export");
    assert_eq!(archive["version"], 1);
    assert_eq!(archive["currentness"], "current-at-read");
    assert_eq!(
        archive["project"]["root_identity"],
        s.project("a").unwrap().root_identity
    );
    assert_eq!(archive["project"]["sources"], json!(["code.rs"]));
    assert_eq!(
        archive["snapshot"],
        s.project("a").unwrap().snapshot.unwrap()
    );
    let evidence = archive["evidence"].as_array().unwrap();
    assert_eq!(evidence.len(), 12);
    for (n, row) in evidence.iter().enumerate() {
        assert_eq!(row.as_object().unwrap().len(), 8);
        assert_eq!(row["line"], n + 1);
        assert_eq!(row["project"], "a");
        assert_eq!(row["source_hash"], sha256(source.as_bytes()));
        assert_eq!(row["producer"], "lexical-lines-v1");
        assert_eq!(row["kind"], "observed-source-line");
        assert_eq!(row["currentness"], "current-at-read");
    }
    let history = archive["human_history"].as_array().unwrap();
    assert_eq!(history.len(), 4);
    assert_eq!(history[0]["id"], "a");
    for (n, row) in history[1..].iter().enumerate() {
        assert_eq!(row["revision"], n + 1);
        assert_eq!(row["retired"], n == 2);
        assert_eq!(row["producer"], "human-authored");
        assert_eq!(
            row["authority"],
            "context-not-authorization-or-observed-truth"
        );
    }
    let encoded = serde_json::to_string(&archive).unwrap();
    assert!(!encoded.contains("synthetic foreign text"));
    assert!(!encoded.contains(f.0.to_str().unwrap()));
    assert!(!encoded.contains(other.0.to_str().unwrap()));
    drop(s);
    assert_eq!(f.store().export_project("a", &token()).unwrap(), archive);
    assert_eq!(
        std::fs::read_to_string(f.source().join("code.rs")).unwrap(),
        source
    );
}

fn dump(s: &Store) -> Vec<Vec<Value>> {
    [
        "SELECT * FROM projects ORDER BY id",
        "SELECT * FROM evidence ORDER BY project,path,line",
        "SELECT * FROM context ORDER BY project,id,revision",
    ]
    .iter()
    .map(|sql| {
        let mut stmt = s.db.prepare(sql).unwrap();
        let count = stmt.column_count();
        stmt.query_map([], |r| {
            Ok((0..count)
                .map(|i| match r.get_ref(i).unwrap() {
                    rusqlite::types::ValueRef::Null => Value::Null,
                    rusqlite::types::ValueRef::Integer(n) => json!(n),
                    rusqlite::types::ValueRef::Text(s) => json!(std::str::from_utf8(s).unwrap()),
                    _ => panic!("unexpected fixture type"),
                })
                .collect::<Vec<_>>())
        })
        .unwrap()
        .collect::<std::result::Result<Vec<_>, _>>()
        .unwrap()
        .into_iter()
        .map(Value::Array)
        .collect()
    })
    .collect()
}

#[test]
fn export_unindexed_stale_missing_unreadable_and_empty_current_are_distinct() {
    let f = Fixture::new();
    let mut s = f.registered();
    s.write_context("a", "memo", "note", "synthetic retained", false)
        .unwrap();
    let unindexed = s.export_project("a", &token()).unwrap();
    assert_eq!(unindexed["currentness"], "stale-or-unindexed");
    assert!(unindexed["snapshot"].is_null());
    index(&mut s);
    let source = f.source().join("code.rs");
    std::fs::write(&source, "synthetic changed\n").unwrap();
    for operation in 0..3 {
        if operation == 1 {
            std::fs::remove_file(&source).unwrap();
        }
        if operation == 2 {
            std::fs::write(&source, "synthetic unreadable\n").unwrap();
            std::fs::set_permissions(&source, std::fs::Permissions::from_mode(0o0)).unwrap();
        }
        let stale = s.export_project("a", &token()).unwrap();
        assert_eq!(stale["currentness"], "stale-or-unindexed");
        assert_eq!(stale["evidence"], json!([]));
        assert_eq!(stale["human_history"][0]["text"], "synthetic retained");
    }
    std::fs::set_permissions(&source, std::fs::Permissions::from_mode(0o600)).unwrap();
    std::fs::write(&source, "\n \n").unwrap();
    index(&mut s);
    let empty = s.export_project("a", &token()).unwrap();
    assert_eq!(empty["currentness"], "current-at-read");
    assert_eq!(empty["evidence"], json!([]));
    s.set_sources("a", vec![]).unwrap();
    let revoked = s.export_project("a", &token()).unwrap();
    assert_eq!(revoked["project"]["sources"], json!([]));
    assert_eq!(revoked["currentness"], "stale-or-unindexed");
    assert_eq!(revoked["evidence"], json!([]));
    assert_eq!(revoked["human_history"], empty["human_history"]);
    index(&mut s);
    assert_eq!(
        s.export_project("a", &token()).unwrap()["currentness"],
        "current-at-read"
    );
}

#[test]
fn export_authorization_loss_never_falls_back_to_human_history() {
    for case in 0..6 {
        let f = Fixture::new();
        let mut s = f.registered();
        s.write_context("a", "memo", "note", "synthetic retained", false)
            .unwrap();
        index(&mut s);
        match case {
            0 => {
                std::fs::set_permissions(f.source(), std::fs::Permissions::from_mode(0o0)).unwrap()
            }
            1 => {
                std::fs::rename(f.source(), f.0.join("old-root")).unwrap();
                std::fs::create_dir(f.source()).unwrap();
            }
            2 => {
                s.db.execute("UPDATE projects SET root_identity='foreign'", [])
                    .unwrap();
            }
            3 => {
                s.db.execute("UPDATE projects SET sources='[\"../outside.rs\"]'", [])
                    .unwrap();
            }
            4 => std::fs::set_permissions(
                f.0.join("private-store"),
                std::fs::Permissions::from_mode(0o755),
            )
            .unwrap(),
            5 => std::fs::set_permissions(
                f.0.join("private-store/knowledge.sqlite"),
                std::fs::Permissions::from_mode(0o644),
            )
            .unwrap(),
            _ => unreachable!(),
        }
        assert!(s.export_project("a", &token()).is_err());
        if case == 0 {
            std::fs::set_permissions(f.source(), std::fs::Permissions::from_mode(0o700)).unwrap();
        }
    }
}

#[test]
fn export_mid_read_source_change_cancellation_and_store_loss_fail_without_mutation() {
    for stage in [ExportStage::Read, ExportStage::ReadyToPublish] {
        for case in 0..5 {
            let f = Fixture::new();
            let mut s = f.registered();
            index(&mut s);
            let before = dump(&s);
            let cancel = token();
            assert!(
                s.export_project_with_progress("a", &cancel, |at| {
                    if at != stage {
                        return;
                    }
                    match case {
                        0 => std::fs::write(
                            f.source().join("code.rs"),
                            "synthetic concurrent edit\n",
                        )
                        .unwrap(),
                        1 => cancel.store(true, Ordering::SeqCst),
                        2 => std::fs::set_permissions(
                            f.0.join("private-store"),
                            std::fs::Permissions::from_mode(0o755),
                        )
                        .unwrap(),
                        3 => {
                            std::fs::rename(f.source(), f.0.join("old-root")).unwrap();
                        }
                        4 => {
                            let source = f.source().join("code.rs");
                            let bytes = std::fs::read(&source).unwrap();
                            // Keep the old inode alive so identical bytes still
                            // deterministically have a different file identity.
                            std::fs::rename(&source, f.source().join("old.rs")).unwrap();
                            std::fs::write(&source, bytes).unwrap();
                        }
                        _ => unreachable!(),
                    }
                })
                .is_err()
            );
            assert_eq!(dump(&s), before);
        }
    }
}

#[test]
fn export_malformed_foreign_anchor_snapshot_and_human_rows_fail_closed() {
    for sql in [
        "UPDATE evidence SET path='foreign.rs'",
        "UPDATE evidence SET line=0 WHERE line=1",
        "UPDATE evidence SET line=4097 WHERE line=1",
        "UPDATE evidence SET text='synthetic forged text'",
        "UPDATE evidence SET hash='ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'",
        "UPDATE evidence SET producer='invalid/producer'",
        "UPDATE projects SET snapshot='ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'",
        "UPDATE projects SET manifest='[]'",
        "UPDATE projects SET manifest=NULL",
        "UPDATE projects SET snapshot=NULL",
        "UPDATE context SET revision=2",
        "UPDATE context SET retired=2",
        "UPDATE context SET kind='foreign'",
        "UPDATE context SET text=''",
    ] {
        let f = Fixture::new();
        let mut s = f.registered();
        index(&mut s);
        s.write_context("a", "memo", "note", "synthetic note", false)
            .unwrap();
        s.db.execute(sql, []).unwrap();
        let before = dump(&s);
        assert!(
            s.export_project("a", &token()).is_err(),
            "malformed fixture accepted"
        );
        assert_eq!(dump(&s), before);
    }
}

#[test]
fn export_escaped_output_bound_rejects_whole_history_and_whole_evidence() {
    for history in [true, false] {
        let f = Fixture::new();
        let mut s = f.registered();
        if history {
            for n in 0..120 {
                s.write_context("a", &format!("n{n:03}"), "note", &"\t".repeat(4096), false)
                    .unwrap();
            }
            let small = s.export_project("a", &token()).unwrap();
            assert!(serde_json::to_vec(&small).unwrap().len() < MAX_TOTAL);
            for n in 120..130 {
                s.write_context("a", &format!("n{n:03}"), "note", &"\t".repeat(4096), false)
                    .unwrap();
            }
        } else {
            let text = format!("a{}\n", "\t".repeat(1023)).repeat(63);
            let mut sources = Vec::new();
            for n in 0..8 {
                let path = format!("f{n}.txt");
                std::fs::write(f.source().join(&path), &text).unwrap();
                sources.push(path);
            }
            s.set_sources("a", sources).unwrap();
            index(&mut s);
        }
        let before = dump(&s);
        assert!(s.export_project("a", &token()).is_err());
        assert_eq!(dump(&s), before);
    }
}

#[test]
fn export_read_transaction_blocks_policy_removal_and_history_writers_coherently() {
    for operation in 0..3 {
        let f = Fixture::new();
        let mut s = f.registered();
        index(&mut s);
        s.write_context("a", "memo", "note", "synthetic old history", false)
            .unwrap();
        let mut writer = f.store();
        writer.db.busy_timeout(std::time::Duration::ZERO).unwrap();
        let before = s.export_project("a", &token()).unwrap();
        let archive = s
            .export_project_with_progress("a", &token(), |stage| {
                if stage == ExportStage::Read {
                    let attempt = match operation {
                        0 => {
                            writer.write_context("a", "memo", "note", "synthetic new history", true)
                        }
                        1 => writer.remove_project("a", &token()).map(|_| ()),
                        2 => writer.set_sources("a", vec![]),
                        _ => unreachable!(),
                    };
                    assert!(attempt.is_err());
                }
            })
            .unwrap();
        assert_eq!(archive, before);
        if operation == 1 {
            writer.remove_project("a", &token()).unwrap();
            let other = Fixture::new();
            writer
                .add_project("a", &other.source(), vec!["code.rs".into()])
                .unwrap();
            let replacement = s.export_project("a", &token()).unwrap();
            assert_eq!(replacement["human_history"], json!([]));
            assert_eq!(replacement["evidence"], json!([]));
            assert_ne!(
                replacement["project"]["root_identity"],
                before["project"]["root_identity"]
            );
        } else if operation == 0 {
            writer
                .write_context("a", "memo", "note", "synthetic new history", true)
                .unwrap();
            assert_eq!(
                s.export_project("a", &token()).unwrap()["human_history"]
                    .as_array()
                    .unwrap()
                    .len(),
                2
            );
        } else {
            writer.set_sources("a", vec![]).unwrap();
            let revoked = s.export_project("a", &token()).unwrap();
            assert_eq!(revoked["project"]["sources"], json!([]));
            assert_eq!(revoked["evidence"], json!([]));
            assert_eq!(revoked["human_history"], before["human_history"]);
        }
    }
}

#[test]
fn export_path_line_order_is_independent_of_policy_order() {
    let f = Fixture::new();
    let mut s = f.registered();
    std::fs::write(
        f.source().join("aaa.txt"),
        "synthetic first\nsynthetic second\n",
    )
    .unwrap();
    s.set_sources("a", vec!["code.rs".into(), "aaa.txt".into()])
        .unwrap();
    index(&mut s);
    let archive = s.export_project("a", &token()).unwrap();
    let evidence = archive["evidence"].as_array().unwrap();
    assert_eq!(evidence[0]["path"], "aaa.txt");
    assert_eq!(evidence[0]["line"], 1);
    assert_eq!(evidence[1]["line"], 2);
    assert_eq!(evidence[2]["path"], "code.rs");
}

#[test]
fn export_cancellation_dependency_failure_and_external_wal_mode_fail_closed() {
    let f = Fixture::new();
    let mut s = f.registered();
    index(&mut s);
    let before = dump(&s);
    assert_eq!(
        s.export_project("a", &AtomicBool::new(true)),
        Err(Error::Canceled)
    );
    assert_eq!(dump(&s), before);
    s.db.execute_batch("PRAGMA journal_mode=WAL;").unwrap();
    assert!(s.export_project("a", &token()).is_err());
    assert_eq!(dump(&s), before);
    s.db.execute_batch("PRAGMA journal_mode=DELETE; DROP TABLE evidence;")
        .unwrap();
    assert!(s.export_project("a", &token()).is_err());
    assert!(f.source().join("code.rs").is_file());
}

#[test]
fn export_revalidates_full_manifest_even_for_sources_without_selected_anchors() {
    let f = Fixture::new();
    let mut s = f.registered();
    std::fs::write(f.source().join("empty.txt"), "\n").unwrap();
    s.set_sources("a", vec!["code.rs".into(), "empty.txt".into()])
        .unwrap();
    index(&mut s);
    let archive = s.export_project("a", &token()).unwrap();
    assert_eq!(archive["evidence"].as_array().unwrap().len(), 2);
    assert!(
        archive["evidence"]
            .as_array()
            .unwrap()
            .iter()
            .all(|a| a["path"] == "code.rs")
    );
    assert!(
        s.export_project_with_progress("a", &token(), |stage| {
            if stage == ExportStage::ReadyToPublish {
                std::fs::write(f.source().join("empty.txt"), "synthetic newly nonempty\n").unwrap();
            }
        })
        .is_err()
    );
    let stale = s.export_project("a", &token()).unwrap();
    assert_eq!(stale["currentness"], "stale-or-unindexed");
    assert_eq!(stale["evidence"], json!([]));
    index(&mut s);
    for (field, value) in [
        ("path", "foreign.txt"),
        ("hash", "bad"),
        ("identity", "bad"),
    ] {
        let original: String =
            s.db.query_row("SELECT manifest FROM projects WHERE id='a'", [], |r| {
                r.get(0)
            })
            .unwrap();
        let mut malformed: Value = serde_json::from_str(&original).unwrap();
        malformed[0][field] = json!(value);
        let encoded = serde_json::to_string(&malformed).unwrap();
        s.db.execute(
            "UPDATE projects SET manifest=?1,snapshot=?2 WHERE id='a'",
            params![encoded, sha256(encoded.as_bytes())],
        )
        .unwrap();
        assert!(s.export_project("a", &token()).is_err());
        s.db.execute(
            "UPDATE projects SET manifest=?1,snapshot=?2 WHERE id='a'",
            params![original, sha256(original.as_bytes())],
        )
        .unwrap();
    }
}
