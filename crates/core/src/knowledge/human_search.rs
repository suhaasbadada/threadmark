//! Human context is an overlay, never verified source evidence or authorization.
use super::*;

// An explicit validated mode at the shared traversal boundary preserves literal
// admission/suppression/validation ordering and its existing wire envelope.
pub(super) enum SearchMode<'a> {
    Literal(&'a str, Option<&'a HumanSearchKinds>),
    Ranked(&'a HumanRankedQuery),
}

/// Validated nonempty unique human-kind selection in deterministic wire order.
#[derive(Clone, Debug)]
pub struct HumanSearchKinds(Vec<String>);

impl HumanSearchKinds {
    /// Validate shape before storage; no SQL identifiers are constructed.
    pub fn new(kinds: &[String]) -> Result<Self> {
        if kinds.is_empty() || kinds.len() > 5 || kinds.iter().any(|k| !context_kind(k)) {
            return Err(invalid());
        }
        let mut canonical = kinds.to_vec();
        canonical.sort();
        canonical.dedup();
        if canonical.len() != kinds.len() {
            return Err(invalid());
        }
        Ok(Self(canonical))
    }

    /// Exact captured canonical selection, not authorization.
    pub fn kinds(&self) -> &[String] {
        &self.0
    }
}

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

    /// Opt-in human search bound before any human SQL read in the same snapshot.
    pub fn search_context_bound(
        &self,
        project: &str,
        query: &str,
        binding: &ContextReadBinding<'_>,
        cancel: &AtomicBool,
    ) -> Result<Value> {
        validate_human_search(project, query)?;
        self.read_human_bound(project, binding, cancel, |tx, registration| {
            self.search_context_in(tx, registration, query, cancel, || {})
        })
    }

    /// Explicit kind-filtered human search; bound admission is mandatory.
    pub fn search_context_kinds_bound(
        &self,
        project: &str,
        query: &str,
        kinds: &HumanSearchKinds,
        binding: &ContextReadBinding<'_>,
        cancel: &AtomicBool,
    ) -> Result<Value> {
        validate_human_search(project, query)?;
        self.read_human_bound(project, binding, cancel, |tx, registration| {
            self.search_context_selected_in(tx, registration, query, Some(kinds), cancel, || {})
        })
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
        let reply = self.search_context_in(&tx, &registration, query, cancel, &mut boundary)?;
        tx.commit().map_err(unavailable)?;
        Ok(reply)
    }

    pub(super) fn search_context_in(
        &self,
        tx: &rusqlite::Transaction<'_>,
        registration: &Project,
        query: &str,
        cancel: &AtomicBool,
        boundary: impl FnMut(),
    ) -> Result<Value> {
        self.search_context_selected_in(tx, registration, query, None, cancel, boundary)
    }

    fn search_context_selected_in(
        &self,
        tx: &rusqlite::Transaction<'_>,
        registration: &Project,
        query: &str,
        kinds: Option<&HumanSearchKinds>,
        cancel: &AtomicBool,
        boundary: impl FnMut(),
    ) -> Result<Value> {
        self.search_context_mode_in(
            tx,
            registration,
            SearchMode::Literal(query, kinds),
            cancel,
            boundary,
        )
    }

    pub(super) fn search_context_mode_in(
        &self,
        tx: &rusqlite::Transaction<'_>,
        registration: &Project,
        mode: SearchMode<'_>,
        cancel: &AtomicBool,
        mut boundary: impl FnMut(),
    ) -> Result<Value> {
        let project = registration.id.as_str();
        let marked = forget::markers(tx, project)?;
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
        let (terms, kinds, ranked) = match mode {
            SearchMode::Literal(query, kinds) => (
                vec![query.trim().to_lowercase()],
                kinds.map(HumanSearchKinds::kinds),
                false,
            ),
            SearchMode::Ranked(query) => (query.terms().to_vec(), Some(query.kinds()), true),
        };
        if ranked {
            let excessive: bool = tx.query_row(
                "SELECT EXISTS(SELECT 1 FROM context WHERE project=?1 GROUP BY id HAVING count(*)>32)",
                [project], |r| r.get(0),
            ).map_err(unavailable)?;
            if excessive {
                return Err(invalid());
            }
        }
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
            // Validate all scoped latest rows before filtering, never hide corruption.
            if retired != 0 || kinds.is_some_and(|selected| !selected.contains(&kind)) {
                continue;
            }
            let lowered = text.to_lowercase();
            let mut matched_terms = Vec::new();
            let mut score = 0;
            for term in &terms {
                let occurrences = lowered.matches(term.as_str()).count();
                if occurrences != 0 {
                    score += occurrences;
                    matched_terms.push(term.clone());
                }
            }
            if score > 0 {
                candidates.push((score, id, revision, kind, text, matched_terms));
            }
        }
        drop(stmt);
        candidates.sort_by(|a, b| {
            b.5.len()
                .cmp(&a.5.len())
                .then_with(|| b.0.cmp(&a.0))
                .then_with(|| a.1.cmp(&b.1))
        });
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
        if let Some(kinds) = kinds {
            reply["version"] = json!("human-search-kind-filter-v1");
            reply["selected_kinds"] = json!(kinds);
        }
        if ranked {
            reply["version"] = json!("human-search-ranked-v1");
            reply["terms"] = json!(terms);
            reply["coverage"] = json!(
                "human-text-only; any distinct Unicode-lowercase whitespace term; no normalization, source, semantic or historical search"
            );
            reply["selection"] = json!(
                "distinct-matched-terms-descending-occurrences-descending-id-byte-order-ascending; max-8; max-8192-JSON-bytes-including-newline; whole-entry-omission; later-fitting-candidates-allowed"
            );
            reply["limitations"] = json!(
                "Human declarations, not observed truth or authorization; per-term nonoverlapping occurrences; distinct-term overlaps counted independently; no relevance-quality claim; current-at-read registration, not atomic revocation."
            );
        }
        if ranked && serde_json::to_vec(&reply).map_err(unavailable)?.len() + 1 > 8192 {
            return Err(invalid());
        }
        for (score, id, revision, kind, text, matched_terms) in candidates {
            canceled(cancel)?;
            let results = reply["results"].as_array_mut().ok_or(invalid())?;
            if results.len() >= 8 {
                continue;
            }
            results.push(json!({"id":id,"revision":revision,"kind":kind,"text":text,
                "producer":"human-authored","status":"active"}));
            if ranked {
                let entry = results.last_mut().ok_or(invalid())?;
                entry["matched_terms"] = json!(matched_terms);
                entry["occurrences"] = json!(score);
            }
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
        Self::require_project_root(tx, registration)?;
        self.healthy()?;
        if serde_json::to_vec(&reply).map_err(unavailable)?.len() + 1 > 8192 {
            return Err(invalid());
        }
        canceled(cancel)?;
        Ok(reply)
    }
}

#[cfg(test)]
mod tests;
