// Disposable fixture controller. No IO, persistence, host or provider capability.
export const original = 'Add team invitations using what we already have. Do not send email or deploy.';
export const projects = Object.freeze([
  Object.freeze({ id: 'fixture-cedar', name: 'Cedar', worktree: 'fixture/cedar/main', revision: 'fixture-a101', rule: 'Use the existing queued invitation path.', anchor: 'fixture-only:cedar/decisions.md#queue' }),
  Object.freeze({ id: 'fixture-cedar-lab', name: 'Cedar Lab', worktree: 'fixture/cedar-lab/experiment', revision: 'fixture-b202', rule: 'Do not use a queue; keep invitations as local previews.', anchor: 'fixture-only:cedar-lab/decisions.md#preview' }),
]);
export function initial() {
  return { project: '', worktree: 'primary', revision: 'current', stale: false, unavailable: false, choice: '', candidate: '', review: null, status: 'Select a synthetic project. No sources have been read.' };
}
export function identity(s) {
  const p = projects.find(p => p.id === s.project);
  return p ? `${p.name} [${p.id}] · ${p.worktree}${s.worktree === 'alternate' ? '-alternate' : ''} · ${p.revision}${s.revision === 'changed' ? '-changed' : ''}` : 'No project selected';
}
export function blockers(s) {
  if (!s.project) return 'Blocked: select a fixture project.';
  if (s.unavailable) return 'Unavailable daemon (simulation). Original fixture draft is safe. Return without enrichment or cancel.';
  if (s.stale || s.worktree !== 'primary' || s.revision !== 'current') return 'Blocked: stale or mismatched fixture evidence. Restore the declared fixture scope; no refresh has run.';
  if (!s.choice) return 'Blocked: invitation permissions are unresolved. Choose a proposed policy for this example or leave unresolved.';
  if (!s.candidate.trim()) return 'Blocked: no prepared example to review.';
  return '';
}
export function transition(state, action) {
  const s = { ...state };
  const invalid = 'Prior review invalidated. Nothing copied or sent.';
  switch (action.type) {
    case 'project':
      if (!projects.some(p => p.id === action.value) && action.value !== '') throw new Error('Unknown fixture');
      return { ...initial(), project: action.value, unavailable: state.unavailable, status: 'Fixture scope selected. Other project rules excluded. Nothing copied or sent.' };
    case 'worktree': case 'revision': case 'choice': case 'stale': case 'unavailable': case 'candidate': {
      const valid = { worktree: ['primary', 'alternate'], revision: ['current', 'changed'], choice: ['', 'owners', 'members'] };
      if (valid[action.type] && !valid[action.type].includes(action.value)) throw new Error('Invalid fixture choice');
      if (['stale', 'unavailable'].includes(action.type) && typeof action.value !== 'boolean') throw new Error('Invalid condition');
      if (action.type === 'candidate' && (typeof action.value !== 'string' || action.value.length > 2000)) throw new Error('Candidate exceeds fixture budget');
      s[action.type] = action.value;
      if (action.type === 'choice') s.candidate = '';
      s.review = null;
      s.status = invalid;
      return s;
    }
    case 'prepare': {
      const p = projects.find(p => p.id === s.project);
      s.review = null;
      s.candidate = p ? `Canned example — no model used.\nOriginal: ${original}\nDecision (fixture only): ${p.rule}\nProposed permission: ${s.choice || 'UNRESOLVED; ask the user'}. This is not authorization.\nVerify tenant boundaries, repeated acceptance and expiry using synthetic tests. No execution is authorized.` : '';
      s.status = 'Canned example loaded; inspect differences and evidence. No model used. Nothing copied or sent.';
      return s;
    }
    case 'review':
      s.status = blockers(s) || 'Marked reviewed (simulation). Nothing copied or sent.';
      s.review = blockers(s) ? null : { identity: identity(s), candidate: s.candidate, choice: s.choice };
      return s;
    case 'cancel': case 'return':
      s.candidate = ''; s.review = null;
      s.status = `${action.type === 'cancel' ? 'Canceled' : 'Returned without enrichment'}. Original fixture draft retained. Nothing copied or sent.`;
      return s;
    default: throw new Error('Unknown action');
  }
}
