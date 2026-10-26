'use strict';
// 发布件形态验收：不含明文源码 / 不含个人路径 / 依赖与 ABI 自检可用。
const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { ROOT, DIST, DISTS, dist, walk } = require('./harness');

const distJs = [];
const distPyc = [];
const allRepoFiles = [];
for (const d of DISTS) {
  for (const p of walk(dist(d))) {
    if (/\.js$/.test(p)) distJs.push(p);
    if (/\.pyc$/.test(p)) distPyc.push(p);
  }
}
for (const p of walk(ROOT)) allRepoFiles.push(p);

test('10 个 dist 齐全且各自有 package.json', () => {
  assert.deepStrictEqual(fs.readdirSync(DIST).sort(), [...DISTS].sort());
  for (const d of DISTS) {
    const pkg = path.join(dist(d), 'package.json');
    assert.ok(fs.existsSync(pkg), `${d}/package.json 缺失`);
    const j = JSON.parse(fs.readFileSync(pkg, 'utf8'));
    assert.ok(j.name && j.version, `${d}/package.json 缺 name/version`);
  }
});

test('dist 内所有 .js 都是 bytenode 桩（体积小、无函数体、指向同名 .jsc）', () => {
  assert.ok(distJs.length >= 1000, `stub 数量异常: ${distJs.length}`);
  for (const p of distJs) {
    const st = fs.statSync(p);
    assert.ok(st.size <= 400, `${path.relative(ROOT, p)} 体积 ${st.size}B，疑似明文源码`);
    const txt = fs.readFileSync(p, 'utf8');
    assert.match(txt, /require\(['"]bytenode['"]\)/, `${path.relative(ROOT, p)} 未加载 bytenode`);
    assert.match(txt, /require\(['"]\.\/[^'"]+\.jsc['"]\)/, `${path.relative(ROOT, p)} 未指向 .jsc`);
    assert.ok(fs.existsSync(p.replace(/\.js$/, '.jsc')), `${path.relative(ROOT, p)} 缺同名 .jsc`);
  }
});

test('dist 内没有 plaintext JS 源码（>400B 的 .js 视为泄露）', () => {
  const big = distJs.filter((p) => fs.statSync(p).size > 400)
    .map((p) => `${path.relative(ROOT, p)}=${fs.statSync(p).size}B`);
  assert.deepStrictEqual(big, []);
});

test('Python 一律 sourceless .pyc，且数量与 magic 符合 3.11.9', () => {
  const py = [];
  for (const d of DISTS) for (const p of walk(dist(d))) if (/\.py$/.test(p)) py.push(p);
  assert.deepStrictEqual(py, []);
  assert.ok(distPyc.length >= 800, `pyc 数量异常: ${distPyc.length}`);
  for (const p of distPyc) {
    const head = fs.readFileSync(p).subarray(0, 4).toString('hex');
    assert.strictEqual(head, 'a70d0d0a', `${path.relative(ROOT, p)} magic=${head}`);
  }
});

test('全仓（含二进制）不含未掩码的 Users 用户名路径与个人标识', () => {
  const hits = [];
  const userRe = /(?:[A-Za-z]:[\\/]{1,8})?Users[\\/]{1,8}([A-Za-z0-9_.-]{1,32})/g;
  const selfId = '13' + '717';
  for (const p of allRepoFiles) {
    const buf = fs.readFileSync(p);
    for (const s of [buf.toString('latin1'), buf.toString('utf16le')]) {
      for (const m of s.matchAll(userRe)) {
        if (!/^redac/.test(m[1])) hits.push(`${path.relative(ROOT, p)}:Users\\${m[1]}`);
      }
    }
    if (buf.includes(Buffer.from(selfId, 'utf8')) || buf.includes(Buffer.from(selfId, 'utf16le'))) {
      hits.push(`${path.relative(ROOT, p)}:personal-id`);
    }
  }
  assert.deepStrictEqual(hits, []);
});

test('仓库根文件与 .gitignore 关键项齐全', () => {
  for (const f of ['LICENSE', 'NOTICE.md', 'SECURITY.md', 'README.md', '.gitignore', 'package.json']) {
    assert.ok(fs.existsSync(path.join(ROOT, f)), `${f} 缺失`);
  }
  const gi = fs.readFileSync(path.join(ROOT, '.gitignore'), 'utf8');
  for (const line of ['node_modules', 'staging', 'memory_store', '.env']) {
    assert.match(gi, new RegExp(`^${line.replace('.', '\\.')}/?$`, 'm'), `.gitignore 缺 ${line}`);
  }
  const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, 'package.json'), 'utf8'));
  assert.ok(pkg.dependencies && pkg.dependencies.bytenode, '未声明 bytenode 依赖');
  assert.match(pkg.scripts.test, /acceptance/, 'test 脚本未指向 acceptance');
});

test('ABI 自检脚本退出码为 0', () => {
  const out = execFileSync(process.execPath, [path.join(ROOT, 'scripts', 'verify-abi.js')], { encoding: 'utf8' });
  const j = JSON.parse(out);
  assert.strictEqual(j.ok, true);
  assert.strictEqual(j.haveNode, j.needNode);
  assert.strictEqual(j.haveV8, j.needV8);
});
