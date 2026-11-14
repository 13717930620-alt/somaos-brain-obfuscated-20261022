# 模型中心规格

> 模型中心（Model Center）不训练模型、不跑控制回路、不连真机。
> 它回答三个问题：**能装什么**（契约）、**怎么跑**（运行）、**现在到底行不行**（门面）。

## 1. 为什么需要这一层

把多个异构模型装进一台机器人，实际会撞上三类问题：

| 问题 | 典型症状 |
|---|---|
| **形状不一致** | 每台本体的清单字段名不同，上层代码到处写 `if (family === 'arm')` |
| **结论不可比** | A 模块说"能跑"，B 模块说"不支持"，没人知道谁对 |
| **降级被当成就绪** | 缺权重时系统还能启动，于是被读成"能力已具备" |

模型中心的存在意义，就是把这三件事**分别锁死在三个层里**，任何一层都不许越界替别人做决定。

```
┌────────────────────────────────────────────────┐
│ ③ 门面 facade    唯一入口，唯一结论形状        │
│   ↑ 只读，不改写                               │
│ ② 运行 runtime   只监督运行态，不产生关节目标  │
│   ↑ 只读契约，不缓存判定                       │
│ ① 契约 contract  只声明字段与归属，不计算档位  │
└────────────────────────────────────────────────┘
```

---

## 2. ① 契约层 `center-contract`

**做**：固化跨模块的数据形状与判定归属。
**不做**：不做任何判定，不写任何业务分支。

### 2.1 `manifest.v1.json` — 云脑清单契约

固化 `cloudBrainManifest` 的输出形状，字段一个不改（运行层 113 条用例已钉死它）。

| 字段 | 类型 | 说明 |
|---|---|---|
| `manifestVersion` | int | 契约版本 |
| `embodimentId` | string | 本体标识，**全系统的连接键** |
| `dof` | int | 自由度数 |
| `state` | object | 当前状态 |
| `commands` | object | 可下发的指令集 |
| `safety` | object | 安全约束 |
| `interfaces` | object | 对外接口声明 |
| `readiness` | enum | `commandable` / `blocked-no-transport` |

契约层**追加**（不修改）一个只读字段：

```json
{
  "appended": {
    "verdict": {
      "driveEvidence": "string",
      "motionSelfSufficiency": "string",
      "scopes": "object",
      "sources": "object"
    }
  }
}
```

### 2.2 `verdict.v1.json` — 三维判定契约

这是整套能力模型的核心。**三个维度作用域不同，因此不允许合并。**

| 维度 | 作用域 | 谁计算 | 枚举 |
|---|---|---|---|
| `driveEvidence` | 全项目 A/B/C/D（含代码根 B） | 仿生脑大底座 | `vendor-controller` / `joint-target-driver` / `no_transport_driver` / `none` |
| `motionSelfSufficiency` | **仅 C/D**，结构性不回落规格根 | 运动脑大底座 | `ready-real` / `ready-sim` / `needs-training` / `unsupported` |
| `commandable` | 运行态实时 | 运行层 | `true` / `false` |

三个维度的语义差别：

- `driveEvidence` 回答"**整个项目里**有没有这台本体的真机指令通路证据"——它可以由别的树的证据推断而来（`evidenceKind: inferred`）。
- `motionSelfSufficiency` 回答"**运动树自己**能不能自足指挥"——它不允许借别处的证据，所以同一个本体完全可能 `driveEvidence = joint-target-driver` 而 `motionSelfSufficiency = unsupported`。
- `commandable` 回答"**此刻**能不能下发"——鉴权、安全、传输三关都过才为 `true`，且只在运行态计算，不落盘。

**这就是为什么不能压成一个 overall**：一个本体"项目里有驱动通路"和"这棵运动树自己能指挥"是两件独立的事，合并会同时丢失两条信息。

### 2.3 `roots.v1.json` — 代码根与证据根

声明代码根与证据根的对应关系。门面据此判断证据是否齐全，缺根直接判 `degraded`。

