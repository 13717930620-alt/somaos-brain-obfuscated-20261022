# center-facade · 模型中心 · 门面

**唯一入口，唯一结论形状。** 把七台本体的 bio / motion 结果并排合成，显式标注降级。

| 项 | 值 |
|---|---|
| 文件 | 12（4 `.jsc`） |
| 体积 | 0.07 MB |
| 外部依赖 | 0 |
| 产出 | `output/capability_overview.json` |
| 验收 | 模型中心 13 条中的 3 条测门面（用例随评估包，不在本仓库） |

---

## 模块

| 文件 | 职责 |
|---|---|
| `src/facade.js` | 唯一入口：`overview()` |
| `config/center.config.json` | 中心配置（根路径、开关） |
| `scripts/overview.js` | 命令行输出能力总览 |
| `output/capability_overview.json` | 最近一次总览（示例产物） |

## 输出结构

```json
{
  "joinKey": "embodiment.id",
  "persist": false,
  "forbidRootMerge": true,
  "degraded": false,
  "requireMissingRootsEmpty": true,
  "verdictSource": "../center-contract",
  "bio": { "root": "../brain-a", "evidenceRoots": [ ... ], "missing": [] },
  "mot": { "specRoot": "../brain-a", "evidenceRoots": [ ... ], "missing": [] },
  "rows": [ ... ]
}
```

### 四个关键开关

| 字段 | 值 | 含义 |
|---|---|---|
| `joinKey` | `embodiment.id` | 两棵树只能按本体 id 对齐，**不能按数组下标** |
| `forbidRootMerge` | `true` | 两棵树的证据**禁止互相顶替** |
| `persist` | `false` | 总览不落盘，每次现算 |
| `requireMissingRootsEmpty` | `true` | 有缺根时拒绝出结论 |

`joinKey` 这一条尤其重要：按数组下标对齐，一旦某一侧少了一行，后面全部错位，而且错得很安静。

## 每行结构

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

这一行的真实含义：**bio 侧有真机通路证据（但来自 `franka_droid` 推断），mot 侧运动树不自足。**

如果有人把它读成"这台能跑"，就是误读。**门面保留矛盾，正是为了让误读无处藏身。**

## 七台本体的实际档位

| 本体 | 族 | `bio.overall` | 证据 | `mot.overall` |
|---|---|---|---|---|
| `franka_7dof` | arm | `ready-real` | inferred | `unsupported` |
| `builtin:franka_droid` | arm | `ready-real` | direct | `unsupported` |
| `builtin:so100` | arm | `ready-real` | direct | `unsupported` |
| `g1_29dof` | humanoid | `ready-real` | direct | `needs-training` |
| `ur5_6dof` | arm | `unsupported` | none | `unsupported` |
| `builtin:ur5` | arm | `unsupported` | none | `unsupported` |
| `builtin:kinova_gen3` | arm | `unsupported` | none | `unsupported` |

`mot` 侧全部未达 `ready-real`，因为**本发布件不含传输驱动与模型权重**。这不是缺陷，是能力模型在正常工作：它拒绝为无法证明的事情给出高档位。

## `degraded` 语义

`degraded = true` 表示"这份总览的证据不完整"，**不等于系统坏了，也不等于能力就绪**。三种成因：

1. 证据根缺失（`missing` 非空）
2. 本发布不含权重，学习/推理能力处于降级态
3. 传输层未配置

## 验收覆盖

```
门面在缺证据根时显式 degraded，并保持七行并排
文本渲染可用且包含并排行
```

第一条的重点是「**并保持七行并排**」——降级不等于丢数据。缺根时仍然输出七行，只是标记 `degraded`。

## 使用

```bash
node dist/center-facade/scripts/overview.js
```

## 相关

- [../center-contract/](../center-contract/) — 契约层
- [../center-runtime/](../center-runtime/) — 运行层
- [../../docs/MODEL_CENTER.md](../../docs/MODEL_CENTER.md) — 完整规格
- [../../docs/CAPABILITY_MODEL.md](../../docs/CAPABILITY_MODEL.md) — 档位语义
