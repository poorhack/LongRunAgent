# 项目名称

<!-- 此文件包含项目特定的 Agent 指令 -->

---

## 🎯 项目目标

[描述项目要实现的核心目标]

---

## 🏗️ 技术架构

- **框架**: [如 Flask / Express / Next.js]
- **数据库**: [如 SQLite / PostgreSQL / MongoDB]
- **测试**: [如 Pytest / Jest / Playwright]
- **UI**: [如 Jinja2 / React / Vue]

---

## 📋 Long-Running Agent 工作流程

此项目使用 Long-Running Agent 最佳实践，确保跨会话持续开发。

### 会话启动检查 (必须执行)

```
1. pwd                                    # 确认目录
2. 读取 .agent/progress.md                # 历史进度
3. 读取 .agent/features.json              # 功能清单
4. git status && git log --oneline -5     # 代码状态
5. ./init.sh                              # 启动环境
```

### 功能完成流程

```
选择功能 → 实现代码 → 编写测试 → 运行测试 → 更新状态 → Git提交
```

---

## 🚀 开发命令

```bash
# 启动开发环境
./init.sh

# 运行测试
[测试命令]

# 运行特定测试
[测试特定功能的命令]

# 代码检查
[lint命令]
```

---

## 📁 项目结构

```
src/                 # 源代码
tests/               # 测试文件
.agent/              # Agent 状态文件
├── features.json    # 功能清单
├── progress.md      # 进度日志
└── state.json       # 状态快照
```

---

## 📝 开发规范

### Git Commit 格式
```
[FXXX] 简洁描述

示例:
[F001] 实现用户注册功能
[F002] 添加登录验证
```

### 代码风格
- [代码风格规范]

---

## ⚠️ 注意事项

- **一次只做一个功能**
- **测试通过才算完成**
- **及时提交代码**
- **更新进度文件**