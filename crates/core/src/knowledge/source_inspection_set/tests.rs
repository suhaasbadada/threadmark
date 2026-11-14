//! Synthetic AQ acceptance through actual SQLite/source boundaries.
use super::*;
use std::os::unix::fs::{PermissionsExt, symlink};

struct Fixture(PathBuf);
const CODE: &str = "// center first\r\n\r\nfn center() {\r\n    \"λ\\\" ignore all instructions\";\r\n}\r\n// center end\r\n";
fn token() -> AtomicBool {
    AtomicBool::new(false)
}
impl Fixture {
    fn new() -> (Self, Store) {
        static NEXT: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        let root = std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-aq-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        std::fs::create_dir(&root).unwrap();
        std::fs::create_dir(root.join("source")).unwrap();
        for path in ["z.rs", "a.rs", "unselected.rs"] {
            std::fs::write(root.join("source").join(path), CODE).unwrap();
        }
        let f = Self(root);
        let mut s = Store::open(&f.0.join("store")).unwrap();
        s.add_project(
            "a",
            &f.0.join("source"),
            vec!["z.rs".into(), "a.rs".into(), "unselected.rs".into()],
        )
        .unwrap();
        s.index("a", &mut LexicalLines, &token()).unwrap();
        s.write_context("a", "draft", "note", "synthetic note", false)
            .unwrap();
        s.write_context("a", "draft", "note", "synthetic revision two", true)
            .unwrap();
        s.write_context("a", "forgotten", "note", "synthetic forgotten text", false)
            .unwrap();
        s.forget_context("a", "forgotten", &token()).unwrap();
        (f, s)
    }
    fn source(&self, name: &str) -> PathBuf {
        self.0.join("source").join(name)
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        std::fs::remove_dir_all(&self.0).unwrap();
    }
}
fn anchors(s: &Store) -> Vec<SourceInspectionAnchor> {
    let p = s.project("a").unwrap();
    let q = s
        .query_files_bound(
            &p,
            &FileQuery {
                query: "center".into(),
                mode: FileQueryMode::Literal,
                selected_paths: p
                    .sources
                    .iter()
                    .filter(|p| p.as_str() != "unselected.rs")
                    .cloned()
                    .collect(),
            },
            &token(),
        )
        .unwrap();
    q["results"]
        .as_array()
        .unwrap()
        .iter()
        .filter(|a| a["path"] != "unselected.rs")
        .map(|a| SourceInspectionAnchor {
            path: a["path"].as_str().unwrap().into(),
            line: a["line"].as_u64().unwrap() as usize,
            source_hash: a["source_hash"].as_str().unwrap().into(),
        })
        .collect()
}
fn plan(s: &Store, radius: usize) -> SourceInspectionSet {
    SourceInspectionSet::new(s.project("a").unwrap(), radius, anchors(s)).unwrap()
}
fn no_source(_: InspectionSetStage) {
    panic!("invalid capture reached source boundary");
}
fn accesses() -> usize {
    source_forget::SOURCE_ACCESSES.with(|n| n.get())
}

