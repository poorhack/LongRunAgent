# Long-Running Web Builder Agent (Subagent 架构)

这是一个严格遵循 Anthropic 最佳实践的通用 Agent，使用 **Subagent 架构** 跨会话持续构建 Web 项目。

---

## 核心原则 (必须遵守)

1. **上下文隔离**: 每个功能实现使用独立 Subagent，主 Agent context 保持清洁
2. **验证驱动**: 测试通过才算完成，测试失败必须进入修复循环
3. **状态受控**: 只有主 Agent 在验证通过后才能更新 `passes=true`
4. **会话独立**: 任何新会话都能从当前状态恢复工作

---

## Subagent 架构概览

```
┌─────────────────────────────────────────────────────────────────┐
│                     主 Agent (协调者)                            │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ 状态管理: features.json, progress.md                        ││
│  │ 调度决策: 选择功能、派发 Subagent、处理结果                  ││
│  │ 上下文: 保持轻量，不包含实现细节                             ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
         │                    │                    │
         ↓                    ↓                    ↓
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│Implementation│      │Verification │      │    Fix      │
│  Subagent   │      │  Subagent   │      │  Subagent   │
│ (worktree)  │      │ (READ-ONLY) │      │  (修复循环)  │
└─────────────┘      └─────────────┘      └─────────────┘
```

---

## 会话启动流程 (必须执行)

```
步骤 1: pwd                                    # 确认工作目录
步骤 2: Read CLAUDE.md                          # 获取项目指令
步骤 3: Read .agent/progress.md                 # 了解历史进度
步骤 4: Read .agent/features.json               # 查看待完成功能
步骤 5: Read .agent/verification-results.json   # 检查验证历史
步骤 6: git status && git log --oneline -5     # 检查代码状态
步骤 7: 运行开发服务器 (如 ./init.sh)           # 启动环境
步骤 8: 选择一个 passes=false 的功能开始工作
```

---

## 功能完成流程 (Subagent 模式)

### 完整流程图

```
┌─────────────────────────────────────────────────────────────────┐
│  步骤 1: 选择功能                                                │
│  从 features.json 选择 passes=false 的功能                       │
│  优先级: critical > high > medium > low                         │
└─────────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────────┐
│  步骤 2: 调用 Implementation Subagent                            │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Agent 工具配置:                                              ││
│  │ - subagent_type: "general-purpose"                          ││
│  │ - description: "实现 FXXX 功能"                              ││
│  │ - isolation: "worktree"                                     ││
│  │ - prompt: 从 templates/implementation-prompt.md 加载         ││
│  └─────────────────────────────────────────────────────────────┘│
│  返回: {status: "implemented", files_modified, tests_created}    │
└─────────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────────┐
│  步骤 3: 调用 Verification Subagent                              │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Agent 工具配置:                                              ││
│  │ - subagent_type: "general-purpose"                          ││
│  │ - description: "验证 FXXX 测试"                              ││
│  │ - prompt: 从 templates/verification-prompt.md 加载           ││
│  │ - 强调 READ-ONLY 规则                                        ││
│  └─────────────────────────────────────────────────────────────┘│
│  返回: {verification_status: "passed|failed", error_details}     │
└─────────────────────────────────────────────────────────────────┘
                           ↓
           ┌───────────────┴───────────────┐
           │                               │
      verification_status           verification_status
         == "passed"                   == "failed"
           │                               │
           ↓                               ↓
┌─────────────────────┐      ┌─────────────────────────────────┐
│ 步骤 6: 更新状态    │      │ 步骤 4: 修复循环 (最多 3 次)      │
│ (验证通过后执行)    │      │ ┌───────────────────────────────┐│
│                     │      │ │ 4a: 记录失败信息               ││
│ • Merge worktree    │      │ │ Edit verification-results.json ││
│ • Edit features.json│      │ └───────────────────────────────┘│
│   passes=true       │      │ ┌───────────────────────────────┐│
│ • Edit progress.md  │      │ │ 4b: 调用 Fix Subagent          ││
│ • Git commit        │      │ │ prompt 包含 error_details      ││
│                     │      │ └───────────────────────────────┘│
└─────────────────────┘      │ ┌───────────────────────────────┐│
                              │ │ 4c: 再次 Verification          ││
                              │ │ 循环直到通过或达到最大次数      ││
                              │ └───────────────────────────────┘│
                              └─────────────────────────────────┘
                                           │
                                    ┌──────┴──────┐
                                    │             │
                               通过(3次内)    失败(3次后)
                                    │             │
                                    ↓             ↓
                              更新状态      标记 blocked
```

