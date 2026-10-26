# arm-c · 运动脑（7-DoF 机械臂）

**零外部依赖**（除 bytenode）的完整运动栈：从认知到执行全链路可跑，默认接 Mock 后端，不接硬件也能看到完整行为。

| 项 | 值 |
|---|---|
| 文件 | 202（65 `.jsc` / 45 `.pyc`） |
| 体积 | 1.97 MB |
| 外部依赖 | **1（bytenode）** |
| 验收 | 运动脑 14 条中的 8 条专测 C（用例随评估包，不在本仓库） |

> 这是**最容易跑起来的 dist**。`npm install` 之后 `node src/index.js` 就能看到完整闭环，不需要 GPU、不需要权重、不需要真机。

---

## 全栈分层

| 层 | 目录 | 模块 |
|---|---|---|
| 认知 | `src/cognition/` | `active-inference` · `global-workspace` · `semantic-grounding` · `intent-parser` · `goal-pipeline-v2` · `skill-router` · `embedding-skill-matcher` |
| 自主 | `src/autonomy/` | `purpose-engine` |
| 模型 | `src/models/` | `world-model` · `groot-policy` · `deterministic-policy` · `model-registry` · `model-lifecycle` |
| 运动 | `src/motor/` | `flowMatchingSmoother` |
| 感知 | `src/perception/` | `gateway` · `point-flow` · `vision-grounding` · `adapters` |
| 执行 | `src/robot/` | `execution-bridge` · `backends` · `ros2-transport` |
| 安全 | `src/safety/` | `action-filter` · `emergency-stop` |
| 学习 | `src/learning/` | `experience-store` · `reward-computer` |
| 记忆 | `src/memory/` | `memory-system` |
| 治理 | `src/governance/`、`src/runtime/` | `governance` · `watchdog` |
| 数据面 | `src/dataplane/` | `gateway` |
| 可观测 | `src/observability/` | `health` |
| 训练/仿真/存储 | `src/training/`、`src/simulation/`、`src/storage/` | `training` · `simulation` · `persistence` |

### 桥接层 `opencastor/`

| 模块 | 职责 |
|---|---|
| `SafetyBridge` | 安全闸门（与仿生脑侧语义对齐） |
| `HardwareDriver` | 硬件驱动抽象 |
| `RCANAdapter` | RCAN 协议适配 |
| `FleetAdapter` | 多机编排 |
| `MCPBridge` / `MessagingBridge` | 工具协议与消息总线 |
| `BrainCastorBridge` | 与云脑对接 |
| `EvolutionLink` | 进化链路 |

### 其他

`services/VLMRouter` · `services/VRAMScheduler` · `adapters/openrouter-proxy` · `dataplane/local_bridge` · `schemas/`（`action` / `core` / `observation` 三份 JSON Schema）· `examples/demo.js`

---

## 运行

```bash
cd dist/arm-c
npm run verify-abi
node src/index.js        # 默认 MockRobotBackend，不接硬件
```

默认后端是 `MockRobotBackend`，所有下发返回 `mode=mock`。接真机需要配置 `ros2-transport` 与后端。

## 安全链

`ActionFilter` 的**九类违规码**是本模块最值得看的部分——错误分类型，不是一个笼统的 `InvalidAction`：

| 类别 | 例子 |
|---|---|
| 类型错误 | 指令类型不在白名单 |
| 缺关节 | 关节数少于声明 |
| 非有限值 | `NaN` / `Infinity` 角度 |
| 超限 | 超出位置限位 |
| 超速 | 超出速度上限 |
| 上游拒绝 | 世界模型评估未通过 |
| 点流拒绝 | 语义接地未通过 |
| 急停闭锁 | 急停期间任何下发 |
| 令牌无效 | 复位令牌错误或为空 |

急停语义：`trigger` 返回冻结记录并发布事件；**复位必须令牌正确**，错误令牌或空操作员一律拒绝。

## 验收覆盖

- 急停：trigger 返回冻结记录并发布事件
- 急停：令牌正确才可复位，错误令牌/空操作员均拒绝
- 动作过滤：合法指令放行 / 类型错误与缺关节各自报码 / 非有限角度·超限角度·超速分别拦截
- 动作过滤：**上游评估拒绝与点流拒绝不得被放行**
- Mock 后端：下发返回 `mode=mock`，急停阻断，复位恢复
- 执行桥：任务经安全门后由 Mock 后端执行；急停期间直接拒绝
- D 侧对照：动作过滤与急停语义需与 C 一致

## 边界

- **不含模型权重**：`groot-policy` 等策略在缺权重时降级，不产出真实动作。
- **不接真机**：需要自行配置 `ros2-transport` 与真实后端。
- 限位表按 7-DoF 维度生成；**24/29-DoF 不得套用**。

## 相关

- [../humanoid-d/](../humanoid-d/) — 同构的人形版本
- [../base-motion/](../base-motion/) — 运动底座（规格摄入、控制器判定）
- [../../docs/CAPABILITY_MODEL.md](../../docs/CAPABILITY_MODEL.md) — `motionSelfSufficiency` 语义