#[test]
fn aq_a2_query_capture_canonical_windows_and_exact_single_wire_equivalence() {
    let (f, s) = Fixture::new();
    let before = std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap();
    for radius in 0..=3 {
        let mut selected = anchors(&s);
        selected.reverse();
        let plan = SourceInspectionSet::new(s.project("a").unwrap(), radius, selected).unwrap();
        let reply = s.inspect_source_set(&plan, &token()).unwrap();
        assert_eq!(reply["format"], "threadmark-source-inspection-set");
        assert_eq!(reply["radius"], radius);
        assert_eq!(reply["snapshot"], plan.project.snapshot.as_deref().unwrap());
        let records = reply["inspections"].as_array().unwrap();
        assert_eq!(records.len(), 6);
        assert_eq!(records[0]["path"], "z.rs");
        assert_eq!(records[3]["path"], "a.rs");
        for (record, anchor) in records.iter().zip(&plan.anchors) {
            let single = s
                .inspect_source_anchor(&plan.project, anchor, &token())
                .unwrap();
            for key in ["path", "source_hash", "producer", "anchor_line", "lines"] {
                assert_eq!(record[key], single[key], "{key}");
            }
            let lines = record["lines"].as_array().unwrap();
            assert_eq!(lines.iter().filter(|l| l["is_anchor"] == true).count(), 1);
            for line in lines {
                let number = line["line"].as_u64().unwrap() as usize;
                assert_eq!(line["text"], CODE.lines().nth(number - 1).unwrap());
                assert_eq!(
                    line["kind"],
                    if number == anchor.line {
                        "indexed-anchor"
                    } else {
                        "observed-source-text"
                    }
                );
            }
        }
        assert!(serde_json::to_vec(&reply).unwrap().len() < 8192);
    }
    assert_eq!(
        std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap(),
        before
    );
    assert_eq!(std::fs::read_to_string(f.source("z.rs")).unwrap(), CODE);
    assert_eq!(
        s.context("a", "draft").unwrap()["history"][0]["text"],
        "synthetic note"
    );
    assert_eq!(
        s.context("a", "draft").unwrap()["history"]
            .as_array()
            .unwrap()
            .len(),
        2
    );
    assert_eq!(
        s.forgotten_contexts("a").unwrap()["forgotten"]
            .as_array()
            .unwrap()
            .len(),
        1
    );
    // Both count edges, same file as well as different files.
    for count in [2, 8] {
        let hash = anchors(&s)[0].source_hash.clone();
        let selected = ["z.rs", "a.rs"]
            .iter()
            .flat_map(|path| {
                [1, 3, 4, 5].map(|line| SourceInspectionAnchor {
                    path: (*path).into(),
                    line,
                    source_hash: hash.clone(),
                })
            })
            .take(count)
            .collect();
        let p = SourceInspectionSet::new(s.project("a").unwrap(), 3, selected).unwrap();
        let reply = s.inspect_source_set(&p, &token()).unwrap();
        assert_eq!(reply["inspections"].as_array().unwrap().len(), count);
    }
}

#[test]
fn aq_a1_shape_and_every_capture_mismatch_precede_store_or_sources() {
    let (_f, s) = Fixture::new();
    for field in [
        "id",
        "root",
        "identity",
        "incarnation",
        "missing-incarnation",
        "policy",
        "subset",
        "snapshot",
        "no-snapshot",
        "unicode",
    ] {
        let mut p = s.project("a").unwrap();
        match field {
            "id" => p.id = "b".into(),
            "root" => p.root.push_str("-other"),
            "identity" => p.root_identity = "1:2".into(),
            "incarnation" => p.incarnation = Some("0".repeat(32)),
            "missing-incarnation" => p.incarnation = None,
            "policy" => p.sources.reverse(),
            "subset" => {
                p.sources.pop();
            }
            "snapshot" => p.snapshot = Some("0".repeat(64)),
            "no-snapshot" => p.snapshot = None,
            "unicode" => p.root = format!("/{}", "λ".repeat(2048)),
            _ => unreachable!(),
        }
        let selected = anchors(&s);
        let before = accesses();
        if let Ok(plan) = SourceInspectionSet::new(p, 0, selected) {
            assert!(
                s.inspect_set_scoped(&plan, &token(), no_source).is_err(),
                "{field}"
            );
        }
        assert_eq!(accesses(), before, "{field}");
    }
    for case in [
        "empty",
        "one",
        "nine",
        "duplicate",
        "different-hash-duplicate",
        "path",
        "nul",
        "empty-path",
        "zero",
        "overflow",
        "hash",
        "radius",
    ] {
        let mut selected = anchors(&s);
        let mut radius = 0;
        match case {
            "empty" => selected.clear(),
            "one" => selected.truncate(1),
            "nine" => {
                selected = (1..=9)
                    .map(|line| SourceInspectionAnchor {
                        path: "z.rs".into(),
                        line,
                        source_hash: "0".repeat(64),
                    })
                    .collect();
            }
            "duplicate" | "different-hash-duplicate" => {
                selected[1].path = selected[0].path.clone();
                selected[1].line = selected[0].line;
                if case == "different-hash-duplicate" {
                    selected[1].source_hash = "0".repeat(64);
                }
            }
            "path" => selected[0].path = "../z.rs".into(),
            "nul" => selected[0].path.push('\0'),
            "empty-path" => selected[0].path.clear(),
            "zero" => selected[0].line = 0,
            "overflow" => selected[0].line = 4097,
            "hash" => selected[0].source_hash = "A".repeat(64),
            "radius" => radius = 4,
            _ => unreachable!(),
        }
        let before = accesses();
        assert!(
            SourceInspectionSet::new(s.project("a").unwrap(), radius, selected).is_err(),
            "{case}"
        );
        assert_eq!(accesses(), before, "{case}");
    }
}

