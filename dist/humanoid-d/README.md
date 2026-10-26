# humanoid-d · 运动脑（24-DoF 人形）

与 `arm-c` 同构的人形版本，**关节表独立**。默认 Mock 后端，零外部依赖可跑。

| 项 | 值 |
|---|---|
| 文件 | 207（68 `.jsc` / 45 `.pyc`） |
| 体积 | 2.02 MB |
| 外部依赖 | **1（bytenode）** |
| 验收 | 运动脑 14 条中的 6 条专测 D（用例随评估包，不在本仓库） |

---

## 与 arm-c 的差异

结构相同，四处关键不同：

| 差异 | 说明 |
|---|---|
| 关节表 | 24-DoF 独立限位表，**不得与 7-DoF / 29-DoF 混用** |
| 世界模型 | `src/models/world-model` 按 24 维预测，要求维度守恒且全为有限值 |
| 技能集 | 额外 `src/cognition/humanoid-skills` |
| 执行后端 | 额外 `src/robot/humanoid-backend`、`src/robot/humanoid-model` |

### 目录

```
src/
├── ai/            llm-client · local-openai-compatible · openrouter · static-embedding-client · thinking-parser
├── autonomy/      purpose-engine
├── cognition/     active-inference · global-workspace · semantic-grounding · intent-parser
│                  goal-pipeline-v2 · skill-router · embedding-skill-matcher · humanoid-skills
├── models/        world-model · groot-policy · deterministic-policy · model-registry · model-lifecycle
├── motor/         flowMatchingSmoother
├── perception/    gateway · point-flow · vision-grounding · adapters
├── robot/         execution-bridge · backends · ros2-transport · humanoid-backend · humanoid-model
├── safety/        action-filter · emergency-stop
├── learning/      experience-store · reward-computer
├── governance/    governance
├── runtime/       watchdog
├── observability/ health
├── simulation/    simulation
├── training/      training
└── storage/       persistence
```

`opencastor/` 桥接层与 `arm-c` 相同（`SafetyBridge` / `HardwareDriver` / `RCANAdapter` / `FleetAdapter` / `MCPBridge` / `MessagingBridge` / `BrainCastorBridge` / `EvolutionLink`）。

---

## 运行

```bash
cd dist/humanoid-d
npm run verify-abi
node src/index.js
```

## 验收覆盖

运动脑 14 条中的 6 条专测 D（用例随评估包，不在本仓库），覆盖三件事：

- 与 `arm-c` 的判定语义一致性（验证一致性，不是各写一套）
- 24 自由度下的维度守恒：输入多少维就必须输出多少维，任何截断、补零、广播都视为违约
- 世界模型评估的正负例成对，避免"永远拒绝"也能通过的假绿

## 边界

- **不含模型权重**：人形策略依赖权重，缺失时降级。
- **24-DoF 限位表不适用于 29-DoF（G1）**。G1 走 `base-bio` 侧的 `g1_29dof` Profile，关节表另行生成。
- 与 C 一样不接真机，需自行配置 `ros2-transport`。

## 相关

- [../arm-c/](../arm-c/) — 7-DoF 机械臂版本
- [../base-motion/](../base-motion/) — 运动底座
- [../../docs/CAPABILITY_MODEL.md](../../docs/CAPABILITY_MODEL.md) — 档位语义
