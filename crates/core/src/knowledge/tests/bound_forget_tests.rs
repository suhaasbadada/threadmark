//! TM-01–04/07/10, partial P2-A3/A5, P3-A4: exact native approvals.
use super::*;

fn binding(project: &Project, revision: u32) -> ForgetBinding<'_> {
    ForgetBinding {
        root: &project.root,
        root_identity: &project.root_identity,
        incarnation: project.incarnation.as_deref().unwrap(),
        revision,
    }
}

#[test]
fn bound_forget_all_revisions_preserves_sources_and_other_project_across_reopen_index() {
    let (f, mut s) = removal_fixture();
    for n in 3..32 {
        s.write_context("a", "note", "note", &format!("synthetic {n}"), true)
            .unwrap();
    }
    let other_root = Fixture::new();
    s.add_project("b", &other_root.source(), vec!["code.rs".into()])
        .unwrap();
    s.index("b", &mut LexicalLines, &token()).unwrap();
    s.write_context("b", "note", "note", "synthetic other project", false)
        .unwrap();
    let p = s.project("a").unwrap();
    let other = project_rows(&s, "b");
    let other_export = s.export_project("b", &token()).unwrap();
    let source = std::fs::read(f.source().join("code.rs")).unwrap();
    let evidence = s.query("a", "synthetic", &token()).unwrap();
    let receipt = s
        .forget_context_bound("a", "note", &binding(&p, 32), &token(), |_| {})
        .unwrap();
    assert_eq!(receipt["removed_revisions"], 32);
    assert_eq!(project_rows(&s, "b"), other);
    assert_eq!(s.export_project("b", &token()).unwrap(), other_export);
    assert_eq!(s.query("a", "synthetic", &token()).unwrap(), evidence);
    drop(s);
    let mut s = f.store();
    index(&mut s);
    assert!(s.context("a", "note").is_err());
    assert_eq!(
        s.forgotten_contexts("a").unwrap()["forgotten"],
        json!([{"id":"note"}])
    );
    assert!(
        s.write_context("a", "note", "note", "cannot resurrect", false)
            .is_err()
    );
    assert_eq!(project_rows(&s, "b"), other);
    assert_eq!(s.export_project("b", &token()).unwrap(), other_export);
    assert_eq!(std::fs::read(f.source().join("code.rs")).unwrap(), source);
}

#[test]
fn revision_edit_absent_marked_and_identical_reregistration_reject_stale_approval() {
    let f = Fixture::new();
    let mut s = f.registered();
    s.write_context("a", "note", "note", "synthetic one", false)
        .unwrap();
    let p = s.project("a").unwrap();
    s.write_context("a", "note", "note", "synthetic two", true)
        .unwrap();
    let before = project_rows(&s, "a");
    for (id, revision) in [("note", 1), ("absent", 1)] {
        assert!(
            s.forget_context_bound("a", id, &binding(&p, revision), &token(), |_| {})
                .is_err()
        );
        assert_eq!(project_rows(&s, "a"), before);
    }
    s.forget_context_bound("a", "note", &binding(&p, 2), &token(), |_| {})
        .unwrap();
    assert!(
        s.forget_context_bound("a", "note", &binding(&p, 2), &token(), |_| {})
            .is_err()
    );
    assert_eq!(
        s.forget_context("a", "note", &token()).unwrap()["removed_revisions"],
        0
    );
    s.remove_project("a", &token()).unwrap();
    s.add_project("a", &f.source(), vec!["code.rs".into()])
        .unwrap();
    s.write_context("a", "note", "note", "synthetic replacement rev one", false)
        .unwrap();
    let replacement = project_rows(&s, "a");
    assert!(
        s.forget_context_bound("a", "note", &binding(&p, 1), &token(), |_| {})
            .is_err()
    );
    assert_eq!(project_rows(&s, "a"), replacement);
    assert_eq!(s.forgotten_contexts("a").unwrap()["forgotten"], json!([]));
}

#[test]
fn actual_bound_path_rolls_back_at_every_cancel_and_sql_failure_stage() {
    for stage in [
        ForgetStage::MarkerStaged,
        ForgetStage::ContentRemoved,
        ForgetStage::ReadyToCommit,
    ] {
        let f = Fixture::new();
        let mut s = f.registered();
        s.write_context("a", "note", "note", "synthetic preserved", false)
            .unwrap();
        let p = s.project("a").unwrap();
        let before = project_rows(&s, "a");
        let cancel = token();
        assert_eq!(
            s.forget_context_bound("a", "note", &binding(&p, 1), &cancel, |at| {
                if at == stage {
                    cancel.store(true, Ordering::SeqCst);
                }
            }),
            Err(Error::Canceled)
        );
        assert_eq!(project_rows(&s, "a"), before);
        assert_eq!(s.forgotten_contexts("a").unwrap()["forgotten"], json!([]));
    }
    let f = Fixture::new();
    let mut s = f.registered();
    s.write_context("a", "note", "note", "synthetic preserved", false)
        .unwrap();
    let p = s.project("a").unwrap();
    let before = project_rows(&s, "a");
    // Inject a SQL failure after marker staging through the actual DELETE.
    s.db.execute_batch("CREATE TEMP TRIGGER fail_bound_delete BEFORE DELETE ON context BEGIN SELECT RAISE(ABORT,'synthetic'); END;").unwrap();
    assert!(
        s.forget_context_bound("a", "note", &binding(&p, 1), &token(), |_| {})
            .is_err()
    );
    assert_eq!(project_rows(&s, "a"), before);
    assert_eq!(s.forgotten_contexts("a").unwrap()["forgotten"], json!([]));
}