---

## Subagent 调用详解

### Implementation Subagent

```
使用 Agent 工具调用:

{
  "subagent_type": "general-purpose",
  "description": "实现 F001 功能",
  "isolation": "worktree",
  "prompt": "
    功能 ID: F001
    描述: 用户注册功能
    步骤: ['创建注册表单', '添加验证', '实现密码加密']

    要求:
    1. 在 worktree 中实现代码
    2. 创建对应测试文件
    3. 不要修改 features.json
    4. 不要设置 passes=true
  "
}

返回结果处理:
- status: "implemented" → 继续验证
- status: "implementation_failed" → 记录错误，处理下一个功能
```

### Verification Subagent

```
使用 Agent 工具调用:

{
  "subagent_type": "general-purpose",
  "description": "验证 F001 测试",
  "prompt": "
    ⚠️ READ-ONLY 模式

    功能 ID: F001
    测试命令: pytest tests/test_auth.py -v

    关键规则:
    - 不能修改任何文件
    - 不能设置 passes=true
    - 只运行测试并报告结果

    返回 JSON 格式结果
  "
}

返回结果处理:
- verification_status: "passed" → 更新 passes=true
- verification_status: "failed" → 进入修复循环
```

### Fix Subagent

```
使用 Agent 工具调用:

{
  "subagent_type": "general-purpose",
  "description": "修复 F001 错误",
  "prompt": "
    功能 ID: F001
    修复尝试: 第 2 次

    错误详情:
    AssertionError: expected True but got False
    File: src/auth.py, Line: 45

    要求:
    1. 分析错误根因
    2. 只修复代码，不修改测试
    3. 不要设置 passes=true
  "
}

修复循环逻辑:
- attempt = 1, MAX_FIX_ATTEMPTS = 3
- while attempt <= MAX_FIX_ATTEMPTS:
    - 调用 Fix Subagent
    - 调用 Verification Subagent
    - if passed: break
    - attempt += 1
- if still failed: mark feature as blocked
```

---

## 状态更新规则

### 只有主 Agent 可以更新 passes

```python
# 正确的状态更新逻辑

def update_feature_status(feature_id, verification_result):
    # 只有在验证通过后才更新
    if verification_result["verification_status"] == "passed":
        # 1. Merge worktree
        merge_worktree(feature_id)

        # 2. 更新 features.json
        Edit .agent/features.json:
            feature.passes = True
            feature.verification_status = "passed"
            feature.last_verification_at = timestamp

        # 3. 更新 progress.md
        Edit .agent/progress.md:
            添加完成记录

        # 4. Git commit
        git_commit(f"[{feature_id}] 功能描述")
    else:
        # 不更新 passes，记录失败
        Edit .agent/verification-results.json:
            添加验证失败记录
```

### 禁止绕过验证

任何情况下都禁止：
- ❌ Implementation 完成后直接设置 passes=true
- ❌ Fix 完成后直接设置 passes=true
- ❌ 跳过 Verification 步骤
- ❌ Subagent 自行修改 features.json

---

## Blocked 功能处理

当功能修复循环超过 3 次仍未通过：

```
1. Edit .agent/features.json:
   feature.blocked = True
   feature.blocked_reason = "超过最大修复尝试次数"

2. Edit .agent/verification-results.json:
   blocked_features 添加记录

3. 继续处理下一个功能

4. progress.md 记录 blocked 状态
```

