# center-contract · 模型中心 · 契约层

**只声明，不判定。** 三份契约固化跨模块的数据形状与判定归属。

| 项 | 值 |
|---|---|
| 文件 | 27（11 `.jsc`） |
| 体积 | 0.10 MB |
| 外部依赖 | 0 |
| 产出 | 校验后的 `manifest` + 追加的 `verdict` |
| 验收 | 模型中心 13 条中的 2 条测契约层（用例随评估包，不在本仓库） |

---

## 三份契约

### `contracts/manifest.v1.json` — 云脑清单

| 必填字段 | 说明 |
|---|---|
| `manifestVersion` | 契约版本 |
| `embodimentId` | 本体标识，**全系统连接键** |
| `dof` | 自由度数 |
| `state` / `commands` / `safety` / `interfaces` | 状态、指令、安全、接口声明 |
| `readiness` | `commandable` / `blocked-no-transport` |

契约层**只追加**一个只读字段 `verdict`（`driveEvidence` / `motionSelfSufficiency` / `scopes` / `sources`），**绝不改写 `readiness`**。

### `contracts/verdict.v1.json` — 三维判定

| 维度 | 作用域 | 谁计算 | 枚举 |
|---|---|---|---|
| `driveEvidence` | A/B/C/D 全项目 | 仿生脑大底座 | `vendor-controller` / `joint-target-driver` / `no_transport_driver` / `none` |
| `motionSelfSufficiency` | 仅 C/D | 运动脑大底座 | `ready-real` / `ready-sim` / `needs-training` / `unsupported` |
| `commandable` | 运行态实时 | 运行层 | `true` / `false` |

### `contracts/roots.v1.json` — 代码根与证据根

声明哪个根提供哪类证据。门面据此判断证据是否齐全。

---

## 模块

| 模块 | 职责 |
|---|---|
| `src/compose.js` | 合成：按 `embodimentId` 把两侧结果并排 |
| `src/verify.js` | 校验：检查不变量（不合并、不硬套、不改写） |
| `src/cache.js` | 缓存：清单级缓存，不缓存判定 |
| `src/paths.js` | 路径解析（相对优先） |
| `src/adapters/bio.js` | 仿生脑侧字段映射 |
| `src/adapters/motion.js` | 运动侧字段映射 |
| `src/adapters/runtime.js` | 运行态字段映射 |
| `scripts/compose.js` | 命令行合成 |
| `scripts/run-jest.js` | 契约层自测驱动 |

---

## 四条不变量

写进契约文件本体，**违约即缺陷**：

```
1. 契约层只追加 verdict，绝不改写 readiness
2. 任何 manifest 改动后必须仍能通过 cloudBrainManifest.validateManifest()
3. 适配器不得出现基于 bio 与 motion 取值的条件分支
4. driveEvidence 与 motionSelfSufficiency 必须同时保留，不得压成一个 overall
```

### 第 3 条为什么最关键

一旦适配器开始"看 bio 的值得出 motion 的结论"，三层就塌回一层——判定逻辑重新混进映射层，两个维度的独立性立刻消失。

所以规则写死为：**适配器只做字段映射**。想加判定，去对应的底座，不要在适配器里加 `if`。

### 第 4 条的现实意义

同一台本体的真实状态可能是：

```json
{ "driveEvidence": "joint-target-driver", "motionSelfSufficiency": "needs-training" }
```

两句话同时为真且互不矛盾。压成一个 `overall` 只能表达其中一句，另一句被永久丢失。

---

## 验收覆盖

```
契约层：七条本体并排合成，双方判定都在
契约层：manifests 暴露 7 条登记本体
```

第一条的重点是「**双方判定都在**」——合成后 bio 与 mot 两侧字段都必须保留，不允许出现"合成时取其一"。

## 使用

```bash
node dist/center-contract/scripts/compose.js
```

或被 `center-facade` 调用（推荐）。

## 相关

- [../center-runtime/](../center-runtime/) — 运行层
- [../center-facade/](../center-facade/) — 门面
- [../../docs/MODEL_CENTER.md](../../docs/MODEL_CENTER.md) — 完整规格
