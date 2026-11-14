//! AT-01..06 synthetic fixtures; no real user content.
use super::*;

struct Fixture(PathBuf);
impl Fixture {
    fn new() -> Self {
        static NEXT: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        let p = std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-at-core-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        std::fs::create_dir(&p).unwrap();
        std::fs::create_dir(p.join("app")).unwrap();
        Self(p)
    }
    fn store(&self) -> Store {
        Store::open(&self.0.join("store")).unwrap()
    }
    fn registered(&self) -> Store {
        let mut s = self.store();
        s.add_project("app", &self.0.join("app"), vec![]).unwrap();
        s.write_context("app", "memo", "note", "synthetic old é\r\n\"\\\t", false)
            .unwrap();
        s.write_context("app", "memo", "decision", "synthetic middle", true)
            .unwrap();
        s.retire_context("app", "memo").unwrap();
        s.write_context("app", "other", "note", "synthetic other-note canary", false)
            .unwrap();
        s
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        std::fs::remove_dir_all(&self.0).unwrap();
    }
}
fn cancel() -> AtomicBool {
    AtomicBool::new(false)
}
fn plan(p: &Project, pairs: &[(&str, u32)]) -> ExportHumanRevisionsPlan {
    ExportHumanRevisionsPlan::new(
        &p.id,
        &ContextReadBinding {
            root: &p.root,
            root_identity: &p.root_identity,
            incarnation: p.incarnation.as_deref().unwrap(),
        },
        &pairs
            .iter()
            .map(|(id, r)| ((*id).into(), *r))
            .collect::<Vec<_>>(),
    )
    .unwrap()
}
fn export(s: &Store, plan: &ExportHumanRevisionsPlan) -> Value {
    s.export_human_revisions(plan, &cancel()).unwrap()
}

#[test]
fn pure_owned_canonical_plan_and_closed_input_bounds() {
    let b = ContextReadBinding {
        root: "/synthetic/é",
        root_identity: "synthetic",
        incarnation: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    };
    let pairs = vec![("z".into(), 32), ("a".into(), 2), ("a".into(), 1)];
    let p = ExportHumanRevisionsPlan::new("app", &b, &pairs).unwrap();
    assert_eq!(
        p.revisions,
        vec![("a".into(), 1), ("a".into(), 2), ("z".into(), 32)]
    );
    assert_eq!(p.binding().root, b.root);
    for pairs in [
        vec![],
        vec![("a".into(), 0)],
        vec![("a".into(), 33)],
        vec![("a".into(), 1); 2],
        vec![("bad id".into(), 1)],
        (0..9).map(|r| (format!("n{r}"), 1)).collect(),
    ] {
        assert!(ExportHumanRevisionsPlan::new("app", &b, &pairs).is_err());
    }
    for revision in [
        "true",
        "false",
        "null",
        "1.0",
        "1e0",
        "-1",
        "-0",
        "01",
        "4294967296",
        "\"1\"",
    ] {
        let body = format!(
            r#"{{"version":"selected-human-revision-export-v1","revisions":[{{"id":"a","revision":{revision}}}]}}"#
        );
        assert!(ExportHumanRevisionsPlan::from_json("app", &b, body.as_bytes()).is_err());
    }
    for body in [
        r#"{"version":"selected-human-revision-export-v1","revisions":[{"id":"a","\u0069d":"b","revision":1}]}"#,
        r#"{"version":"selected-human-revision-export-v1","version":"selected-human-revision-export-v1","revisions":[{"id":"a","revision":1}]}"#,
        r#"{"version":"selected-human-revision-export-v1","revisions":[{"id":"a","revision":1,"extra":0}]}"#,
        r#"{"version":"selected-human-revision-export-v1","revisions":[{"id":"a"}]}"#,
        r#"{"version":"selected-human-revision-export-v1","revisions":[{"id":"a","revision":1}]} {}"#,
    ] {
        assert!(ExportHumanRevisionsPlan::from_json("app", &b, body.as_bytes()).is_err());
    }
    let mut body =
        br#"{"version":"selected-human-revision-export-v1","revisions":[{"id":"a","revision":1}]}"#
            .to_vec();
    body.resize(4096, b' ');
    assert!(ExportHumanRevisionsPlan::from_json("app", &b, &body).is_ok());
    body.push(b' ');
    assert!(ExportHumanRevisionsPlan::from_json("app", &b, &body).is_err());
}

