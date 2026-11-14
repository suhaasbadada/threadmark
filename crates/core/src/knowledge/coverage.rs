//! Explicit metadata-only diagnosis; no implicit Build and no content publication.
use super::*;

#[cfg(test)]
thread_local! {
    static CANCEL_AFTER_CHUNKS: std::cell::Cell<Option<usize>> = const { std::cell::Cell::new(None) };
}

#[cfg(test)]
pub(super) fn observe_chunk(cancel: &AtomicBool) {
    CANCEL_AFTER_CHUNKS.with(|n| {
        if let Some(left) = n.get() {
            if left <= 1 {
                n.set(None);
                cancel.store(true, Ordering::SeqCst);
            } else {
                n.set(Some(left - 1));
            }
        }
    });
}

/// Pure complete-binding validation before storage or source access.
pub fn validate_coverage_binding(expected: &Project) -> Result<()> {
    validate_query_binding(expected, "coverage")
}

#[derive(Debug, PartialEq, Eq)]
struct Observation {
    source: Source,
    bytes: usize,
    lines: usize,
}

#[derive(Debug, PartialEq, Eq)]
struct ObservedFile {
    admitted: Option<Observation>,
    // Refused bytes/unsafe metadata may be compared privately, never relabeled
    // as a current hash or disclosed in JSON.
    refused_fingerprint: Option<Source>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct ManifestSource {
    path: String,
    hash: String,
    identity: String,
}

fn hash_valid(hash: &str) -> bool {
    hash.len() == 64
        && hash
            .bytes()
            .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
}

fn identity_valid(identity: &str) -> bool {
    identity.split_once(':').is_some_and(|(dev, ino)| {
        !dev.is_empty()
            && !ino.is_empty()
            && dev.bytes().all(|b| b.is_ascii_digit())
            && ino.bytes().all(|b| b.is_ascii_digit())
            && dev.parse::<u64>().is_ok()
            && ino.parse::<u64>().is_ok()
    })
}

fn output_bound(reply: &Value) -> Result<()> {
    if serde_json::to_vec(reply).map_err(unavailable)?.len() + 1 > MAX_FILE {
        return Err(invalid());
    }
    Ok(())
}

fn scan(
    p: &Project,
    anchors: &[(usize, usize, String)],
    baseline: Option<&[Source]>,
    cancel: &AtomicBool,
) -> Result<Vec<ObservedFile>> {
    canceled(cancel)?;
    let root = directory(Path::new(&p.root))?;
    if file_identity(&root)? != p.root_identity {
        return Err(Error::ScopeMismatch);
    }
    let mut total = 0;
    let mut observations = Vec::new();
    for (i, path) in p.sources.iter().enumerate() {
        canceled(cancel)?;
        let mut refused_fingerprint = None;
        let admitted = match read_source(&root, path, cancel, &mut total) {
            Ok((source, text)) => {
                let lines: Vec<_> = text.lines().collect();
                if lines.len() > 4096 {
                    return Err(invalid());
                }
                if baseline.is_some_and(|m| m[i] == source) {
                    for (_, line, stored) in anchors.iter().filter(|(index, _, _)| *index == i) {
                        canceled(cancel)?;
                        if lines.get(line - 1).copied() != Some(stored.as_str()) {
                            return Err(invalid());
                        }
                    }
                }
                Some(Observation {
                    source,
                    bytes: text.len(),
                    lines: lines.len(),
                })
            }
            Err(SourceReadError::File(_)) => None,
            Err(SourceReadError::Observed(_, fingerprint, lines)) => {
                if lines > 4096 {
                    return Err(invalid());
                }
                refused_fingerprint = Some(fingerprint);
                None
            }
            Err(SourceReadError::Whole(e)) => return Err(e),
        };
        observations.push(ObservedFile {
            admitted,
            refused_fingerprint,
        });
    }
    if file_identity(&directory(Path::new(&p.root))?)? != p.root_identity {
        return Err(Error::ScopeMismatch);
    }
    canceled(cancel)?;
    Ok(observations)
}

impl Store {
    /// Inspect all and only explicitly approved files; no unbound convenience form.
    pub fn coverage_report(&self, expected: &Project, cancel: &AtomicBool) -> Result<Value> {
        self.coverage_scoped(expected, cancel, || {}, || {})
    }