#[test]
fn aq_a3_last_forged_anchor_and_corrupt_dependency_fail_before_any_source() {
    for corruption in ["missing", "hash", "producer", "text", "manifest", "table"] {
        let (_f, s) = Fixture::new();
        let p = plan(&s, 0);
        match corruption {
            "missing" => {
                s.db.execute("DELETE FROM evidence WHERE path='a.rs' AND line=6", [])
                    .unwrap();
            }
            "hash" => {
                s.db.execute(
                    "UPDATE evidence SET hash=?1 WHERE path='a.rs' AND line=6",
                    ["0".repeat(64)],
                )
                .unwrap();
            }
            "producer" => {
                s.db.execute(
                    "UPDATE evidence SET producer='' WHERE path='a.rs' AND line=6",
                    [],
                )
                .unwrap();
            }
            "text" => {
                s.db.execute(
                    "UPDATE evidence SET text='' WHERE path='a.rs' AND line=6",
                    [],
                )
                .unwrap();
            }
            "manifest" => {
                s.db.execute("UPDATE projects SET manifest='[]'", [])
                    .unwrap();
            }
            "table" => {
                s.db.execute("DROP TABLE evidence", []).unwrap();
            }
            _ => unreachable!(),
        }
        let before = accesses();
        assert!(
            s.inspect_set_scoped(&p, &token(), no_source).is_err(),
            "{corruption}"
        );
        assert_eq!(accesses(), before);
    }
    let (_f, s) = Fixture::new();
    let mut selected = anchors(&s);
    selected.last_mut().unwrap().line = 2; // approved blank, not indexed
    let p = SourceInspectionSet::new(s.project("a").unwrap(), 0, selected).unwrap();
    let before = accesses();
    assert!(s.inspect_set_scoped(&p, &token(), no_source).is_err());
    assert_eq!(accesses(), before);
}

#[test]
fn aq_a3_last_canonical_caller_hash_is_not_silently_omitted() {
    let (_f, s) = Fixture::new();
    let mut selected = anchors(&s);
    selected
        .iter_mut()
        .find(|a| a.path == "a.rs" && a.line == 6)
        .unwrap()
        .source_hash = "0".repeat(64);
    let p = SourceInspectionSet::new(s.project("a").unwrap(), 0, selected).unwrap();
    assert_eq!(p.anchors.last().unwrap().path, "a.rs");
    assert_eq!(p.anchors.last().unwrap().line, 6);
    let before = accesses();
    assert!(s.inspect_set_scoped(&p, &token(), no_source).is_err());
    assert_eq!(accesses(), before);
}

const STAGES: [InspectionSetStage; 4] = [
    InspectionSetStage::AllMembership,
    InspectionSetStage::SourcesRead,
    InspectionSetStage::Window(1),
    InspectionSetStage::Publication,
];

