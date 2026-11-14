//! Source authorization revocation, distinct from human-history Forget.
use super::*;

const RETENTION: &str = "Active source-derivative removal and same-scope suppression only; not forensic erasure. Source files and human context are untouched. SQLite free pages, journals, backups, earlier exports and displayed copies may retain bytes.";

/// All boundaries precede the single atomic commit.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SourceForgetStage {
    /// Approved policy updated, not committed.
    PolicyRevoked,
    /// Non-content suppression staged.
    MarkerStaged,
    /// Coherent source snapshot invalidated.
    EvidenceRemoved,
    /// Final cancellation boundary.
    ReadyToCommit,
}

/// Exact displayed native approval; not credentials or new source authority.
pub struct SourceForgetBinding<'a> {
    /// Registered root.
    pub root: &'a str,
    /// Registered root identity.
    pub root_identity: &'a str,
    /// Registration incarnation.
    pub incarnation: &'a str,
    /// Complete displayed approved policy, including order.
    pub sources: &'a [String],
}

/// Validate selectors before opening or creating storage.
pub fn validate_source_forget(project: &str, path: &str) -> Result<()> {
    identity(project)?;
    if path.len() > 240 {
        return Err(invalid());
    }
    validate_paths(&[path.into()])
}

impl SourceForgetBinding<'_> {
    /// Reject incomplete or malformed approval before storage access.
    pub fn validate(&self, project: &str, path: &str) -> Result<()> {
        validate_source_forget(project, path)?;
        validate_index_binding(project, self.root, self.root_identity, self.sources)?;
        validate_incarnation(self.incarnation)?;
        if !self.sources.iter().any(|p| p == path) {
            return Err(Error::ScopeMismatch);
        }
        Ok(())
    }
}

// Validate at most 64 policies and 4096 markers, with byte/type bounds before
// JSON decoding. Cache each policy once rather than parsing for every marker.
pub(super) fn validate_store(db: &Connection) -> Result<()> {
    let mut policies = std::collections::BTreeMap::new();
    let mut stmt = db
        .prepare("SELECT id,sources FROM projects LIMIT 65")
        .map_err(unavailable)?;
    let rows = stmt
        .query_map([], |r| Ok((r.get::<_, String>(0)?, r.get::<_, String>(1)?)))
        .map_err(unavailable)?;
    for row in rows {
        let (id, encoded) = row.map_err(unavailable)?;
        identity(&id)?;
        if policies.len() == 64 || encoded.len() > 16384 || encoded.contains('\0') {
            return Err(invalid());
        }
        let paths: Vec<String> = serde_json::from_str(&encoded).map_err(unavailable)?;
        validate_paths(&paths)?;
        policies.insert(id, paths);
    }
    let mut counts = std::collections::BTreeMap::new();
    let mut stmt = db
        .prepare("SELECT project,path FROM forgotten_sources LIMIT 4097")
        .map_err(unavailable)?;
    let rows = stmt
        .query_map([], |r| Ok((r.get::<_, String>(0)?, r.get::<_, String>(1)?)))
        .map_err(unavailable)?;
    for (index, row) in rows.enumerate() {
        let (project, path) = row.map_err(unavailable)?;
        validate_source_forget(&project, &path)?;
        let policy = policies.get(&project).ok_or(invalid())?;
        let count = counts.entry(project).or_insert(0);
        *count += 1;
        if index >= 4096 || *count > 64 || policy.contains(&path) {
            return Err(invalid());
        }
    }
    // A forged stale snapshot must not make marked evidence exportable. Fail
    // before any source filesystem access, even when currentness would be stale.
    let overlap: bool = db.query_row("SELECT EXISTS(SELECT 1 FROM evidence e JOIN forgotten_sources f ON e.project=f.project AND e.path=f.path)", [], |r| r.get(0)).map_err(unavailable)?;
    if overlap {
        return Err(invalid());
    }
    Ok(())
}

fn markers(db: &Connection, project: &str) -> Result<Vec<String>> {
    if schema::version(db)? != 4 {
        return Err(Error::Unavailable);
    }
    validate_store(db)?;
    let mut stmt = db
        .prepare("SELECT path FROM forgotten_sources WHERE project=?1 ORDER BY path LIMIT 65")
        .map_err(unavailable)?;
    stmt.query_map([project], |r| r.get(0))
        .map_err(unavailable)?
        .collect::<std::result::Result<Vec<_>, _>>()
        .map_err(unavailable)
}

pub(super) fn require_allowed(db: &Connection, project: &str, paths: &[String]) -> Result<()> {
    if schema::version(db)? == 4 && markers(db, project)?.iter().any(|p| paths.contains(p)) {
        return Err(Error::ScopeMismatch);
    }
    Ok(())
}

