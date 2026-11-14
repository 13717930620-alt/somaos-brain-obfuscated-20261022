---
name: 缺陷报告
about: 报告运行异常、验收失败或文档与实际不符
title: '[BUG] '
labels: bug
---

## 环境

- Node 版本（`node -v`）：
- Python 版本（`python --version`）：
- 操作系统：
- 涉及的 dist：

## 复现步骤

```bash
# 1.
# 2.
```

## 期望结果

## 实际结果

```
# 错误栈 / 验收失败的具体用例名
```

## 已做的自查

- [ ] `node scripts/verify-abi.js` 退出码为 0
- [ ] `npm test` 已执行
- [ ] Node 版本为 v24.15.0

> 提醒：`.jsc` 与 V8 版本强绑定，Node 版本不符是"跑不起来"最常见的原因。
