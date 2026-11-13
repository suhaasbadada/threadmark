//! Bounded synchronous orchestration over core storage. No listener or background service.

use threadmark_core::{Clock, Error, Extractor, Scope, ScopeGuard};

/// Manual local knowledge orchestration. One operation at a time, no listener or worker.
pub mod knowledge;

/// Memory-only context preparation over revalidated core evidence; never delivery.
pub mod preparation;

/// Metadata-only successful check; not a persisted knowledge snapshot.
#[derive(Debug, PartialEq, Eq)]
pub struct CheckReceipt {
    /// Worker item count.
    pub items: usize,
    /// Completion tick supplied by the injected clock.
    pub completed_at: u64,
}

/// Execute at most one extraction call after scope and cancellation checks.
/// Timeout/process isolation for real workers is a Phase 1 feasibility gate.
pub fn check_once(
    guard: &ScopeGuard,
    requested: &Scope,
    canceled: bool,
    max_items: usize,
    worker: &mut impl Extractor,
    clock: &impl Clock,
) -> Result<CheckReceipt, Error> {
    guard.check(requested)?;
    if canceled {
        return Err(Error::Canceled);
    }
    let reply = worker.extract(requested)?;
    reply.validate(guard, max_items)?;
    Ok(CheckReceipt {
        items: reply.items,
        completed_at: clock.ticks(),
    })
}

/// Run a finite synthetic contract smoke check with no network, files, or user content.
pub fn smoke() -> Result<CheckReceipt, Error> {
    use threadmark_core::{CONTRACT_VERSION, ExtractionReceipt};
    struct Worker;
    impl Extractor for Worker {
        fn extract(&mut self, scope: &Scope) -> Result<ExtractionReceipt, Error> {
            Ok(ExtractionReceipt {
                version: CONTRACT_VERSION,
                scope: scope.clone(),
                complete: true,
                items: 1,
            })
        }
    }
    struct FixedClock;
    impl Clock for FixedClock {
        fn ticks(&self) -> u64 {
            1
        }
    }
    let scope = Scope::new("synthetic", "worktree-a", "revision-a")?;
    check_once(
        &ScopeGuard::new(scope.clone()),
        &scope,
        false,
        1,
        &mut Worker,
        &FixedClock,
    )
}
