import assert from 'node:assert/strict';
import { test } from 'node:test';
import { readFileSync } from 'node:fs';
import { performance } from 'node:perf_hooks';
import { PROMPT_LINK_LIMIT, parseDestination, prepareCopy, runtimeGate } from './prepare.mjs';

// No real user data, capability URLs, prompt-bearing public URLs, or host calls.
const destination = 'https://app.t3.codes/threads/synthetic-env/synthetic-thread';
const content = 'Do NOT rename synthetic_id_42. λ';
const review = (text = content, url = destination) => ({
  decision: 'copy', content: text, destination: url,
});
const prepare = (text = content, url = destination) => prepareCopy({
  content: text, destination: url, review: review(text, url),
});
const exact = (actual, expected) => assert.ok(actual === expected, 'exact comparison failed');

test('bare source-verified copied route preserves both IDs exactly, decoding once', () => {
  const url = 'https://app.t3.codes/threads/Env%2E1/thread%3Adelegated%2Fmcp%253A1%2E';
  const target = parseDestination(url);
  exact(target.environmentId, 'Env.1');
  exact(target.threadId, 'thread:delegated/mcp%3A1.');
  exact(prepare(content, url).target.threadId, target.threadId);
  const unicode = parseDestination('https://app.t3.codes/threads/%CE%BB/%E4%B8%AD%E6%96%87');
  exact(unicode.environmentId, 'λ');
  exact(unicode.threadId, '中文');
});

test('rejects malformed, implicit, internal display and new-thread destinations', () => {
  const bad = ['', null, 42, '/threads/e/t', 't3-thread://v1/t', 't3-thread://v2/e/t',
    't3code://threads/e/t', 'https://app.t3.codes/new',
    'https://app.t3.codes/e/t', 'https://app.t3.codes/threads/e',
    'https://app.t3.codes/threads//t', 'https://app.t3.codes/threads/e/t/extra',
    destination + '/', destination + '\n', ' ' + destination,
    destination.replace('/synthetic-thread', '/..'), destination.replace('/synthetic-thread', '/%2e%2e')];
  for (const url of bad) exact(parseDestination(url), null);
});

test('rejects origins, userinfo, ports, fragments and URL normalization tricks', () => {
  for (const url of [destination.replace('https:', 'http:'),
    destination.replace('app.t3.codes', 'evil.invalid'),
    destination.replace('app.t3.codes', 'app.t3.codes.evil.invalid'),
    destination.replace('app.t3.codes', 'user@app.t3.codes'),
    destination.replace('app.t3.codes', 'app.t3.codes@evil.invalid'),
    destination.replace('app.t3.codes', 'app.t3.codes:443'),
    destination.replace('app.t3.codes', 'APP.T3.CODES'),
    destination.replace('/threads/', '/x/../threads/'),
    destination.replace('/threads/', '\\threads/'), destination + '#', destination + '#synthetic'])
    exact(parseDestination(url), null);
});

test('rejects every query including empty, unknown, permissions, send and duplicate params', () => {
  for (const query of ['?', '?unknown=1', '?prompt=x', '?prompt=x&prompt=y',
    '?%70rompt=x&prompt=y', '?repo=a/b', '?pr=a/b/1', '?provider=synthetic',
    '?model=synthetic', '?send=true', '?permissionMode=full', '?permissions=full',
    '?branch=x', '?worktree=x', '?newthread=true', '?threadId=other'])
    exact(parseDestination(destination + query), null);
});

test('strict percent/UTF-8 decoding rejects replacement, malformed, blank and control IDs', () => {
  for (const id of ['%', '%GG', '%1', '%C0%AF', '%ED%A0%80', '%FF', '%E2%82',
    '%00', '%0A', '%09', '%20', '%E2%80%8B', '%EF%BB%BF'])
    exact(parseDestination('https://app.t3.codes/threads/e/' + id), null);
});

test('review requires exact raw destination, exact text and explicit copy decision', () => {
  for (const approval of [undefined, {}, { ...review(), decision: 'send' },
    { ...review(), decision: true }, { ...review(), content: content.replace('NOT ', '') },
    { ...review(), destination: destination.replace('synthetic-env', 'other-env') }]) {
    const result = prepareCopy({ destination, content, review: approval });
    exact(result.status, 'needs-review');
    exact(result.copyText, undefined);
  }
  const url = destination.replace('synthetic-thread', '%73ynthetic-thread');
  exact(prepareCopy({ destination: url, content, review: review() }).status, 'needs-review');
});

test('copy output preserves negation, identifiers, unicode and internal whitespace', () => {
  for (const text of [content, 'Do NOT change ID_9\n\tKeep  two spaces.',
    'é e\u0301 中文 👩‍💻 ❤️ !\'()*~ + & / % # ? =', 'x\u0085y']) {
    const result = prepare(text);
    if (text.includes('\u0085')) exact(result.status, 'needs-review');
    else {
      exact(result.status, 'copy-only');
      exact(result.copyText, text);
      exact(decodeURIComponent(encodeURIComponent(result.copyText)), text);
    }
  }
});

