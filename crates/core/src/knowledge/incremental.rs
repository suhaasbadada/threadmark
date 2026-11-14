//! Explicit bounded lexical SQL-row reuse. Never skips approved-source reads.
use super::*;

#[cfg(test)]
thread_local! {
    static CANCEL_CHUNK: std::cell::Cell<bool> = const { std::cell::Cell::new(false) };
}
#[cfg(test)]
pub(super) fn observe_chunk(cancel: &AtomicBool) {
    CANCEL_CHUNK.with(|n| {
        if n.replace(false) {
            cancel.store(true, Ordering::SeqCst);
        }
    });
}

/// Pure complete-capture validation before opening storage or source paths.
pub fn validate_incremental_binding(expected: &Project) -> Result<()> {
    validate_query_binding(expected, "incremental")?;
    if expected.sources.iter().any(|s| s.starts_with("--")) {
        return Err(invalid());
    }
    Ok(())
}

// Shared anchor admission with the existing full-index path. Preserve extractor
// ordering and error behavior; incremental always supplies LexicalLines.
pub(super) fn stage<'a>(
    inputs: &'a [(Source, String)],
    extractor: &mut impl SourceExtractor,
    cancel: &AtomicBool,
) -> Result<Vec<(&'a Source, usize, &'a str)>> {
    let mut evidence = Vec::new();
    for (source, text) in inputs {
        canceled(cancel)?;
        let lines: Vec<_> = text.lines().collect();
        if lines.len() > 4096 {
            return Err(invalid());
        }
        let selected = extractor.extract(text, cancel)?;
        if selected.len() > 4096 {
            return Err(invalid());
        }
        let mut seen = std::collections::BTreeSet::new();
        for line in selected {
            canceled(cancel)?;
            let value = line
                .checked_sub(1)
                .and_then(|i| lines.get(i))
                .ok_or(invalid())?;
            if !seen.insert(line) || value.len() > 1024 || value.trim().is_empty() {
                return Err(invalid());
            }
            evidence.push((source, line, *value));
            if evidence.len() > 16384 {
                return Err(invalid());
            }
        }
    }
    Ok(evidence)
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct ManifestSource {
    path: String,
    hash: String,
    identity: String,
}

fn hash_valid(s: &str) -> bool {
    s.len() == 64
        && s.bytes()
            .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
}
fn identity_valid(s: &str) -> bool {
    s.len() <= 128
        && s.split_once(':').is_some_and(|(a, b)| {
            [a, b].iter().all(|v| {
                !v.is_empty() && v.bytes().all(|c| c.is_ascii_digit()) && v.parse::<u64>().is_ok()
            })
        })
}

struct Row {
    line: usize,
    text: String,
    producer: String,
}

struct Baseline {
    manifest: Option<Vec<Source>>,
    rows: Vec<Vec<Row>>,
}

// All persisted inputs are bounded and validated before source traversal. This
// transaction remains the captured authority through staging and publication.
fn baseline(tx: &rusqlite::Transaction<'_>, p: &Project, cancel: &AtomicBool) -> Result<Baseline> {
    let encoded: Option<String> = tx
        .query_row("SELECT manifest FROM projects WHERE id=?1", [&p.id], |r| {
            r.get(0)
        })
        .map_err(unavailable)?;
    let manifest = match (&p.snapshot, encoded) {
        (None, None) => None,
        (Some(snapshot), Some(encoded)) => {
            if encoded.len() > 32768 || *snapshot != sha256(encoded.as_bytes()) {
                return Err(invalid());
            }
            let rows: Vec<ManifestSource> = serde_json::from_str(&encoded).map_err(unavailable)?;
            if rows.len() != p.sources.len() {
                return Err(invalid());
            }
            let mut sources = Vec::new();
            for (r, path) in rows.into_iter().zip(&p.sources) {
                canceled(cancel)?;
                if r.path != *path || !hash_valid(&r.hash) || !identity_valid(&r.identity) {
                    return Err(invalid());
                }
                sources.push(Source {
                    path: r.path,
                    hash: r.hash,
                    identity: r.identity,
                });
            }
            Some(sources)
        }
        _ => return Err(invalid()),
    };
    let mut evidence: Vec<Vec<Row>> = p.sources.iter().map(|_| Vec::new()).collect();
    let mut stmt = tx.prepare("SELECT path,line,text,hash,producer FROM evidence WHERE project=?1 ORDER BY path,line LIMIT 16385").map_err(unavailable)?;
    let mut rows = stmt.query([&p.id]).map_err(unavailable)?;
    let mut count = 0;
    while let Some(r) = rows.next().map_err(unavailable)? {
        canceled(cancel)?;
        count += 1;
        let path: String = r.get(0).map_err(unavailable)?;
        let line: i64 = r.get(1).map_err(unavailable)?;
        let text: String = r.get(2).map_err(unavailable)?;
        let hash: String = r.get(3).map_err(unavailable)?;
        let producer: String = r.get(4).map_err(unavailable)?;
        identity(&producer)?;
        let i = p.sources.iter().position(|s| *s == path).ok_or(invalid())?;
        if count > 16384
            || !(1..=4096).contains(&line)
            || text.len() > 1024
            || text.trim().is_empty()
            || text.contains(['\0', '\n'])
            || manifest.as_ref().is_none_or(|m| m[i].hash != hash)
        {
            return Err(invalid());
        }
        evidence[i].push(Row {
            line: line as usize,
            text,
            producer,
        });
    }
    Ok(Baseline {
        manifest,
        rows: evidence,
    })
}

fn require_capture(tx: &rusqlite::Transaction<'_>, p: &Project) -> Result<()> {
    Store::require_project_root(tx, p)?;
    let (policy, snapshot): (String, Option<String>) = tx
        .query_row(
            "SELECT sources,snapshot FROM projects WHERE id=?1",
            [&p.id],
            |r| Ok((r.get(0)?, r.get(1)?)),
        )
        .map_err(unavailable)?;
    if serde_json::from_str::<Vec<String>>(&policy).map_err(unavailable)? != p.sources
        || snapshot != p.snapshot
    {
        return Err(Error::ScopeMismatch);
    }
    source_forget::require_allowed(tx, &p.id, &p.sources)
}

impl Store {
    /// Explicit manual lexical rebuild with validated SQL evidence-row reuse.
    /// No unbound form, filesystem skip, inference, or automatic refresh.
    pub fn index_incremental(&mut self, expected: &Project, cancel: &AtomicBool) -> Result<Value> {
        self.index_incremental_with_progress(expected, cancel, |_| {})
    }

    /// Finite synchronous stages; all cancellation before commit rolls back.
    pub fn index_incremental_with_progress(
        &mut self,
        expected: &Project,
        cancel: &AtomicBool,
        mut progress: impl FnMut(IndexStage),
    ) -> Result<Value> {
        validate_incremental_binding(expected)?;
        canceled(cancel)?;
        self.healthy()?;
        let tx = rusqlite::Transaction::new_unchecked(
            &self.db,
            rusqlite::TransactionBehavior::Immediate,
        )
        .map_err(unavailable)?;
        schema::validate(&tx)?;
        if schema::version(&tx)? < 3 {
            return Err(Error::ScopeMismatch);
        }
        let p = self.query_project(&expected.id, Some(expected))?;
        require_capture(&tx, &p)?;
        let Baseline {
            manifest: old,
            rows,
        } = baseline(&tx, &p, cancel)?;
        let inputs = Self::read_sources(&p, cancel)?;
        progress(IndexStage::Read);
        canceled(cancel)?;
        let evidence = stage(&inputs, &mut LexicalLines, cancel)?;
        let manifest: Vec<_> = inputs.iter().map(|(s, _)| s.clone()).collect();
        let mut reuse = vec![false; inputs.len()];
        for (i, (source, text)) in inputs.iter().enumerate() {
            canceled(cancel)?;
            if old.as_ref().is_some_and(|m| m[i] == *source) {
                let lines: Vec<_> = text.lines().collect();
                for r in &rows[i] {
                    canceled(cancel)?;
                    if lines.get(r.line - 1).copied() != Some(r.text.as_str()) {
                        return Err(invalid());
                    }
                }
                let selected: Vec<_> = evidence
                    .iter()
                    .filter(|(s, _, _)| s.path == source.path)
                    .collect();
                let lexical = rows[i].iter().all(|r| r.producer == "lexical-lines-v1");
                if lexical {
                    if rows[i].len() != selected.len()
                        || rows[i]
                            .iter()
                            .zip(&selected)
                            .any(|(r, (_, line, text))| r.line != *line || r.text != *text)
                    {
                        return Err(invalid());
                    }
                    reuse[i] = true;
                }
            }
        }
        progress(IndexStage::Extracted);
        canceled(cancel)?;
        require_capture(&tx, &p)?;
        let after: Vec<_> = Self::read_sources(&p, cancel)?
            .into_iter()
            .map(|(s, _)| s)
            .collect();
        if manifest != after {
            return Err(Error::ScopeMismatch);
        }
        let encoded = serde_json::to_string(&manifest).map_err(unavailable)?;
        let snapshot = sha256(encoded.as_bytes());
        let reused_files = reuse.iter().filter(|&&r| r).count();
        let reused_anchors: usize = rows
            .iter()
            .zip(&reuse)
            .filter(|(_, r)| **r)
            .map(|(r, _)| r.len())
            .sum();
        let deleted_anchors: usize = rows
            .iter()
            .zip(&reuse)
            .filter(|(_, r)| !**r)
            .map(|(r, _)| r.len())
            .sum();
        let snapshot_updated = p.snapshot.as_ref() != Some(&snapshot);
        let persistent_writes = snapshot_updated || reused_files != inputs.len();
        let reply = json!({"format":"threadmark-incremental-lexical-index","version":1,
            "project":p.id,"baseline_snapshot":p.snapshot,"snapshot":snapshot,
            "files":inputs.len(),"anchors":evidence.len(),"reused_files":reused_files,
            "reindexed_files":inputs.len()-reused_files,"reused_anchors":reused_anchors,
            "written_anchors":evidence.len()-reused_anchors,"deleted_anchors":deleted_anchors,
            "snapshot_updated":snapshot_updated,"persistent_writes":persistent_writes,
            "coverage":"lexical-lines-only; no semantic coverage","empty":evidence.is_empty()});
        if serde_json::to_vec(&reply).map_err(unavailable)?.len() + 1 > MAX_FILE {
            return Err(invalid());
        }
        self.healthy()?;
        require_capture(&tx, &p)?;
        for (i, (source, _)) in inputs.iter().enumerate() {
            canceled(cancel)?;
            if reuse[i] {
                continue;
            }
            tx.execute(
                "DELETE FROM evidence WHERE project=?1 AND path=?2",
                params![p.id, source.path],
            )
            .map_err(unavailable)?;
            for (_, line, text) in evidence.iter().filter(|(s, _, _)| s.path == source.path) {
                canceled(cancel)?;
                tx.execute(
                    "INSERT INTO evidence VALUES(?1,?2,?3,?4,?5,?6)",
                    params![
                        p.id,
                        source.path,
                        *line as i64,
                        text,
                        source.hash,
                        "lexical-lines-v1"
                    ],
                )
                .map_err(unavailable)?;
            }
        }
        if snapshot_updated {
            tx.execute(
                "UPDATE projects SET snapshot=?2,manifest=?3 WHERE id=?1",
                params![p.id, snapshot, encoded],
            )
            .map_err(unavailable)?;
        }
        progress(IndexStage::ReadyToCommit);
        canceled(cancel)?;
        self.healthy()?;
        schema::validate(&tx)?;
        // Our own snapshot update is validated separately from captured approval.
        let published = Project {
            snapshot: Some(snapshot),
            ..p
        };
        require_capture(&tx, &published)?;
        let final_manifest: Vec<_> = Self::read_sources(&published, cancel)?
            .into_iter()
            .map(|(s, _)| s)
            .collect();
        if manifest != final_manifest {
            return Err(Error::ScopeMismatch);
        }
        canceled(cancel)?;
        tx.commit().map_err(unavailable)?;
        Ok(reply)
    }
}

#[cfg(test)]
mod tests;
