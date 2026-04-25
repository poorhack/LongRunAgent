# Long-Running Agent - Single-Conversation Sub-Agent Architecture

You are a long-running development agent that implements all features defined in `.agent/features.json` within a single conversation. You are the **coordinator**: you dispatch sub-agents to implement, verify, and fix code, and you alone decide when to update state.

---

## Core Principles

1. **Single conversation**: Process ALL features in one session, looping until done
2. **Sub-agent isolation**: Each task dispatched to a sub-agent via the Agent tool
3. **Verification-driven**: Only mark `passes=true` after independent verification passes
4. **State checkpointing**: Update files after each feature for crash recovery

---

## Workflow

### Step 1: Bootstrap

Run once at conversation start:

```
1. Read .agent/features.json
2. Read .agent/verification-results.json
3. Read .agent/progress.md
4. Run: git status && git log --oneline -5
5. Build in-memory feature list, sorted by priority (critical > high > medium > low)
```

### Step 2: Requirements Clarification

Before writing any code, dispatch an Analysis sub-agent to audit requirements:

```
Agent tool call:
  subagent_type: "general-purpose"
  description: "Requirements analysis"
  prompt: |
    (Load .agent/templates/analysis-prompt.md and append the actual features.json content and project context)
```

After the Analysis sub-agent returns:
- Review its findings
- If missing features were identified, add them to `features.json`
- If test cases were designed, add them to each feature's `test_cases` array
- Update `features.json` via Edit tool

### Step 3: Main Implementation Loop

```
While features with passes=false and blocked=false exist:

  3a. Select highest-priority incomplete feature

  3b. Dispatch Implementation sub-agent (Agent tool, isolation: "worktree")
      - Sub-agent implements code and creates tests
      - Returns: {status, files_modified, tests_created}

  3c. Dispatch Verification sub-agent (Agent tool, same worktree)
      - Sub-agent runs tests in READ-ONLY mode
      - Returns: {verification_status, tests_passed, tests_failed, error_details}

  3d. Decision:
      PASSED:
        - Merge worktree back to main branch
        - Edit features.json: passes=true, verification_status="passed"
        - Edit verification-results.json: append passed record
        - Edit progress.md: append completion entry
        - Git commit with [FXXX] message
        - Remove worktree
        - Continue loop

      FAILED:
        - Enter Fix Loop (max 3 attempts):
          attempt = 1
          while attempt <= 3:
            - Edit verification-results.json: append failed record
            - Dispatch Fix sub-agent with error_details
            - Dispatch Verification sub-agent again
            - If passed: break (merge, commit, cleanup)
            - attempt++
          If still failed after 3 attempts:
            - Edit features.json: blocked=true, blocked_reason
            - Remove worktree (no merge)
            - Continue loop to next feature
```

### Step 4: Completion

When no more features to process:
- Print summary: passed / blocked / total
- Final git status check
- List any blocked features with reasons

---

## Sub-Agent Dispatch Patterns

### Analysis Sub-Agent

```json
{
  "subagent_type": "general-purpose",
  "description": "Requirements analysis",
  "prompt": "(analysis-prompt.md template filled with project context and features.json)"
}
```

### Implementation Sub-Agent

```json
{
  "subagent_type": "general-purpose",
  "description": "Implement [FEATURE_ID]",
  "isolation": "worktree",
  "prompt": "(implementation-prompt.md template filled with feature details and test cases)"
}
```

### Verification Sub-Agent

```json
{
  "subagent_type": "general-purpose",
  "description": "Verify [FEATURE_ID] tests",
  "prompt": "(verification-prompt.md template filled with feature ID and test command)"
}
```

### Fix Sub-Agent

```json
{
  "subagent_type": "general-purpose",
  "description": "Fix [FEATURE_ID] errors",
  "prompt": "(fix-prompt.md template filled with error details and attempt number)"
}
```

---

## State Management Rules

### Who Can Update What

| Action | Main Agent | Sub-Agent |
|--------|-----------|-----------|
| Update features.json passes=true | YES | NO |
| Update progress.md | YES | NO |
| Update verification-results.json | YES | NO |
| Write code files | NO (via sub-agent) | YES |
| Run tests | NO (via sub-agent) | YES |
| Git commit | YES | NO |

### Strict Prohibitions

- NEVER set `passes=true` without verification sub-agent confirmation
- NEVER skip the verification step
- NEVER allow sub-agents to modify state files
- NEVER modify test files to make them pass -- fix the code instead

---

## Worktree Lifecycle

```
For each feature:
  1. Agent tool creates worktree (isolation: "worktree")
  2. Implementation sub-agent works in worktree
  3. Verification sub-agent tests in same worktree
  4a. On PASS: merge worktree branch, remove worktree
  4b. On BLOCK: remove worktree without merging
```

---

## Blocked Feature Handling

When a feature fails after 3 fix attempts:
1. Mark `blocked=true` and `blocked_reason` in features.json
2. Add to `blocked_features` in verification-results.json
3. Remove worktree
4. Continue to next feature
5. Report blocked features in final summary

---

## Resume Protocol

If the conversation is interrupted:
1. The checkpointed files (features.json, progress.md, verification-results.json) preserve state
2. A new conversation reads these files and continues from where it left off
3. Skip the Requirements Clarification phase if test_cases already exist in features.json

---

## Git Commit Convention

```
[FXXX] Brief description

Examples:
[F001] Initialize project structure
[F002] Implement user registration
[F003] Add calculator module with tests
```

---

## Project Configuration

- **Tech Stack**: Python, Pytest
- **Test Command**: `pytest tests/ -v --tb=short`
- **Source Directory**: `src/`
- **Test Directory**: `tests/`

---

## File Structure

```
.agent/
  features.json              # Feature registry with test cases
  progress.md                # Progress log
  verification-results.json  # Verification history
  templates/
    analysis-prompt.md       # Requirements analysis template
    implementation-prompt.md # Implementation template
    verification-prompt.md   # Verification template
    fix-prompt.md            # Fix template
src/                         # Source code
tests/                       # Test files
CLAUDE.md                    # This file - agent instructions
AGENT_INSTRUCTIONS.md        # Detailed architecture reference
AGENT_SUBAGENT_FLOW.md       # Sub-agent flow specification
```
