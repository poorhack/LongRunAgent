# Fix Task

## Context

- **Feature ID**: [FEATURE_ID]
- **Fix Attempt**: [ATTEMPT_NUMBER] of 3

---

## Error Details

```
[ERROR_DETAILS]
```

---

## Failed Tests

| Test | Error |
|------|-------|
| [FAILED_TESTS_TABLE] |

---

## Your Task

1. **Analyze root cause** of the test failures
2. **Locate the problem** in the source code
3. **Fix the code** -- make minimal, targeted changes
4. **Verify logic** -- ensure the fix addresses the root cause

---

## Prohibitions

- Do NOT modify `.agent/features.json`
- Do NOT set `passes=true`
- Do NOT modify test files -- tests define correct behavior
- Do NOT delete or skip tests
- Do NOT make unrelated changes

---

## Fix Principles

- Tests fail because code has bugs, not because tests are wrong
- Make minimal fixes -- do not refactor or redesign
- Each fix should target the specific failing test(s)
- If you cannot identify the root cause, return `fix_failed` with your analysis

---

## Return Format

```json
{
  "status": "fixed" | "fix_failed",
  "files_modified": ["file1", "file2"],
  "fix_summary": "What was changed and why",
  "root_cause": "Analysis of why the bug occurred"
}
```

If you cannot fix the issue, return `status: "fix_failed"` with a detailed analysis.
