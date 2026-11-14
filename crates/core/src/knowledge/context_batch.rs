//! Explicit atomic human edits; no add, semantic resolution or source traversal.
use super::*;

/// One closed, existing-note compare-and-append action.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "operation", rename_all = "lowercase", deny_unknown_fields)]
pub enum ContextBatchAction {
    /// Explicit fresh edit, including deliberate reactivation of retired history.
    Update {
        /// Existing local note ID.
        id: String,
        /// Exact captured latest revision.
        expected_revision: u32,
        /// Closed human declaration kind.
        kind: String,
        /// Human-authored declaration, not observed truth or permission.
        text: String,
    },
    /// Append retirement using the compared latest row's kind and text.
    Retire {
        /// Existing local note ID.
        id: String,
        /// Exact captured latest revision.
        expected_revision: u32,
    },
}

impl ContextBatchAction {
    fn target(&self) -> (&str, u32) {
        match self {
            Self::Update {
                id,
                expected_revision,
                ..
            }
            | Self::Retire {
                id,
                expected_revision,
            } => (id, *expected_revision),
        }
    }
}

/// Versioned closed human-context-batch-edit-v1 document.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ContextBatchEdit {
    /// Must equal human-context-batch-edit-v1.
    pub version: String,
    /// 2..8 distinct existing notes in the separately bound project.
    pub actions: Vec<ContextBatchAction>,
}

impl ContextBatchEdit {
    /// Parse one bounded closed JSON document; serde rejects duplicate fields.
    pub fn parse(bytes: &[u8]) -> Result<Self> {
        if bytes.len() > 65_536 || bytes.contains(&0) {
            return Err(invalid());
        }
        // Explicit UTF-8 admission; no lossy decoding or partial frames.
        std::str::from_utf8(bytes).map_err(unavailable)?;
        serde_json::from_slice(bytes).map_err(unavailable)
    }

    /// Repeat applicable admission checks before storage, including typed callers.
    pub fn validate(&self, project: &str, binding: &ContextReadBinding<'_>) -> Result<()> {
        binding.validate(project)?;
        if self.version != "human-context-batch-edit-v1" || !(2..=8).contains(&self.actions.len()) {
            return Err(invalid());
        }
        let mut ids = std::collections::BTreeSet::new();
        let mut text_bytes = 0;
        for action in &self.actions {
            let (id, revision) = action.target();
            identity(id)?;
            if !ids.insert(id) || !(1..=32).contains(&revision) {
                return Err(invalid());
            }
            if let ContextBatchAction::Update { kind, text, .. } = action {
                validate_context_kind(kind)?;
                validate_context_text(text)?;
                text_bytes += text.len();
            }
        }
        if text_bytes > 32_768 || serde_json::to_vec(self).map_err(unavailable)?.len() > 65_536 {
            return Err(invalid());
        }
        Ok(())
    }
}

/// Finite synchronous transaction boundaries, never a listener or async worker.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ContextBatchStage {
    /// An append is staged, not committed; count is 1..8.
    AppendStaged(usize),
    /// Complete receipt prepared; final cancellation check precedes commit.
    ReadyToCommit,
}

impl Store {
    /// Atomically compare all targets before appending any, in one IMMEDIATE transaction.
    pub fn edit_context_batch_bound(
        &mut self,
        project: &str,
        binding: &ContextReadBinding<'_>,
        request: &ContextBatchEdit,
        cancel: &AtomicBool,
        mut progress: impl FnMut(ContextBatchStage),
    ) -> Result<Value> {
        canceled(cancel)?;
        request.validate(project, binding)?;
        canceled(cancel)?;
        self.healthy()?;
        let tx = rusqlite::Transaction::new_unchecked(
            &self.db,
            rusqlite::TransactionBehavior::Immediate,
        )
        .map_err(unavailable)?;
        // Metadata only: no sources, policy, snapshot or human SQL before exact binding.
        let registration = self.human_registration(project)?;
        if registration.root != binding.root
            || registration.root_identity != binding.root_identity
            || registration.incarnation.as_deref() != Some(binding.incarnation)
        {
            return Err(Error::ScopeMismatch);
        }
        Self::require_project_root(&tx, &registration)?;
        canceled(cancel)?;
        let count: i64 = tx
            .query_row(
                "SELECT count(*) FROM context WHERE project=?1",
                [project],
                |r| r.get(0),
            )
            .map_err(unavailable)?;
        if count < 0 || count + request.actions.len() as i64 > 4096 {
            return Err(invalid());
        }
        let mut plan = Vec::new();
        for action in &request.actions {
            canceled(cancel)?;
            let (id, expected) = action.target();
            // Complete bounded history validation, including unselected old revisions.
            let history = Self::context_in(&tx, project, id)?;
            let rows = history["history"].as_array().ok_or_else(invalid)?;
            let latest = rows.last().ok_or_else(invalid)?;
            let revision = rows.len() as u32;
            if revision != expected {
                return Err(Error::ScopeMismatch);
            }
            if revision >= 32 {
                return Err(invalid());
            }
            let (kind, text, retired, operation) = match action {
                ContextBatchAction::Update { kind, text, .. } => {
                    (kind.clone(), text.clone(), false, "update")
                }
                ContextBatchAction::Retire { .. } => (
                    latest["kind"].as_str().ok_or_else(invalid)?.to_owned(),
                    latest["text"].as_str().ok_or_else(invalid)?.to_owned(),
                    true,
                    "retire",
                ),
            };
            plan.push((id, revision, kind, text, retired, operation));
        }
        canceled(cancel)?;
        let mut receipts = Vec::new();
        for (index, (id, revision, kind, text, retired, operation)) in plan.iter().enumerate() {
            canceled(cancel)?;
            tx.execute(
                "INSERT INTO context VALUES(?1,?2,?3,?4,?5,?6)",
                params![project, id, revision + 1, kind, text, retired],
            )
            .map_err(unavailable)?;
            receipts.push(json!({"id":id,"operation":operation,"old_revision":revision,"new_revision":revision+1}));
            progress(ContextBatchStage::AppendStaged(index + 1));
            canceled(cancel)?;
        }
        receipts.sort_by(|a, b| a["id"].as_str().cmp(&b["id"].as_str()));
        let receipt = json!({"version":"human-context-batch-edit-v1","project":project,
            "count":receipts.len(),"actions":receipts});
        if serde_json::to_vec(&receipt).map_err(unavailable)?.len() + 1 > 8192 {
            return Err(invalid());
        }
        self.healthy()?;
        progress(ContextBatchStage::ReadyToCommit);
        canceled(cancel)?;
        tx.commit().map_err(unavailable)?;
        Ok(receipt)
    }
}
