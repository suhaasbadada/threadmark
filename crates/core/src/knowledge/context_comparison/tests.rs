//! AA-01..05: synthetic actual SQLite reads, no source/provider/host access.
use super::*;

struct Fixture(PathBuf);
impl Fixture {
    fn new() -> Self {
        static NEXT: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        let path = std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-aa-core-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        std::fs::create_dir(&path).unwrap();
        std::fs::create_dir(path.join("source")).unwrap();
        std::fs::create_dir(path.join("source-copy")).unwrap();
        std::fs::write(path.join("source/code.rs"), "// synthetic source\n").unwrap();
        Self(path)
    }
    fn store(&self) -> Store {
        Store::open_existing(&self.0.join("store")).unwrap()
    }
    fn registered(&self) -> Store {
        let mut s = Store::open(&self.0.join("store")).unwrap();
        for project in ["app", "app-copy"] {
            let root = if project == "app" {
                "source"
            } else {
                "source-copy"
            };
            s.add_project(project, &self.0.join(root), vec!["code.rs".into()])
                .unwrap();
            s.write_context(project, "memo", "note", "first\r\nunchanged\n", false)
                .unwrap();
        }
        s.write_context("app", "memo", "decision", "second\r\nunchanged\n", true)
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
fn bound(p: &Project) -> ContextReadBinding<'_> {
    ContextReadBinding {
        root: &p.root,
        root_identity: &p.root_identity,
        incarnation: p.incarnation.as_deref().unwrap(),
    }
}
fn compare(s: &Store, p: &Project, from: u32, to: u32) -> Result<Value> {
    s.context_comparison_bound("app", "memo", from, to, &bound(p), &cancel())
}
fn reconstruct(v: &Value, which: &str) -> String {
    let d = &v["delta"];
    format!(
        "{}{}{}",
        d["prefix"].as_str().unwrap(),
        d[which].as_str().unwrap(),
        d["suffix"].as_str().unwrap()
    )
}

#[test]
fn logical_line_segments_keep_terminators_and_do_not_invent_empty_lines() {
    for (old, new, prefix, from, to, suffix) in [
        ("a\nx\na\n", "a\ny\na\n", "a\n", "x\n", "y\n", "a\n"),
        ("a\n", "a", "", "a\n", "a", ""),
        ("a\n", "a\n\n", "a\n", "", "\n", ""),
        ("a\r\n", "a\n", "", "a\r\n", "a\n", ""),
        ("a\na\n", "a\n", "a\n", "a\n", "", ""),
        ("é", "e\u{301}", "", "é", "e\u{301}", ""),
    ] {
        assert_eq!(
            delta(old, new),
            json!({
                "algorithm":"common-prefix-suffix-logical-lines-not-minimal",
                "prefix":prefix,"from":from,"to":to,"suffix":suffix,
            })
        );
    }
}

#[test]
fn exact_logical_lines_metadata_and_determinism() {
    let f = Fixture::new();
    let mut s = f.registered();
    let p = s.project("app").unwrap();
    let mut texts = vec![
        "first\r\nunchanged\n".to_owned(),
        "second\r\nunchanged\n".to_owned(),
    ];
    for text in [
        "second\r\nunchanged\n",
        "é\n",
        "e\u{301}\n",
        "a\r\nb\r\n",
        "a\r\nb",
        "a\nb\n",
        "\n",
        "\"\\\t\u{1}\r\n",
        "👩‍💻\n終",
    ] {
        s.write_context("app", "memo", "constraint", text, true)
            .unwrap();
        texts.push(text.into());
    }
    s.retire_context("app", "memo").unwrap();
    texts.push(texts.last().unwrap().clone());
    s.write_context("app", "memo", "pitfall", texts.last().unwrap(), true)
        .unwrap();
    texts.push(texts.last().unwrap().clone());
    for from in 1..=texts.len() as u32 {
        for to in from..=texts.len() as u32 {
            let v = compare(&s, &p, from, to).unwrap();
            assert_eq!(v, compare(&s, &p, from, to).unwrap());
            assert_eq!(reconstruct(&v, "from"), texts[from as usize - 1]);
            assert_eq!(reconstruct(&v, "to"), texts[to as usize - 1]);
            assert_eq!(
                v["text_changed"],
                texts[from as usize - 1] != texts[to as usize - 1]
            );
            assert_eq!(v["version"], "human-context-comparison-v1");
            assert_eq!(v["producer"], "human-authored");
            assert_eq!(
                v["authority"],
                "context-not-authorization-or-observed-truth"
            );
            assert_eq!(
                v["delta"]["algorithm"],
                "common-prefix-suffix-logical-lines-not-minimal"
            );
            assert!(v["from"].get("text").is_none());
            if texts[from as usize - 1] == texts[to as usize - 1] {
                assert_eq!(v["delta"]["from"], "");
                assert_eq!(v["delta"]["to"], "");
            }
        }
    }
    let kind_only = compare(&s, &p, 2, 3).unwrap();
    assert_eq!(kind_only["kind_changed"], true);
    assert_eq!(kind_only["text_changed"], false);
    let retired = texts.len() as u32 - 1;
    let retirement = compare(&s, &p, retired - 1, retired).unwrap();
    assert_eq!(retirement["retirement_changed"], true);
    assert_eq!(retirement["kind_changed"], false);
    let reactivated = compare(&s, &p, retired, retired + 1).unwrap();
    assert_eq!(reactivated["to"]["retired"], false);
    assert_eq!(reactivated["text_changed"], false);
}

#[test]
fn exact_json_escape_budget_and_whole_response_boundary() {
    let f = Fixture::new();
    let mut s = f.registered();
    let p = s.project("app").unwrap();
    let a = "\u{1}".repeat(4096);
    let b = "\u{2}".repeat(4096);
    s.write_context("app", "memo", "note", &a, true).unwrap();
    s.write_context("app", "memo", "note", &b, true).unwrap();
    let v = compare(&s, &p, 3, 4).unwrap();
    assert_eq!(reconstruct(&v, "from"), a);
    assert_eq!(reconstruct(&v, "to"), b);
    assert_eq!(
        serde_json::to_vec(&v["delta"]["from"]).unwrap().len(),
        4096 * 6 + 2
    );
    // Reserve one byte for the CLI stdout newline.
    assert!(serde_json::to_vec(&v).unwrap().len() < MAX_JSON_BYTES);
    // Valid histories cannot reach 64 KiB even at maximum escaping. Exercise
    // the actual whole-value guard at its exact boundary with synthetic values.
    let fits = Value::String("x".repeat(MAX_JSON_BYTES - 3));
    assert_eq!(serde_json::to_vec(&fits).unwrap().len() + 1, MAX_JSON_BYTES);
    assert!(bounded_reply(fits).is_ok());
    assert!(bounded_reply(Value::String("x".repeat(MAX_JSON_BYTES - 2))).is_err());
    assert!(bounded_reply(Value::String("\u{1}".repeat(MAX_JSON_BYTES / 6 + 1))).is_err());
    assert!(
        s.write_context("app", "memo", "note", &"é".repeat(2049), true)
            .is_err()
    );
}

#[test]
fn full_history_validation_missing_reversed_cancel_and_dependency_are_read_only() {
    for corrupt in [
        "UPDATE context SET text='' WHERE project='app' AND revision=2",
        "UPDATE context SET kind='invalid' WHERE project='app' AND revision=2",
        "UPDATE context SET retired=2 WHERE project='app' AND revision=2",
        "UPDATE context SET text=char(0) WHERE project='app' AND revision=2",
        "UPDATE context SET revision=4 WHERE project='app' AND revision=2",
        "UPDATE context SET text=replace(hex(zeroblob(2049)),'0','x') WHERE project='app' AND revision=2",
        "DROP TABLE context",
        "DROP TABLE forgotten_context",
    ] {
        let f = Fixture::new();
        let s = f.registered();
        let p = s.project("app").unwrap();
        s.db.execute_batch(corrupt).unwrap();
        let before = std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap();
        assert!(compare(&s, &p, 1, 1).is_err()); // corrupt unselected revision also fails
        assert_eq!(
            before,
            std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap()
        );
    }
    let f = Fixture::new();
    let s = f.registered();
    let p = s.project("app").unwrap();
    let before = std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap();
    for (from, to) in [
        (0, 1),
        (1, 0),
        (2, 1),
        (1, 3),
        (1, 33),
        (u32::MAX, u32::MAX),
    ] {
        assert!(compare(&s, &p, from, to).is_err());
    }
    assert!(
        s.context_comparison_bound("app", "missing", 1, 1, &bound(&p), &cancel())
            .is_err()
    );
    assert!(matches!(
        s.context_comparison_bound("app", "memo", 1, 2, &bound(&p), &AtomicBool::new(true)),
        Err(Error::Canceled)
    ));
    assert_eq!(
        before,
        std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap()
    );
    // An over-budget 33rd revision is invalid even if both selected rows exist.
    for revision in 3..=32 {
        s.db.execute(
            "INSERT INTO context VALUES('app','memo',?1,'note','synthetic',0)",
            [revision],
        )
        .unwrap();
    }
    assert!(compare(&s, &p, 1, 32).is_ok());
    assert!(compare(&s, &p, 32, 32).is_ok());
    s.db.execute(
        "INSERT INTO context VALUES('app','memo',33,'note','synthetic',0)",
        [],
    )
    .unwrap();
    assert!(compare(&s, &p, 1, 2).is_err());
}

#[test]
fn exact_binding_precedes_first_human_sql_including_replacement_and_legacy() {
    let f = Fixture::new();
    let s = f.registered();
    s.db.execute(
        "UPDATE projects SET root='/synthetic/é',root_identity='identity-é' WHERE id='app'",
        [],
    )
    .unwrap();
    let p = s.project("app").unwrap();
    assert!(compare(&s, &p, 1, 2).is_ok());
    s.db.execute_batch("DROP TABLE context; DROP TABLE forgotten_context;")
        .unwrap();
    for (root, root_identity, incarnation) in [
        (
            "/synthetic/e\u{301}",
            p.root_identity.as_str(),
            p.incarnation.as_deref().unwrap(),
        ),
        (
            p.root.as_str(),
            "identity-e\u{301}",
            p.incarnation.as_deref().unwrap(),
        ),
        (
            p.root.as_str(),
            p.root_identity.as_str(),
            "00000000000000000000000000000000",
        ),
    ] {
        let b = ContextReadBinding {
            root,
            root_identity,
            incarnation,
        };
        assert!(matches!(
            s.context_comparison_bound("app", "memo", 1, 2, &b, &cancel()),
            Err(Error::ScopeMismatch)
        ));
    }
    // Actual same-ID/same-root replacement is a different registration.
    let f = Fixture::new();
    let mut s = f.registered();
    let p = s.project("app").unwrap();
    s.remove_project("app", &cancel()).unwrap();
    s.add_project("app", &f.0.join("source"), vec![]).unwrap();
    s.write_context("app", "memo", "note", "B-private-synthetic", false)
        .unwrap();
    assert!(matches!(compare(&s, &p, 1, 1), Err(Error::ScopeMismatch)));
}

#[test]
fn wal_peer_append_forget_replacement_and_cancel_use_one_snapshot() {
    for action in ["append", "forget", "replace", "replace-root", "cancel"] {
        let f = Fixture::new();
        let s = f.registered();
        let mut peer = f.store();
        s.db.pragma_update(None, "journal_mode", "WAL").unwrap();
        let p = s.project("app").unwrap();
        let peer_root = f.0.join("source");
        let cancelled = std::sync::Arc::new(AtomicBool::new(false));
        let hook_cancelled = cancelled.clone();
        AFTER_HISTORY.with_borrow_mut(|slot| {
            *slot = Some(Box::new(move || match action {
                "append" => peer
                    .write_context("app", "memo", "pitfall", "B-private-synthetic", true)
                    .unwrap(),
                "forget" => {
                    peer.forget_context("app", "memo", &cancel()).unwrap();
                }
                "replace" | "replace-root" => {
                    peer.remove_project("app", &cancel()).unwrap();
                    let root = if action == "replace-root" {
                        let root = peer_root.join("new");
                        std::fs::create_dir(&root).unwrap();
                        root
                    } else {
                        peer_root
                    };
                    peer.add_project("app", &root, vec![]).unwrap();
                    peer.write_context("app", "memo", "note", "B-private-synthetic", false)
                        .unwrap();
                }
                _ => hook_cancelled.store(true, Ordering::SeqCst),
            }))
        });
        let result = s.context_comparison_bound("app", "memo", 1, 2, &bound(&p), &cancelled);
        match action {
            "replace" | "replace-root" => assert!(matches!(result, Err(Error::ScopeMismatch))),
            "cancel" => assert!(matches!(result, Err(Error::Canceled))),
            _ => {
                let v = result.unwrap();
                assert_eq!(reconstruct(&v, "from"), "first\r\nunchanged\n");
                assert_eq!(reconstruct(&v, "to"), "second\r\nunchanged\n");
                assert!(!v.to_string().contains("B-private"));
                if action == "forget" {
                    assert!(compare(&s, &p, 1, 2).is_err());
                }
            }
        }
    }
}

#[test]
fn reopen_rebuild_source_forget_and_missing_root_preserve_human_comparison() {
    let f = Fixture::new();
    let mut s = f.registered();
    let p = s.project("app").unwrap();
    let before = compare(&s, &p, 1, 2).unwrap();
    s.index("app", &mut LexicalLines, &cancel()).unwrap();
    assert_eq!(before, compare(&s, &p, 1, 2).unwrap());
    s.forget_source("app", "code.rs", &cancel()).unwrap();
    drop(s);
    let mut s = f.store();
    assert_eq!(before, compare(&s, &p, 1, 2).unwrap());
    s.set_sources("app", vec!["missing.rs".into()]).unwrap();
    s.db.execute(
        "UPDATE projects SET snapshot=?1 WHERE id='app'",
        ["a".repeat(64)],
    )
    .unwrap();
    s.db.execute("UPDATE context SET text='' WHERE project='app-copy'", [])
        .unwrap();
    std::fs::rename(f.0.join("source"), f.0.join("missing-root")).unwrap();
    source_forget::SOURCE_ACCESSES.with(|n| n.set(0));
    assert_eq!(before, compare(&s, &p, 1, 2).unwrap());
    source_forget::SOURCE_ACCESSES.with(|n| assert_eq!(n.get(), 0));
    s.forget_context("app", "memo", &cancel()).unwrap();
    assert!(compare(&s, &p, 1, 2).is_err());
    assert!(
        s.write_context("app", "memo", "note", "no resurrection", false)
            .is_err()
    );
    assert_eq!(
        std::fs::read_to_string(f.0.join("missing-root/code.rs")).unwrap(),
        "// synthetic source\n"
    );
}
