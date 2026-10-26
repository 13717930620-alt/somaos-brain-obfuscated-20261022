'use strict';
// 单文件跑法：node acceptance/run-one.js acceptance/03_motion_cd.test.js
const path = require('path');
const { spawnSync } = require('child_process');

const target = process.argv[2];
if (!target) {
  console.error('用法: node acceptance/run-one.js <acceptance/xxx.test.js>');
  process.exit(2);
}
const abs = path.resolve(__dirname, path.basename(target));
const r = spawnSync(process.execPath, ['--test', abs], { stdio: 'inherit' });
process.exit(r.status === null ? 1 : r.status);
