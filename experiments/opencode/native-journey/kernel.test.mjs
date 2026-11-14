import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createJourney, prepare, stableJSON } from './kernel.js';

const scope = { directory: '/synthetic/project', projectID: 'synthetic-project', revision: 'synthetic-revision' };
const input = () => ({ sessionID: 'synthetic-session', delivery: 'queue', prompt: {
  text: '@agent use $skill; keep branch, scope and constraints unchanged',
  files: [{ uri: 'data:text/plain,synthetic', source: { type: 'inline' }, name: 'fixture.txt' }],
  agents: [{ name: 'agent', mention: { start: 0, end: 6, text: '@agent' } }],
  skills: [{ id: 'skill', mention: { start: 11, end: 17, text: '$skill' } }],
} });
function harness(options = {}) {
  const sends = [];
  const events = [];
  const journey = createJourney({ scope, reviewMs: 1000,
    notify: (e) => { events.push(e); }, prompt: async (p) => {
      sends.push(p);
      return { id: 'synthetic-inbox-id', sessionID: p.sessionID, type: 'user', delivery: p.delivery,
        payload: { ...p, ...(p.skills ? { skills: p.skills.map((s) => ({ ...s, name: 'Synthetic skill', text: 'Synthetic resolved content' })) } : {}) } };
    }, ...options });
  const claim = (sessionID = 'synthetic-session', owner = 'synthetic-ui') => journey.pending({ sessionID, owner });
  const decision = (p, decision = 'approve') => ({ sessionID: p.candidate.sessionID,
    candidateID: p.candidate.candidateID, digest: p.candidate.digest, owner: p.owner, claim: p.claim, decision });
  return { journey, sends, events, claim, decision };
}

test('immutable deterministic preparation preserves original, mention offsets and exact metadata', () => {
  const i = input(); const before = structuredClone(i); const c = prepare(i, scope);
  assert.deepEqual(i, before);
  assert.deepEqual(c.original, i.prompt);
  assert.equal(c.prepared.text.slice(0, i.prompt.text.length), i.prompt.text);
  for (const k of ['files', 'agents', 'skills']) assert.deepEqual(c.prepared[k], i.prompt[k]);
  assert.equal(c.digest, prepare(i, scope).digest);
  assert.notEqual(c.candidateID, prepare(i, scope).candidateID);
  assert.throws(() => { c.prepared.files[0].uri = 'changed'; }, TypeError);
  i.prompt.text = 'changed'; assert.equal(c.original.text, before.prompt.text);
  assert.notEqual(c.digest, prepare(before, { ...scope, revision: 'other' }).digest);
  assert.equal(stableJSON({ b: 2, a: 1 }), '{"a":1,"b":2}');
});

test('zero admission before approval; exact one prompt and actual receipt ID after approval', async () => {
  const h = harness(); const result = h.journey.run(input());
  const p = h.claim(); assert.equal(h.sends.length, 0);
  const receipt = await h.journey.decide(h.decision(p));
  assert.deepEqual(receipt, { status: 'inbox-receipt-attachments-unverified', attempts: 1, receiptID: 'synthetic-inbox-id' });
  assert.deepEqual(await result, receipt); assert.equal(h.sends.length, 1);
  assert.equal(p.candidate.resume, false);
  assert.deepEqual(h.sends[0], { ...p.candidate.prepared, sessionID: input().sessionID, delivery: 'queue', resume: false });
  assert.equal((await h.journey.decide(h.decision(p))).status, 'rejected');
  assert.equal(h.sends.length, 1); h.journey.dispose();
});

for (const decision of ['cancel', 'closed']) test(`${decision}: zero admission`, async () => {
  const h = harness(); const r = h.journey.run(input()); const p = h.claim();
  await h.journey.decide(h.decision(p, 'cancel'));
  assert.equal((await r).status, 'canceled'); assert.equal(h.sends.length, 0); h.journey.dispose();
});

test('aborted approval, unload and late approval cannot send', async () => {
  for (const mode of ['abort', 'unload']) {
    const h = harness(); const r = h.journey.run(input()); const p = h.claim();
    const controller = new AbortController();
    if (mode === 'abort') controller.abort(); else h.journey.dispose();
    await h.journey.decide(h.decision(p), controller.signal);
    assert.equal((await r).attempts, 0); assert.equal(h.sends.length, 0); h.journey.dispose();
  }
});

test('disconnect/no decision expires; stale approval cannot affect recovery invocation', async () => {
  const h = harness({ reviewMs: 10 }); const r = h.journey.run(input()); const p = h.claim();
  assert.equal((await r).status, 'expired');
  const next = h.journey.run(input());
  assert.equal((await h.journey.decide(h.decision(p))).status, 'rejected');
  assert.equal(h.sends.length, 0);
  h.journey.dispose(); assert.equal((await next).status, 'unloaded');
});

test('duplicate invocation/approval and competing TUI ownership fail closed', async () => {
  let complete;
  const h = harness({ prompt: () => new Promise((r) => { complete = r; }) });
  const r = h.journey.run(input()); const p = h.claim();
  assert.equal(h.claim('synthetic-session', 'other-ui'), null);
  assert.equal((await h.journey.run(input())).status, 'blocked');
  const approval = h.journey.decide(h.decision(p));
  assert.equal((await h.journey.decide(h.decision(p))).status, 'rejected');
  h.journey.dispose(); complete({ admitted: true });
  assert.equal((await r).status, 'unknown'); assert.equal((await approval).attempts, 1);
});

