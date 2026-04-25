# Sub-Agent Flow Specification

How the main agent dispatches sub-agents and processes results.

---

## Agent Tool Calling Convention

All sub-agents are dispatched via Claude Code's Agent tool:

```
Agent({
  subagent_type: "general-purpose",
  description: "Brief task description",
  isolation: "worktree" | undefined,
  prompt: "Complete task instructions"
})
```

- `subagent_type`: Always `general-purpose` (needs Bash access for running tests)
- `isolation`: `"worktree"` for Implementation; undefined for Analysis/Verification/Fix
- `description`: Short label for logging
- `prompt`: Full instructions constructed from templates

---

## Prompt Construction

### Step 1: Read Template

```
Read .agent/templates/[template-name].md
```

### Step 2: Replace Placeholders

Replace `[PLACEHOLDER]` markers with actual values from features.json:

| Placeholder | Source |
|-------------|--------|
| `[FEATURE_ID]` | feature.id |
| `[FEATURE_DESCRIPTION]` | feature.description |
| `[FEATURE_CATEGORY]` | feature.category |
| `[FEATURE_PRIORITY]` | feature.priority |
| `[FEATURE_STEPS]` | feature.steps (formatted as list) |
| `[FEATURE_TEST_CASES]` | feature.test_cases (formatted as list) |
| `[TEST_COMMAND]` | project test command |
| `[ERROR_DETAILS]` | verification sub-agent error output |
| `[ATTEMPT_NUMBER]` | current fix attempt (1-3) |
| `[FAILED_TESTS_TABLE]` | failed tests from verification result |

### Step 3: Dispatch

Pass the constructed prompt to the Agent tool.

---

## Flow: Requirements Analysis

```
Main Agent:
  1. Read .agent/templates/analysis-prompt.md
  2. Append features.json content and project context
  3. Agent({ description: "Requirements analysis", prompt: constructed_prompt })
  4. Review returned JSON
  5. Edit features.json: add missing features, add test_cases
```

---

## Flow: Feature Implementation

```
Main Agent:
  1. Read .agent/templates/implementation-prompt.md
  2. Replace placeholders with feature data (including test_cases)
  3. Agent({
       description: "Implement [FEATURE_ID]",
       isolation: "worktree",
       prompt: constructed_prompt
     })
  4. Review result:
     - status == "implemented" → proceed to verification
     - status == "implementation_failed" → mark blocked, skip to next
```

---

## Flow: Verification

```
Main Agent:
  1. Read .agent/templates/verification-prompt.md
  2. Replace placeholders with feature ID and test command
  3. Agent({ description: "Verify [FEATURE_ID]", prompt: constructed_prompt })
  4. Review result:
     - verification_status == "passed" → merge, update state, commit
     - verification_status == "failed" → enter fix loop
```

---

## Flow: Fix Loop

```
Main Agent:
  attempt = 1
  MAX_FIX_ATTEMPTS = 3
  last_error = verification_result.error_details

  while attempt <= MAX_FIX_ATTEMPTS:
    1. Edit verification-results.json: append failed record
    2. Read .agent/templates/fix-prompt.md
    3. Replace: [ERROR_DETAILS], [ATTEMPT_NUMBER], [FAILED_TESTS_TABLE]
    4. Agent({ description: "Fix [FEATURE_ID] attempt [N]", prompt: constructed_prompt })
    5. Review fix result
    6. Dispatch Verification sub-agent again
    7. If passed: break
    8. last_error = new verification error_details
    9. attempt++

  if verification still failed:
    Edit features.json: blocked=true, blocked_reason=last_error
    Edit verification-results.json: add to blocked_features
    Cleanup worktree
```

---

## Result Interpretation

### Implementation Result

```json
{
  "status": "implemented" | "implementation_failed",
  "files_created": [],
  "files_modified": [],
  "tests_created": [],
  "implementation_summary": "..."
}
```

- `implemented` → proceed to verification
- `implementation_failed` → log error, mark blocked if retry is pointless

### Verification Result

```json
{
  "verification_status": "passed" | "failed",
  "tests_passed": [],
  "tests_failed": [],
  "error_details": "..."
}
```

- `passed` → merge worktree, update state, commit
- `failed` → extract error_details for fix sub-agent

### Fix Result

```json
{
  "status": "fixed" | "fix_failed",
  "files_modified": [],
  "fix_summary": "...",
  "root_cause": "..."
}
```

- `fixed` → re-verify
- `fix_failed` → still re-verify (fix may have partial effect), count toward max attempts

---

## Worktree Management

```
Implementation sub-agent creates worktree via isolation: "worktree"
  → Sub-agent gets a new branch and working directory
  → All changes are isolated from main working tree

After feature resolves:
  PASS:  Worktree auto-merges when sub-agent returns (handled by Agent tool)
  BLOCK: Worktree auto-cleans if no changes needed (handled by Agent tool)

Note: If Agent tool with isolation:"worktree" returns successfully and changes
are desired, the main agent can cherry-pick or merge the branch. If the agent
returns without changes, the worktree is automatically cleaned up.
```
