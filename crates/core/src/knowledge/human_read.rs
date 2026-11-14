//! Opt-in registration-scoped human and suppression metadata reads.
//! No source-policy/currentness binding or source filesystem access.
use super::*;

/// Exact UTF-8 registration metadata, not credentials or source authorization.
pub struct ContextReadBinding<'a> {
    /// Captured registered root (not resolved or normalized by the reader).
    pub root: &'a str,
    /// Captured filesystem identity.
    pub root_identity: &'a str,
    /// Captured registration nonce; legacy registrations cannot satisfy it.
    pub incarnation: &'a str,
}

impl ContextReadBinding<'_> {
    /// Shape validation only; safe before opening storage or reading stdin.
    pub fn validate(&self, project: &str) -> Result<()> {
        validate_removal_binding(project, self.root, self.root_identity)?;
        validate_incarnation(self.incarnation)
    }

    fn require(&self, project: &Project) -> Result<()> {
        if project.root != self.root
            || project.root_identity != self.root_identity
            || project.incarnation.as_deref() != Some(self.incarnation)
        {
            return Err(Error::ScopeMismatch);
        }
        Ok(())
    }
}

impl Store {
    // Only this registration's metadata, not source policies/other projects.
    pub(super) fn human_registration(&self, project: &str) -> Result<Project> {
        if schema::version(&self.db)? < 3 {
            return Err(Error::ScopeMismatch);
        }
        let (root, root_identity, incarnation) = self.db.query_row(
            "SELECT root,root_identity,incarnation FROM projects JOIN project_incarnations ON project_incarnations.project=projects.id WHERE id=?1",
            [project], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)),
        ).map_err(unavailable)?;
        Ok(Project {
            id: project.into(),
            root,
            root_identity,
            incarnation,
            sources: Vec::new(),
            snapshot: None,
        })
    }

    /// List latest human metadata only after checking the captured registration.
    pub fn contexts_bound(
        &self,
        project: &str,
        binding: &ContextReadBinding<'_>,
        cancel: &AtomicBool,
    ) -> Result<Value> {
        self.read_human_bound(project, binding, cancel, |tx, _| {
            Self::contexts_in(tx, project)
        })
    }

    /// Read bounded human history only inside the captured registration snapshot.
    pub fn context_bound(
        &self,
        project: &str,
        id: &str,
        binding: &ContextReadBinding<'_>,
        cancel: &AtomicBool,
    ) -> Result<Value> {
        identity(id)?;
        self.read_human_bound(project, binding, cancel, |tx, _| {
            Self::context_in(tx, project, id)
        })
    }

    /// Inspect human suppression IDs only inside the captured registration.
    pub fn forgotten_contexts_bound(
        &self,
        project: &str,
        binding: &ContextReadBinding<'_>,
        cancel: &AtomicBool,
    ) -> Result<Value> {
        self.read_human_bound(project, binding, cancel, |tx, _| {
            Self::forgotten_contexts_in(tx, project)
        })
    }

    /// Inspect source suppression paths, not source content or authorization.
    /// Existing schema v4 is required; no implicit upgrade is performed.
    pub fn forgotten_sources_bound(
        &self,
        project: &str,
        binding: &ContextReadBinding<'_>,
        cancel: &AtomicBool,
    ) -> Result<Value> {
        self.read_human_bound(project, binding, cancel, |tx, _| {
            Self::forgotten_sources_in(tx, project)
        })
    }

    // The callback is the private pre-data boundary: no Forget marker,
    // context row or search traversal is read before binding.require succeeds.
    // Callbacks reuse this transaction; they must not open a nested transaction.
    pub(super) fn read_human_bound(
        &self,
        project: &str,
        binding: &ContextReadBinding<'_>,
        cancel: &AtomicBool,
        read: impl FnOnce(&rusqlite::Transaction<'_>, &Project) -> Result<Value>,
    ) -> Result<Value> {
        binding.validate(project)?;
        canceled(cancel)?;
        self.healthy()?;
        let tx = self.db.unchecked_transaction().map_err(unavailable)?;
        let registration = self.human_registration(project)?;
        binding.require(&registration)?;
        Self::require_project_root(&tx, &registration)?;
        canceled(cancel)?;
        let reply = read(&tx, &registration)?;
        canceled(cancel)?;
        Self::require_project_root(&tx, &registration)?;
        self.healthy()?;
        tx.commit().map_err(unavailable)?;
        // A fresh view detects committed replacement during a WAL read. This
        // is current-at-read publication checking, not an external revocation lease.
        binding.require(&self.human_registration(project)?)?;
        self.healthy()?;
        canceled(cancel)?;
        Ok(reply)
    }
}

#[cfg(test)]
mod tests;
