//! Explicit specific-stored-revision selection, not current policy or consent.
use super::*;

/// Immutable owned human-only selection. Callers separately obtain export consent.
pub struct ExportHumanRevisionsPlan {
    project: String,
    root: String,
    root_identity: String,
    incarnation: String,
    revisions: Vec<(String, u32)>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Selection {
    version: String,
    revisions: Vec<Revision>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Revision {
    id: String,
    revision: u32,
}

impl ExportHumanRevisionsPlan {
    /// Pure construction; copies exact binding bytes and canonicalizes unique pairs.
    pub fn new(
        project: &str,
        binding: &ContextReadBinding<'_>,
        revisions: &[(String, u32)],
    ) -> Result<Self> {
        binding.validate(project)?;
        if revisions.is_empty() || revisions.len() > 8 {
            return Err(invalid());
        }
        for (id, revision) in revisions {
            identity(id)?;
            if !(1..=32).contains(revision) {
                return Err(invalid());
            }
        }
        let mut canonical = revisions.to_vec();
        canonical.sort();
        if canonical.windows(2).any(|w| w[0] == w[1]) {
            return Err(invalid());
        }
        Ok(Self {
            project: project.into(),
            root: binding.root.into(),
            root_identity: binding.root_identity.into(),
            incarnation: binding.incarnation.into(),
            revisions: canonical,
        })
    }

    /// Closed bounded JSON selection, including duplicate-key rejection, before I/O.
    pub fn from_json(
        project: &str,
        binding: &ContextReadBinding<'_>,
        input: &[u8],
    ) -> Result<Self> {
        binding.validate(project)?;
        if input.len() > 4096 {
            return Err(invalid());
        }
        let selection: Selection = serde_json::from_slice(input).map_err(unavailable)?;
        if selection.version != "selected-human-revision-export-v1" {
            return Err(invalid());
        }
        Self::new(
            project,
            binding,
            &selection
                .revisions
                .into_iter()
                .map(|r| (r.id, r.revision))
                .collect::<Vec<_>>(),
        )
    }

    fn binding(&self) -> ContextReadBinding<'_> {
        ContextReadBinding {
            root: &self.root,
            root_identity: &self.root_identity,
            incarnation: &self.incarnation,
        }
    }
}

impl Store {
    /// Sensitive local content export; explicit caller consent is required separately.
    pub fn export_human_revisions(
        &self,
        plan: &ExportHumanRevisionsPlan,
        cancel: &AtomicBool,
    ) -> Result<Value> {
        self.read_human_bound(&plan.project, &plan.binding(), cancel, |tx, registration| {
            let marked = forget::markers(tx, &plan.project)?;
            canceled(cancel)?;
            if plan.revisions.iter().any(|(id, _)| marked.contains(id)) {
                return Err(invalid());
            }
            let count: i64 = tx.query_row("SELECT count(*) FROM context WHERE project=?1", [&plan.project], |r| r.get(0)).map_err(unavailable)?;
            if !(0..=4096).contains(&count) {
                return Err(invalid());
            }
            let mut records = Vec::with_capacity(plan.revisions.len());
            let mut at = 0;
            while at < plan.revisions.len() {
                canceled(cancel)?;
                let id = &plan.revisions[at].0;
                let history = Self::context_history_in(tx, &plan.project, id, cancel)?;
                #[cfg(test)]
                boundary();
                canceled(cancel)?;
                let rows = history["history"].as_array().ok_or_else(invalid)?;
                while at < plan.revisions.len() && &plan.revisions[at].0 == id {
                    let revision = plan.revisions[at].1;
                    let row = rows.get(revision as usize - 1).ok_or_else(invalid)?;
                    records.push(json!({"id":id,"revision":revision,"kind":row["kind"],"text":row["text"],
                        "retired_at_revision":row["retired"],"producer":"human-authored",
                        "authority":"context-not-authorization-or-observed-truth"}));
                    at += 1;
                }
            }
            let reply = json!({"format":"threadmark-selected-human-revision-export","version":1,
                "project":{"id":plan.project,"root_identity":registration.root_identity,"incarnation":registration.incarnation},
                "selection_semantics":"specific-stored-revisions-not-current-policy","count":records.len(),"records":records});
            // Encode once to a bounded counting sink, not the growing envelope per row.
            check_frame(&reply)?;
            #[cfg(test)]
            boundary();
            canceled(cancel)?;
            Ok(reply)
        })
    }
}

fn check_frame(reply: &Value) -> Result<()> {
    struct Budget(usize);
    impl std::io::Write for Budget {
        fn write(&mut self, bytes: &[u8]) -> std::io::Result<usize> {
            if bytes.len() > self.0 {
                return Err(std::io::Error::other("frame budget"));
            }
            self.0 -= bytes.len();
            Ok(bytes.len())
        }
        fn flush(&mut self) -> std::io::Result<()> {
            Ok(())
        }
    }
    serde_json::to_writer(Budget(65535), reply).map_err(unavailable)
}

#[cfg(test)]
std::thread_local! {
    static BOUNDARY: std::cell::RefCell<Option<Box<dyn FnMut()>>> = std::cell::RefCell::new(None);
}
#[cfg(test)]
fn boundary() {
    BOUNDARY.with_borrow_mut(|hook| {
        if let Some(hook) = hook {
            hook();
        }
    });
}

#[cfg(test)]
mod tests;
