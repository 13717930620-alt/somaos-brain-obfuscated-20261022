# base-bio · 仿生脑大底座

仿生脑侧的公共能力：**Profile 存储、大脑蓝图、控制器判定、云脑清单产出**。

| 项 | 值 |
|---|---|
| 文件 | 44（14 `.jsc`） |
| 体积 | 0.28 MB |
| 外部依赖 | 0 |
| 产出 | `manifest` + `driveEvidence` |
| 验收 | 三底座 12 条中的 3 条测 base-bio（用例随评估包，不在本仓库） |

---

## 模块

| 模块 | 职责 |
|---|---|
| `ProfileStore.js` | 本体 Profile 的读取与校验 |
| `BrainBlueprint.js` | 大脑蓝图：脑区清单与接线声明 |
| `ControllerResolver.js` | 控制器判定：这台本体有没有可用的控制通路 |
| `SpecIngestor.js` | 规格摄入：URDF / MJCF / YAML → 内部规格 |
| `ArtifactLedger.js` | 工件账本：记录产出了什么、来自哪个根 |
| `BaseOrchestrator.js` | 编排：按顺序调用上述模块 |
| `cloudBrainManifest.js` | **产出云脑清单**（契约 `manifest.v1` 的唯一来源） |
| `brainBridge.js` | 与主工程树对接 |
| `llmConnector.js` | 模型服务连接 |
| `specSchema.js` | 规格 schema（委托 `base-core`） |
| `_coreRef.js` | 公共核心引用解析 |

## 数据

```
data/
├── profiles/   7 台本体的 Profile（判定输入）
└── manifests/  7 台本体的清单（含内置 4 台：franka_droid / kinova_gen3 / so100 / ur5）
```

| Profile | 族 | DoF |
|---|---|---|
| `franka_7dof` | arm | 7 |
| `builtin:franka_droid` | arm | 7 |
| `builtin:kinova_gen3` | arm | 7 |
| `builtin:ur5` | arm | 6 |
| `ur5_6dof` | arm | 6 |
| `builtin:so100` | arm | 6 |
| `g1_29dof` | humanoid | 29 |

## 判定逻辑：`driveEvidence`

作用域是**全项目 A/B/C/D**（含代码根 B）。判定顺序：

```
有厂商控制器通路          → vendor-controller
有关节目标级通路          → joint-target-driver
有通路但无传输驱动        → no_transport_driver
无任何证据                → none
```

每条结论带 `evidenceKind`：

| 值 | 含义 |
|---|---|
| `direct` | 该本体自己有证据 |
| `inferred` | 由同族本体推断，`inferredFrom` 标注来源 |
| `none` | 无证据 |

**推断必须显式**：`franka_7dof` 的 `ready-real` 来自 `inferredFrom: ["franka_droid"]`，不是自己探到的。这个区别在门面输出里保留，不被抹平。

## 关键行为

### 宁可判低，不冒充

```
臂类无证据              → unsupported，且证据面显式降级
腿式本体缺训练/厂商控制器 → needs-training，不冒充"可走"
无关节表                → unsupported，原因写 no_joints
```

第二条是设计要点：**有腿 ≠ 能走**。结构齐备但策略未训练时，正确结论是 `needs-training`，不是 `ready-sim`。

### 只读

`base-bio` 不写回任何主工程树。写入守卫在 `base-core`，根内路径一律拒绝。

## 验收覆盖

```
base-bio：臂类无证据时判 unsupported，且证据面显式降级
base-bio：腿式本体缺训练/厂商控制器时判 needs-training，不冒充可走
base-bio：无关节表直接判 unsupported 并说明 no_joints
```

## 相关

- [../base-core/](../base-core/) — 规格与注册表
- [../brain-a/](../brain-a/) — 仿生脑主工程
- [../../docs/CAPABILITY_MODEL.md](../../docs/CAPABILITY_MODEL.md) — `driveEvidence` 语义