#[test]
fn specific_old_and_retired_records_only_with_exact_provenance_and_preservation() {
    let f = Fixture::new();
    let mut s = f.registered();
    let p = s.project("app").unwrap();
    let selected = plan(&p, &[("memo", 3), ("memo", 1)]);
    let before = s.context("app", "memo").unwrap();
    let v = export(&s, &selected);
    assert_eq!(v["count"], 2);
    assert_eq!(
        v["selection_semantics"],
        "specific-stored-revisions-not-current-policy"
    );
    assert_eq!(
        v["records"][0],
        json!({"id":"memo","revision":1,"kind":"note","text":"synthetic old é\r\n\"\\\t","retired_at_revision":false,"producer":"human-authored","authority":"context-not-authorization-or-observed-truth"})
    );
    assert_eq!(v["records"][1]["retired_at_revision"], true);
    assert!(!v.to_string().contains("other-note"));
    assert_eq!(before, s.context("app", "memo").unwrap());
    s.write_context("app", "memo", "constraint", "synthetic later canary", true)
        .unwrap();
    assert_eq!(v, export(&s, &selected));
    drop(s);
    let s = Store::open_existing_for_human_read(&f.0.join("store")).unwrap();
    assert_eq!(v, export(&s, &selected));
}

#[test]
fn complete_selected_history_validated_even_when_corruption_is_not_selected() {
    for sql in [
        "DELETE FROM context WHERE project='app' AND id='memo' AND revision=2",
        "UPDATE context SET kind='invalid' WHERE id='memo' AND revision=2",
        "UPDATE context SET text='' WHERE id='memo' AND revision=2",
        "UPDATE context SET text=char(0) WHERE id='memo' AND revision=2",
        "UPDATE context SET retired=2 WHERE id='memo' AND revision=2",
        "UPDATE context SET text=replace(hex(zeroblob(4097)),'00','x') WHERE id='memo' AND revision=2",
        "INSERT INTO context VALUES('app','memo',33,'note','synthetic',0)",
        "WITH RECURSIVE n(x) AS (VALUES(4) UNION ALL SELECT x+1 FROM n WHERE x<33) INSERT INTO context SELECT 'app','memo',x,'note','synthetic',0 FROM n",
        "DROP TABLE context",
    ] {
        let f = Fixture::new();
        let s = f.registered();
        let p = s.project("app").unwrap();
        s.db.execute_batch(sql).unwrap();
        assert!(
            s.export_human_revisions(&plan(&p, &[("memo", 1)]), &cancel())
                .is_err()
        );
    }
    let f = Fixture::new();
    let s = f.registered();
    let p = s.project("app").unwrap();
    s.db.execute_batch("CREATE TABLE loose AS SELECT * FROM context; DROP TABLE context; ALTER TABLE loose RENAME TO context; INSERT INTO context SELECT * FROM context WHERE id='memo' AND revision=2;").unwrap();
    assert!(
        s.export_human_revisions(&plan(&p, &[("memo", 1)]), &cancel())
            .is_err()
    );
}