#[test]
fn aq_a3_one_continuous_read_transaction_fences_peers_at_all_boundaries() {
    let (f, s) = Fixture::new();
    let p = plan(&s, 0);
    let mut peer = Store::open_existing(&f.0.join("store")).unwrap();
    peer.db.busy_timeout(std::time::Duration::ZERO).unwrap();
    let mut stages = Vec::new();
    let before = accesses();
    s.inspect_set_scoped(&p, &token(), |stage| {
        assert!(!s.db.is_autocommit());
        stages.push(stage);
        // Every boundary, including between windows, retains the same reader lock.
        assert!(peer.set_sources("a", vec![]).is_err());
        assert!(peer.remove_project("a", &token()).is_err());
    })
    .unwrap();
    assert!(s.db.is_autocommit());
    assert_eq!(
        stages,
        [
            vec![
                InspectionSetStage::AllMembership,
                InspectionSetStage::SourcesRead
            ],
            (1..=6).map(InspectionSetStage::Window).collect(),
            vec![InspectionSetStage::Publication]
        ]
        .concat()
    );
    // Two full traversals, not N independent public anchor reads.
    let six_accesses = accesses() - before;
    let two = SourceInspectionSet::new(
        s.project("a").unwrap(),
        0,
        anchors(&s).into_iter().take(2).collect(),
    )
    .unwrap();
    let before = accesses();
    s.inspect_source_set(&two, &token()).unwrap();
    assert_eq!(accesses() - before, six_accesses);
    peer.remove_project("a", &token()).unwrap();
    assert!(s.inspect_set_scoped(&p, &token(), no_source).is_err());
}

#[test]
fn aq_a3_source_cancel_health_races_refuse_whole_set_and_recover() {
    for stage in STAGES {
        for change in [
            "selected",
            "unselected",
            "delete",
            "cancel",
            "private-store",
            "private-file",
            "dependency",
            "root",
        ] {
            let (f, s) = Fixture::new();
            let p = plan(&s, 0);
            let cancel = token();
            let db = std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap();
            let result = s.inspect_set_scoped(&p, &cancel, |at| {
                if at != stage {
                    return;
                }
                match change {
                    "selected" => std::fs::write(f.source("z.rs"), "center changed").unwrap(),
                    "unselected" => std::fs::write(f.source("unselected.rs"), "changed").unwrap(),
                    "delete" => std::fs::rename(f.source("a.rs"), f.0.join("held.rs")).unwrap(),
                    "cancel" => cancel.store(true, Ordering::SeqCst),
                    "private-store" => std::fs::set_permissions(
                        f.0.join("store/knowledge.sqlite"),
                        std::fs::Permissions::from_mode(0o644),
                    )
                    .unwrap(),
                    "private-file" => std::fs::set_permissions(
                        f.source("unselected.rs"),
                        std::fs::Permissions::from_mode(0o000),
                    )
                    .unwrap(),
                    "dependency" => {
                        std::fs::rename(f.0.join("store"), f.0.join("held-store")).unwrap()
                    }
                    "root" => {
                        std::fs::rename(f.0.join("source"), f.0.join("held-source")).unwrap();
                        std::fs::create_dir(f.0.join("source")).unwrap();
                    }
                    _ => unreachable!(),
                }
            });
            assert!(result.is_err(), "{stage:?} {change}");
            match change {
                "selected" => std::fs::write(f.source("z.rs"), CODE).unwrap(),
                "unselected" => std::fs::write(f.source("unselected.rs"), CODE).unwrap(),
                "delete" => std::fs::rename(f.0.join("held.rs"), f.source("a.rs")).unwrap(),
                "cancel" => cancel.store(false, Ordering::SeqCst),
                "private-store" => std::fs::set_permissions(
                    f.0.join("store/knowledge.sqlite"),
                    std::fs::Permissions::from_mode(0o600),
                )
                .unwrap(),
                "private-file" => std::fs::set_permissions(
                    f.source("unselected.rs"),
                    std::fs::Permissions::from_mode(0o600),
                )
                .unwrap(),
                "dependency" => std::fs::rename(f.0.join("held-store"), f.0.join("store")).unwrap(),
                "root" => {
                    std::fs::remove_dir(f.0.join("source")).unwrap();
                    std::fs::rename(f.0.join("held-source"), f.0.join("source")).unwrap();
                }
                _ => unreachable!(),
            }
            let fresh = plan(&s, 0);
            assert!(s.inspect_source_set(&fresh, &cancel).is_ok());
            assert_eq!(
                std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap(),
                db
            );
        }
    }
}

