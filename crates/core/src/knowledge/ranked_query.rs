//! Explicit bounded any-term lexical ranking. Never used implicitly by literal query.
use super::*;
use std::cmp::Reverse;
use std::collections::BTreeMap;

/// Validate the project and explicit whitespace-split Unicode-lowercase query.
/// No stemming, Unicode normalization, semantic expansion or inferred authority.
pub fn validate_query_terms(id: &str, query: &str) -> Result<()> {
    identity(id)?;
    terms(query).map(|_| ())
}

fn terms(query: &str) -> Result<Vec<String>> {
    if query.len() > 256 || query.chars().any(char::is_control) {
        return Err(invalid());
    }
    let mut terms = Vec::new();
    for raw in query.split_whitespace() {
        let term = raw.to_lowercase();
        if term.len() > 64 {
            return Err(invalid());
        }
        if !terms.contains(&term) {
            terms.push(term);
            if terms.len() > 8 {
                return Err(invalid());
            }
        }
    }
    if terms.is_empty() {
        return Err(invalid());
    }
    Ok(terms)
}

struct Candidate {
    path: String,
    line: i64,
    text: String,
    hash: String,
    producer: String,
    matched: usize,
    occurrences: usize,
}

impl Candidate {
    fn key(&self) -> (Reverse<usize>, Reverse<usize>, &str, i64) {
        (
            Reverse(self.matched),
            Reverse(self.occurrences),
            &self.path,
            self.line,
        )
    }
}

impl Store {
    // Both query methods bind the exact policy passed to read_sources; never
    // replace this with a metadata preflight followed by an unbound ID reload.
    pub(super) fn query_project(&self, id: &str, expected: Option<&Project>) -> Result<Project> {
        if let Some(expected) = expected {
            validate_paths(&expected.sources)?;
            let p = self.bound_project(
                id,
                &expected.root,
                &expected.root_identity,
                expected
                    .incarnation
                    .as_deref()
                    .ok_or(Error::ScopeMismatch)?,
            )?;
            if p.id != expected.id
                || p.sources != expected.sources
                || p.snapshot != expected.snapshot
            {
                return Err(Error::ScopeMismatch);
            }
            Ok(p)
        } else {
            self.project(id)
        }
    }

    // Shared with literal query; retain its conservative whole-manifest semantics.
    pub(super) fn current_query_inputs(
        &self,
        p: &Project,
        cancel: &AtomicBool,
    ) -> Result<Option<Vec<(Source, String)>>> {
        let stored: Option<String> = self
            .db
            .query_row("SELECT manifest FROM projects WHERE id=?1", [&p.id], |r| {
                r.get(0)
            })
            .map_err(unavailable)?;
        Ok(match (stored, Self::read_sources(p, cancel)) {
            (Some(encoded), Ok(inputs)) if encoded.len() <= 32768 => {
                let expected: Vec<Source> = serde_json::from_str(&encoded).map_err(unavailable)?;
                if p.snapshot.as_ref() == Some(&sha256(encoded.as_bytes()))
                    && expected == inputs.iter().map(|(s, _)| s.clone()).collect::<Vec<_>>()
                {
                    Some(inputs)
                } else {
                    None
                }
            }
            _ => None,
        })
    }

    /// Rank all admitted current anchors by distinct terms, then nonoverlapping
    /// occurrences per term, then path/line. At most eight complete entries and
    /// 8192 serialized bytes including the CLI newline. Source-only, no indexing.
    pub fn query_terms(&self, id: &str, query: &str, cancel: &AtomicBool) -> Result<Value> {
        self.query_terms_with_progress(id, query, cancel, || {})
    }

    /// Ranked retrieval bound before source access to the exact inspected
    /// registration, source policy and stored snapshot. Not authentication.
    pub fn query_terms_bound(
        &self,
        expected: &Project,
        query: &str,
        cancel: &AtomicBool,
    ) -> Result<Value> {
        self.query_terms_scoped(&expected.id, query, cancel, Some(expected), || {}, || {})
    }

    fn query_terms_with_progress(
        &self,
        id: &str,
        query: &str,
        cancel: &AtomicBool,
        ready: impl FnMut(),
    ) -> Result<Value> {
        self.query_terms_scoped(id, query, cancel, None, || {}, ready)
    }

