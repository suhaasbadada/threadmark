'use strict';
// Fixed, separately hashed candidate. NOT RUN or approved by checking it in.
// Builtins only; no eval, package/SDK/config discovery, DNS or external targets.
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const net = require('node:net');
const dgram = require('node:dgram');
const moduleAPI = require('node:module');
const [mode, root, tcpPort, udpPort] = process.argv.slice(2);
const pass = label => process.stdout.write(label + ':PASS\n');
const permission = error => error && (error.code === 'EPERM' || error.code === 'EACCES');
function denied(label, operation) {
  try { operation(); } catch (error) {
    if (permission(error)) { pass(label); return; }
  }
  throw new Error('control failed');
}
function filesystem() {
  if (fs.readFileSync(path.join(root, 'read-canary'), 'utf8') !== 'synthetic-unchanged\n')
    throw new Error('control failed');
  pass('approved-read');
  for (const name of ['home', 'tmp', 'config', 'cache', 'data', 'state']) {
    const target = path.join(root, 'state', name, 'positive');
    fs.writeFileSync(target, 'owned\n', {flag: 'wx', mode: 0o600});
    if (fs.readFileSync(target, 'utf8') !== 'owned\n') throw new Error('control failed');
    pass('write-' + name);
  }
  const reads = {sibling: 'sibling', home: 'outside/home/.config/opencode/config.json',
    repo: 'outside/repository/AGENTS.md', config: 'outside/config/settings.json',
    'symlink-read': 'state/home/outside-link'};
  for (const [label, relative] of Object.entries(reads))
    denied('deny-' + label, () => fs.readFileSync(path.join(root, relative)));
  const writes = {'symlink-write': 'state/home/outside-link', 'workspace-write': 'workspace/check',
    'probe-write': 'probe.cjs', 'policy-write': 'guard.sb',
    'inventory-write': 'config-inventory/settings.json'};
  for (const [label, relative] of Object.entries(writes))
    denied('deny-' + label, () => fs.writeFileSync(path.join(root, relative), 'forbidden'));
  // A real spawn request. ENOENT/ENOEXEC or missing error are NOT denial evidence.
  const child = cp.spawnSync(path.join(root, 'exec-marker'), [], {env: {}, timeout: 500,
    maxBuffer: 1024, stdio: 'pipe', shell: false});
  if (!permission(child.error)) throw new Error('control failed');
  pass('deny-spawn');
  if (typeof moduleAPI.getCompileCacheDir !== 'function' ||
      typeof moduleAPI.enableCompileCache !== 'function' ||
      !moduleAPI.constants || !moduleAPI.constants.compileCacheStatus ||
      typeof moduleAPI.constants.compileCacheStatus.DISABLED !== 'number' ||
      moduleAPI.getCompileCacheDir() !== undefined ||
      moduleAPI.enableCompileCache().status !== moduleAPI.constants.compileCacheStatus.DISABLED ||
      moduleAPI.getCompileCacheDir() !== undefined) throw new Error('control failed');
  pass('cache-disabled');
}
function network(label, action) {
  const v6 = mode === 'v6';
  const host = v6 ? '::1' : '127.0.0.1';
  return new Promise((resolve, reject) => {
    let endpoint;
    let complete = false;
    const finish = error => {
      if (complete) return;
      complete = true;
      if (endpoint) {
        if (typeof endpoint.destroy === 'function') endpoint.destroy();
        else { try { endpoint.close(); } catch {} }
      }
      if (!permission(error)) { reject(new Error('control failed')); return; }
      pass(mode + '-' + label);
      resolve();
    };
    try {
      if (action === 'connect') {
        endpoint = new net.Socket();
        endpoint.once('error', finish);
        endpoint.once('connect', () => finish(null));
        endpoint.connect({host, port: Number(tcpPort), family: v6 ? 6 : 4});
      } else if (action === 'udp') {
        endpoint = dgram.createSocket(v6 ? 'udp6' : 'udp4');
        endpoint.once('error', finish);
        endpoint.send(Buffer.from('owned'), Number(udpPort), host, finish);
      } else if (action === 'bind') {
        endpoint = dgram.createSocket(v6 ? 'udp6' : 'udp4');
        endpoint.once('error', finish);
        endpoint.once('listening', () => finish(null));
        endpoint.bind({address: host, port: 0});
      } else {
        endpoint = net.createServer();
        endpoint.once('error', finish);
        endpoint.once('listening', () => finish(null));
        endpoint.listen({host, port: 0, ipv6Only: v6});
      }
    } catch (error) { finish(error); }
  });
}
async function main() {
  if (mode === 'filesystem' && process.argv.length === 4) filesystem();
  else if (['v4', 'v6'].includes(mode) && process.argv.length === 6 &&
           [tcpPort, udpPort].every(p => /^[1-9][0-9]{0,4}$/.test(p) && Number(p) <= 65535)) {
    for (const action of ['connect', 'udp', 'bind', 'listen']) await network(action, action);
  } else throw new Error('control failed');
}
// No error content, paths, stack or private bytes enter the output protocol.
main().catch(() => { process.exitCode = 1; });