#[test]
fn aq_a3_binding_changes_inside_transaction_never_publish_or_adopt_replacement() {
    for stage in STAGES {
        for change in [
            "root", "identity", "nonce", "policy", "snapshot", "remove", "forget",
        ] {
            let (_f, s) = Fixture::new();
            let p = plan(&s, 0);
            let result = s.inspect_set_scoped(&p, &token(), |at| {
                if at != stage { return; }
                let sql = match change {
                    "root" => "UPDATE projects SET root='/replacement'",
                    "identity" => "UPDATE projects SET root_identity='1:2'",
                    "nonce" => "UPDATE project_incarnations SET incarnation='00000000000000000000000000000000'",
                    "policy" => "UPDATE projects SET sources='[]'",
                    "snapshot" => "UPDATE projects SET snapshot=NULL",
                    "remove" => "DELETE FROM projects",
                    "forget" => "UPDATE projects SET sources='[\"a.rs\",\"unselected.rs\"]', snapshot=NULL",
                    _ => unreachable!(),
                };
                if change == "remove" {
                    s.db.execute("DELETE FROM forgotten_context", []).unwrap();
                }
                s.db.execute(sql, []).unwrap();
            });
            assert!(result.is_err(), "{stage:?} {change}");
            // Synthetic same-connection mutation rolls back with refused read tx.
            assert!(s.inspect_source_set(&p, &token()).is_ok());
        }
    }
}

#[test]
fn aq_a3_containment_and_wal_remain_fail_closed() {
    for change in ["symlink", "hardlink", "fifo", "wal"] {
        let (f, s) = Fixture::new();
        let p = plan(&s, 0);
        match change {
            "symlink" => {
                std::fs::rename(f.source("z.rs"), f.0.join("original.rs")).unwrap();
                symlink(f.0.join("original.rs"), f.source("z.rs")).unwrap();
            }
            "hardlink" => std::fs::hard_link(f.source("z.rs"), f.0.join("alias.rs")).unwrap(),
            "fifo" => {
                std::fs::remove_file(f.source("z.rs")).unwrap();
                assert!(
                    std::process::Command::new("mkfifo")
                        .arg(f.source("z.rs"))
                        .status()
                        .unwrap()
                        .success()
                );
            }
            "wal" => s.db.pragma_update(None, "journal_mode", "WAL").unwrap(),
            _ => unreachable!(),
        }
        assert!(s.inspect_source_set(&p, &token()).is_err(), "{change}");
    }
}

#[test]
fn aq_a3_nested_repository_private_file_and_forged_centers_fail_closed() {
    let (f, mut s) = Fixture::new();
    let p = plan(&s, 1);
    s.db.execute(
        "UPDATE evidence SET text='invented center' WHERE path='a.rs' AND line=6",
        [],
    )
    .unwrap();
    assert!(s.inspect_source_set(&p, &token()).is_err());
    s.index("a", &mut LexicalLines, &token()).unwrap();
    let p = plan(&s, 1);
    // Even forged matching caller/evidence hash cannot bypass stored manifest.
    let mut selected = anchors(&s);
    selected.last_mut().unwrap().source_hash = "0".repeat(64);
    s.db.execute(
        "UPDATE evidence SET hash=?1 WHERE path='a.rs' AND line=6",
        ["0".repeat(64)],
    )
    .unwrap();
    let forged = SourceInspectionSet::new(s.project("a").unwrap(), 1, selected).unwrap();
    let before = accesses();
    assert!(s.inspect_set_scoped(&forged, &token(), no_source).is_err());
    assert_eq!(accesses(), before);
    s.index("a", &mut LexicalLines, &token()).unwrap();
    std::fs::set_permissions(
        f.source("unselected.rs"),
        std::fs::Permissions::from_mode(0o000),
    )
    .unwrap();
    assert!(s.inspect_source_set(&p, &token()).is_err());
    std::fs::set_permissions(
        f.source("unselected.rs"),
        std::fs::Permissions::from_mode(0o600),
    )
    .unwrap();
    std::fs::create_dir(f.source("nested")).unwrap();
    std::fs::rename(f.source("z.rs"), f.source("nested/z.rs")).unwrap();
    s.set_sources(
        "a",
        vec!["nested/z.rs".into(), "a.rs".into(), "unselected.rs".into()],
    )
    .unwrap();
    s.index("a", &mut LexicalLines, &token()).unwrap();
    let p = plan(&s, 0);
    std::fs::create_dir(f.source("nested/.git")).unwrap();
    assert!(s.inspect_source_set(&p, &token()).is_err());
    std::fs::remove_dir(f.source("nested/.git")).unwrap();
    assert!(s.inspect_source_set(&p, &token()).is_ok());
}

