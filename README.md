# Long-Running Agent Template

A template for building long-running agents that use Claude Code's sub-agent architecture to implement all features in a single conversation.

---

## How It Works

1. Run `claude` in this directory
2. Claude reads `CLAUDE.md` and follows the orchestration instructions
3. The agent:
   - Analyzes requirements and designs test cases (Analysis sub-agent)
   - Loops through each feature:
     - Dispatches Implementation sub-agent (worktree isolation)
     - Dispatches Verification sub-agent (read-only testing)
     - Dispatches Fix sub-agents if needed (max 3 attempts)
   - Reports final summary

---

## Feature List

| ID | Feature | Status |
|----|---------|--------|
| F001 | Project structure | DONE |
| F002 | Core module | DONE |
| F003 | Calculator module | PENDING |

---

## Quick Start

```bash
# Start the agent
claude

# Or run tests directly
pytest tests/ -v
```

---

## Tech Stack

- Language: Python
- Testing: Pytest

---

## Project Structure

```
CLAUDE.md                    # Agent orchestration instructions
AGENT_INSTRUCTIONS.md        # Architecture reference
AGENT_SUBAGENT_FLOW.md       # Sub-agent flow specification
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
init.sh                      # Environment setup
```
