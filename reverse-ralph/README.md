# Reverse Ralph (🚧 WIP 🚧)

**Reverse Ralph** is a *ticket-first* planning tool that derives a concrete, step-by-step implementation plan from a Jira ticket or GitHub issue **using repository context**.

Instead of starting from code and discovering requirements later, Reverse Ralph starts with the **problem description** and works backward into an actionable plan.

It is designed to be:

* Deterministic and file-based
* Stateless with respect to the LLM
* Safe to re-run and regenerate
* Friendly to Git workflows

---

## What Reverse Ralph Produces

Running the script generates a small set of artifacts inside an output directory (default: `.ralph/`):

| File                 | Purpose                                                                  |
| -------------------- | ------------------------------------------------------------------------ |
| `ticket.md`          | Normalized ticket text (source of truth)                                 |
| `context.bundle.md`  | Curated repo context (docs, config, images, optional code excerpts)      |
| `ticket_analysis.md` | Structured understanding of the problem (requirements, risks, questions) |
| `derived_plan.json`  | Ordered, implementation-ready plan (5–30 steps)                          |
| `reverse_state.json` | Tracks the current stage (for incremental runs)                          |

---

## High-Level Workflow

Reverse Ralph runs as a **two-stage state machine**:

### Stage 0 – Ticket Analysis

Produces `ticket_analysis.md`:

* Problem statement
* In-scope / out-of-scope
* Requirements & acceptance criteria
* Risks, assumptions, and open questions
* Suggested repo touchpoints

### Stage 1 – Plan Derivation

Produces `derived_plan.json`:

* Small, incremental steps (≤ 1 day each)
* Acceptance criteria per step
* Early “spike” steps if unknowns exist
* Realistic references to repo structure

After Stage 1, Reverse Ralph is **complete**.

---

## Requirements

* Bash (tested with `bash` + `set -euo pipefail`)
* `claude` CLI (or compatible LLM command)
* `file` utility (optional but recommended)
* A local repository (run from repo root)

---

## Installation

```bash
chmod +x reverse_ralph.sh
```

(Optional) Put it on your PATH:

```bash
mv reverse_ralph.sh ~/bin/reverse_ralph
```

---

## Basic Usage

You must provide **exactly one** source of ticket input.

### From a ticket file

```bash
./reverse_ralph.sh --ticket-file TICKET.md
```

### From stdin

```bash
cat TICKET.md | ./reverse_ralph.sh --ticket-stdin
```

### From inline text

```bash
./reverse_ralph.sh --ticket "ABC-123: Add filtering to groups table"
```

By default, **one stage advances per run**.

---

## Running All Stages in One Go

To fully generate both `ticket_analysis.md` and `derived_plan.json` in a single invocation:

```bash
./reverse_ralph.sh --ticket-file TICKET.md --iterations 2
```

---

## Regenerating Outputs

If you update the ticket or repo context and want to re-derive everything:

```bash
./reverse_ralph.sh --ticket-file TICKET.md --regen --iterations 2
```

This:

* Keeps `ticket.md` and context
* Deletes derived outputs
* Resets state to Stage 0

---

## Context Collection (Important)

Reverse Ralph builds a **context bundle** automatically.

### Included by default

* README files
* Docs (`docs/`, `design/`, `adr/`, etc.)
* Config files (`*.yaml`, `*.json`, `package.json`, `go.mod`, etc.)
* Images (paths + metadata)
* Representative code excerpts

### Excluded by default

* `.git/`, `node_modules/`, `dist/`, `build/`, caches, IDE files
* Any paths listed in `.ralphignore`

### Disable code excerpts (docs-only mode)

```bash
./reverse_ralph.sh --ticket-file TICKET.md --no-include-code
```

---

## Ignoring Files with `.ralphignore`

Create a `.ralphignore` file in your repo root to exclude paths from context scanning:

```text
# Ignore generated files
dist/
coverage/
tmp/
```

Rules are simple prefix matches (similar to `.gitignore`, but intentionally minimal).

---

## Output Directory

By default, all artifacts go into:

```text
.ralph/
```

You can override this:

```bash
./reverse_ralph.sh --ticket-file TICKET.md --out-dir .reverse-ralph
```

---

## LLM Configuration

Reverse Ralph is **stateless by design**.

By default it runs:

```bash
claude --permission-mode plan --max-turns 3 --no-session-persistence
```

You can override this behavior via environment variables:

```bash
export LLM_CMD=claude
export LLM_ARGS="--permission-mode plan --max-turns 5 --no-session-persistence"
```

No hidden memory is used. All state lives on disk.

---

## Typical Workflow

1. Paste or export a Jira ticket
2. Run Reverse Ralph
3. Review `ticket_analysis.md`
4. Review and edit `derived_plan.json`
5. Feed plan steps into:

   * A forward “Ralph loop”
   * A task runner
   * A human-driven implementation process

---

## Design Philosophy

* **Tickets are contracts**, not suggestions
* **Assumptions must be explicit**
* **Unknowns should surface early**
* **Plans should be incremental and testable**
* **LLMs should not hold hidden state**

Reverse Ralph exists to turn vague tickets into something an engineer can *actually execute*.

---

## License / Usage

This script is intended for internal tooling, experimentation, and developer workflows.
Adapt it freely to fit your planning or execution loops.