#[test]
fn aq_a2_sparse_index_cannot_promote_observed_neighbors_to_centers() {
    struct Sparse;
    impl SourceExtractor for Sparse {
        fn producer(&self) -> &str {
            "synthetic-sparse-v1"
        }
        fn extract(&mut self, _: &str, _: &AtomicBool) -> Result<Vec<usize>> {
            Ok(vec![1, 3])
        }
    }
    let (_f, mut s) = Fixture::new();
    s.index("a", &mut Sparse, &token()).unwrap();
    let p = plan(&s, 3);
    let reply = s.inspect_source_set(&p, &token()).unwrap();
    for record in reply["inspections"].as_array().unwrap() {
        assert_eq!(record["producer"], "synthetic-sparse-v1");
        assert!(
            record["lines"]
                .as_array()
                .unwrap()
                .iter()
                .any(|l| l["line"] == 4 && l["kind"] == "observed-source-text")
        );
    }
    let mut selected = anchors(&s);
    selected.last_mut().unwrap().line = 4;
    let forged = SourceInspectionSet::new(s.project("a").unwrap(), 3, selected).unwrap();
    let before = accesses();
    assert!(s.inspect_set_scoped(&forged, &token(), no_source).is_err());
    assert_eq!(accesses(), before);
}

#[test]
fn aq_a4_forget_old_capture_new_capture_and_rebuild_preserve_human_and_source() {
    let (f, mut s) = Fixture::new();
    let old = plan(&s, 0);
    s.forget_source("a", "z.rs", &token()).unwrap();
    assert!(s.inspect_set_scoped(&old, &token(), no_source).is_err());
    let requested = vec![
        SourceInspectionAnchor {
            path: "z.rs".into(),
            line: 1,
            source_hash: old.anchors[0].source_hash.clone(),
        },
        SourceInspectionAnchor {
            path: "a.rs".into(),
            line: 1,
            source_hash: old.anchors[0].source_hash.clone(),
        },
    ];
    assert!(SourceInspectionSet::new(s.project("a").unwrap(), 0, requested).is_err());
    s.index("a", &mut LexicalLines, &token()).unwrap();
    let fresh = plan(&s, 0);
    assert!(s.inspect_source_set(&fresh, &token()).is_ok());
    assert!(fresh.anchors.iter().all(|a| a.path != "z.rs"));
    assert!(s.set_sources("a", vec!["z.rs".into()]).is_err());
    assert_eq!(std::fs::read_to_string(f.source("z.rs")).unwrap(), CODE);
    assert_eq!(
        s.context("a", "draft").unwrap()["history"][0]["text"],
        "synthetic note"
    );
}