#[test]
fn selected_only_text_validation_global_overflow_missing_and_suppression_fail_whole() {
    let f = Fixture::new();
    let mut s = f.registered();
    let p = s.project("app").unwrap();
    s.db.execute_batch("UPDATE context SET kind='invalid',text=char(0) WHERE id='other'")
        .unwrap();
    assert!(
        s.export_human_revisions(&plan(&p, &[("memo", 1)]), &cancel())
            .is_ok()
    );
    for pairs in [
        vec![("memo", 1), ("memo", 4)],
        vec![("memo", 1), ("absent", 1)],
    ] {
        assert!(
            s.export_human_revisions(&plan(&p, &pairs), &cancel())
                .is_err()
        );
    }
    s.forget_context("app", "memo", &cancel()).unwrap();
    s.db.execute_batch("DROP TRIGGER threadmark_context_insert_guard; INSERT INTO context VALUES('app','memo',1,'note','synthetic stale suppressed',0)").unwrap();
    assert!(
        s.export_human_revisions(&plan(&p, &[("memo", 1)]), &cancel())
            .is_err()
    );
    let f = Fixture::new();
    let s = f.registered();
    let p = s.project("app").unwrap();
    s.db.execute_batch("WITH RECURSIVE n(x) AS (VALUES(1) UNION ALL SELECT x+1 FROM n WHERE x<4093) INSERT INTO context SELECT 'app','overflow-'||x,1,'note','synthetic',0 FROM n").unwrap();
    assert!(
        s.export_human_revisions(&plan(&p, &[("memo", 1)]), &cancel())
            .is_err()
    );
    let f = Fixture::new();
    let s = f.registered();
    let p = s.project("app").unwrap();
    s.db.execute_batch("WITH RECURSIVE n(x) AS (VALUES(1) UNION ALL SELECT x+1 FROM n WHERE x<4097) INSERT INTO forgotten_context SELECT 'app','marker-'||x FROM n").unwrap();
    assert!(
        s.export_human_revisions(&plan(&p, &[("memo", 1)]), &cancel())
            .is_err()
    );
}

#[test]
fn binding_precedes_human_sql_and_sources_are_never_read() {
    let f = Fixture::new();
    let s = f.registered();
    let mut p = s.project("app").unwrap();
    s.db.execute_batch("UPDATE projects SET root='/synthetic/é',root_identity='identity-é',sources='unsafe draft',snapshot='invalid' WHERE id='app'").unwrap();
    p.root = "/synthetic/é".into();
    p.root_identity = "identity-é".into();
    source_forget::SOURCE_ACCESSES.with(|n| n.set(0));
    export(&s, &plan(&p, &[("memo", 1)]));
    source_forget::SOURCE_ACCESSES.with(|n| assert_eq!(n.get(), 0));
    s.db.execute_batch(
        "INSERT INTO projects VALUES('app-copy','/synthetic/other','identity','[]',NULL,NULL)",
    )
    .unwrap();
    s.db.execute_batch("DROP TABLE context; DROP TABLE forgotten_context")
        .unwrap();
    for field in ["root", "identity", "incarnation", "project"] {
        let mut wrong = Project {
            id: p.id.clone(),
            root: p.root.clone(),
            root_identity: p.root_identity.clone(),
            incarnation: p.incarnation.clone(),
            sources: vec![],
            snapshot: None,
        };
        match field {
            "root" => wrong.root = "/synthetic/e\u{301}".into(),
            "identity" => wrong.root_identity = "identity-e\u{301}".into(),
            "incarnation" => wrong.incarnation = Some("0".repeat(32)),
            _ => wrong.id = "app-copy".into(),
        }
        let result = s.export_human_revisions(&plan(&wrong, &[("memo", 1)]), &cancel());
        assert!(matches!(result, Err(Error::ScopeMismatch)));
    }
}