    fn coverage_scoped(
        &self,
        expected: &Project,
        cancel: &AtomicBool,
        before_sources: impl FnOnce(),
        ready: impl FnOnce(),
    ) -> Result<Value> {
        validate_coverage_binding(expected)?;
        canceled(cancel)?;
        self.healthy()?;
        let tx = self.db.unchecked_transaction().map_err(unavailable)?;
        schema::validate(&tx)?;
        let p = self.query_project(&expected.id, Some(expected))?;
        let journal: String = tx
            .pragma_query_value(None, "journal_mode", |r| r.get(0))
            .map_err(unavailable)?;
        if journal != "delete" {
            return Err(Error::Unavailable);
        }
        let encoded: Option<String> = tx
            .query_row("SELECT manifest FROM projects WHERE id=?1", [&p.id], |r| {
                r.get(0)
            })
            .map_err(unavailable)?;
        let baseline: Option<Vec<Source>> = match (&p.snapshot, encoded) {
            (None, None) => None,
            (Some(snapshot), Some(encoded)) => {
                if encoded.len() > 32768 || *snapshot != sha256(encoded.as_bytes()) {
                    return Err(invalid());
                }
                let manifest: Vec<ManifestSource> =
                    serde_json::from_str(&encoded).map_err(unavailable)?;
                let manifest: Vec<Source> = manifest
                    .into_iter()
                    .map(|s| Source {
                        path: s.path,
                        hash: s.hash,
                        identity: s.identity,
                    })
                    .collect();
                if manifest.len() != p.sources.len() {
                    return Err(invalid());
                }
                for (s, path) in manifest.iter().zip(&p.sources) {
                    if s.path != *path
                        || !hash_valid(&s.hash)
                        || s.identity.len() > 128
                        || !identity_valid(&s.identity)
                    {
                        return Err(invalid());
                    }
                }
                Some(manifest)
            }
            _ => return Err(invalid()),
        };
        // Validate every record before source authorization; corrupt or out-of-policy
        // evidence is a whole failure even when its file would be unreadable.
        let mut counts = vec![0_usize; p.sources.len()];
        let mut anchors = Vec::new();
        let mut stmt = tx.prepare("SELECT path,line,text,hash,producer FROM evidence WHERE project=?1 ORDER BY path,line LIMIT 16385").map_err(unavailable)?;
        let mut rows = stmt.query([&p.id]).map_err(unavailable)?;
        while let Some(row) = rows.next().map_err(unavailable)? {
            canceled(cancel)?;
            if anchors.len() == 16384 {
                return Err(invalid());
            }
            let path: String = row.get(0).map_err(unavailable)?;
            let line: i64 = row.get(1).map_err(unavailable)?;
            let text: String = row.get(2).map_err(unavailable)?;
            let hash: String = row.get(3).map_err(unavailable)?;
            let producer: String = row.get(4).map_err(unavailable)?;
            identity(&producer)?;
            let i = p.sources.iter().position(|s| *s == path).ok_or(invalid())?;
            if !(1..=4096).contains(&line)
                || text.len() > 1024
                || text.trim().is_empty()
                || text.contains(['\0', '\n'])
                || baseline.as_ref().is_none_or(|m| m[i].hash != hash)
            {
                return Err(invalid());
            }
            counts[i] += 1;
            anchors.push((i, line as usize, text));
        }
        drop(rows);
        drop(stmt);
        before_sources();
        let initial = scan(&p, &anchors, baseline.as_deref(), cancel)?;
        let mut files = Vec::new();
        let mut readable = 0;
        let mut matching = 0;
        for (i, observed) in initial.iter().enumerate() {
            let observation = &observed.admitted;
            let stored = baseline.as_ref().map(|m| &m[i]);
            let matches = observation
                .as_ref()
                .is_some_and(|o| stored == Some(&o.source));
            matching += usize::from(matches);
            let (status, metadata) = match observation {
                None => ("unavailable-or-unsafe", Value::Null),
                Some(o) => {
                    readable += 1;
                    let status = match stored {
                        Some(s) if s.identity != o.source.identity => "replaced",
                        Some(s) if s.hash != o.source.hash => "changed",
                        _ if o.bytes == 0 => "readable-empty",
                        None => "unindexed",
                        Some(_) => "current",
                    };
                    (
                        status,
                        json!({"byte_count":o.bytes,"line_count":o.lines,"hash":o.source.hash}),
                    )
                }
            };
            files.push(
                json!({"path":p.sources[i],"baseline_exists":stored.is_some(),
                "stored_anchor_record_count":counts[i],"current_metadata":metadata,
                "baseline_matches":matches,"status":status}),
            );
        }
        let current = baseline.is_some() && matching == p.sources.len();
        let needs_build = if baseline.is_none() || matching < readable {
            json!(true)
        } else if readable < p.sources.len() {
            Value::Null // Unavailable does not prove a new Build is necessary.
        } else {
            json!(false)
        };
        let reply = json!({"format":"threadmark-coverage-report","version":1,
            "project":p.id,"root_identity":p.root_identity,"incarnation":p.incarnation,
            "baseline_snapshot":p.snapshot,"coverage":"lexical-only",
            "semantic_completeness":"not-assessed","review_scope":"explicit-approved-files-only",
            "files":files,"summary":{"approved_file_count":p.sources.len(),
                "readable_file_count":readable,"unavailable_file_count":p.sources.len()-readable,
                "matching_file_count":matching,"stored_anchor_record_count":anchors.len(),
                "project_snapshot_current":current,"needs_build":needs_build,
                "needs_readability_review":readable != p.sources.len()}});
        output_bound(&reply)?;
        ready();
        canceled(cancel)?;
        self.healthy()?;
        schema::validate(&tx)?;
        let after = scan(&p, &anchors, baseline.as_deref(), cancel)?;
        if initial != after {
            return Err(Error::ScopeMismatch);
        }
        self.query_project(&p.id, Some(&p))?;
        canceled(cancel)?;
        tx.commit().map_err(unavailable)?;
        canceled(cancel)?;
        Ok(reply)
    }
}

#[cfg(test)]
mod tests;
