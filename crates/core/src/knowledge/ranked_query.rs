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

    fn query_terms_with_progress(
        &self,
        id: &str,
        query: &str,
        cancel: &AtomicBool,
        mut ready: impl FnMut(),
    ) -> Result<Value> {
        canceled(cancel)?;
        validate_query_terms(id, query)?;
        let terms = terms(query)?;
        let p = self.project(id)?;
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
            let mut matched = 0;
            let mut stmt = self.db.prepare(
                "SELECT path,line,text,hash,producer FROM evidence WHERE project=?1 ORDER BY path,line LIMIT 262145"
            ).map_err(unavailable)?;
            let mut rows = stmt.query([id]).map_err(unavailable)?;
            while let Some(row) = rows.next().map_err(unavailable)? {
                canceled(cancel)?;
                scanned += 1;
                if scanned > 64 * 4096 {
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
                let lower = text.to_lowercase();
                let mut distinct = 0;
                let mut occurrences = 0;
                for term in &terms {
                    let count = lower.matches(term.as_str()).count();
                    distinct += usize::from(count > 0);
                    occurrences += count;
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
