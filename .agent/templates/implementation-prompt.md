---
feature_id: {feature_id}
---

# 功能实现任务

## 功能信息

- **ID**: {feature_id}
- **描述**: {description}
- **步骤**: {steps}
- **类别**: {category}
- **优先级**: {priority}

---

## 实现要求

1. 根据描述实现功能代码
2. 在 `tests/` 目录创建对应的测试文件
3. 确保代码符合项目规范

---

## 项目上下文

- **技术栈**: {tech_stack}
- **工作目录**: worktree 隔离环境

---

## 禁止事项 ⚠️

- ❌ **不要修改** `.agent/features.json`
- ❌ **不要设置** `passes=true`
- ❌ **不要提交代码**（worktree 会由主 agent 处理）
- ❌ **不要标记功能完成**

---

## 返回格式

完成后请返回以下格式的摘要：

```json
{
  "status": "implemented" | "implementation_failed",
  "files_created": ["文件列表"],
  "files_modified": ["文件列表"],
  "tests_created": ["测试文件列表"],
  "implementation_summary": "实现内容摘要"
}
```

---

## 注意事项

- 你是在隔离的 worktree 中工作
- 所有变更会由主 agent 决定是否合并
- 测试文件是必需的，不要省略
- 如果实现遇到问题，返回 `implementation_failed` 并说明原因