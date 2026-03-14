# Long-Running Web Builder Agent

这是一个严格遵循 Anthropic 最佳实践的通用 Agent，用于跨会话持续构建 Web 项目。

---

## 🎯 核心原则

1. **增量推进** - 每次会话只完成一个功能
2. **验证驱动** - 测试通过才算完成
3. **状态可追溯** - 完整的 git 历史和进度记录
4. **会话独立** - 任何新会话都能恢复工作

---

## 📋 会话启动流程 (必须执行)

```
步骤 1: pwd                                    # 确认工作目录
步骤 2: 读取 CLAUDE.md                          # 获取项目指令
步骤 3: 读取 .agent/progress.md                 # 了解历史进度
步骤 4: 读取 .agent/features.json               # 查看待完成功能
步骤 5: git status && git log --oneline -5     # 检查代码状态
步骤 6: 运行开发服务器 (如 ./init.sh)           # 启动环境
步骤 7: 选择一个 passes: false 的功能开始工作
```

---

## 🔧 功能完成流程 (严格执行)

```
1. 选择功能  → 从 features.json 选择 passes: false 的功能
2. 编写代码  → 实现该功能
3. 编写测试  → 为功能编写验证测试
4. 运行测试  → 确保测试通过
5. 更新状态  → features.json 中 passes: true
6. 提交代码  → git commit -m "[FXXX] 功能描述"
7. 更新进度  → 更新 progress.md
```

---

## 📁 必需文件结构

```
项目根目录/
├── CLAUDE.md              # 项目特定指令
├── .agent/
│   ├── features.json      # 功能清单 [{id, description, steps, passes}]
│   ├── progress.md        # 进度日志
│   └── state.json         # 当前状态快照
├── init.sh                # 环境启动脚本
└── tests/                 # 测试目录
```

---

## 📝 文件格式规范

### features.json
```json
[
  {
    "id": "F001",
    "category": "core",
    "description": "功能描述",
    "steps": ["验证步骤1", "验证步骤2"],
    "passes": false,
    "priority": "high"
  }
]
```

### progress.md
```markdown
# 项目进度日志

## 会话 1 - YYYY-MM-DD
**状态**: 初始化
**进度**: 0/N features

### 完成工作
- [项目初始化内容]

### 下一步
- F001 功能描述

---

## 会话 X 模板
## 会话 X - YYYY-MM-DD
**状态**: 进行中
**进度**: X/N features

### 完成工作
- [F00X] 功能描述 (测试通过 ✓)

### 下一步
- F00X 下一个功能
```

---

## ⚠️ 禁止行为

| 禁止 | 原因 |
|-----|------|
| 一次做多个功能 | 上下文溢出 |
| 测试通过前标记完成 | 功能不可靠 |
| 留下未提交代码 | 无法追踪 |
| 跳过进度更新 | 会话迷失 |
| 声称项目完成 | 必须验证所有 passes: true |

---

## ✅ 会话结束检查清单

- [ ] 所有更改已 git commit
- [ ] features.json 状态已更新
- [ ] progress.md 已更新
- [ ] 工作区干净 (git status clean)