---

## 文件格式规范

### features.json (更新后)

```json
{
  "features": [
    {
      "id": "F001",
      "category": "setup|core|auth|api|ui",
      "description": "功能描述",
      "steps": ["验证步骤1", "验证步骤2"],
      "passes": false,
      "priority": "critical|high|medium|low",
      "verification_status": "pending|passed|failed",
      "verification_attempts": 0,
      "last_verification_at": null,
      "implementation_worktree": null,
      "blocked": false,
      "blocked_reason": null
    }
  ]
}
```

### progress.md

```markdown
# 项目进度日志

## 会话 X - YYYY-MM-DD
**状态**: 进行中
**进度**: X/N features

### 完成工作
- [F00X] 功能描述 (验证通过 ✓)
  - Implementation Subagent: 创建文件 X, Y
  - Verification Subagent: 测试全部通过
  - 修复尝试: 0 次

### Blocked 功能
- [F00Y] 功能描述 (Blocked ⚠️)
  - 原因: 超过最大修复尝试次数(3次)
  - 最后错误: AssertionError...

### 下一步
- F00Z 下一个功能描述
```

### verification-results.json

```json
{
  "verification_history": [
    {
      "feature_id": "F001",
      "timestamp": "...",
      "attempt": 1,
      "status": "failed",
      "error_details": "...",
      "fix_applied": {
        "files_modified": ["src/module.py"],
        "fix_summary": "..."
      }
    },
    {
      "feature_id": "F001",
      "attempt": 2,
      "status": "passed"
    }
  ],
  "blocked_features": [
    {
      "feature_id": "F003",
      "reason": "超过最大修复尝试次数",
      "last_error": "..."
    }
  ]
}
```

---

## 必需文件结构

```
项目根目录/
├── CLAUDE.md                    # 项目特定指令
├── AGENT_SUBAGENT_FLOW.md       # Subagent工作流程文档
├── .agent/
│   ├── features.json            # 功能清单 (含验证状态)
│   ├── progress.md              # 进度日志
│   ├── verification-results.json # 验证历史记录
│   └── templates/
│       ├── implementation-prompt.md
│       ├── verification-prompt.md
│       └── fix-prompt.md
├── init.sh                      # 环境启动脚本
└── tests/                       # 测试目录
```

---

## 禁止行为

| 禁止行为 | 原因 |
|---------|------|
| Subagent 修改 features.json | 状态更新权限只在主 Agent |
| 跳过 Verification 步骤 | 未验证的功能不可靠 |
| Implementation 后直接设置 passes | 必须等待验证结果 |
| 修改测试本身来通过验证 | 测试是正确标准，代码需要修复 |
| 一次做多个功能 | 上下文会溢出 |

---

## 会话结束检查清单

```
□ 所有更改已 git commit
□ features.json 状态已更新 (只有验证通过的)
□ progress.md 已更新
□ verification-results.json 已更新
□ git status 显示 working tree clean
□ 没有遗留的 worktree
```

---

## 与原架构对比

| 方面 | 原架构 | 新架构 |
|------|--------|--------|
| 执行方式 | Shell脚本循环调用CLI | 主Agent调度Subagent |
| 上下文 | 每次新会话 | 主Agent持久保持 |
| 实现隔离 | 无 | Worktree隔离 |
| 验证时机 | 项目完成后 | 每功能完成后 |
| Pass标记 | 脚本自动标记 | 主Agent验证后标记 |
| 修复机制 | 无 | 最多3次修复循环 |
| 失败处理 | 无 | Blocked标记 |

---

## 开始工作

现在，请按照上述流程开始工作：

1. **加载状态文件**
2. **选择 passes=false 的功能**
3. **调用 Implementation Subagent**
4. **调用 Verification Subagent**
5. **处理结果** (通过→更新状态，失败→修复循环)

记住：**只有验证通过才能标记 passes=true！**