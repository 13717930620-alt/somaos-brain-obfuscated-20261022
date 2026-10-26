# NOTICE — 第三方组件与外部依赖

本发布件**不打包**任何第三方二进制、模型权重或依赖代码。下列依赖由使用者通过
`npm install` / `pip install -r requirements.txt` 自行获取，各自适用其原有许可。

## npm 运行时依赖（各 dist 的 package.json 已声明）
- @darksol/remem
- @grpc/grpc-js
- @grpc/proto-loader
- adm-zip
- better-sqlite3
- dotenv
- iconv-lite
- json-rules-engine
- onnxruntime-node
- pdf-parse
- pngjs
- pptxgenjs
- sharp
- sqlite-vec
- sqlite3
- winston
- ws
- yuandian-mcp-server
- zeromq

## 构建期工具（仅用于生成发布件，不随包分发）
- javascript-obfuscator@5.9.0（BSD-2-Clause）
- bytenode@2.1.0（MIT）
- terser（BSD-2-Clause，未用于本次构建）
- CPython 3.11.9（PSF License）

## 明确排除的第三方内容
| 组件 | 许可 | 排除原因 |
|---|---|---|
| croco / gush3r | CC BY-NC-SA 4.0 | 非商业 + 相同方式共享，与本发布许可不兼容 |
| whisper.cpp / llama.cpp 的 ggml-cuda、cublasLt DLL | MIT(代码) + NVIDIA CUDA EULA(二进制) | NVIDIA 禁止再分发 CUDA 运行库 |
| electron 二进制 | MIT + Chromium/FFmpeg 等 | 体积 216MB，超仓库限制，可由使用者自行安装 |
| 各类模型包（cosyvoice / sensevoice / qwen2vl / embedding / world_model 权重与配置） | 各自许可 | 无权重发布原则 |
| ProtoMotions | NVIDIA 源许可 | 第三方研究代码，不随本发布件分发 |

## 安全与隐私
- 不含 `.env` 真值；仅含 `.env.example` 模板（已清洗）。
- 不含遥测、不含回连地址。
- 本机个人绝对路径已在构建期机械改写（317 处）。
