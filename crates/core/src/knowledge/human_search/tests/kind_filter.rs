use super::*;

fn kinds(values: &[&str]) -> HumanSearchKinds {
    HumanSearchKinds::new(&values.iter().map(|s| (*s).into()).collect::<Vec<_>>()).unwrap()
}
fn binding(p: &Project) -> ContextReadBinding<'_> {
    ContextReadBinding {
        root: &p.root,
        root_identity: &p.root_identity,
        incarnation: p.incarnation.as_deref().unwrap(),
    }
}
fn search(s: &Store, values: &[&str]) -> Value {
    s.search_context_kinds_bound(
        "app",
        "needle",
        &kinds(values),
        &binding(&s.project("app").unwrap()),
        &token(),
    )
    .unwrap()
}

#[test]
fn ae01_filter_before_score_limit_counts_and_encoded_budget() {
    let f = Fixture::new();
    let mut s = f.registered();
    for n in 0..12 {
        s.write_context(
            "app",
            &format!("a{n:02}"),
            "pitfall",
            "needle ".repeat(20).as_str(),
            false,
        )
        .unwrap();
    }
    s.write_context(
        "app",
        "b-huge",
        "note",
        &format!("needle{}", "\u{1}".repeat(4000)),
        false,
    )
    .unwrap();
    for n in (0..10).rev() {
        s.write_context("app", &format!("c{n:02}"), "note", "needle", false)
            .unwrap();
    }
    let old = s
        .search_context_bound(
            "app",
            "needle",
            &binding(&s.project("app").unwrap()),
            &token(),
        )
        .unwrap();
    assert!(
        old["results"]
            .as_array()
            .unwrap()
            .iter()
            .all(|e| e["kind"] == "pitfall")
    );
    let selected = search(&s, &["note"]);
    assert_eq!(selected["matched_entries"], 11);
    assert_eq!(selected["omitted_entries"], 3);
    assert_eq!(selected["truncated"], true);
    assert_eq!(selected["results"][0]["id"], "c00");
    assert_eq!(selected["results"][7]["id"], "c07");
    assert!(serde_json::to_vec(&selected).unwrap().len() < 8192);
    let mut all = search(
        &s,
        &["pitfall", "note", "decision", "correction", "constraint"],
    );
    assert_eq!(
        all["selected_kinds"],
        json!(["constraint", "correction", "decision", "note", "pitfall"])
    );
    all.as_object_mut().unwrap().remove("version");
    all.as_object_mut().unwrap().remove("selected_kinds");
    assert_eq!(
        serde_json::to_vec(&all).unwrap(),
        serde_json::to_vec(&old).unwrap()
    );
    assert_eq!(selected, search(&s, &["note"]));
    s.db.execute("DELETE FROM context WHERE project='app'", [])
        .unwrap();
    for id in ["a", "b", "c"] {
        s.write_context(
            "app",
            id,
            "decision",
            &format!("needle{}", "界".repeat(1300)),
            false,
        )
        .unwrap();
    }
    let result = search(&s, &["decision"]);
    assert_eq!(result["matched_entries"], 3);
    assert_eq!(result["omitted_entries"], 2);
    assert_eq!(result["results"].as_array().unwrap().len(), 1);
    assert!(serde_json::to_vec(&result).unwrap().len() < 8192);
}

#[test]
fn ae02_latest_kind_only_retire_reactivate_forget_and_invalid_unselected() {
    let f = Fixture::new();
    let mut s = f.registered();
    s.write_context("app", "memo", "note", "needle", false)
        .unwrap();
    assert_eq!(search(&s, &["note"])["matched_entries"], 1);
    s.write_context("app", "memo", "decision", "needle", true)
        .unwrap();
    assert_eq!(search(&s, &["note"])["matched_entries"], 0);
    assert_eq!(search(&s, &["decision"])["results"][0]["revision"], 2);
    s.retire_context("app", "memo").unwrap();
    assert_eq!(search(&s, &["decision"])["matched_entries"], 0);
    s.write_context("app", "memo", "constraint", "needle", true)
        .unwrap();
    assert_eq!(search(&s, &["constraint"])["matched_entries"], 1);
    s.forget_context("app", "memo", &token()).unwrap();
    assert_eq!(search(&s, &["constraint"])["matched_entries"], 0);
    assert!(
        s.write_context("app", "memo", "note", "needle", false)
            .is_err()
    );
    s.write_context("app", "bad", "pitfall", "unselected", false)
        .unwrap();
    s.db.execute(
        "UPDATE context SET text=?1 WHERE id='bad'",
        ["x".repeat(4097)],
    )
    .unwrap();
    let p = s.project("app").unwrap();
    assert!(
        s.search_context_kinds_bound("app", "needle", &kinds(&["note"]), &binding(&p), &token())
            .is_err()
    );
    s.db.execute("DELETE FROM context", []).unwrap();
    s.db.execute_batch("WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM n WHERE i<4097) INSERT INTO context SELECT 'app','n'||i,1,'pitfall','unselected',0 FROM n;").unwrap();
    assert!(
        s.search_context_kinds_bound("app", "needle", &kinds(&["note"]), &binding(&p), &token())
            .is_err()
    );
}

