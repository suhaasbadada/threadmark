//! Synthetic scope, worker failure, recovery and replaceable-port contract tests.

use threadmark_core::{
    CONTRACT_VERSION, Clock, Error, ExtractionReceipt, Extractor, HostTransport, Inference, Scope,
    ScopeGuard,
};
use threadmark_daemon::check_once;

struct FixedClock;
impl Clock for FixedClock {
    fn ticks(&self) -> u64 {
        42
    }
}

struct Worker {
    calls: usize,
    result: Result<ExtractionReceipt, Error>,
}
impl Extractor for Worker {
    fn extract(&mut self, _: &Scope) -> Result<ExtractionReceipt, Error> {
        self.calls += 1;
        self.result.clone()
    }
}

fn scope() -> Scope {
    Scope::new("project-a", "tree-a", "rev-a").unwrap()
}
fn worker() -> Worker {
    Worker {
        calls: 0,
        result: Ok(ExtractionReceipt {
            version: CONTRACT_VERSION,
            scope: scope(),
            complete: true,
            items: 2,
        }),
    }
}

#[test]
fn p0_a3_scope_matrix_rejects_conflicting_projects_branches_and_revisions() {
    let guard = ScopeGuard::new(scope());
    for row in include_str!("../../../tests/fixtures/scopes.tsv")
        .lines()
        .skip(1)
    {
        let parts: Vec<_> = row.split('\t').collect();
        assert_eq!(parts.len(), 4);
        let requested = Scope::new(parts[0], parts[1], parts[2]).unwrap();
        let mut worker = worker();
        let result = check_once(&guard, &requested, false, 2, &mut worker, &FixedClock);
        assert_eq!(result.is_ok(), parts[3] == "allow", "{row}");
        assert_eq!(worker.calls, usize::from(parts[3] == "allow"));
    }
}

#[test]
fn p0_a3_cancel_unavailable_and_restart_are_explicit() {
    let guard = ScopeGuard::new(scope());
    let mut worker = worker();
    assert_eq!(
        check_once(&guard, &scope(), true, 2, &mut worker, &FixedClock),
        Err(Error::Canceled)
    );
    assert_eq!(worker.calls, 0);
    worker.result = Err(Error::Unavailable);
    assert_eq!(
        check_once(&guard, &scope(), false, 2, &mut worker, &FixedClock),
        Err(Error::Unavailable)
    );
    // A fresh runner has no persisted snapshot or implicit retry; caller starts a new check.
    let mut restarted = self::worker();
    let receipt = check_once(&guard, &scope(), false, 2, &mut restarted, &FixedClock).unwrap();
    assert_eq!(receipt.items, 2);
    assert_eq!(receipt.completed_at, 42);
    assert_eq!(restarted.calls, 1);
}

#[test]
fn p0_a3_malformed_partial_oversized_and_foreign_replies_fail_closed() {
    let good = worker().result.unwrap();
    let mut bad_version = good.clone();
    bad_version.version += 1;
    let mut partial = good.clone();
    partial.complete = false;
    let mut oversized = good.clone();
    oversized.items = 3;
    let mut foreign = good;
    foreign.scope = Scope::new("project-b", "tree-a", "rev-a").unwrap();
    for reply in [bad_version, partial, oversized, foreign] {
        let mut worker = Worker {
            calls: 0,
            result: Ok(reply),
        };
        assert!(
            check_once(
                &ScopeGuard::new(scope()),
                &scope(),
                false,
                2,
                &mut worker,
                &FixedClock
            )
            .is_err()
        );
        assert_eq!(worker.calls, 1);
    }
}

#[test]
fn p0_a3_ids_are_bounded_not_paths_or_credentials() {
    for invalid in [
        "",
        "../private/path",
        "project\nsecret",
        "a b",
        &"x".repeat(129),
    ] {
        assert_eq!(
            Scope::new(invalid, "tree", "rev"),
            Err(Error::InvalidIdentity)
        );
    }
}

#[test]
fn p0_a3_optional_ports_can_be_substituted_without_providers() {
    struct Offline;
    impl Inference for Offline {
        fn ready(&self) -> bool {
            false
        }
    }
    impl HostTransport for Offline {
        fn draft_available(&self) -> bool {
            false
        }
    }
    assert!(!Offline.ready());
    assert!(!Offline.draft_available());
}
