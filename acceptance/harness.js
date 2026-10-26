'use strict';
// 黑盒验收公共件：只通过发布件暴露的路径/接口访问，不引用 staging 或原始树。
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const DIST = path.join(ROOT, 'dist');
const DISTS = [
  'brain-a', 'brain-b', 'arm-c', 'humanoid-d',
  'base-core', 'base-bio', 'base-motion',
  'center-contract', 'center-runtime', 'center-facade',
];

function dist(name) {
  return path.join(DIST, name);
}

function load(name, rel) {
  return require(path.join(DIST, name, rel));
}

function walk(dir, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) {
      if (e.name !== 'node_modules' && e.name !== '.git') walk(p, out);
      continue;
    }
    out.push(p);
  }
  return out;
}

function eventBus() {
  const events = [];
  return {
    events,
    publish(topic, payload, meta) {
      events.push({ topic, payload, meta });
    },
  };
}

function noWalk() {
  return { canWalk: false, bipedal: false, canManipulate: true };
}

function walker() {
  return { canWalk: true, bipedal: true, canManipulate: false };
}

module.exports = { ROOT, DIST, DISTS, dist, load, walk, eventBus, noWalk, walker };