#[test]
fn ae03_exact_binding_before_human_sql_and_source_independence() {
    let f = Fixture::new();
    let mut s = f.registered();
    s.write_context("app", "memo", "note", "needle", false)
        .unwrap();
    let p = s.project("app").unwrap();
    s.set_sources("app", vec![]).unwrap();
    std::fs::rename(f.0.join("app"), f.0.join("missing")).unwrap();
    source_forget::SOURCE_ACCESSES.with(|n| n.set(0));
    assert_eq!(search(&s, &["note"])["matched_entries"], 1);
    source_forget::SOURCE_ACCESSES.with(|n| assert_eq!(n.get(), 0));
    assert!(matches!(
        s.search_context_kinds_bound(
            "app",
            "needle",
            &kinds(&["note"]),
            &binding(&p),
            &AtomicBool::new(true)
        ),
        Err(Error::Canceled)
    ));
    s.db.execute(
        "UPDATE projects SET root='/synthetic/é',root_identity='identity-é' WHERE id='app'",
        [],
    )
    .unwrap();
    let p = s.project("app").unwrap();
    s.db.execute_batch("DROP TABLE context; DROP TABLE forgotten_context;")
        .unwrap();
    for field in 0..3 {
        let mut b = binding(&p);
        match field {
            0 => b.root = "/synthetic/e\u{301}",
            1 => b.root_identity = "identity-e\u{301}",
            _ => b.incarnation = "ffffffffffffffffffffffffffffffff",
        }
        assert!(matches!(
            s.search_context_kinds_bound("app", "needle", &kinds(&["note"]), &b, &token()),
            Err(Error::ScopeMismatch)
        ));
    }
}

#[test]
fn ae03_wal_snapshot_and_fresh_publication_reject_replacement() {
    for replacement in [false, true] {
        let f = Fixture::new();
        let mut s = f.registered();
        let mut peer = f.store();
        s.db.execute_batch("PRAGMA journal_mode=WAL;").unwrap();
        s.write_context("app", "memo", "note", "needle A", false)
            .unwrap();
        let p = s.project("app").unwrap();
        let selected = kinds(&["note"]);
        let mut once = false;
        let reply = s.read_human_bound("app", &binding(&p), &token(), |tx, registration| {
            s.search_context_selected_in(
                tx,
                registration,
                "needle",
                Some(&selected),
                &token(),
                || {
                    if once {
                        return;
                    }
                    once = true;
                    if replacement {
                        peer.remove_project("app", &token()).unwrap();
                        peer.add_project("app", &f.0.join("app"), vec![]).unwrap();
                        peer.write_context("app", "b", "note", "needle B private", false)
                            .unwrap();
                    } else {
                        peer.write_context("app", "memo", "decision", "needle B private", true)
                            .unwrap();
                    }
                },
            )
        });
        if replacement {
            assert!(matches!(reply, Err(Error::ScopeMismatch)));
        } else {
            let reply = reply.unwrap();
            assert_eq!(reply["results"][0]["text"], "needle A");
            assert!(!reply.to_string().contains("B private"));
        }
    }
}

#[test]
fn ae04_typed_kind_shape_is_nonempty_unique_known_and_bounded() {
    for values in [
        vec![],
        vec!["note", "note"],
        vec!["unknown"],
        vec![""],
        vec!["note"; 6],
    ] {
        assert!(
            HumanSearchKinds::new(&values.into_iter().map(String::from).collect::<Vec<_>>())
                .is_err()
        );
    }
    assert_eq!(kinds(&["note", "decision"]).kinds(), &["decision", "note"]);
}

#[test]
fn ae01_exact_whole_frame_boundary_filtered_score_and_unicode() {
    let f = Fixture::new();
    let mut s = f.registered();
    s.write_context("app", "z", "note", "needle needle", false)
        .unwrap();
    s.write_context("app", "a", "note", "needle", false)
        .unwrap();
    assert_eq!(search(&s, &["note"])["results"][0]["id"], "z");
    s.write_context(
        "app",
        "a",
        "note",
        &format!("needle{}", "x".repeat(3400)),
        true,
    )
    .unwrap();
    s.write_context(
        "app",
        "z",
        "note",
        &format!("needle{}", "x".repeat(3400)),
        true,
    )
    .unwrap();
    let before = search(&s, &["note"]);
    let extra = 8192 - (serde_json::to_vec(&before).unwrap().len() + 1);
    assert!(extra < 690);
    s.write_context(
        "app",
        "z",
        "note",
        &format!("needle{}", "x".repeat(3400 + extra)),
        true,
    )
    .unwrap();
    let exact = search(&s, &["note"]);
    assert_eq!(serde_json::to_vec(&exact).unwrap().len() + 1, 8192);
    assert_eq!(exact["results"].as_array().unwrap().len(), 2);
    s.write_context(
        "app",
        "z",
        "note",
        &format!("needle{}", "x".repeat(3401 + extra)),
        true,
    )
    .unwrap();
    let over = search(&s, &["note"]);
    assert_eq!(over["results"].as_array().unwrap().len(), 1);
    assert_eq!(over["omitted_entries"], 1);
    s.write_context("app", "a", "note", "ÉCLAIR", true).unwrap();
    let p = s.project("app").unwrap();
    assert_eq!(
        s.search_context_kinds_bound("app", "éclair", &kinds(&["note"]), &binding(&p), &token())
            .unwrap()["matched_entries"],
        1
    );
    assert_eq!(
        s.search_context_kinds_bound(
            "app",
            "e\u{301}clair",
            &kinds(&["note"]),
            &binding(&p),
            &token()
        )
        .unwrap()["matched_entries"],
        0
    );
}