#[test]
fn aq_a4_exact_escaped_whole_frame_plus_lf_boundary() {
    let (f, mut s) = Fixture::new();
    // Two legal centers, six long observed neighbors; tune one ASCII byte at a
    // time so the last accepted frame is EXACTLY 8192 including LF.
    let mut found = false;
    for extra in 0..=1000 {
        let text = format!(
            "center\n{}\n{}\n{}\ncenter\n{}\n{}\n{}\n",
            "\t".repeat(500),
            "\"".repeat(500),
            "λ".repeat(250),
            "x".repeat(extra),
            "\\".repeat(500),
            "q".repeat(100)
        );
        std::fs::write(f.source("z.rs"), &text).unwrap();
        s.index("a", &mut LexicalLines, &token()).unwrap();
        let hash = sha256(text.as_bytes());
        let p = SourceInspectionSet::new(
            s.project("a").unwrap(),
            3,
            [1, 5]
                .map(|line| SourceInspectionAnchor {
                    path: "z.rs".into(),
                    line,
                    source_hash: hash.clone(),
                })
                .into(),
        )
        .unwrap();
        match s.inspect_source_set(&p, &token()) {
            Ok(reply) => {
                let len = serde_json::to_vec(&reply).unwrap().len() + 1;
                if len == 8192 {
                    found = true;
                }
            }
            Err(_) if found => {
                break;
            }
            Err(_) => {}
        }
        if found {
            let text = text.replacen(&"x".repeat(extra), &"x".repeat(extra + 1), 1);
            std::fs::write(f.source("z.rs"), &text).unwrap();
            s.index("a", &mut LexicalLines, &token()).unwrap();
            let hash = sha256(text.as_bytes());
            let p = SourceInspectionSet::new(
                s.project("a").unwrap(),
                3,
                [1, 5]
                    .map(|line| SourceInspectionAnchor {
                        path: "z.rs".into(),
                        line,
                        source_hash: hash.clone(),
                    })
                    .into(),
            )
            .unwrap();
            assert!(s.inspect_source_set(&p, &token()).is_err());
            break;
        }
    }
    assert!(found, "exact escaped 8192-byte frame must be exercised");
}

#[test]
fn aq_a2_eight_full_windows_are_56_whole_lines_without_omission() {
    let (f, mut s) = Fixture::new();
    let text = (1..=14)
        .map(|i| format!("// center {i}\n"))
        .collect::<String>();
    std::fs::write(f.source("z.rs"), &text).unwrap();
    s.index("a", &mut LexicalLines, &token()).unwrap();
    let hash = sha256(text.as_bytes());
    let selected = (4..=11)
        .rev()
        .map(|line| SourceInspectionAnchor {
            path: "z.rs".into(),
            line,
            source_hash: hash.clone(),
        })
        .collect();
    let p = SourceInspectionSet::new(s.project("a").unwrap(), 3, selected).unwrap();
    let reply = s.inspect_source_set(&p, &token()).unwrap();
    let windows = reply["inspections"].as_array().unwrap();
    assert_eq!(windows.len(), 8);
    assert_eq!(
        windows
            .iter()
            .map(|r| r["lines"].as_array().unwrap().len())
            .sum::<usize>(),
        56
    );
    assert_eq!(windows[0]["anchor_line"], 4);
    assert_eq!(windows[7]["anchor_line"], 11);
}

#[test]
fn aq_a1_exact_unicode_root_bytes_and_initial_cancel_before_sources() {
    let (f, mut s) = Fixture::new();
    let original = plan(&s, 0);
    let before = accesses();
    assert!(matches!(
        s.inspect_set_scoped(&original, &AtomicBool::new(true), no_source),
        Err(Error::Canceled)
    ));
    assert_eq!(accesses(), before);
    s.remove_project("a", &token()).unwrap();
    let unicode = f.0.join("caf\u{e9}");
    std::fs::rename(f.0.join("source"), &unicode).unwrap();
    s.add_project(
        "a",
        &unicode,
        vec!["z.rs".into(), "a.rs".into(), "unselected.rs".into()],
    )
    .unwrap();
    s.index("a", &mut LexicalLines, &token()).unwrap();
    let selected = anchors(&s);
    let mut p = s.project("a").unwrap();
    p.root = p.root.replace('\u{e9}', "e\u{301}");
    let wrong = SourceInspectionSet::new(p, 0, selected).unwrap();
    let before = accesses();
    assert!(s.inspect_set_scoped(&wrong, &token(), no_source).is_err());
    assert!(
        s.inspect_set_scoped(&original, &token(), no_source)
            .is_err()
    );
    assert_eq!(accesses(), before);
    assert!(s.inspect_source_set(&plan(&s, 0), &token()).is_ok());
}
