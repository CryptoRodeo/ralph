# Reverse Ralph →  Implementation Steps (Claude)

This repository includes a **Ralph-style planning loop** that turns a Jira / feature ticket into a **step-by-step implementation plan**, emitting **one concrete step at a time** using **Claude Code (`claude` CLI)**.

It is designed to be run from the **root of a software repository** and will automatically use that repository as contextual input (docs, configs, selected code, and images).

---

## What this script does

At a high level:

1. Takes a **ticket or user story** (Jira, GitHub issue, feature description)
2. Snapshots **high-signal repo context** (docs, design files, configs, images)
3. Generates a **structured implementation plan** (`plan.json`)
4. On each run, emits **exactly ONE next step** in executable detail
5. Persists progress so repeated runs continue where you left off

This makes it ideal for:
- Breaking down large features
- Onboarding into unfamiliar codebases
- Driving incremental, reviewable implementation
- AI-assisted planning without losing human control

---

## Requirements

- Bash (macOS / Linux)
- Claude Code CLI
- A Claude account with CLI access

---

## Quick start

### 1. Place the script at repo root

```
./ralph_ticket_steps.sh
```

---

### 2. Provide a ticket (choose one)

From a file:
```
./ralph_ticket_steps.sh --ticket-file TICKET.md
```

From stdin:
```
echo "As a user, I want..." | ./ralph_ticket_steps.sh --ticket-stdin
```

From a string / Jira URL:
```
./ralph_ticket_steps.sh --ticket "ABC-123: Add SBOM grouping support"
```

---

### 3. Get the first step

By default, the script emits **one step per run**:

```
./ralph_ticket_steps.sh --ticket-file TICKET.md
```

Re-run it to get the **next step**.

---

## Output files

All artifacts are written to `.ralph/`:

```
.ralph/
├── ticket.md
├── context.bundle.md
├── plan.json
├── state.json
└── progress.md
```

---

## Context handling

Included by default:
- README files
- docs/, design/, adr/
- Config files (JSON, YAML, etc.)
- Images (design mocks, diagrams)
- Limited code excerpts

Excluded by default:
- .git/
- node_modules/
- dist/, build/, target/
- Generated artifacts and caches

---

## Optional: .ralphignore

Create a `.ralphignore` file at repo root to exclude paths:

```
node_modules
dist
build
coverage
vendor
```

Each line is treated as a path prefix.

---

## Claude CLI configuration (recommended)

```
export LLM_CMD=claude
export LLM_ARGS="--permission-mode plan --max-turns 3 --no-session-persistence"
```

---

## Typical workflow

1. Paste ticket into `TICKET.md`
2. Run script → get Step 1
3. Implement step
4. Commit
5. Re-run script → next step

---

This tool is intentionally **planning-only**.
It does not edit files or execute code.

Happy shipping.
