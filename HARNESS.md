# Long-Running Agent Harness

## How It Works

This project uses a single-conversation agent model:

1. Run `claude` in the project directory
2. Claude reads `CLAUDE.md` and follows the orchestration instructions
3. The agent loops through all features, dispatching sub-agents for each task
4. State is checkpointed to files for crash recovery

No shell scripts needed -- everything runs within a single Claude Code conversation.

---

## File Structure

```
CLAUDE.md                         # Agent orchestration instructions (entry point)
AGENT_INSTRUCTIONS.md             # Architecture reference
AGENT_SUBAGENT_FLOW.md            # Sub-agent flow specification
.agent/
  features.json                   # Feature registry with test cases
  progress.md                     # Progress log
  verification-results.json       # Verification history
  templates/
    analysis-prompt.md            # Requirements analysis template
    implementation-prompt.md      # Implementation template
    verification-prompt.md        # Verification template
    fix-prompt.md                 # Fix template
src/                              # Source code
tests/                            # Test files
init.sh                           # Environment setup script
```

---

## Workflow Phases

| Phase | What Happens | Sub-Agent |
|-------|-------------|-----------|
| Bootstrap | Load state, check git | None |
| Requirements Clarification | Audit features, design test cases | Analysis |
| Main Loop (per feature) | Implement code | Implementation |
| | Verify tests | Verification |
| | Fix failures (max 3x) | Fix + Verification |
| Completion | Summary report | None |

---

## How to Customize

### For Your Project

1. Edit `CLAUDE.md` -- update project configuration section
2. Edit `.agent/features.json` -- define your features with test cases
3. Edit templates in `.agent/templates/` -- adjust for your tech stack
4. Edit `init.sh` -- set up your development environment

### Feature Format

```json
{
  "id": "F001",
  "category": "setup",
  "description": "What this feature does",
  "steps": ["Step 1", "Step 2"],
  "test_cases": [
    {
      "name": "test something",
      "input": "conditions to test",
      "expected": "expected outcome",
      "type": "unit"
    }
  ],
  "passes": false,
  "priority": "high"
}
```

---

## How to Resume

If the conversation is interrupted:
1. Start a new `claude` session in the project directory
2. Claude reads the checkpointed state files automatically
3. It skips the analysis phase if test_cases already exist
4. It continues from the next incomplete feature
