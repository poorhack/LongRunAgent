# Long-Running Agent - Architecture Reference

Single-conversation coordinator model using Claude Code sub-agents.

---

## Architecture

```
                    Main Agent (Coordinator)
                    ├─ State management (features.json, progress.md)
                    ├─ Sub-agent dispatch and result review
                    └─ Final authority on passes=true
                          │
            ┌─────────────┼─────────────┐
            │             │             │
     ┌──────┴──────┐ ┌───┴────┐ ┌──────┴──────┐
     │ Analysis    │ │ Verify │ │    Fix      │
     │ (once)      │ │(per    │ │(max 3x)     │
     └─────────────┘ │feature)│ └─────────────┘
                     └────────┘
            ┌─────────────┐
            │Implement    │
            │(per feature)│
            └─────────────┘
```

---

## Workflow

### Phase 1: Bootstrap

```
Read .agent/features.json
Read .agent/verification-results.json
Read .agent/progress.md
git status && git log --oneline -5
Build prioritized feature list
```

### Phase 2: Requirements Clarification

Dispatch Analysis sub-agent to:
- Audit feature completeness
- Design test cases for each feature
- Validate dependency ordering

Main agent reviews findings and updates `features.json`.

### Phase 3: Main Loop

```
for each feature (sorted by priority, passes=false, blocked=false):
    1. Implementation sub-agent (worktree isolation)
    2. Verification sub-agent (read-only, same worktree)
    3. If passed:
       - Merge worktree
       - Update features.json: passes=true
       - Update verification-results.json
       - Update progress.md
       - Git commit
    4. If failed:
       - Fix loop (max 3 attempts):
         a. Fix sub-agent (with error details)
         b. Verification sub-agent again
         c. If passed: merge, commit, break
       - If still failed: mark blocked, cleanup worktree
```

### Phase 4: Completion

Print summary of passed/blocked/total features.

---

## Sub-Agent Contracts

| Sub-Agent | Type | Isolation | Can Write Code | Can Run Tests | Can Update State |
|-----------|------|-----------|---------------|--------------|-----------------|
| Analysis | general-purpose | none | NO | NO | NO |
| Implementation | general-purpose | worktree | YES | YES | NO |
| Verification | general-purpose | same worktree | NO | YES | NO |
| Fix | general-purpose | same worktree | YES | NO | NO |

### Analysis Sub-Agent
- **Input**: Project context, features.json content
- **Output**: Completeness audit, test case designs, dependency analysis
- **Runs**: Once, before main loop

### Implementation Sub-Agent
- **Input**: Feature ID, description, steps, test cases
- **Output**: `{status, files_created, files_modified, tests_created, implementation_summary}`
- **Runs**: Once per feature

### Verification Sub-Agent
- **Input**: Feature ID, test command
- **Output**: `{verification_status, tests_passed, tests_failed, error_details}`
- **Runs**: After implementation, and after each fix attempt

### Fix Sub-Agent
- **Input**: Feature ID, error details, attempt number
- **Output**: `{status, files_modified, fix_summary, root_cause}`
- **Runs**: Up to 3 times per failed feature

---

## State Management

### Only the Main Agent Updates State

- `passes=true` -- only after verification sub-agent confirms passed
- `blocked=true` -- only after 3 fix attempts fail
- `progress.md` -- main agent appends entries
- `verification-results.json` -- main agent appends records
- Git commits -- main agent only

### Sub-Agents Must NOT

- Modify `.agent/features.json`
- Modify `.agent/progress.md`
- Modify `.agent/verification-results.json`
- Set `passes=true` or `blocked=true`
- Make git commits

---

## Worktree Lifecycle

```
Per feature:
  1. Agent tool with isolation: "worktree" creates isolated worktree
  2. Implementation sub-agent writes code in worktree
  3. Verification sub-agent tests in same worktree
  4a. PASS:  merge worktree branch → remove worktree
  4b. BLOCK: remove worktree (no merge)
```

---

## Blocked Features

After 3 failed fix attempts:
1. Set `blocked=true` in features.json
2. Set `blocked_reason` with last error summary
3. Add to `blocked_features` in verification-results.json
4. Remove worktree without merging
5. Continue to next feature

---

## Resume Protocol

If the conversation is interrupted:
1. New conversation reads checkpointed state files
2. Skips Requirements Clarification if `test_cases` already populated
3. Resumes from the next incomplete feature
4. Any in-progress worktree should be cleaned up manually

---

## Features.json Schema

```json
{
  "project": {
    "name": "string",
    "description": "string",
    "tech_stack": ["string"],
    "created_at": "date"
  },
  "features": [
    {
      "id": "FXXX",
      "category": "setup|core|auth|api|ui|test",
      "description": "string",
      "steps": ["step"],
      "test_cases": [
        {
          "name": "string",
          "input": "string",
          "expected": "string",
          "type": "unit|integration|edge_case"
        }
      ],
      "passes": false,
      "priority": "critical|high|medium|low",
      "verification_status": "pending|passed|failed",
      "verification_attempts": 0,
      "last_verification_at": null,
      "blocked": false,
      "blocked_reason": null
    }
  ],
  "statistics": {
    "total": 0,
    "passed": 0,
    "failed": 0,
    "pending": 0,
    "blocked": 0
  }
}
```
