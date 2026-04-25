# Implementation Task

## Feature

- **ID**: [FEATURE_ID]
- **Description**: [FEATURE_DESCRIPTION]
- **Category**: [FEATURE_CATEGORY]
- **Priority**: [FEATURE_PRIORITY]

---

## Implementation Steps

[FEATURE_STEPS]

---

## Test Cases

The following test cases must be covered by your tests:

[FEATURE_TEST_CASES]

---

## Requirements

1. Implement the feature code in the appropriate source files
2. Create corresponding test files in `tests/`
3. Tests must cover all test cases listed above
4. Follow the project's coding conventions
5. Ensure code compiles/runs without errors

---

## Prohibitions

- Do NOT modify `.agent/features.json`
- Do NOT set `passes=true`
- Do NOT commit code (worktree is handled by main agent)
- Do NOT modify state files (progress.md, verification-results.json)

---

## Return Format

After completing implementation, return:

```json
{
  "status": "implemented" | "implementation_failed",
  "files_created": ["list of new files"],
  "files_modified": ["list of modified files"],
  "tests_created": ["list of test files"],
  "implementation_summary": "Brief description of what was implemented"
}
```

If implementation fails, return `status: "implementation_failed"` with an explanation of what went wrong.