test('mismatch of session, candidate, digest, owner or claim never sends', async () => {
  const h = harness(); const r = h.journey.run(input()); const p = h.claim();
  for (const key of ['sessionID', 'candidateID', 'digest', 'owner', 'claim']) {
    assert.equal((await h.journey.decide({ ...h.decision(p), [key]: 'wrong' })).status, 'rejected');
  }
  assert.equal(h.sends.length, 0); h.journey.dispose(); await r;
});

for (const mode of ['throw', 'hang', 'fake', 'wrong-session', 'wrong-text', 'wrong-delivery', 'wrong-skill']) {
  test(`ambiguous ${mode} is unknown, bounded and never retried`, async () => {
    let attempts = 0;
    const h = harness({ reviewMs: 10, prompt: async (p) => {
      attempts++;
      if (mode === 'throw') throw new Error('synthetic failure');
      if (mode === 'hang') return new Promise(() => {});
      const receipt = { id: 'synthetic-id', type: 'user', sessionID: p.sessionID, delivery: p.delivery,
        payload: { ...p } };
      if (mode === 'fake') return { admitted: true };
      if (mode === 'wrong-session') receipt.sessionID = 'wrong';
      if (mode === 'wrong-text') receipt.payload.text = 'wrong';
      if (mode === 'wrong-delivery') receipt.delivery = 'steer';
      if (mode === 'wrong-skill') receipt.payload.skills = [{ id: 'other', name: 'Other' }];
      return receipt;
    } });
    const r = h.journey.run(input()); const p = h.claim();
    assert.equal((await h.journey.decide(h.decision(p))).status, 'unknown');
    assert.equal((await r).status, 'unknown');
    assert.equal((await h.journey.run(input())).status, 'blocked');
    await h.journey.decide(h.decision(p)); assert.equal(attempts, 1); h.journey.dispose();
  });
}

test('notification dependency failure blocks admission and allows a fresh explicit invocation', async () => {
  let first = true;
  const h = harness({ notify: async () => { if (first) { first = false; throw new Error('synthetic transport failure'); } } });
  assert.equal((await h.journey.run(input())).status, 'unavailable');
  const recovered = h.journey.run(input()); const p = h.claim();
  await h.journey.decide(h.decision(p, 'cancel'));
  assert.equal((await recovered).status, 'canceled');
  assert.equal(h.sends.length, 0); h.journey.dispose();
});

test('late host completion after timeout cannot upgrade unknown or trigger a retry', async () => {
  let complete; let sent;
  const h = harness({ reviewMs: 10, prompt: (p) => { sent = p; return new Promise((r) => { complete = r; }); } });
  const r = h.journey.run(input()); const p = h.claim();
  const decided = h.journey.decide(h.decision(p));
  assert.equal((await r).status, 'unknown');
  complete({ id: 'synthetic-late-id', type: 'user', sessionID: sent.sessionID, delivery: sent.delivery, payload: sent });
  assert.equal((await decided).status, 'unknown');
  assert.equal((await h.journey.run(input())).status, 'blocked'); h.journey.dispose();
});

test('unsupported/oversize values and network/filesystem attachments rejected without sends', async () => {
  const cases = [
    (i) => { i.prompt.text = 'x'.repeat(2049); },
    (i) => { i.prompt.extra = 'unknown'; },
    (i) => { i.prompt.files[0].uri = 'https://example.invalid/synthetic'; },
    (i) => { i.prompt.files[0].uri = 'file:///synthetic/private'; },
    (i) => { i.prompt.files[0].mime = 'text/plain'; },
    (i) => { i.prompt.agents[0].mention.end = 7; },
    (i) => { i.prompt.skills = undefined; },
    (i) => { i.prompt.files = Array(5).fill(i.prompt.files[0]); },
    (i) => { i.delivery = 'unknown'; },
  ];
  for (const mutate of cases) {
    const h = harness(); const i = input(); mutate(i);
    await assert.rejects(h.journey.run(i), /unsupported bounded input/);
    assert.equal(h.sends.length, 0); h.journey.dispose();
  }
});

test('no-attachment receipt is inbox admission, not processing or completion proof', async () => {
  const h = harness(); const i = input(); delete i.prompt.files; delete i.prompt.skills;
  const r = h.journey.run(i); const p = h.claim();
  assert.equal((await h.journey.decide(h.decision(p))).status, 'inbox-receipt');
  assert.equal((await r).attempts, 1); h.journey.dispose();
});

test('file-only receipt retains identity without claiming resolved bytes verified', async () => {
  const h = harness(); const i = input(); delete i.prompt.skills;
  const r = h.journey.run(i); const p = h.claim();
  assert.equal((await h.journey.decide(h.decision(p))).status, 'inbox-receipt-files-unverified');
  assert.equal((await r).receiptID, 'synthetic-inbox-id'); h.journey.dispose();
});
