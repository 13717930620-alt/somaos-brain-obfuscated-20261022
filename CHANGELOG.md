# 变更记录

格式参照 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

## [1.0.1] — 2026-11-14

### 变更（仅文档，二进制未动）

- **README 重写**：从「发布说明」改为「架构文档」——以系统能力与分层结构开篇，把交付形态、排除项与保护边界移到后段并归入明确章节。
- **新增 `docs/` 四篇规格**：
  - `ARCHITECTURE.md` — 四树 / 三底座 / 三中心的分层、依赖规则、230 个服务模块的职责索引
  - `MODEL_CENTER.md` — 模型中心三层规格、三份契约字段、四条不变量、完整调用链
  - `CAPABILITY_MODEL.md` — `readiness` 与三维 `verdict` 的语义、降级阶梯、七台本体实测档位
  - `VERIFICATION.md` — 黑盒原则、58 条用例逐组说明、突变证伪方法、作用域声明
- **新增架构图** `docs/assets/architecture.svg`（五层分层视图）。
- **10 个子 README 全部重写**：此前 10 份内容相同，只讲"不含什么"；现在各自说明定位、目录结构、核心模块、对外接口、验收覆盖与边界。
- **新增 `dist/README.md`**：10 个发布单元的索引、依赖关系图、按目的选择指南。
- **新增 `CHANGELOG.md`、`CONTRIBUTING.md`**。
- **修正**：`.js` 桩数量表述由「1,210」精确为「dist 内 1,200 个桩 + 10 个验收/脚本文件」；各 dist 体积按实际字节重算。
- **修正**：`evidence/` 与 `RELEASE_CHECKSUMS.txt` 的引用改为明确标注「随发布归档提供，不在本仓库」，避免悬空引用。

### 未变更

- 全部 `.jsc` / `.pyc` 字节码未改动：3,710 个原有文件的 SHA-256 与上一版逐条比对一致。
- 验收套件 58 条用例未改动。

### 附带更新

- `sha256sums.txt` 因文档变更重算：3,722 → 3,731 条（新增 9 个文档文件）。

## [1.0.0] — 2026-10-26

### 首次发布

- 10 个 dist：`brain-a`、`brain-b`、`arm-c`、`humanoid-d`、`base-core`、`base-bio`、`base-motion`、`center-contract`、`center-runtime`、`center-facade`。
- 3,722 个文件 / 47.5 MB。
- JavaScript 经 `javascript-obfuscator@5.9.0`（medium）混淆后由 `bytenode@2.1.0` 编译为 `.jsc`；Python 经 CPython 3.11.9 编译为 sourceless `.pyc`。
- 黑盒验收套件 58 条（6 组）。
- 全仓 SHA-256 校验和 3,722 条。
- 构建于 2026-10-26T11:56:06.263Z，ABI：Node v24.15.0 / V8 13.6.233.17-node.48 / Python 3.11.9（magic `a70d0d0a`）。

### 已知限制

- 成员属性名不重命名（全程序改名对安全链风险过高），字节码中可提取。
- `.jsc` / `.pyc` 可被反编译或 dump；混淆只提高成本，不等于加密。
- `.jsc` 与 Node/V8 版本强绑定，换版本必须重新构建。
