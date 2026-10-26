# base-motion · 运动脑大底座

运动侧的公共能力：**规格摄入、控制器解析、工件账本、运动证据判定**。

| 项 | 值 |
|---|---|
| 文件 | 25（8 `.jsc`） |
| 体积 | 0.13 MB |
| 外部依赖 | 0 |
| 产出 | `manifest` + `motionSelfSufficiency` |
| 验收 | 三底座 12 条中的 2 条测 base-motion（用例随评估包，不在本仓库） |

---

## 模块

| 模块 | 职责 |
|---|---|
| `SpecIngestor.js` | 规格摄入：只取关节表，不取其他证据 |
| `MotionControllerResolver.js` | 控制器解析：这棵运动树能不能自足指挥 |
| `MotionArtifactLedger.js` | 工件账本：记录运动侧产出的来源与根标签 |
| `motionBridge.js` | 与 C/D 运动树对接 |
| `_coreRef.js` | 公共核心引用解析 |

## 数据

```
data/profiles/   7 台本体的运动侧 Profile（与 base-bio 同名但语义不同）
```

## 判定逻辑：`motionSelfSufficiency`

作用域**仅 C/D**，**结构性不回落规格根**。这是与 `driveEvidence` 最本质的区别。

```
运动树自身具备真机指挥能力   → ready-real
仿真可跑，真机未验证         → ready-sim
结构齐备，策略未训练         → needs-training
结构不支持该本体             → unsupported
```

### 「不回落」是什么意思

`base-bio` 的 `driveEvidence` 可以借用别的树的证据（`inferred`），因为它问的是"整个项目里有没有"。

`base-motion` **不可以**。它问的是"这棵运动树自己行不行"，所以：

- 只承认 C/D 两棵运动树作为证据根
- **绝不把仿生脑树（A/B）当证据**
- 规格根缺失时直接判 `unsupported`，不向上找替代

## 关键行为

### 证据根白名单

```
C-arm      → 承认
D-humanoid → 承认
A-trained-legacy / B-current → 拒绝（不是运动证据）
```

这条规则由验收直接钉住：`base-motion：运动证据根只含 C/D 家族，绝不把仿生脑树当证据`。

### 负结果对照

显式传入 `roots: []` 时，结论必须是 `unsupported`。

这条用例的价值：**证明系统在"什么证据都没有"时会给出负结论**，而不是因为没检查就默认通过。只测正例的验收是假验收。

### 只取关节表

`SpecIngestor` 从规格文件里**只读关节表**，其余字段不纳入证据面。原因：运动侧只关心"有几个关节、限位多少"，其他信息属于仿生脑侧职责，跨界读取会导致职责混乱。

## 验收覆盖

```
base-motion：运动证据根只含 C/D 家族，绝不把仿生脑树当证据
base-motion：显式 roots:[] 时判 unsupported（负结果对照）
```

## 相关

- [../base-core/](../base-core/) — 规格与注册表
- [../arm-c/](../arm-c/) · [../humanoid-d/](../humanoid-d/) — 两棵运动树
- [../../docs/CAPABILITY_MODEL.md](../../docs/CAPABILITY_MODEL.md) — `motionSelfSufficiency` 语义
