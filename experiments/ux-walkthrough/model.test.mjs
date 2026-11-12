import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { initial, transition as go, projects, blockers, identity, original } from './model.mjs';
const ready = () => go(go(go(initial(), { type: 'project', value: projects[0].id }), { type: 'choice', value: 'owners' }), { type: 'prepare' });
test('empty and material ambiguity fail closed', () => {
  assert.match(blockers(initial()), /select/);
  const s = go(go(initial(), { type: 'project', value: projects[0].id }), { type: 'prepare' });
  assert.match(s.candidate, /UNRESOLVED/);
  assert.equal(go(s, { type: 'review' }).review, null);
});
test('project switch cannot mix conflicting rules or retain approval', () => {
  const a = go(ready(), { type: 'review' });
  assert.ok(a.review);
  const b = go(a, { type: 'project', value: projects[1].id });
  assert.equal(b.review, null); assert.equal(b.candidate, ''); assert.equal(b.choice, '');
  const example = go(b, { type: 'prepare' });
  assert.ok(example.candidate.includes(projects[1].rule));
  assert.ok(!example.candidate.includes(projects[0].rule));
  assert.match(identity(b), /fixture-b202/);
});
for (const [type, value] of [['stale', true], ['worktree', 'alternate'], ['revision', 'changed'], ['candidate', 'Edited synthetic candidate'], ['choice', 'members'], ['unavailable', true]]) {
  test(`${type} invalidates reviewed scope/content`, () => {
    const s = go(go(ready(), { type: 'review' }), { type, value });
    assert.equal(s.review, null); assert.match(s.status, /invalidated/);
    if (['stale', 'worktree', 'revision', 'unavailable'].includes(type)) assert.equal(go(s, { type: 'review' }).review, null);
  });
}
test('recovery is explicit and never restores approval', () => {
  const stale = go(go(ready(), { type: 'review' }), { type: 'stale', value: true });
  const restored = go(stale, { type: 'stale', value: false });
  assert.equal(restored.review, null); assert.equal(blockers(restored), '');
});
test('project selection cannot silently recover the simulated shared daemon', () => {
  const unavailable = go(ready(), { type: 'unavailable', value: true });
  const switched = go(unavailable, { type: 'project', value: projects[1].id });
  assert.equal(switched.unavailable, true);
  assert.match(blockers(switched), /Unavailable daemon/);
  assert.equal(go(switched, { type: 'review' }).review, null);
  assert.equal(switched.candidate, '');
  const restored = go(switched, { type: 'unavailable', value: false });
  assert.equal(restored.review, null);
  assert.match(blockers(restored), /permissions are unresolved/);
});
test('cancel and degraded return retain immutable original without effects', () => {
  for (const type of ['cancel', 'return']) {
    const s = go(go(ready(), { type: 'unavailable', value: true }), { type });
    assert.equal(s.candidate, ''); assert.equal(s.review, null);
    assert.match(s.status, /Original fixture draft retained. Nothing copied or sent/);
    assert.equal(original, 'Add team invitations using what we already have. Do not send email or deploy.');
  }
});
test('bounded fixture inputs reject unknown identities and values', () => {
  for (const action of [{ type: 'project', value: 'private-project' }, { type: 'worktree', value: 'other' }, { type: 'candidate', value: 'x'.repeat(2001) }, { type: 'choice', value: 'automatic' }]) assert.throws(() => go(initial(), action));
});
test('permission changes discard the old permission-bearing example', () => {
  const s = go(ready(), { type: 'choice', value: 'members' });
  assert.equal(s.candidate, ''); assert.match(blockers(s), /no prepared/);
});
test('static browser surface has no external resources or delivery/storage APIs', () => {
  const html = readFileSync(new URL('./index.html', import.meta.url), 'utf8');
  const app = readFileSync(new URL('./app.mjs', import.meta.url), 'utf8');
  const model = readFileSync(new URL('./model.mjs', import.meta.url), 'utf8');
  const css = readFileSync(new URL('./style.css', import.meta.url), 'utf8');
  assert.match(html, /connect-src 'none'/);
  assert.match(html, /form-action 'none'/);
  assert.match(html, /role="status" aria-live="polite"/);
  assert.match(html, /<header>[\s\S]*id="identity"[\s\S]*<\/header>/);
  assert.match(css, /prefers-reduced-motion/);
  assert.match(css, /:focus-visible/);
  assert.doesNotMatch(app + model, /innerHTML|outerHTML|fetch\(|XMLHttpRequest|WebSocket|sendBeacon|clipboard|localStorage|indexedDB|serviceWorker|console\./);
  assert.doesNotMatch(html + css, /https?:|@import|type="file"|<form|<iframe/);
  for (const id of ['theme', 'project', 'worktree', 'revision', 'choice', 'candidate']) assert.ok(html.includes(`for="${id}"`));
});
