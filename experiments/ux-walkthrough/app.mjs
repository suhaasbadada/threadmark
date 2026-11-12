import { initial, transition, identity, blockers, projects, original } from './model.mjs';
let state = initial();
const el = id => document.getElementById(id);
function render() {
  const p = projects.find(p => p.id === state.project);
  for (const id of ['project', 'worktree', 'revision', 'choice', 'candidate']) el(id).value = state[id];
  for (const id of ['stale', 'unavailable']) el(id).checked = state[id];
  for (const id of ['identity', 'review-identity']) el(id).textContent = identity(state);
  el('scope').textContent = p ? `Selected synthetic scope only: ${p.id}. No context from another project.` : 'Empty: select a fixture; no context available.';
  el('rule').textContent = p ? p.rule : 'No decision selected.';
  el('anchor').textContent = p ? `Evidence anchor (not a file link): ${p.anchor} · evidence worktree ${p.worktree} · evidence revision ${p.revision}` : 'No provenance anchor selected.';
  el('original').textContent = original;
  el('blocker').textContent = blockers(state) || 'Example available for manual review; no delivery capability.';
  el('review').disabled = Boolean(blockers(state));
  el('prepare').disabled = !p || state.unavailable || state.stale || state.worktree !== 'primary' || state.revision !== 'current';
  el('stage').textContent = state.review ? `Reviewed scope (simulation): ${state.review.identity}. Nothing copied or sent.` : 'No applicable review.';
  el('status').textContent = state.status;
}
for (const id of ['project', 'worktree', 'revision', 'choice', 'stale', 'unavailable', 'candidate']) {
  el(id).addEventListener(id === 'candidate' ? 'input' : 'change', event => {
    state = transition(state, { type: id, value: event.target.type === 'checkbox' ? event.target.checked : event.target.value });
    render();
  });
}
for (const id of ['prepare', 'review', 'return', 'cancel']) el(id).addEventListener('click', () => {
  state = transition(state, { type: id }); render();
});
el('theme').addEventListener('change', event => { document.documentElement.dataset.theme = event.target.value; });
render();
