'use strict';
// .jsc 字节码与 V8 版本强绑定：版本不符时必须明确失败，而不是给出误导性错误。
const NEED_NODE = "v24.15.0";
const NEED_V8 = "13.6.233.17-node.48";
const ok = process.version === NEED_NODE && process.versions.v8 === NEED_V8;
console.log(JSON.stringify({
  ok, needNode: NEED_NODE, needV8: NEED_V8,
  haveNode: process.version, haveV8: process.versions.v8,
  hint: ok ? null : '本发布件的 .jsc 由 bytenode 在 Node ' + NEED_NODE + ' / V8 ' + NEED_V8 + ' 下编译，只能在同版本 V8 上加载。请安装完全相同的 Node 版本（或向维护者索取对应版本的构建）。',
}, null, 2));
process.exit(ok ? 0 : 1);
