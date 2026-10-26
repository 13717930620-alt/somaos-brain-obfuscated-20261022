# 架构说明

> 本文描述 SOMAOS 云脑运行时的分层结构、模块划分与依赖规则。
> 所有规则在代码与契约中均有对应实现，不只是文档约定。

## 1. 分层与依赖方向

```
验收与证据
    ↑
模型中心（契约 / 运行 / 门面）
    ↑
公共底座（base-core / base-bio / base-motion）
    ↑
工程树（brain-a / brain-b / arm-c / humanoid-d）
    ↑
本体 Profile（7 台）
```

**依赖只能向上，不允许向下或跨层回落。** 三条硬约束：

| 约束 | 含义 | 违约表现 |
|---|---|---|
| 不回落 | 运动树不得回落到规格根去借证据 | `motionSelfSufficiency` 出现跨族取值 |
| 不合并 | 两个 `overall` 作用域不同，不得压成单一档位 | `verdict` 只剩一个字段 |
| 不硬套 | 关节维度不匹配必须拒绝 | 7-DoF 限位表套到 24-DoF 上 |

## 2. 四棵工程树

每棵树可**独立构建、独立验收、独立升级**——这是"四棵树"而不是"一棵树四个分支"的原因：任何一棵树出问题，不影响其余三棵的交付。

### brain-a · 仿生脑（最新）

| 项 | 值 |
|---|---|
| 文件 | 1,615（524 `.jsc` / 413 `.pyc`） |
| 体积 | 22.15 MB |
| 脑区模块 | 20 个（解剖学命名） |
| 服务模块 | 230 个（`services/`） |

脑区模块（`dist/brain-a/<region>/`）：

```
amygdala            杏仁核          basal_ganglia     基底神经节
brainstem           脑干            cerebellum        小脑
cingulate_gyrus     扣带回          corpus_callosum   胼胝体
cortex              皮层            default_mode_network 默认模式网络
hippocampus         海马            hypothalamus      下丘脑
interoception       内感受          language_cortex   语言皮层
mirror_neurons      镜像神经元      motor_cortex      运动皮层
pineal_gland        松果体          prefrontal_cortex 前额叶皮层
reward_system       奖赏系统        sensory_cortex    感觉皮层
thalamus            丘脑            visual_cortex     视觉皮层
```

基础设施目录（非脑区）：`brain/`（装配、状态机、接线、启停）、`memory/`、`perception/`、`perception_engine/`、`training/`、`simulation/`、`monitoring/`、`bridge/`、`adapters/`、`lib/`、`services/`。

**为什么用解剖学命名**：每个脑区是一个职责单一的功能单元，命名让"谁负责什么"在目录层面就可见。它不是神经科学仿真，是**职责划分的记号系统**——读代码的人不需要先读文档就知道 `hippocampus` 管记忆、`amygdala` 管风险标记。

### brain-b · 仿生脑（训练完版·旧）

与 A 树结构同构，保留用于**对照**：A/B 联合验收要求两棵树在同样的安全约束下行为一致。旧版不删除，因为"新版更好"这件事需要证据，而证据只能来自可对照的旧版。

### arm-c · 运动脑（7-DoF 机械臂）

完整运动栈，从认知到执行：

| 层 | 模块 |
|---|---|
| 认知 | `cognition/active-inference`、`global-workspace`、`semantic-grounding`、`intent-parser`、`goal-pipeline-v2`、`skill-router`、`embedding-skill-matcher` |
| 自主 | `autonomy/purpose-engine` |
| 模型 | `models/world-model`、`groot-policy`、`deterministic-policy`、`model-registry`、`model-lifecycle` |
| 运动 | `motor/flowMatchingSmoother` |
| 感知 | `perception/gateway`、`point-flow`、`vision-grounding`、`adapters` |
| 执行 | `robot/execution-bridge`、`backends`、`ros2-transport` |
| 安全 | `safety/action-filter`（九类违规码）、`safety/emergency-stop` |
| 学习 | `learning/experience-store`、`reward-computer` |
| 治理 | `governance/governance`、`runtime/watchdog` |

### humanoid-d · 运动脑（24-DoF 人形）

与 C 同构，**关节表独立**。额外模块：`cognition/humanoid-skills`、`robot/humanoid-backend`、`robot/humanoid-model`。

C 与 D 的限位表**不得混用**：7-DoF / 24-DoF / 29-DoF 三套维度各自独立，维度不匹配时拒绝执行而不是截断或补零。

## 3. 三大底座

底座是**被调用**的公共层，不主动驱动任何东西。

| 底座 | 文件 | 核心模块 | 职责 |
|---|---|---|---|
| `base-core` | 20 | `specSchema`、`registry`、`evidenceCore`、`codeRoot`、`specEmit` | 规格 schema、本体注册表、证据核心、代码根解析 |
| `base-bio` | 44 | `ProfileStore`、`BrainBlueprint`、`ControllerResolver`、`SpecIngestor`、`ArtifactLedger`、`BaseOrchestrator`、`brainBridge`、`cloudBrainManifest`、`llmConnector` | 仿生脑侧：Profile 存储、大脑蓝图、控制器判定、云脑清单产出 |
| `base-motion` | 25 | `SpecIngestor`、`MotionControllerResolver`、`MotionArtifactLedger`、`motionBridge` | 运动侧：规格摄入、控制器解析、工件账本 |

