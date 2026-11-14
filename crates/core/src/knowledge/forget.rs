//! Bounded human-history removal; no source Forget, restore, or forensic erasure.
use super::*;

pub(super) const RETENTION: &str = "Active human-history removal and same-scope suppression only; not forensic erasure. SQLite free pages, journals, backups, earlier exports and displayed copies may retain bytes. Source files are untouched.";

/// Synchronous Forget boundaries. All stages precede the atomic commit.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ForgetStage {
    /// Suppression marker staged.
    MarkerStaged,
    /// Every target revision staged for deletion.
    ContentRemoved,
    /// Receipt ready; final cancellation check precedes commit.
    ReadyToCommit,
}

/// Immutable displayed approval, not authentication or source authority.
pub struct ForgetBinding<'a> {
    /// Displayed registered root.
    pub root: &'a str,
    /// Displayed filesystem identity.
    pub root_identity: &'a str,
    /// Displayed schema-v3 registration incarnation.
    pub incarnation: &'a str,
    /// Displayed latest revision and complete history count.
    pub revision: u32,
}

impl ForgetBinding<'_> {
    /// Validate before opening storage.
    pub fn validate(&self, project: &str, id: &str) -> Result<()> {
        validate_removal_binding(project, self.root, self.root_identity)?;
        identity(id)?;
        validate_incarnation(self.incarnation)?;
        if !(1..=32).contains(&self.revision) {
            return Err(invalid());
        }
        Ok(())
    }
}

// Consult the live schema in the operation's transaction, not an open-time cache.
pub(super) fn markers(
    db: &Connection,
    project: &str,
) -> Result<std::collections::BTreeSet<String>> {
    match schema::version(db)? {
        1 => return Ok(Default::default()),
        2..=4 => (),
        _ => return Err(Error::Unavailable),
    }
    let mut stmt = db
        .prepare("SELECT id FROM forgotten_context WHERE project=?1 ORDER BY id LIMIT 4097")
        .map_err(unavailable)?;
    let rows = stmt
        .query_map([project], |r| r.get::<_, String>(0))
        .map_err(unavailable)?;
    let mut result = std::collections::BTreeSet::new();
    for row in rows {
        let id = row.map_err(unavailable)?;
        identity(&id)?;
        if result.len() >= 4096 || !result.insert(id) {
            return Err(invalid());
        }
    }
    Ok(result)
}

pub(super) fn require_unmarked(db: &Connection, project: &str, id: &str) -> Result<()> {
    if markers(db, project)?.contains(id) {
        return Err(invalid());
    }
    Ok(())
}

impl Store {
    /// Forget only the exact live history approved by an incarnation-aware caller.
    pub fn forget_context_bound(
        &mut self,
        project: &str,
        id: &str,
        binding: &ForgetBinding<'_>,
        cancel: &AtomicBool,
        progress: impl FnMut(ForgetStage),
    ) -> Result<Value> {
        binding.validate(project, id)?;
        canceled(cancel)?;
        let project = self.project(project)?;
        if project.root != binding.root
            || project.root_identity != binding.root_identity
            || project.incarnation.as_deref() != Some(binding.incarnation)
        {
            return Err(Error::ScopeMismatch);
        }
        self.forget_for_policy_bound(&project, id, Some(binding.revision), cancel, progress)
    }
    /// Remove all revisions and suppress same-scope recreation, not forensic erasure.
    pub fn forget_context(
        &mut self,
        project: &str,
        id: &str,
        cancel: &AtomicBool,
    ) -> Result<Value> {
        self.forget_context_with_progress(project, id, cancel, |_| {})
    }

    /// Observe transactional stages. Unknown IDs never create suppression markers.
    pub fn forget_context_with_progress(
        &mut self,
        project: &str,
        id: &str,
        cancel: &AtomicBool,
        progress: impl FnMut(ForgetStage),
    ) -> Result<Value> {
        canceled(cancel)?;
        identity(id)?;
        let project = self.project(project)?;
        self.forget_for_policy(&project, id, cancel, progress)
    }

    pub(super) fn forget_for_policy(
        &mut self,
        project: &Project,
        id: &str,
        cancel: &AtomicBool,
        progress: impl FnMut(ForgetStage),
    ) -> Result<Value> {
        self.forget_for_policy_bound(project, id, None, cancel, progress)
    }

    fn forget_for_policy_bound(
        &mut self,
        project: &Project,
        id: &str,
        revision: Option<u32>,
        cancel: &AtomicBool,
        mut progress: impl FnMut(ForgetStage),
    ) -> Result<Value> {
        self.healthy()?;
        identity(id)?;
        let tx = self
            .db
            .transaction_with_behavior(rusqlite::TransactionBehavior::Immediate)
            .map_err(unavailable)?;
        Self::require_project_root(&tx, project)?;
        if schema::version(&tx)? < 2 {
            return Err(Error::Unavailable);
        }
        canceled(cancel)?;
        let marked = markers(&tx, &project.id)?;
        let count: i64 = tx
            .query_row(
                "SELECT count(*) FROM context WHERE project=?1 AND id=?2",
                params![project.id, id],
                |r| r.get(0),
            )
            .map_err(unavailable)?;
        if let Some(revision) = revision {
            let (first, latest): (Option<i64>, Option<i64>) = tx
                .query_row(
                    "SELECT min(revision),max(revision) FROM context WHERE project=?1 AND id=?2",
                    params![project.id, id],
                    |r| Ok((r.get(0)?, r.get(1)?)),
                )
                .map_err(unavailable)?;
            if marked.contains(id)
                || count != i64::from(revision)
                || first != Some(1)
                || latest != Some(i64::from(revision))
            {
                return Err(Error::ScopeMismatch);
            }
        }
        if !(0..=32).contains(&count)
            || (!marked.contains(id) && (count == 0 || marked.len() == 4096))
        {
            return Err(invalid());
        }
        tx.execute(
            "INSERT OR IGNORE INTO forgotten_context(project,id) VALUES(?1,?2)",
            params![project.id, id],
        )
        .map_err(unavailable)?;
        progress(ForgetStage::MarkerStaged);
        canceled(cancel)?;
        tx.execute(
            "DELETE FROM context WHERE project=?1 AND id=?2",
            params![project.id, id],
        )
        .map_err(unavailable)?;
        progress(ForgetStage::ContentRemoved);
        canceled(cancel)?;
        let receipt = json!({"project":project.id,"id":id,"forgotten":true,"removed_revisions":count,"retention_limits":RETENTION});
        progress(ForgetStage::ReadyToCommit);
        canceled(cancel)?;
        tx.commit().map_err(unavailable)?;
        Ok(receipt)
    }

    /// Inspect deterministic bounded suppression IDs, never retained text.
    pub fn forgotten_contexts(&self, project: &str) -> Result<Value> {
        self.healthy()?;
        let tx = self.db.unchecked_transaction().map_err(unavailable)?;
        self.project(project)?;
        if schema::version(&tx)? < 2 {
            return Err(Error::Unavailable);
        }
        let forgotten: Vec<_> = markers(&tx, project)?
            .into_iter()
            .map(|id| json!({"id":id}))
            .collect();
        let reply = json!({"project":project,"forgotten":forgotten});
        if serde_json::to_vec(&reply).map_err(unavailable)?.len() + 1 > MAX_TOTAL {
            return Err(invalid());
        }
        tx.commit().map_err(unavailable)?;
        Ok(reply)
    }
}
