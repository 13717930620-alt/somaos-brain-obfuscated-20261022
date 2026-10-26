'use strict';
// 跨平台跑全套：显式列出 acceptance/*.test.js（不让 node 自行发现，避开商店版 python 之类的外部挂起）。
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const dir = __dirname;
const files = fs.readdirSync(dir).filter((n) => n.endsWith('.test.js')).sort().map((n) => path.join(dir, n));
if (!files.length) {
  console.error('acceptance/ 下没有找到 *.test.js');
  process.exit(2);
}
const args = ['--test', '--test-concurrency=1', ...files];
const r = spawnSync(process.execPath, args, { stdio: 'inherit', cwd: path.resolve(dir, '..') });
process.exit(r.status === null ? 1 : r.status);
