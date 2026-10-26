# brain-a · 仿生脑主工程（最新）

认知侧全栈：**20 个解剖学命名脑区 + 230 个服务模块**，负责"想不想做、敢不敢做、先做哪个"。

| 项 | 值 |
|---|---|
| 文件 | 1,615（524 `.jsc` / 413 `.pyc` / 其余为桩与配置） |
| 体积 | 22.15 MB |
| 外部依赖 | 20 个 npm 包 |
| 入口 | `index.js`（`npm start`） |
| 验收 | 仿生脑 9 条，与 brain-b 联合（用例随评估包，不在本仓库） |

---

## 结构

### 脑区（20）

每个目录是一个职责单一的功能单元。命名是**职责记号**，不是神经科学仿真——看目录名就知道谁管什么。

| 脑区 | 目录 | 脑区 | 目录 |
|---|---|---|---|
| 杏仁核 | `amygdala/` | 基底神经节 | `basal_ganglia/` |
| 脑干 | `brainstem/` | 小脑 | `cerebellum/` |
| 扣带回 | `cingulate_gyrus/` | 胼胝体 | `corpus_callosum/` |
| 皮层 | `cortex/` | 默认模式网络 | `default_mode_network/` |
| 海马 | `hippocampus/` | 下丘脑 | `hypothalamus/` |
| 内感受 | `interoception/` | 语言皮层 | `language_cortex/` |
| 镜像神经元 | `mirror_neurons/` | 运动皮层 | `motor_cortex/` |
| 松果体 | `pineal_gland/` | 前额叶皮层 | `prefrontal_cortex/` |
| 奖赏系统 | `reward_system/` | 感觉皮层 | `sensory_cortex/` |
| 丘脑 | `thalamus/` | 视觉皮层 | `visual_cortex/` |

### 基础设施（非脑区）

| 目录 | 职责 |
|---|---|
| `brain/` | 核心装配：`BrainAssembly`、`BrainBoot`、`BrainWiring`、`BrainStateMachine`、`BrainShutdown`、`SoulCore`、`KnowledgeOps` |
| `services/` | 230 个跨脑区公共服务模块 |
| `memory/` | 记忆子系统 |
| `perception/`、`perception_engine/` | 感知与感知引擎（13 + 1 模块） |
| `training/` | 训练接口（13 模块） |
| `simulation/` | 仿真注入 |
| `monitoring/` | 运行监控 |
| `bridge/`、`adapters/` | 外部桥接 |
| `opencastor/` | 本体/总线接入层（10 模块） |
| `lib/`、`config/`、`scripts/` | 工具、配置、脚本 |

### 根级装配模块

```
Brain.js                 总装
RobotBrain.js            机器人侧门面
UnifiedBrainArchitecture 统一架构声明
BrainBoot.js             启动序列
BrainConfig.js           配置
BrainEvents.js           事件总线
BrainRegions.js          脑区注册表
BrainAgent_Main.js       代理主循环
VirtualWorldInjector.js  虚拟世界注入
```

---

## 服务模块索引（节选，按职责）

`services/` 有 230 个模块，以下是最能说明设计意图的部分：

### 调度与编排
`BrainScheduler` · `ModelOrchestrator` · `VRAMScheduler` · `AdmissionControl` · `PriorityQueue` · `TaskOrchestrator` · `SchedulerGateway` · `OrchestratorWatchdog` · `WorkerPool`

### 安全与治理
`RegionGuard` · `RuntimeGuard` · `StartupGuard` · `PermissionManager` · `SecureSandbox` · `CircuitBreaker` · `AdversarialVerifier` · `QualitySystem` · `ResponseQualityGate` · `MutualReview`

### 认知与推理
`SomaCognitiveCore` · `SomaDeliberativeCore` · `SomaGlobalWorkspace` · `SomaPredictiveCoding` · `SomaActiveInference` · `SomaNeuromodulator` · `SomaNarrativeSelf` · `SomaReflexiveSelf` · `SelfAwareness` · `ReasoningEngine` · `BrainConsensus`

### 接地与空间
`SymbolGroundingBottleneck` · `SpatialRelationGrounding` · `TactileGroundingBridge` · `AnalogicalGrounding` · `CausalPointFlowGrounding` · `PointFlowUnifier` · `SomaAffordanceMapper`

### 学习与可塑性
`ThresholdedHybridContrastiveLoss` · `NeuromodulatorGate` · `MirrorNeuronAligner` · `ActiveInferenceSignal` · `AttentionRecalibrator` · `UnifiedPlasticityRule` · `SkillEvolver` · `SelfEvolver` · `BrainRegionEvolver`

### 记忆
`MemoryService` · `MemoryRecallService` · `UnifiedMemory` · `SomaSNNMemory` · `BinarySignatureMemory` · `ANNIndex`

### 运动接口
`MotorCoordinator` · `MotorAdaptationLayer` · `MotorConsciousnessBridge` · `MotorRuleEngine` · `ArmTrajectory` · `RobotExecutionBridge` · `MultiRobotAdapter` · `MockMotorServer`

### 桥接
`UnitreeConnector` · `ZMQBridge` · `RTABMapBridge` · `AprilTagBridge` · `PyMDPBridge` · `PerceptionBridge` · `RealityBridge` · `PhysicsForwardModel` · `WorldPredictor`

### 模型服务
`VLMRouter` · `VLMOfflineFallback` · `UnifiedTrainingInterface` · `RouterHub` · `SemanticRouter` · `QueryRouter`

---

## 运行

```bash
cd dist/brain-a
npm install
npm run verify-abi
node index.js
```

缺少 `onnxruntime-node` / `sharp` 等原生依赖时，相关感知能力会**显式降级并上报**，不会静默假装成功。

## 验收覆盖

与 `brain-b` 联合验收 9 条（用例随评估包提供，不在本仓库），覆盖四类边界：

- 安全门对正常指令与低置信度指令的放行/拦截分界
- 紧急停机指令本身不被安全门拦截
- 急停后的闭锁与释放，以及审计链计数自洽
- 双通道生命支持：单通道急停不连带另一通道；看门狗超时只锁执行通道

## 边界

- **不含模型权重**。认知能力依赖权重，缺权重时相关模块以 degraded 运行。
- **不含明文源码与白盒测试**。设计意图通过模块名、目录结构与契约文档表达。
- `.jsc` 绑定 Node v24.15.0，换版本必须重新构建。

## 相关

- [../brain-b/](../brain-b/) — 同构旧版，用于 A/B 对照
- [../base-bio/](../base-bio/) — 仿生脑底座（Profile、蓝图、清单）
- [../../docs/ARCHITECTURE.md](../../docs/ARCHITECTURE.md) — 整体分层