test('encodeURIComponent differs from URLSearchParams but both decode exact synthetic text', () => {
  const text = "Do NOT change id+1 !'()~* é";
  const encoded = encodeURIComponent(prepare(text).copyText);
  assert.ok(encoded.includes('%20') && encoded.includes('%2B') && encoded.includes("!'()~*"));
  const params = new URLSearchParams({ prompt: text });
  assert.ok(params.toString().includes('+') && params.toString().includes('%21'));
  exact(params.get('prompt'), text);
  exact(decodeURIComponent(encoded), text);
});

test('host-changing whitespace, line separators and invisible characters require re-review', () => {
  for (const text of [' leading', 'trailing ', '\nedge', 'a\r\nb', 'a\rb',
    'a\u2028b', 'a\u2029b', 'a\u200bb', 'a\u200cb', 'a\u200db',
    'a\u202eb', 'a\ufeffb', 'a\u00adb', 'a\u034fb', 'a\ufe00b',
    'a' + String.fromCodePoint(0xe0041) + 'b', '👩‍', '𠀀‍𠀁']) {
    const result = prepare(text);
    exact(result.status, 'needs-review');
    exact(result.reason, 'prompt-link-normalization');
    exact(result.copyText, undefined);
  }
});

test('prompt-link size limit counts raw UTF-16 units, not bytes or code points', () => {
  exact(PROMPT_LINK_LIMIT, 8000);
  for (const text of ['x'.repeat(8000), 'é'.repeat(8000), '😀'.repeat(4000)]) {
    exact(prepare(text).reason, 'local-uri-unsupported');
    exact(prepare(text).copyText, text);
  }
  for (const text of ['x'.repeat(8001), '😀'.repeat(4000) + 'x', '😀'.repeat(4001)]) {
    exact(prepare(text).reason, 'prompt-link-limit');
    exact(prepare(text).copyText, text); // Never truncate.
  }
  // Raw length exceeds host limit even though trimming could shrink it.
  exact(prepare(' ' + 'x'.repeat(8000)).status, 'needs-review');
});

test('rejects unpaired surrogates instead of lossy Unicode replacement', () => {
  for (const text of ['\ud800', 'x\udfff']) exact(prepare(text).reason, 'invalid-unicode');
});

test('bounded experiment accepts large copy, rejects beyond caps and empty text', () => {
  exact(prepare('x'.repeat(32)).status, 'copy-only');
  exact(prepare('x'.repeat(65536)).copyText.length, 65536);
  for (const text of ['', ' \n\t', null, 42, 'x'.repeat(65537)]) {
    const result = prepare(text);
    exact(result.status, 'rejected');
    exact(result.copyText, undefined);
  }
  exact(parseDestination('https://app.t3.codes/threads/e/' + 'x'.repeat(4096)), null);
});

test('cancel has zero output payload and does not even inspect inputs', () => {
  const result = prepareCopy({ cancelled: true,
    get destination() { throw Error('must not read destination'); },
    get content() { throw Error('must not read content'); },
    get review() { throw Error('must not read review'); },
  });
  exact(result.status, 'cancelled');
  exact(Object.keys(result).join(), 'status');
});

test('malformed top-level inputs return content-free rejection without throwing', () => {
  for (const input of [undefined, null, false, 1, 'synthetic', []]) {
    const result = prepareCopy(input);
    exact(result.status, 'rejected');
    exact(result.reason, 'input');
    exact(result.copyText, undefined);
  }
});

test('closed/occupied/unknown destination and acknowledgment never enable runtime or retry', () => {
  for (const state of ['closed', 'occupied', 'unknown', 'received', 'sent', 'cancelled', null, {}]) {
    const result = runtimeGate(state);
    exact(result.status, 'unsupported');
    exact(result.retry, false);
    exact(Object.keys(result).sort().join(), 'retry,status');
  }
});

test('private synthetic prompt never becomes a URL or content-bearing receipt', () => {
  const text = 'SYNTHETIC_PRIVATE: do NOT route identifier_9';
  const result = prepare(text);
  exact(Object.keys(result).sort().join(), 'copyText,reason,status,target');
  exact(result.copyText, text);
  for (const value of [result.status, result.reason, ...Object.values(result.target)])
    assert.ok(!value.includes(text) && !value.includes(encodeURIComponent(text)));
  exact(prepareCopy({ destination, content: text }).copyText, undefined);
});

test('component has no imports or effect APIs; repeated preparation is stateless', () => {
  const source = readFileSync(new URL('./prepare.mjs', import.meta.url), 'utf8');
  assert.ok(!/\b(import|require|fetch|process|console|setTimeout|setInterval)\b/.test(source));
  // RegExp.exec is the route parser, not a process execution API.
  assert.ok(!/\b(writeFile|spawn|execFile|openExternal|clipboard|send|launch)\s*\(/.test(source));
  exact(prepare().status, 'copy-only');
  exact(prepareCopy({ cancelled: true }).status, 'cancelled');
  exact(prepare().copyText, content);
});

test('bounded synthetic size sweep stays within provisional latency and RSS budgets', () => {
  const start = performance.now();
  for (const size of [32, 8000, 65536]) exact(prepare('x'.repeat(size)).copyText.length, size);
  assert.ok(performance.now() - start < 5000, 'latency budget exceeded');
  assert.ok(process.resourceUsage().maxRSS < 128 * 1024, 'RSS budget exceeded');
});
