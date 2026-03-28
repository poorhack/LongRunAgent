---
feature_id: {feature_id}
---

# 功能验证任务

## 关键规则 ⚠️ **READ-ONLY 模式**

**你必须遵守以下规则：**

- ❌ **不能修改**任何代码文件
- ❌ **不能更新** `.agent/features.json`
- ❌ **不能设置** `passes=true`
- ❌ **不能创建**或删除文件
- ✓ **只能**运行测试和读取文件
- ✓ **只能**报告验证结果

---

## 验证对象

- **ID**: {feature_id}
- **描述**: {description}
- **验证步骤**: {steps}

---

## 测试命令

执行以下测试命令验证功能：

```bash
{test_command}
```

如果没有指定测试命令，请查找并运行相关测试：

```bash
# 常用测试命令（根据项目类型选择）
pytest tests/ -v --tb=short
npm test
go test ./...
```

---

## 验证流程

1. 确认测试文件存在
2. 运行测试命令
3. 检查测试输出
4. 验证功能步骤是否通过

---

## 返回格式

请返回以下 JSON 格式的验证结果：

```json
{
  "feature_id": "{feature_id}",
  "verification_status": "passed" | "failed",
  "tests_run": ["test1", "test2"],
  "tests_passed": ["test1"],
  "tests_failed": ["test2"],
  "total_tests": 3,
  "passed_count": 2,
  "failed_count": 1,
  "error_details": "如果失败，包含具体的错误信息和堆栈",
  "step_verification": {
    "step1": true,
    "step2": false
  }
}
```

---

## 重要提醒

- 你的任务是**验证**，不是**修复**
- 如果测试失败，只报告结果，不要尝试修复
- 主 agent 会根据结果决定下一步操作
- 修改文件会导致验证结果无效