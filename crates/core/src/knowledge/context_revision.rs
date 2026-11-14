//! Opt-in compare-and-append for human history; not semantic conflict resolution.
use super::*;

// Deterministic fault injection at the real append/commit boundary, test-only.
#[cfg(test)]
std::thread_local! {
    pub(super) static BEFORE_COMMIT: std::cell::RefCell<Option<Box<dyn FnOnce()>>> =
        std::cell::RefCell::new(None);
}

#[cfg(test)]
pub(super) fn before_commit() {
    if let Some(hook) = BEFORE_COMMIT.with_borrow_mut(Option::take) {
        hook();
    }
}

/// Captured registration and latest human revision. Metadata is not authentication.
pub struct ContextRevisionBinding<'a> {
    /// Registered absolute root.
    pub root: &'a str,
    /// Registered filesystem identity.
    pub root_identity: &'a str,
    /// Registration incarnation, protecting same-ID/same-root reuse.
    pub incarnation: &'a str,
    /// Exact existing latest revision, including a retirement revision.
    pub revision: u32,
}

impl ContextRevisionBinding<'_> {
    /// Validate before storage access (and before reading update text on stdin).
    pub fn validate(&self, project: &str, id: &str) -> Result<()> {
        validate_removal_binding(project, self.root, self.root_identity)?;
        validate_incarnation(self.incarnation)?;
        identity(id)?;
        if !(1..=32).contains(&self.revision) {
            return Err(invalid());
        }
        Ok(())
    }
}

/// Validate the closed human-kind vocabulary before reading input or storage.
pub fn validate_context_kind(kind: &str) -> Result<()> {
    if !context_kind(kind) {
        return Err(invalid());
    }
    Ok(())
}

/// Validate human text before opening storage; the bound is UTF-8 bytes.
pub fn validate_context_text(text: &str) -> Result<()> {
    if text.is_empty() || text.len() > 4096 || text.contains('\0') {
        return Err(invalid());
    }
    Ok(())
}

impl Store {
    /// Append only if the captured registration and latest revision still match.
    /// The comparison, budget checks and append share one SQLite transaction.
    pub fn update_context_revision_bound(
        &mut self,
        project: &str,
        id: &str,
        kind: &str,
        text: &str,
        binding: &ContextRevisionBinding<'_>,
        cancel: &AtomicBool,
    ) -> Result<()> {
        binding.validate(project, id)?;
        validate_context_kind(kind)?;
        validate_context_text(text)?;
        canceled(cancel)?;
        let project = self.bound_project(
            project,
            binding.root,
            binding.root_identity,
            binding.incarnation,
        )?;
        self.write_context_guarded(
            &project,
            id,
            kind,
            text,
            true,
            Some((binding.revision, cancel)),
        )
    }

    /// Retire exactly the captured latest revision, never a peer's newer edit.
    /// A fresh explicit update can reactivate retired history, as in trusted forms.
    pub fn retire_context_revision_bound(
        &mut self,
        project: &str,
        id: &str,
        binding: &ContextRevisionBinding<'_>,
        cancel: &AtomicBool,
    ) -> Result<()> {
        binding.validate(project, id)?;
        canceled(cancel)?;
        let project = self.bound_project(
            project,
            binding.root,
            binding.root_identity,
            binding.incarnation,
        )?;
        self.retire_context_guarded(&project, id, Some((binding.revision, cancel)))
    }
}