### 2.4 契约层的不变量

以下四条写进契约文件本体，属于**违约即缺陷**的级别：

```
1. 契约层只追加 verdict，绝不改写 readiness
2. 任何 manifest 改动后必须仍能通过 cloudBrainManifest.validateManifest()
3. 适配器不得出现基于 bio 与 motion 取值的条件分支
4. driveEvidence 与 motionSelfSufficiency 必须同时保留，不得压成一个 overall
```

第 3 条是最容易被破坏的一条：一旦适配器开始"看 bio 的值得出 motion 的结论"，三层就塌回一层了。

### 2.5 适配器

| 适配器 | 职责 |
|---|---|
| `adapters/bio.js` | 仿生脑侧字段映射 |
| `adapters/motion.js` | 运动侧字段映射 |
| `adapters/runtime.js` | 运行态字段映射 |

**只做字段映射，不做判定。** 配套模块：`compose.js`（合成）、`verify.js`（校验）、`cache.js`（缓存）、`paths.js`（路径解析）。

---

## 3. ② 运行层 `center-runtime`

**做**：监督运行态、管理传输、执行安全三道门、上报状态。
**不做**：不产生关节目标、不跑控制回路、不连真机。

> 原话见 `output/runtime_status.json` 的 `note` 字段：
> *"本运行层不产生关节目标、不跑控制回路、不连真机。readiness=real 需要真实且已探活的传输层。"*

### 3.1 模块

| 模块 | 职责 |
|---|---|
| `safetySupervisor.js` | 安全三道门 |
| `executionTransport.js` | 传输层抽象 |
| `manifestSource.js` | 从契约层取清单 |
| `cloudServiceLayer.js` | 云服务编排 |
| `statusReport.js` | 运行态上报 |
| `runtime.js` | 生命周期与状态机 |

### 3.2 安全三道门

```
请求 ──▶ ① 速率门 ──▶ ② 看门狗门 ──▶ ③ 复位令牌门 ──▶ 放行
              │              │                  │
              └── 超速 ──────┴── 超时 ──────────┴── 未授权 ──▶ 拒绝 + 记录
```

三道门是**串联**的，任何一道不过即拒绝，且拒绝原因要能区分（便于运维定位）。

### 3.3 传输抽象与 readiness

`transport.kind` 只有三种：

| kind | `isReal` | 含义 |
|---|---|---|
| `null` | false | 无传输，最保守 |
| `loopback` | false | 自环，能跑通但不代表接了硬件 |
| 真实 | true | 已探活的物理通路 |

`readiness` 的判定：

```
readiness = real  ⇔  transport.isReal === true ∧ 已探活
否则              →  blocked（armCode 说明卡在哪一门）
```

只有 loopback 且云未配置时，输出：

```json
{
  "readiness": "blocked",
  "armed": false,
  "armStage": "cloud",
  "armCode": "CLOUD_UNCONFIGURED"
}
```

**这是刻意设计的"诚实失败"**：宁可报 `blocked` 并说明卡在哪，也不要报一个看起来正常的假就绪。

### 3.4 单本体运行态输出示例

```json
{
  "id": "franka_7dof",
  "readiness": "commandable",
  "dof": 7,
  "jointWindows": 7,
  "verbsAllowed": 5,
  "verbsConditional": 0,
  "verbsBlocked": 8,
  "withNoTransport": { "readiness": "blocked", "armCode": "NO_TRANSPORT" }
}
```

`verbsAllowed` / `verbsConditional` / `verbsBlocked` 三档把"哪些指令现在能发、哪些要条件、哪些禁止"量化出来——这是给上层做决策用的，不是给人看的形容词。

---

## 4. ③ 门面 `center-facade`

**做**：提供唯一入口，把七台本体的 bio / motion 结果并排合成一个总览。
**不做**：不合并档位、不掩盖缺失、不落盘。

### 4.1 输出结构

