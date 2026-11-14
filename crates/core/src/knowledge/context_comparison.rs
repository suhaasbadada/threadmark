//! Explicit textual revision review, never semantic conflict resolution.
use super::*;

const MAX_JSON_BYTES: usize = 65536;

/// Validate comparison scope and revision arguments before storage or stdin.
pub fn validate_context_comparison(
    project: &str,
    id: &str,
    from: u32,
    to: u32,
    binding: &ContextReadBinding<'_>,
) -> Result<()> {
    binding.validate(project)?;
    identity(id)?;
    if !(1..=32).contains(&from) || !(from..=32).contains(&to) {
        return Err(invalid());
    }
    Ok(())
}

impl Store {
    /// Compare two explicit revisions in one registration-bound human snapshot.
    pub fn context_comparison_bound(
        &self,
        project: &str,
        id: &str,
        from: u32,
        to: u32,
        binding: &ContextReadBinding<'_>,
        cancel: &AtomicBool,
    ) -> Result<Value> {
        validate_context_comparison(project, id, from, to, binding)?;
        self.read_human_bound(project, binding, cancel, |tx, _| {
            Self::context_comparison_in(tx, project, id, from, to)
        })
    }

    fn context_comparison_in(
        tx: &rusqlite::Transaction<'_>,
        project: &str,
        id: &str,
        from: u32,
        to: u32,
    ) -> Result<Value> {
        // Reuse complete history validation inside the admitted transaction, not
        // either public history method. Both selections come from this one value.
        let history = Self::context_in(tx, project, id)?;
        #[cfg(test)]
        if let Some(hook) = AFTER_HISTORY.with_borrow_mut(Option::take) {
            hook();
        }
        let rows = history["history"].as_array().ok_or_else(invalid)?;
        let old = rows.get(from as usize - 1).ok_or_else(invalid)?;
        let new = rows.get(to as usize - 1).ok_or_else(invalid)?;
        let old_text = old["text"].as_str().ok_or_else(invalid)?;
        let new_text = new["text"].as_str().ok_or_else(invalid)?;
        let reply = json!({
            "version":"human-context-comparison-v1", "project":project, "id":id,
            "producer":"human-authored",
            "authority":"context-not-authorization-or-observed-truth",
            "from":{"revision":from,"kind":old["kind"],"retired":old["retired"]},
            "to":{"revision":to,"kind":new["kind"],"retired":new["retired"]},
            "text_changed":old_text != new_text,
            "kind_changed":old["kind"] != new["kind"],
            "retirement_changed":old["retired"] != new["retired"],
            "delta":delta(old_text, new_text)
        });
        bounded_reply(reply)
    }
}

fn bounded_reply(reply: Value) -> Result<Value> {
    let encoded = serde_json::to_vec(&reply).map_err(unavailable)?;
    if encoded.len() >= MAX_JSON_BYTES {
        return Err(invalid());
    }
    Ok(reply)
}

fn delta(old: &str, new: &str) -> Value {
    let a: Vec<&str> = old.split_inclusive('\n').collect();
    let b: Vec<&str> = new.split_inclusive('\n').collect();
    let prefix = a.iter().zip(&b).take_while(|(a, b)| a == b).count();
    let suffix = a[prefix..]
        .iter()
        .rev()
        .zip(b[prefix..].iter().rev())
        .take_while(|(a, b)| a == b)
        .count();
    json!({
        "algorithm":"common-prefix-suffix-logical-lines-not-minimal",
        "prefix":a[..prefix].concat(),
        "from":a[prefix..a.len()-suffix].concat(),
        "to":b[prefix..b.len()-suffix].concat(),
        "suffix":a[a.len()-suffix..].concat()
    })
}

#[cfg(test)]
std::thread_local! {
    static AFTER_HISTORY: std::cell::RefCell<Option<Box<dyn FnOnce()>>> =
        std::cell::RefCell::new(None);
}

#[cfg(test)]
mod tests;
