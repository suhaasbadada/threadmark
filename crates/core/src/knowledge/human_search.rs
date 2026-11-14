//! Human context is an overlay, never verified source evidence or authorization.
use super::*;

/// Validate human-only lexical search before opening storage; no query is echoed.
pub fn validate_human_search(project: &str, query: &str) -> Result<()> {
    identity(project)?;
    if query.len() > 256 || query.trim().is_empty() || query.chars().any(char::is_control) {
        return Err(invalid());
    }
    Ok(())
}

impl Store {
    /// Search active latest human revisions in one bounded SQLite read snapshot.
    /// No source content/currentness checks, inference, indexing, or cached results.
    pub fn search_context(&self, project: &str, query: &str, cancel: &AtomicBool) -> Result<Value> {
        self.search_context_observed(project, query, cancel, || {})
    }

    fn search_context_observed(
        &self,
        project: &str,
        query: &str,
        cancel: &AtomicBool,
        mut boundary: impl FnMut(),
    ) -> Result<Value> {
        validate_human_search(project, query)?;
        canceled(cancel)?;
        self.healthy()?;
        let tx = self.db.unchecked_transaction().map_err(unavailable)?;
        let registration = self.project(project)?;
        Self::require_project_root(&tx, &registration)?;
        let marked = forget::markers(&tx, project)?;
        boundary();
        canceled(cancel)?;
        // At most 4096 persisted revisions are admitted by the writer. Fail on
        // overflow rather than silently giving prefix-only lexical coverage.
        let count: i64 = tx
            .query_row(
                "SELECT count(*) FROM context WHERE project=?1",
                [project],
                |r| r.get(0),
            )
            .map_err(unavailable)?;
        if !(0..=4096).contains(&count) {
            return Err(invalid());
        }
        let needle = query.trim().to_lowercase();
        let mut stmt = tx.prepare(
            "SELECT id,revision,kind,text,retired FROM context c WHERE project=?1 AND revision=(SELECT max(revision) FROM context WHERE project=c.project AND id=c.id) ORDER BY id LIMIT 4097",
        ).map_err(unavailable)?;
        let rows = stmt
            .query_map([project], |r| {
                Ok((
                    r.get::<_, String>(0)?,
                    r.get::<_, i64>(1)?,
                    r.get::<_, String>(2)?,
                    r.get::<_, String>(3)?,
                    r.get::<_, i64>(4)?,
                ))
            })
            .map_err(unavailable)?;
        let mut candidates = Vec::new();
        for (n, row) in rows.enumerate() {
            canceled(cancel)?;
            let (id, revision, kind, text, retired) = row.map_err(unavailable)?;
            if n >= 4096 {
                return Err(invalid());
            }
            // Suppression is authoritative, even if stale content remains.
            if marked.contains(&id) {
                continue;
            }
            identity(&id)?;
            if !(1..=32).contains(&revision)
                || !context_kind(&kind)
                || text.is_empty()
                || text.len() > 4096
                || text.contains('\0')
                || !matches!(retired, 0 | 1)
            {
                return Err(invalid());
            }
            if retired != 0 {
                continue;
            }
            let score = text.to_lowercase().matches(&needle).count();
            if score > 0 {
                candidates.push((score, id, revision, kind, text));
            }
        }
        drop(stmt);
        candidates.sort_by(|a, b| b.0.cmp(&a.0).then_with(|| a.1.cmp(&b.1)));
        let matched = candidates.len();
        let mut reply = json!({
            "project": project, "root_identity": registration.root_identity,
            "incarnation": registration.incarnation,
            "producer": "human-authored", "status": "active-latest-at-read",
            "authority": "context-not-authorization-or-observed-truth",
            "coverage": "human-text-only; Unicode-lowercase literal substring; no normalization, source, semantic or historical search",
            "selection": "occurrence-count-descending-id-ascending; max-8; max-8192-JSON-bytes-including-newline; whole-entry-omission",
            "matched_entries": matched, "omitted_entries": matched,
            "truncated": matched != 0, "results": []
        });
        for (_, id, revision, kind, text) in candidates {
            canceled(cancel)?;
            let results = reply["results"].as_array_mut().ok_or(invalid())?;
            if results.len() >= 8 {
                continue;
            }
            results.push(json!({"id":id,"revision":revision,"kind":kind,"text":text,
                "producer":"human-authored","status":"active"}));
            let selected = results.len();
            reply["omitted_entries"] = json!(matched - selected);
            reply["truncated"] = json!(matched != selected);
            if serde_json::to_vec(&reply).map_err(unavailable)?.len() + 1 > 8192 {
                reply["results"].as_array_mut().ok_or(invalid())?.pop();
                reply["omitted_entries"] = json!(matched - selected + 1);
                reply["truncated"] = json!(true);
            }
        }
        boundary();
        canceled(cancel)?;
        Self::require_project_root(&tx, &registration)?;
        self.healthy()?;
        if serde_json::to_vec(&reply).map_err(unavailable)?.len() + 1 > 8192 {
            return Err(invalid());
        }
        canceled(cancel)?;
        tx.commit().map_err(unavailable)?;
        Ok(reply)
    }
}

#[cfg(test)]
mod tests;
