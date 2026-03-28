# Long-Running Agent - Subagent 工作流程

本文档定义基于 Claude Code Subagent 架构的功能实现流程。

---

## 主Agent职责

主agent作为协调者，负责：
- **状态管理**: 加载和更新 `features.json`
- **调度subagent**: 实现subagent、验证subagent、修复subagent
- **结果判定**: 只有验证通过才更新 `passes=true`
- **上下文保持**: 主agent context保持轻量，不被实现细节污染

---

## 功能实现流程

```
┌─────────────────────────────────────────────────────────────────┐
│                     主 Agent 工作循环                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. 加载状态                                                    │
│     Read .agent/features.json                                   │
│     Read .agent/progress.md                                     │
│                                                                 │
│  2. 选择功能                                                    │
│     选择 passes=false 且优先级最高的功能                         │
│                                                                 │
│  3. 调用 Implementation Subagent                                │
│     - isolation: "worktree"                                     │
│     - 在隔离环境中实现代码                                       │
│     - 返回: {status, changes_summary}                           │
│                                                                 │
│  4. 调用 Verification Subagent                                  │
│     - READ-ONLY 模式                                            │
│     - 运行测试验证                                               │
│     - 返回: {verification_status, error_details}                │
│                                                                 │
│  5. 判断结果                                                    │
│     ┌───────────────┬───────────────┐                          │
│     │   passed      │    failed     │                          │
│     │       ↓       │       ↓       │                          │
│     │  更新状态     │  进入修复循环  │                          │
│     └───────────────┴───────────────┘                          │
│                                                                 │
│  6. 修复循环 (最多3次)                                          │
│     - 记录失败信息                                               │
│     - 调用 Fix Subagent                                         │
│     - 再次验证                                                   │
│     - 循环直到通过或达到最大尝试次数                              │
│                                                                 │
│  7. 最终状态更新                                                │
│     - 只有 verification_status=="passed" 才更新                 │
│     - Merge worktree                                            │
│     - Edit features.json: passes=true                           │
│     - Git commit                                                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Subagent 类型定义

### Implementation Subagent

| 属性 | 值 |
|------|-----|
| 类型 | `general-purpose` |
| 隔离 | `isolation: "worktree"` |
| 职责 | 实现功能代码、创建测试文件 |
| 限制 | 不能修改 `features.json`，不能设置 `passes=true` |
| 返回 | `{status: "implemented", files_modified, tests_created}` |

### Verification Subagent

| 属性 | 值 |
|------|-----|
| 类型 | `general-purpose` |
| 隔离 | 使用同一 worktree |
| 职责 | 运行测试，报告验证结果 |
| 限制 | READ-ONLY 模式，不能修改任何文件 |
| 返回 | `{verification_status, tests_passed, tests_failed, error_details}` |

### Fix Subagent

| 属性 | 值 |
|------|-----|
| 类型 | `general-purpose` |
| 隔离 | 使用同一 worktree |
| 职责 | 根据错误信息修复代码 |
| 限制 | 不能修改 `features.json`，不能设置 `passes=true`，不能修改测试本身 |
| 输入 | 包含错误详情和失败测试信息 |
| 返回 | `{status: "fixed", files_modified, fix_summary}` |
| 最大尝试 | 3 次 |

---

## 修复循环机制

当 Verification Subagent 返回 `verification_status: "failed"` 时：

```
attempt = 1
MAX_FIX_ATTEMPTS = 3

while attempt <= MAX_FIX_ATTEMPTS:

    # 1. 记录失败信息
    Edit .agent/verification-results.json
    添加验证失败记录

    # 2. 调用 Fix Subagent
    Agent tool:
    - description: "修复 {feature_id} 错误"
    - prompt: 包含 error_details 的修复指令

    # 3. 再次验证
    Agent tool (Verification Subagent)

    if verification_status == "passed":
        break  # 成功，退出循环

    attempt += 1

# 结果处理
if verification_status == "passed":
    # 更新状态为完成
    Edit features.json: passes=true