#[cfg(test)]
thread_local! { pub(super) static SOURCE_ACCESSES: std::cell::Cell<usize> = const { std::cell::Cell::new(0) }; }
#[cfg(test)]
pub(super) fn observe_source_access() {
    SOURCE_ACCESSES.with(|n| n.set(n.get() + 1));
}

impl Store {
    /// Revoke one approved file without ever opening its source root or file.
    pub fn forget_source(
        &mut self,
        project: &str,
        path: &str,
        cancel: &AtomicBool,
    ) -> Result<Value> {
        self.forget_source_with_progress(project, path, None, cancel, |_| {})
    }

    /// Atomically revoke an exact captured approval, or unbound CLI selection.
    pub fn forget_source_with_progress(
        &mut self,
        project: &str,
        path: &str,
        binding: Option<&SourceForgetBinding<'_>>,
        cancel: &AtomicBool,
        mut progress: impl FnMut(SourceForgetStage),
    ) -> Result<Value> {
        validate_source_forget(project, path)?;
        if let Some(binding) = binding {
            binding.validate(project, path)?;
        }
        canceled(cancel)?;
        let p = self.project(project)?;
        if let Some(b) = binding
            && (p.root != b.root
                || p.root_identity != b.root_identity
                || p.incarnation.as_deref() != Some(b.incarnation)
                || p.sources != b.sources)
        {
            return Err(Error::ScopeMismatch);
        }
        let tx = self
            .db
            .transaction_with_behavior(rusqlite::TransactionBehavior::Immediate)
            .map_err(unavailable)?;
        Self::require_project_root(&tx, &p)?;
        let live: String = tx
            .query_row("SELECT sources FROM projects WHERE id=?1", [project], |r| {
                r.get(0)
            })
            .map_err(unavailable)?;
        if serde_json::from_str::<Vec<String>>(&live).map_err(unavailable)? != p.sources {
            return Err(Error::ScopeMismatch);
        }
        let marked = markers(&tx, project)?;
        let already = marked.iter().any(|m| m == path);
        if (binding.is_some() && already) || (!already && !p.sources.iter().any(|s| s == path)) {
            return Err(Error::ScopeMismatch);
        }
        if !already && marked.len() == 64 {
            return Err(invalid());
        }
        canceled(cancel)?;
        // Unbound idempotence does not invalidate a later remaining-source rebuild.
        if !already {
            let paths: Vec<_> = p.sources.iter().filter(|s| *s != path).collect();
            tx.execute(
                "UPDATE projects SET sources=?2 WHERE id=?1",
                params![project, serde_json::to_string(&paths).map_err(unavailable)?],
            )
            .map_err(unavailable)?;
            progress(SourceForgetStage::PolicyRevoked);
            canceled(cancel)?;
            tx.execute(
                "INSERT INTO forgotten_sources(project,path) VALUES(?1,?2)",
                params![project, path],
            )
            .map_err(unavailable)?;
            progress(SourceForgetStage::MarkerStaged);
            canceled(cancel)?;
            tx.execute("DELETE FROM evidence WHERE project=?1", [project])
                .map_err(unavailable)?;
            tx.execute(
                "UPDATE projects SET snapshot=NULL,manifest=NULL WHERE id=?1",
                [project],
            )
            .map_err(unavailable)?;
            progress(SourceForgetStage::EvidenceRemoved);
            canceled(cancel)?;
        }
        let receipt = json!({"project":project,"path":path,"forgotten":true,"source_authorization":"revoked","snapshot":if already { "unchanged" } else { "invalidated" },"human_context":"unchanged","retention_limits":RETENTION});
        progress(SourceForgetStage::ReadyToCommit);
        canceled(cancel)?;
        tx.commit().map_err(unavailable)?;
        Ok(receipt)
    }

    /// List bounded non-content markers in lexical path order.
    pub fn forgotten_sources(&self, project: &str) -> Result<Value> {
        self.healthy()?;
        identity(project)?;
        let tx = self.db.unchecked_transaction().map_err(unavailable)?;
        self.project(project)?;
        let reply = Self::forgotten_sources_in(&tx, project)?;
        tx.commit().map_err(unavailable)?;
        Ok(reply)
    }

    pub(super) fn forgotten_sources_in(tx: &Connection, project: &str) -> Result<Value> {
        let forgotten: Vec<_> = markers(tx, project)?
            .into_iter()
            .map(|path| json!({"path":path}))
            .collect();
        let reply = json!({"project":project,"forgotten":forgotten});
        if serde_json::to_vec(&reply).map_err(unavailable)?.len() + 1 > MAX_TOTAL {
            return Err(invalid());
        }
        Ok(reply)
    }
}
