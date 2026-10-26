# center-runtime · 模型中心 · 运行层

**只监督，不产生关节目标。** 管理传输、执行安全三道门、上报运行态。

| 项 | 值 |
|---|---|
| 文件 | 25（11 `.jsc`） |
| 体积 | 0.14 MB |
| 外部依赖 | 0 |
| 产出 | `runtime_status.json` + 实时 `readiness` |
| 验收 | 模型中心 13 条中的 8 条测运行层（用例随评估包，不在本仓库） |

> 作用域声明（写在 `output/runtime_status.json` 的 `note` 字段）：
> *"本运行层不产生关节目标、不跑控制回路、不连真机。readiness=real 需要真实且已探活的传输层。"*

---

## 模块

| 模块 | 职责 |
|---|---|
| `safetySupervisor.js` | 安全三道门：速率 → 看门狗 → 复位令牌 |
| `executionTransport.js` | 传输抽象：`null` / `loopback` / 真实 |
| `manifestSource.js` | 从契约层取清单，不缓存判定 |
| `cloudServiceLayer.js` | 云服务编排 |
| `statusReport.js` | 运行态上报 |
| `runtime.js` | 生命周期与状态机 |

---

## 安全三道门

串联，任何一道不过即拒绝，且拒绝原因可区分：

```
请求 ──▶ ① 速率门 ──▶ ② 看门狗门 ──▶ ③ 复位令牌门 ──▶ 放行
          超速拒绝      心跳超时闭锁      确认/令牌/保持时间缺一不可
```

### ① 速率门

位置窗口内的指令若超出速率上限，**立即拒绝**，不是限幅放行。

### ② 看门狗门

心跳超时**自动闭锁，无需人工**。`idle` 状态下没有心跳可续，因此不参与闭锁判定。

### ③ 复位令牌门

复位需同时满足三项，缺一不可：

| 条件 | 说明 |
|---|---|
| 确认 | 显式确认动作 |
| 令牌 | `SOMAOS_SAFETY_RESET_TOKEN` 匹配 |
| 保持时间 | 满足最小保持时长 |

未设置令牌时**拒绝复位**，急停保持闭锁——这是默认安全。

---

## 传输抽象

| `transport.kind` | `isReal` | 含义 |
|---|---|---|
| `null` | false | 无传输 |
| `loopback` | false | 自环，能跑通但不代表接了硬件 |
| 真实 | true | 已探活的物理通路 |

`readiness = real` 的充分条件：`isReal === true` **且**已探活。否则 `blocked`，并给出 `armCode`。

### 两种典型阻塞

```json
{ "readiness": "blocked", "armStage": "supervisor", "armCode": "NO_TRANSPORT" }
{ "readiness": "blocked", "armStage": "cloud",      "armCode": "CLOUD_UNCONFIGURED" }
```

**这是刻意的诚实失败**：宁可报 `blocked` 并说明卡在哪一门，也不报一个看起来正常的假就绪。

---

## 单本体输出示例

```json
{
  "id": "franka_7dof",
  "readiness": "commandable",
  "dof": 7,
  "jointWindows": 7,
  "verbsAllowed": 5,
  "verbsConditional": 0,
  "verbsBlocked": 8,
  "withNoTransport": { "readiness": "blocked", "armCode": "NO_TRANSPORT" }
}
```

`verbsAllowed` / `verbsConditional` / `verbsBlocked` 三态把"哪些指令现在能发、哪些有条件、哪些禁止"量化出来——给上层做决策，不是给人看的形容词。

---

## 验收覆盖（8 条）

```
无传输不许 arm，不可指挥不许 arm，缺 manifest 报 BAD_MANIFEST
arm→start 后模拟态显式标记 simulated
未被 arm 前 checkCommand 拒绝
位置窗口内的指令放行，越界/无窗口/未知关节都拒绝
动词白名单三态（blocked / conditional / 不在表内）
速率闸门在窗口内超限即拒绝
心跳超时自动闭锁（无需人工）
复位三道门（确认 / 令牌 / 保持时间）缺一不可
idle 状态没有心跳可续
```

三条设计意图：

- **`模拟态显式标记 simulated`** —— 仿真跑通不许冒充真机。
- **`未被 arm 前 checkCommand 拒绝`** —— 未授权状态下所有指令一律拒绝，不存在"先跑起来再说"。
- **`idle 状态没有心跳可续`** —— 空闲态不误判为心跳超时。

---

## 相关

- [../center-contract/](../center-contract/) — 契约层
- [../center-facade/](../center-facade/) — 门面
- [../../docs/MODEL_CENTER.md](../../docs/MODEL_CENTER.md) — 完整规格
- [../../SECURITY.md](../../SECURITY.md) — 安全边界