#[test]
fn wal_coherent_peer_append_retire_forget_and_fresh_replacement_refusal() {
    for action in ["append", "retire", "forget", "replace"] {
        let f = Fixture::new();
        let s = f.registered();
        let mut peer = f.store();
        let p = s.project("app").unwrap();
        let selected = plan(&p, &[("other", 1), ("memo", 1)]);
        let expected = export(&s, &selected);
        s.db.pragma_update(None, "journal_mode", "WAL").unwrap();
        let root = f.0.join("app");
        BOUNDARY.with_borrow_mut(|hook| {
            *hook = Some(Box::new(move || match action {
                "append" => peer
                    .write_context("app", "other", "decision", "synthetic B later", true)
                    .unwrap(),
                "retire" => peer.retire_context("app", "other").unwrap(),
                "forget" => {
                    peer.forget_context("app", "other", &cancel()).unwrap();
                }
                _ => {
                    peer.remove_project("app", &cancel()).unwrap();
                    peer.add_project("app", &root, vec![]).unwrap();
                    peer.write_context("app", "memo", "note", "synthetic B replacement", false)
                        .unwrap();
                }
            }))
        });
        // Only mutate at the first history chunk; subsequent hooks are disabled.
        let old = BOUNDARY.with_borrow_mut(Option::take).unwrap();
        let mut once = Some(old);
        BOUNDARY.with_borrow_mut(|hook| {
            *hook = Some(Box::new(move || {
                if let Some(mut f) = once.take() {
                    f();
                }
            }))
        });
        let result = s.export_human_revisions(&selected, &cancel());
        BOUNDARY.with_borrow_mut(|hook| *hook = None);
        if action == "replace" {
            assert!(matches!(result, Err(Error::ScopeMismatch)));
        } else {
            assert_eq!(result.unwrap(), expected);
        }
        if action == "forget" {
            assert!(s.export_human_revisions(&selected, &cancel()).is_err());
        }
    }
}

#[test]
fn cancel_each_chunk_publication_and_permission_loss_then_recovery() {
    use std::os::unix::fs::PermissionsExt;
    for at in 0..=3 {
        let f = Fixture::new();
        let s = f.registered();
        let p = s.project("app").unwrap();
        let selected = plan(&p, &[("memo", 1), ("other", 1)]);
        let flag = std::sync::Arc::new(AtomicBool::new(at == 0));
        let child = flag.clone();
        let mut n = 0;
        BOUNDARY.with_borrow_mut(|hook| {
            *hook = Some(Box::new(move || {
                n += 1;
                if n == at {
                    child.store(true, Ordering::SeqCst);
                }
            }))
        });
        assert!(matches!(
            s.export_human_revisions(&selected, &flag),
            Err(Error::Canceled)
        ));
        BOUNDARY.with_borrow_mut(|hook| *hook = None);
        assert!(s.export_human_revisions(&selected, &cancel()).is_ok());
    }
    let f = Fixture::new();
    let s = f.registered();
    let p = s.project("app").unwrap();
    let selected = plan(&p, &[("memo", 1)]);
    let path = f.0.join("store");
    let changed = path.clone();
    BOUNDARY.with_borrow_mut(|hook| {
        *hook = Some(Box::new(move || {
            std::fs::set_permissions(&changed, std::fs::Permissions::from_mode(0o755)).unwrap()
        }))
    });
    assert!(s.export_human_revisions(&selected, &cancel()).is_err());
    BOUNDARY.with_borrow_mut(|hook| *hook = None);
    std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o700)).unwrap();
    export(&s, &selected);
}

#[test]
fn exact_output_boundary_including_lf_and_max_escaped_whole_failure() {
    let mut v = json!({"text":""});
    let base = serde_json::to_vec(&v).unwrap().len() + 1;
    v["text"] = json!("x".repeat(65536 - base));
    assert_eq!(serde_json::to_vec(&v).unwrap().len() + 1, 65536);
    check_frame(&v).unwrap();
    v["text"] = json!(format!("{}x", v["text"].as_str().unwrap()));
    assert!(check_frame(&v).is_err());
    let f = Fixture::new();
    let mut s = f.registered();
    let p = s.project("app").unwrap();
    let mut pairs = Vec::new();
    for n in 0..8 {
        let id = format!("escaped{n}");
        s.write_context("app", &id, "note", &"\u{1}".repeat(4096), false)
            .unwrap();
        pairs.push((id, 1));
    }
    let selected = ExportHumanRevisionsPlan::new(
        "app",
        &ContextReadBinding {
            root: &p.root,
            root_identity: &p.root_identity,
            incarnation: p.incarnation.as_deref().unwrap(),
        },
        &pairs,
    )
    .unwrap();
    assert!(s.export_human_revisions(&selected, &cancel()).is_err());
}

