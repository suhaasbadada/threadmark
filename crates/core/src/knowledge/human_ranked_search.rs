//! Explicit human-note ranking; no source authority or filesystem reads.
use super::*;

/// Immutable validated normalized terms and canonical explicit kind selection.
#[derive(Clone, Debug)]
pub struct HumanRankedQuery {
    terms: Vec<String>,
    kinds: HumanSearchKinds,
}

impl HumanRankedQuery {
    /// Validate without opening storage; the raw query is never retained.
    pub fn new(query: &str, kinds: &[String]) -> Result<Self> {
        Ok(Self {
            terms: ranked_query::terms(query)?,
            kinds: HumanSearchKinds::new(kinds)?,
        })
    }

    /// Normalized distinct terms in first-seen order.
    pub fn terms(&self) -> &[String] {
        &self.terms
    }

    /// Explicit canonical kind selection.
    pub fn kinds(&self) -> &[String] {
        self.kinds.kinds()
    }
}

impl Store {
    /// Rank durable active latest human notes in one registration-bound snapshot.
    pub fn search_context_terms_bound(
        &self,
        project: &str,
        query: &HumanRankedQuery,
        binding: &ContextReadBinding<'_>,
        cancel: &AtomicBool,
    ) -> Result<Value> {
        self.read_human_bound(project, binding, cancel, |tx, registration| {
            self.search_context_mode_in(
                tx,
                registration,
                human_search::SearchMode::Ranked(query),
                cancel,
                || {},
            )
        })
    }
}

#[cfg(test)]
mod tests;