else:
    # 标记为 blocked
    Edit features.json: blocked=true, blocked_reason
    Edit verification-results.json: 添加到 blocked_features
```

---

## Prompt 模板使用

主agent在调用各subagent时，使用 `.agent/templates/` 目录下的模板：

- `implementation-prompt.md` - 实现任务模板
- `verification-prompt.md` - 验证任务模板
- `fix-prompt.md` - 修复任务模板

模板中的变量会被替换为实际功能信息：
- `{feature_id}` - 功能ID
- `{description}` - 功能描述
- `{steps}` - 实现步骤
- `{error_details}` - 错误详情（仅fix模板）
- `{attempt_number}` - 修复尝试次数（仅fix模板）

---

## Agent 工具调用示例

### 调用 Implementation Subagent

```
使用 Agent 工具:

{
  "subagent_type": "general-purpose",
  "description": "实现 F001 功能",
  "isolation": "worktree",
  "prompt": "从 .agent/templates/implementation-prompt.md 加载模板，
             替换变量为 F001 的实际信息，
             添加具体实现要求..."
}
```

### 调用 Verification Subagent

```
使用 Agent 工具:

{
  "subagent_type": "general-purpose",
  "description": "验证 F001 测试",
  "prompt": "从 .agent/templates/verification-prompt.md 加载模板，
             替换变量为 F001 的实际信息，
             强调 READ-ONLY 规则..."
}
```

### 调用 Fix Subagent

```
使用 Agent 工具:

{
  "subagent_type": "general-purpose",
  "description": "修复 F001 错误",
  "prompt": "从 .agent/templates/fix-prompt.md 加载模板，
             替换变量为 F001 的实际信息和错误详情，
             强调不能修改测试本身..."
}
```

---

## 状态更新规则

### 只有验证通过才更新 passes

主agent必须遵守以下规则：

1. **Implementation Subagent 完成** → 不更新 passes
2. **Verification Subagent 返回 passed** → 可以更新 passes=true
3. **Fix Subagent 完成** → 不更新 passes
4. **Verification Subagent 返回 failed** → 进入修复循环，不更新 passes

### 禁止绕过验证

任何情况下，主agent都不能：
- 在 Implementation 完成后直接设置 passes=true
- 在 Fix 完成后直接设置 passes=true
- 跳过 Verification 步骤

---

## Blocked 功能处理

当功能修复循环超过最大尝试次数仍未通过时：

1. 标记功能为 `blocked`（不是 `passes=true`）
2. 记录原因到 `.agent/verification-results.json`
3. 继续处理下一个功能
4. 用户可手动检查 blocked 功能并决定是否重试

---

## 文件结构

```
.agent/
├── features.json          # 功能清单（含验证状态）
├── progress.md            # 进度日志
├── verification-results.json  # 验证历史记录
├── templates/
│   ├── implementation-prompt.md
│   ├── verification-prompt.md
│   └ fix-prompt.md
└── worktrees/             # worktree 目录（自动创建）
```

---

## 与原架构对比

| 方面 | 原架构 (Shell脚本) | 新架构 (Subagent) |
|------|------------------|------------------|
| 上下文 | 每次新会话 | 主agent持久保持 |
| 状态加载 | 每次重新读取 | 加载一次，维护内存 |
| 实现隔离 | 无隔离 | worktree隔离 |
| 验证时机 | 项目完成后 | 每功能完成后 |
| Pass标记 | 脚本自动标记 | 主agent验证后标记 |
| 上下文污染 | 所有在一个context | subagent隔离执行 |
| 修复机制 | 无修复循环 | 最多3次修复尝试 |
| 失败处理 | 无 | blocked标记 |

---

## 开始工作

主agent启动时，请按照以下步骤：

1. `Read .agent/features.json` - 加载功能清单
2. `Read .agent/progress.md` - 了解历史进度
3. `Read .agent/verification-results.json` - 检查验证历史
4. 选择 `passes=false` 的功能
5. 调用 Implementation Subagent 开始工作

记住：**只有验证通过才能标记 passes=true！**