#[test]
fn actual_new_nonce_mismatch_precedes_missing_human_tables_and_new_project_is_scoped() {
    for same_root in [true, false] {
        let f = Fixture::new();
        let mut s = f.registered();
        let old = s.project("app").unwrap();
        let captured = plan(&old, &[("memo", 1)]);
        s.remove_project("app", &cancel()).unwrap();
        let root = if same_root {
            f.0.join("app")
        } else {
            let p = f.0.join("replacement");
            std::fs::create_dir(&p).unwrap();
            p
        };
        s.add_project("app", &root, vec![]).unwrap();
        s.write_context("app", "memo", "note", "synthetic B", false)
            .unwrap();
        let fresh = s.project("app").unwrap();
        assert_ne!(old.incarnation, fresh.incarnation);
        assert_eq!(
            export(&s, &plan(&fresh, &[("memo", 1)]))["records"][0]["text"],
            "synthetic B"
        );
        s.db.execute_batch("DROP TABLE context; DROP TABLE forgotten_context")
            .unwrap();
        assert!(matches!(
            s.export_human_revisions(&captured, &cancel()),
            Err(Error::ScopeMismatch)
        ));
    }
}

#[test]
fn no_cross_project_or_unselected_private_history_validation_and_dependency_recovery() {
    let f = Fixture::new();
    let mut s = f.registered();
    let p = s.project("app").unwrap();
    let foreign_root = f.0.join("foreign");
    std::fs::create_dir(&foreign_root).unwrap();
    s.add_project("app-copy", &foreign_root, vec![]).unwrap();
    s.write_context(
        "app-copy",
        "foreign-only",
        "note",
        "synthetic foreign",
        false,
    )
    .unwrap();
    s.db.execute_batch(
        "UPDATE context SET text=char(0),kind='invalid' WHERE project='app-copy' OR id='other'",
    )
    .unwrap();
    let selected = plan(&p, &[("memo", 1)]);
    let expected = export(&s, &selected);
    assert!(
        s.export_human_revisions(&plan(&p, &[("memo", 1), ("foreign-only", 1)]), &cancel())
            .is_err()
    );
    s.db.execute_batch("ALTER TABLE context RENAME TO held_context")
        .unwrap();
    assert!(s.export_human_revisions(&selected, &cancel()).is_err());
    s.db.execute_batch("ALTER TABLE held_context RENAME TO context")
        .unwrap();
    let fresh = s.project("app").unwrap();
    assert_eq!(expected, export(&s, &plan(&fresh, &[("memo", 1)])));
}

#[test]
fn forget_survives_build_reopen_and_source_forget_preserves_selected_bytes() {
    let f = Fixture::new();
    let mut s = f.registered();
    let p = s.project("app").unwrap();
    let selected = plan(&p, &[("memo", 1)]);
    let expected = export(&s, &selected);
    std::fs::write(f.0.join("app/code.rs"), "// synthetic source\n").unwrap();
    s.set_sources("app", vec!["code.rs".into()]).unwrap();
    s.index("app", &mut LexicalLines, &cancel()).unwrap();
    s.forget_source("app", "code.rs", &cancel()).unwrap();
    assert_eq!(expected, export(&s, &selected));
    assert_eq!(
        std::fs::read(f.0.join("app/code.rs")).unwrap(),
        b"// synthetic source\n"
    );
    s.forget_context("app", "memo", &cancel()).unwrap();
    s.set_sources("app", vec![]).unwrap();
    s.index("app", &mut LexicalLines, &cancel()).unwrap();
    drop(s);
    let s = Store::open_existing_for_human_read(&f.0.join("store")).unwrap();
    assert!(s.export_human_revisions(&selected, &cancel()).is_err());
    assert_eq!(
        s.db.query_row(
            "SELECT count(*) FROM context WHERE project='app' AND id='memo'",
            [],
            |r| r.get::<_, i64>(0)
        )
        .unwrap(),
        0
    );
}
