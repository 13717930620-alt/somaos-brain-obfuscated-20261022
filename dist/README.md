# dist — 10 个可独立运行的发布单元

每个 `dist/*` 是一个**自洽的发布单元**：有自己的 `package.json`、自己的依赖声明、自己的 `.jsc` / `.pyc`，可以单独拷走、单独安装、单独验收。

## 索引

| dist | 定位 | 文件 | 体积 | 外部依赖 | 能单独跑 |
|---|---|---|---|---|---|
| [`brain-a`](brain-a/) | 仿生脑主工程（最新） | 1,615 | 22.15 MB | 20 | 需 `npm install` |
| [`brain-b`](brain-b/) | 仿生脑主工程（训练完版·旧） | 1,527 | 20.60 MB | 6 | 需 `npm install` |
| [`arm-c`](arm-c/) | 运动脑：7-DoF 机械臂全栈 | 202 | 1.97 MB | **1（仅 bytenode）** | 是 |
| [`humanoid-d`](humanoid-d/) | 运动脑：24-DoF 人形全栈 | 207 | 2.02 MB | **1（仅 bytenode）** | 是 |
| [`base-core`](base-core/) | 公共核心：规格 / 注册表 / 证据 | 20 | 0.12 MB | 0 | 是被调用库 |
| [`base-bio`](base-bio/) | 仿生脑底座 | 44 | 0.28 MB | 0 | 是被调用库 |
| [`base-motion`](base-motion/) | 运动脑底座 | 25 | 0.13 MB | 0 | 是被调用库 |
| [`center-contract`](center-contract/) | 模型中心 · 契约层 | 27 | 0.10 MB | 0 | 是被调用库 |
| [`center-runtime`](center-runtime/) | 模型中心 · 运行层 | 25 | 0.14 MB | 0 | 是被调用库 |
| [`center-facade`](center-facade/) | 模型中心 · 门面 | 12 | 0.07 MB | 0 | 有 CLI |

## 按目的选择

| 我想…… | 从这里开始 |
|---|---|
| 最快看到东西动起来（不接硬件） | `arm-c` 或 `humanoid-d`，零外部依赖 |
| 理解整套大脑怎么组织 | 根 [README](../README.md) → [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) |
| 看能力判定怎么算出来 | `center-contract` → `base-bio` / `base-motion` → `center-facade` |
| 接自己的机器人 | `base-bio/data/profiles/` 里的 Profile 格式 + `base-motion` 的 `SpecIngestor` |
| 验证发布件完整性 | 根 `npm test` + `sha256sums.txt` |

## 依赖关系

```
center-facade ──▶ center-contract ──▶ base-core
      │                │
      ├──▶ center-runtime ──▶ base-core
      │
      ├──▶ base-bio ──▶ base-core ──▶ (brain-a / brain-b)
      └──▶ base-motion ──▶ base-core ──▶ (arm-c / humanoid-d)
```

底座与中心都**不反向依赖**主工程树；它们只读取树产出的清单与证据。

## 共同约定

| 项 | 说明 |
|---|---|
| `.js` 文件 | 3 行 bytenode 桩，指向同名 `.jsc`，无函数体 |
| `.jsc` | V8 字节码，绑定 Node **v24.15.0** / V8 13.6.233.17-node.48 |
| `.pyc` | CPython 3.11.9 sourceless 字节码，magic `a70d0d0a` |
| `verify-abi` | 每个 dist 都有该脚本，换环境后先跑 |
| 权重 | **全部不含**；需要权重的能力以 degraded 运行并显式上报 |
