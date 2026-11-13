//! Small, offline foundation contracts. IDs are not authentication credentials.
//!
//! ```
//! use threadmark_core::Scope;
//! let scope = Scope::new("project-a", "worktree-a", "revision-a").unwrap();
//! assert_eq!(scope, scope.clone());
//! ```

/// Contract version. Incompatible changes must increment this value.
pub const CONTRACT_VERSION: u32 = 1;

/// Durable, explicitly scoped local knowledge store.
pub mod knowledge;

/// Non-content-bearing failures. Never include source text or supplied IDs.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Error {
    /// Invalid or oversized identifier.
    InvalidIdentity,
    /// Project, worktree, or revision did not match the locally approved scope.
    ScopeMismatch,
    /// An extraction reply was unsupported, partial, or beyond the item budget.
    InvalidExtraction,
    /// Work was canceled before invoking a dependency.
    Canceled,
    /// A dependency could not complete the operation.
    Unavailable,
}

/// Explicit project/worktree/revision identity, not a folder name or remote URL.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Scope {
    project: String,
    worktree: String,
    revision: String,
}

impl Scope {
    /// Construct bounded opaque identifiers. Repository discovery is not implemented.
    pub fn new(project: &str, worktree: &str, revision: &str) -> Result<Self, Error> {
        for id in [project, worktree, revision] {
            if id.is_empty()
                || id.len() > 128
                || !id
                    .bytes()
                    .all(|b| b.is_ascii_alphanumeric() || b"-_.".contains(&b))
            {
                return Err(Error::InvalidIdentity);
            }
        }
        Ok(Self {
            project: project.into(),
            worktree: worktree.into(),
            revision: revision.into(),
        })
    }
}

/// Scope selected by a trusted local owner, not accepted from a remote request.
/// This comparison is one policy check, NOT an authenticated transport.
pub struct ScopeGuard(Scope);

impl ScopeGuard {
    /// Bind a guard to the owner's explicitly selected scope.
    pub fn new(approved: Scope) -> Self {
        Self(approved)
    }

    /// Reject any project, worktree, or revision mismatch.
    pub fn check(&self, requested: &Scope) -> Result<(), Error> {
        if self.0 == *requested {
            Ok(())
        } else {
            Err(Error::ScopeMismatch)
        }
    }
}

/// Metadata-only reply used to test worker boundaries, not a graph import schema.
#[derive(Debug, Clone)]
pub struct ExtractionReceipt {
    /// Worker contract version.
    pub version: u32,
    /// The exact source scope.
    pub scope: Scope,
    /// Whether the worker completed its requested synthetic input.
    pub complete: bool,
    /// Number of returned items; content import is deferred to Phase 2.
    pub items: usize,
}

impl ExtractionReceipt {
    /// Validate metadata before a caller may consider the reply successful.
    pub fn validate(&self, guard: &ScopeGuard, max_items: usize) -> Result<(), Error> {
        guard.check(&self.scope)?;
        if self.version != CONTRACT_VERSION || !self.complete || self.items > max_items {
            return Err(Error::InvalidExtraction);
        }
        Ok(())
    }
}

/// Replaceable extraction port; implementations must enforce their own resource bounds.
pub trait Extractor {
    /// Extract approved synthetic inputs. No real worker ships in Phase 0.
    fn extract(&mut self, scope: &Scope) -> Result<ExtractionReceipt, Error>;
}

/// Replaceable monotonic clock for deterministic receipts.
pub trait Clock {
    /// Monotonic elapsed ticks, not wall-clock identity or authorization.
    fn ticks(&self) -> u64;
}

/// Optional inference port. No provider or credential discovery is implemented.
pub trait Inference {
    /// Readiness only; does not send project data.
    fn ready(&self) -> bool;
}

/// Host capability port. Preparation never invokes host execution.
pub trait HostTransport {
    /// Whether a separately certified draft transport is available.
    fn draft_available(&self) -> bool;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn identity_limits_and_character_policy() {
        assert!(Scope::new(&"x".repeat(128), "tree_1", "rev.1").is_ok());
        assert_eq!(Scope::new("é", "tree", "rev"), Err(Error::InvalidIdentity));
        assert_eq!(
            Scope::new("project", "", "rev"),
            Err(Error::InvalidIdentity)
        );
        assert_eq!(
            Scope::new("project", "tree", "bad/rev"),
            Err(Error::InvalidIdentity)
        );
    }

    #[test]
    fn receipt_budget_is_inclusive_and_zero_is_explicit() {
        let scope = Scope::new("project", "tree", "rev").unwrap();
        let guard = ScopeGuard::new(scope.clone());
        let mut receipt = ExtractionReceipt {
            version: CONTRACT_VERSION,
            scope,
            complete: true,
            items: 0,
        };
        assert_eq!(receipt.validate(&guard, 0), Ok(()));
        receipt.items = 1;
        assert_eq!(receipt.validate(&guard, 0), Err(Error::InvalidExtraction));
        assert_eq!(receipt.validate(&guard, 1), Ok(()));
    }
}
