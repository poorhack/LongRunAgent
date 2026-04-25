# Verification Task

**READ-ONLY MODE** -- You must NOT modify any files.

---

## Feature

- **ID**: [FEATURE_ID]
- **Description**: [FEATURE_DESCRIPTION]

---

## Test Command

Run this command to verify:

```bash
[TEST_COMMAND]
```

If no specific command is provided, try:

```bash
pytest tests/ -v --tb=short
```

---

## Verification Steps

1. Confirm test files exist
2. Run the test command
3. Check output for pass/fail status
4. Note any error messages or stack traces

---

## Prohibitions

- Do NOT modify any source files
- Do NOT modify any test files
- Do NOT modify `.agent/features.json`
- Do NOT set `passes=true`
- Do NOT create or delete files

---

## Return Format

Return verification results:

```json
{
  "feature_id": "[FEATURE_ID]",
  "verification_status": "passed" | "failed",
  "tests_run": ["test1", "test2"],
  "tests_passed": ["test1"],
  "tests_failed": ["test2"],
  "total_tests": 3,
  "passed_count": 2,
  "failed_count": 1,
  "error_details": "Full error output if any tests failed, including stack traces"
}
```

---

## Important

- Your job is to VERIFY, not to fix
- If tests fail, report the failure details -- the main agent will decide what to do
- Run tests exactly as specified, do not skip any