    fn query_terms_scoped(
        &self,
        id: &str,
        query: &str,
        cancel: &AtomicBool,
        expected: Option<&Project>,
        before_sources: impl FnOnce(),
        mut ready: impl FnMut(),
    ) -> Result<Value> {
        self.query_selected_pipeline(
            id,
            query,
            cancel,
            (expected, None),
            before_sources,
            &mut ready,
        )
    }

    // One source walk, row verification, ranking and publication fence for both modes.
    pub(super) fn query_selected_pipeline(
        &self,
        id: &str,
        query: &str,
        cancel: &AtomicBool,
        scope: (Option<&Project>, Option<&FileQuery>),
        before_sources: impl FnOnce(),
        mut ready: impl FnMut(),
    ) -> Result<Value> {
        let (expected, filter) = scope;
        canceled(cancel)?;
        let literal = filter.is_some_and(|r| r.mode == FileQueryMode::Literal);
        let terms = if literal {
            Vec::new()
        } else {
            validate_query_terms(id, query)?;
            terms(query)?
        };
        let p = self.query_project(id, expected)?;
        before_sources();
        let inputs = self.current_query_inputs(&p, cancel)?;
        canceled(cancel)?;
        let mut reply = json!({
            "project":id, "root_identity":p.root_identity, "snapshot":p.snapshot,
            "currentness":if inputs.is_some() {"current-at-read"} else {"stale-or-unindexed"},
            "coverage":"indexed-source-lines-only; any-term literal text matches; no semantic/symbol coverage",
            "selection":"distinct-matched-terms-desc,total-nonoverlap-occurrences-desc,path-line-asc",
            "terms":terms, "truncated":false, "matching_anchors":0, "scanned_anchors":0,
            "results":[],
            "limitations":"Unicode lowercase only; no stemming or normalization; no notes/history, inference or permission from content; current-at-read is not a filesystem lock"
        });
        if let Some(filter) = filter {
            reply["format"] = json!("threadmark-file-scoped-retrieval");
            reply["version"] = json!(1);
            reply["incarnation"] = json!(p.incarnation);
            reply["selected_paths"] = json!(filter.selected_paths);
            reply["mode"] = json!(if literal {
                "literal"
            } else {
                "ranked-any-terms"
            });
            if literal {
                reply.as_object_mut().ok_or(invalid())?.remove("terms");
                reply["selection"] = json!("bounded-path-line-prefix");
                reply["coverage"] = json!("lexical-lines-only; no semantic coverage");
                reply["limitations"] = json!(
                    "SQLite ASCII lowercase substring only; full approved policy freshness reads; current-at-read is not a filesystem lock"
                );
            }
            // An explicit scope must never be silently truncated out of the frame.
            if serde_json::to_vec(&reply).map_err(unavailable)?.len() + 2 > 8192 {
                return Err(invalid());
            }
        }
        if let Some(inputs) = &inputs {
            // Precompute line tables once per source: no repeated lines().nth().
            let mut lookup = BTreeMap::new();
            for (source, text) in inputs {
                let lines: Vec<_> = text.lines().collect();
                if lines.len() > 4096 {
                    return Err(invalid());
                }
                lookup.insert(source.path.as_str(), (source, lines));
            }
            let mut best: Vec<Candidate> = Vec::with_capacity(9);
            let mut scanned = 0;
            let mut visited = 0;
            let mut matched = 0;
            let mut literal_match = if literal {
                Some(
                    self.db
                        .prepare("SELECT instr(lower(?1),lower(?2))>0")
                        .map_err(unavailable)?,
                )
            } else {
                None
            };
            let mut stmt = self.db.prepare(
                "SELECT path,line,text,hash,producer FROM evidence WHERE project=?1 ORDER BY path,line LIMIT 262145"
            ).map_err(unavailable)?;
            let mut rows = stmt.query([id]).map_err(unavailable)?;
            while let Some(row) = rows.next().map_err(unavailable)? {
                canceled(cancel)?;
                visited += 1;
                if visited > 64 * 4096 {
                    return Err(invalid());
                }
                let path: String = row.get(0).map_err(unavailable)?;
                let line: i64 = row.get(1).map_err(unavailable)?;
                let text: String = row.get(2).map_err(unavailable)?;
                let hash: String = row.get(3).map_err(unavailable)?;
                let producer: String = row.get(4).map_err(unavailable)?;
                if path.len() > 240 || text.len() > 1024 || hash.len() != 64 || producer.len() > 128
                {
                    return Err(invalid());
                }
                identity(&producer)?;
                let (source, lines) = lookup.get(path.as_str()).ok_or(invalid())?;
                let coordinate = usize::try_from(line)
                    .ok()
                    .and_then(|n| n.checked_sub(1))
                    .ok_or(invalid())?;
                if hash != source.hash || lines.get(coordinate).copied() != Some(text.as_str()) {
                    return Err(invalid());
                }
                if filter.is_some_and(|r| !r.selected_paths.contains(&path)) {
                    continue;
                }
                scanned += 1;
                let mut distinct = 0;
                let mut occurrences = 0;
                if let Some(matcher) = &mut literal_match {
                    // Match only selected, verified rows, using the exact existing
                    // SQLite folding (Rust Unicode lowercase is NOT equivalent).
                    distinct = usize::from(
                        matcher
                            .query_row(params![text, query], |r| r.get::<_, bool>(0))
                            .map_err(unavailable)?,
                    );
                    occurrences = distinct;
                } else {
                    let lower = text.to_lowercase();
                    for term in &terms {
                        let count = lower.matches(term.as_str()).count();
                        distinct += usize::from(count > 0);
                        occurrences += count;
                    }
                }
                if distinct == 0 {
                    continue;
                }
                matched += 1;
                best.push(Candidate {
                    path,
                    line,
                    text,
                    hash,
                    producer,
                    matched: distinct,
                    occurrences,
                });
                best.sort_by(|a, b| a.key().cmp(&b.key()));
                if best.len() > 8 {
                    best.pop();
                }
            }
            reply["scanned_anchors"] = json!(scanned);
            reply["matching_anchors"] = json!(matched);
            reply["truncated"] = json!(matched > best.len());
            for c in best {
                reply["results"].as_array_mut().ok_or(invalid())?.push(json!({
                    "project":id,"path":c.path,"line":c.line,"text":c.text,"source_hash":c.hash,
                    "producer":c.producer,"kind":"observed-source-line","currentness":"current-at-read",
                    "coverage":"lexical-only","matched_terms":c.matched,"occurrences":c.occurrences
                }));
                if literal {
                    let result = reply["results"]
                        .as_array_mut()
                        .ok_or(invalid())?
                        .last_mut()
                        .ok_or(invalid())?;
                    result
                        .as_object_mut()
                        .ok_or(invalid())?
                        .remove("matched_terms");
                    result
                        .as_object_mut()
                        .ok_or(invalid())?
                        .remove("occurrences");
                }
                // Include newline; reserve one byte for either boolean spelling.
                if serde_json::to_vec(&reply).map_err(unavailable)?.len() + 2 > 8192 {
                    reply["results"].as_array_mut().ok_or(invalid())?.pop();
                    reply["truncated"] = json!(true);
                    break;
                }
            }
        }
        ready();
        canceled(cancel)?;
        if filter.is_some() {
            self.healthy()?;
        }
        let latest = self.project(id)?;
        if latest.root != p.root
            || latest.root_identity != p.root_identity
            || latest.incarnation != p.incarnation
            || latest.sources != p.sources
            || latest.snapshot != p.snapshot
        {
            return Err(Error::ScopeMismatch);
        }
        // Suppress the complete snapshot if any approved file changed during ranking.
        if inputs.is_some() && self.current_query_inputs(&latest, cancel)?.is_none() {
            reply["results"] = json!([]);
            reply["currentness"] = json!("stale-or-unindexed");
            reply["matching_anchors"] = json!(0);
            reply["truncated"] = json!(false);
        }
        canceled(cancel)?;
        // Scope can change during the final source read as well.
        let final_policy = self.project(id)?;
        if final_policy.root != p.root
            || final_policy.root_identity != p.root_identity
            || final_policy.incarnation != p.incarnation
            || final_policy.sources != p.sources
            || final_policy.snapshot != p.snapshot
        {
            return Err(Error::ScopeMismatch);
        }
        canceled(cancel)?;
        if serde_json::to_vec(&reply).map_err(unavailable)?.len() + 1 > 8192 {
            return Err(invalid());
        }
        Ok(reply)
    }
}

#[cfg(test)]
mod tests;