```json
{
  "joinKey": "embodiment.id",
  "persist": false,
  "forbidRootMerge": true,
  "degraded": false,
  "requireMissingRootsEmpty": true,
  "verdictSource": "../center-contract",
  "bio": { "root": "../brain-a", "evidenceRoots": [...], "missing": [] },
  "mot": { "specRoot": "../brain-a", "evidenceRoots": [...], "missing": [] },
  "rows": [ ... ]
}
```

四个关键开关：

| 字段 | 值 | 含义 |
|---|---|---|
| `joinKey` | `embodiment.id` | 两棵树只能按本体 id 对齐，不能按数组下标 |
| `forbidRootMerge` | `true` | 两棵树的证据**禁止互相顶替** |
| `persist` | `false` | 总览不落盘，每次现算 |
| `requireMissingRootsEmpty` | `true` | 有缺根时拒绝出结论 |

### 4.2 每行结构

```json
{
  "id": "franka_7dof",
  "family": "arm",
  "bio": {
    "overall": "ready-real",
    "simTier": "none",
    "realTier": "joint-target-driver",
    "countedForReadiness": 0,
    "evidenceKind": "inferred",
    "inferredFrom": ["franka_droid"]
  },
  "mot": {
    "overall": "unsupported",
    "simTier": "none",
    "realTier": "no_transport_driver",
    "counted": 0
  }
}
```

注意这一行的真实含义：**bio 侧 `ready-real`，mot 侧 `unsupported`**。它同时告诉你两件事——仿生脑侧有真机通路证据（且是从 `franka_droid` 推断的，`evidenceKind: inferred`），但运动树自己不自足。

如果有人把它读成"这台能跑"，就是误读。**门面保留矛盾，正是为了让误读无处藏身。**

### 4.3 `degraded` 语义

`degraded = true` 表示"这份总览的证据不完整"，**不等于系统坏了**，也不等于能力就绪。三种常见成因：

1. 证据根缺失（`missing` 非空）
2. 本发布不含权重，学习/推理能力处于降级态
3. 传输层未配置

---

## 5. 一次完整调用链

```
上层请求能力总览
   │
   ├─▶ facade.overview()
   │      ├─▶ contract: 读 roots.v1 → 确认证据根齐全？
   │      │       └─ 缺根 → degraded=true（若 requireMissingRootsEmpty 则中止）
   │      ├─▶ base-bio:  产出 manifest + driveEvidence
   │      ├─▶ base-motion: 产出 manifest + motionSelfSufficiency
   │      ├─▶ contract.adapters: 只映射字段，不判定
   │      ├─▶ contract.verify: 校验不变量（不合并、不硬套）
   │      └─▶ 合成 rows（joinKey = embodiment.id）
   │
   └─▶ runtime.statusReport()
          ├─▶ safetySupervisor: 三道门状态
          ├─▶ executionTransport: transport.kind / isReal
          └─▶ readiness / armCode
```

---

## 6. 常见误读清单

| 误读 | 实际含义 |
|---|---|
| "`degraded: false` 说明能力全就绪" | 只说明证据根齐全，不说明权重在位 |
| "`bio.overall = ready-real` 说明这台能跑" | 只说明全项目有驱动通路证据，看 `mot` 才知道运动侧 |
| "`commandable = true` 说明能安全执行" | 说明鉴权/安全/传输三关过了，不代表任务能成功 |
| "`verbsBlocked = 8` 是缺陷" | 是设计：明确列出此刻禁止的指令，比隐式失败好 |
| "两个 overall 合并成一个更简洁" | 合并会丢失"项目级证据"与"树级自足"的区分，属违约 |

---

## 7. 相关文档

- [ARCHITECTURE.md](ARCHITECTURE.md) — 整体分层
- [CAPABILITY_MODEL.md](CAPABILITY_MODEL.md) — 档位语义与降级阶梯
- [VERIFICATION.md](VERIFICATION.md) — 验收如何覆盖这三层
