# 能力模型

> SOMAOS 对外只讲**档位**，不讲形容词。
> 这套模型的目的不是"证明能行"，而是"**让不能行的地方无法被说成能行**"。

## 1. 两个概念，不要混

| 概念 | 出处 | 性质 | 谁写 |
|---|---|---|---|
| `readiness` | `manifest` 内字段 | 契约的**原始**字段 | 底座产出，运行层判 `commandable` |
| `verdict` | 契约层**追加**的只读字段 | 对原始字段的**三维解读** | 两个底座分别计算 |

关键约束：**契约层只追加 `verdict`，绝不改写 `readiness`。** 原始字段是事实，`verdict` 是解读，两者分开存，才能在解读出错时回溯到事实。

## 2. `readiness`：能不能下发

| 值 | 含义 |
|---|---|
| `commandable` | 鉴权、安全、传输三关全过，此刻可下发 |
| `blocked-no-transport` | 无可用传输，或传输未探活 |

`blocked` 时必带 `armCode` 说明卡在哪一门：

| `armCode` | 卡点 |
|---|---|
| `NO_TRANSPORT` | 传输层为空 |
| `CLOUD_UNCONFIGURED` | 只有 loopback 且云未配置 |
| 其他 | 安全三道门之一未过 |

## 3. 三维 `verdict`

### 3.1 `driveEvidence` — 全项目有没有驱动通路证据

作用域：**A / B / C / D 四棵树（含代码根 B）**。

| 枚举 | 含义 |
|---|---|
| `vendor-controller` | 有厂商控制器级的驱动通路 |
| `joint-target-driver` | 有关节目标级的驱动通路 |
| `no_transport_driver` | 有通路但无传输驱动 |
| `none` | 无任何证据 |

附 `evidenceKind`：

| 值 | 含义 |
|---|---|
| `direct` | 该本体自己就有证据 |
| `inferred` | 由同族其他本体的证据推断（`inferredFrom` 列出源） |
| `none` | 无证据 |

**`inferred` 是显式的**：推断来的证据一定标注来源，不允许静默继承。

### 3.2 `motionSelfSufficiency` — 运动树自己能不能自足

作用域：**仅 C / D**，结构性不回落规格根。

| 枚举 | 含义 |
|---|---|
| `ready-real` | 运动树自身具备真机指挥能力 |
| `ready-sim` | 仿真环境可跑，真机未验证 |
| `needs-training` | 结构齐备，策略未训练 |
| `unsupported` | 结构不支持该本体 |

### 3.3 `commandable` — 此刻能不能发

作用域：**运行态实时计算**，不落盘。鉴权 + 安全 + 传输三关都过才为 `true`。

## 4. 为什么必须是三个而不是一个

同一个本体的真实状态可能是：

```json
{
  "driveEvidence": "joint-target-driver",   // 项目里有驱动通路
  "motionSelfSufficiency": "needs-training", // 但这棵运动树还没训练
  "commandable": false                       // 所以此刻不能发
}
```

三句话同时为真，且**互不矛盾**。压成一个 `overall` 只能表达其中一句：

- 压成 `ready` → 掩盖了没训练的事实
- 压成 `blocked` → 掩盖了结构齐备的事实

所以契约里写死：**两个 `overall` 作用域不同，禁止合并成单一档位。**

## 5. 降级阶梯

```
ready-real ──(无真机证据)──▶ ready-sim ──(无策略)──▶ needs-training ──(结构不支持)──▶ unsupported
     │                          │                        │                          │
     └────────── 每一档都必须带「为什么降」的理由，不允许无理由降级 ──────────────┘
```

降级是**设计行为，不是故障**。判据：

| 现象 | 正确解读 |
|---|---|
| 缺权重 | 学习/推理能力降级，档位下落，**不是系统坏了** |
| 缺传输驱动 | `mot` 落 `unsupported`，`readiness` 落 `blocked` |
| 缺证据根 | 门面 `degraded = true` |
| 维度不匹配 | **直接拒绝**，不降级、不截断、不补零 |

## 6. 本发布件的真实档位

以下是 `center-facade/output/capability_overview.json` 的实际输出（`degraded: false`）：

| 本体 | 族 | `bio.overall` | 证据 | `mot.overall` |
|---|---|---|---|---|
| `franka_7dof` | arm | `ready-real` | inferred（← franka_droid） | `unsupported` |
| `builtin:franka_droid` | arm | `ready-real` | direct | `unsupported` |
| `builtin:so100` | arm | `ready-real` | direct | `unsupported` |
| `g1_29dof` | humanoid | `ready-real` | direct | `needs-training` |
| `ur5_6dof` | arm | `unsupported` | none | `unsupported` |
| `builtin:ur5` | arm | `unsupported` | none | `unsupported` |
| `builtin:kinova_gen3` | arm | `unsupported` | none | `unsupported` |

**怎么读这张表**：`bio` 侧有 4 台达到 `ready-real`，说明仿生脑侧对这 4 台已有真机指令通路证据；`mot` 侧全部未达 `ready-real`，因为**本发布件不含传输驱动与模型权重**——运动树无法自证。

这不是缺陷，是能力模型在正常工作：**它拒绝为无法证明的事情给出高档位。**

补上传输驱动与权重后，`mot` 会沿 `needs-training → ready-sim → ready-real` 上移；`g1_29dof` 已经在 `needs-training`，说明结构齐备、只差训练。

## 7. 给使用方的三条建议

1. **看 `mot` 而不是看 `bio` 决定能不能上机。** `bio` 是项目级证据，`mot` 才是这台本体自身的能力。
2. **`degraded = true` 时不要做安全相关决策。** 证据不完整时的结论不能用于放行。
3. **`verbsBlocked` 不是错误清单，是当前禁令清单。** 它的存在是为了让上层知道哪些指令现在不能发，而不是等运行时失败。

## 8. 相关文档

- [MODEL_CENTER.md](MODEL_CENTER.md) — 三层规格与不变量
- [VERIFICATION.md](VERIFICATION.md) — 档位如何被验收覆盖