`base-bio` 与 `base-motion` 的 `SpecIngestor` / `ControllerResolver` 是**同构但独立**的两份实现——刻意不抽公共父类，因为两侧的判定语义不同（见 [CAPABILITY_MODEL.md](CAPABILITY_MODEL.md)）。

## 4. 模型中心

三层，共 64 个模块。详细规格见 [MODEL_CENTER.md](MODEL_CENTER.md)。

| 层 | 模块数 | 一句话 |
|---|---|---|
| `center-contract` | 27 | 只声明数据形状与判定归属，不计算 |
| `center-runtime` | 25 | 只监督运行态，不产生关节目标 |
| `center-facade` | 12 | 单一入口，把七台本体的结果并排合成 |

## 5. 关键模块索引

`brain-a/services/` 有 230 个模块，按职责归类如下（节选）：

### 调度与编排

`BrainScheduler`、`ModelOrchestrator`、`VRAMScheduler`、`AdmissionControl`、`PriorityQueue`、`TaskOrchestrator`、`SchedulerGateway`、`OrchestratorWatchdog`、`WorkerPool`

### 安全与治理

`RegionGuard`、`RuntimeGuard`、`StartupGuard`、`PermissionManager`、`SecureSandbox`、`CircuitBreaker`、`AdversarialVerifier`、`QualitySystem`、`QualityMetrics`、`ResponseQualityGate`、`MutualReview`

### 认知与推理

`SomaCognitiveCore`、`SomaDeliberativeCore`、`SomaGlobalWorkspace`、`SomaPredictiveCoding`、`SomaActiveInference`、`SomaNeuromodulator`、`SomaNarrativeSelf`、`SomaReflexiveSelf`、`SelfAwareness`、`ReasoningEngine`、`SymbolicReasoningEngine`、`BrainConsensus`

### 接地与空间

`SymbolGroundingBottleneck`、`SpatialRelationGrounding`、`TactileGroundingBridge`、`AnalogicalGrounding`、`CausalPointFlowGrounding`、`PointFlowUnifier`、`SomaAffordanceMapper`、`PointCloudSegmenter`

### 学习与可塑性

`ThresholdedHybridContrastiveLoss`、`NeuromodulatorGate`、`MirrorNeuronAligner`、`ActiveInferenceSignal`、`AttentionRecalibrator`、`UnifiedPlasticityRule`、`SkillEvolver`、`SelfEvolver`、`BrainRegionEvolver`、`BrainRegionTuner`、`RuleGrowth`、`ACTRRuleLearner`

### 记忆

`MemoryService`、`MemoryRecallService`、`UnifiedMemory`、`SomaSNNMemory`、`BinarySignatureMemory`、`ANNIndex`

### 运动与执行

`MotorCoordinator`、`MotorAdaptationLayer`、`MotorConsciousnessBridge`、`MotorRuleEngine`、`MotorRuleLibrary`、`ArmTrajectory`、`RobotExecutionBridge`、`MultiRobotAdapter`、`MockMotorServer`

### 桥接与外部

`UnitreeConnector`、`ZMQBridge`、`RTABMapBridge`、`AprilTagBridge`、`PyMDPBridge`、`PerceptionBridge`、`RealityBridge`、`PhysicsForwardModel`、`WorldPredictor`

### 模型与推理服务

`VLMRouter`、`VLMOfflineFallback`、`UnifiedTrainingInterface`、`ModuleCapabilities`、`RouterHub`、`SemanticRouter`、`QueryRouter`

## 6. 命名与目录约定

| 约定 | 说明 |
|---|---|
| `<Name>.js` + `<Name>.jsc` | `.js` 是 3 行 stub（`require('bytenode')` 后转 `require('./<Name>.jsc')`），`.jsc` 是实际字节码 |
| `<region>/` | 解剖学命名的脑区，一个目录一个职责 |
| `services/` | 跨脑区的公共服务模块，扁平结构 |
| `src/` | 运动树的完整源码级目录（`cognition/`、`safety/` 等按层划分） |
| `opencastor/` | 与外部本体/总线的桥接层 |

## 7. 构建与发布形态

- JavaScript → `javascript-obfuscator@5.9.0`（medium：string array + base64、十六进制标识符、**不做**控制流平坦化）→ `bytenode@2.1.0` → `.jsc`
- Python → CPython 3.11.9 编译为 sourceless `.pyc`（剥除 docstring，保留 `assert` 语义）
- 明文源码、白盒测试、设计文档**不随包发布**

构建产物与 ABI 的绑定关系记录在根 `package.json` 的 `somaosRelease` 字段：

```json
{
  "node": "v24.15.0",
  "v8": "13.6.233.17-node.48",
  "python": "3.11.9",
  "pythonMagic": "a70d0d0a",
  "obfuscator": "javascript-obfuscator@5.9.0",
  "bytecode": "bytenode@2.1.0"
}
```
