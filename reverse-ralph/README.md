# Reverse Ralph (🚧 WIP 🚧)

**Reverse Ralph** is a *ticket-first* planning tool that derives a concrete, step-by-step implementation plan from a Jira ticket or GitHub issue **using repository context**.

Instead of starting from code and discovering requirements later, Reverse Ralph starts with the **problem description** and works backward into an actionable plan.

It is designed to be:

- Deterministic and file-based
- Stateless with respect to the LLM (no hidden memory)
- Safe to re-run (skips work when outputs already exist)
- Friendly to Git workflows

---

## What Reverse Ralph Produces

Running the script generates artifacts inside an output directory (default: `.ralph/`):

| File                | Purpose                                                                 |
| ------------------- | ----------------------------------------------------------------------- |
| `ticket.md`         | Normalized ticket text (source of truth)                                |
| `context.bundle.md` | Curated repo context (docs/config, images, optional code excerpts)      |
| `ticket_analysis.md`| Structured understanding of the problem (requirements, risks, questions)|
| `derived_plan.json` | Ordered, implementation-ready plan (5–30 steps)                         |

> Note: There is **no** `reverse_state.json` in the current script. “State” is simply the presence/absence of these files.

---

## High-Level Workflow

Reverse Ralph runs in two stages:

### Stage 0 – Ticket Analysis

Produces `ticket_analysis.md` with:

- Problem statement
- In-scope / out-of-scope
- Requirements & acceptance criteria
- Constraints, assumptions, risks
- Open questions (prioritized)
- Suggested repo touchpoints

### Stage 1 – Plan Derivation (JSON)

Produces `derived_plan.json`:

- 5–30 incremental steps (each sized for \< 1 day)
- Acceptance criteria per step
- Early “spike/confirm” steps when unknowns remain
- Realistic repo touchpoints (based on provided context)

---

## Requirements

- Bash (the script uses `#!/usr/bin/env bash` + `set -euo pipefail`)
- An LLM CLI command (default: `claude`)
- `jq` (**required for Stage 1**; used to extract/validate schema output)
- `file` (optional; improves text/image detection)

---

## Installation

```bash
chmod +x reverse-ralph.sh
````

(Optional) Put it on your PATH:

```bash
mv reverse-ralph.sh ~/bin/reverse_ralph
```

---

## Basic Usage

You must provide **exactly one** ticket input mode.

### From a ticket file

```bash
./reverse-ralph.sh --ticket-file TICKET.md
```

### From stdin

```bash
cat TICKET.md | ./reverse-ralph.sh --ticket-stdin
```

### From inline text

```bash
./reverse-ralph.sh --ticket "ABC-123: Add filtering to groups table"
```

---

## Re-running Behavior

Reverse Ralph is intentionally “idempotent-ish”:

* It **always regenerates** `context.bundle.md` (fresh snapshot of repo context).
* Stage outputs are **skipped if they already exist**, unless you pass `--regen`.

Specifically:

* If `.ralph/ticket_analysis.md` exists and you **don’t** use `--regen`, Stage 0 is skipped.
* If `.ralph/derived_plan.json` exists and you **don’t** use `--regen`, Stage 1 is skipped.

---

## Regenerating Outputs

If you update the ticket or repo context and want to re-derive the analysis and plan:

```bash
./reverse-ralph.sh --ticket-file TICKET.md --regen
```

This will re-run Stage 0 and Stage 1 even if previous outputs exist.

> Note: The script does not delete previous artifacts; it simply overwrites the stage outputs it regenerates.

---

## Context Collection (Important)

Reverse Ralph builds a **context bundle** automatically (`context.bundle.md`), including:

### Included by default

* README files
* Docs (`docs/`, `design/`, `adr/`, etc.)
* Config and metadata (`package.json`, `tsconfig*.json`, `go.mod`, `Cargo.toml`, `*.yaml`, `*.json`, etc.)
* Images (paths + MIME/size metadata + “Analyze this image:” hints)
* **Optional code excerpts** (enabled by default)

### Excluded by default

* `.git/`, `node_modules/`, `dist/`, `build/`, caches, IDE files, venvs, etc.
* Anything matching prefixes in `.ralphignore`

### Disable code excerpts (docs-only mode)

```bash
./reverse-ralph.sh --ticket-file TICKET.md --no-code
```

---

## Ignoring Files with `.ralphignore`

Create a `.ralphignore` file in your repo root to exclude paths from scanning:

```text
# Ignore generated files
dist/
coverage/
tmp/
```

Rules are simple **prefix matches** (intentionally minimal).

---

## Output Directory

By default, all artifacts go into:

```text
.ralph/
```

Override with:

```bash
./reverse-ralph.sh --ticket-file TICKET.md --out-dir .reverse-ralph
```

---

## Repo Context Root

By default, Reverse Ralph scans the current directory (`.`). Override with:

```bash
./reverse-ralph.sh --ticket-file TICKET.md --context-dir /path/to/repo
```

---

## LLM Configuration

Reverse Ralph is **stateless by design**. It uses no hidden conversational memory (`--no-session-persistence` by default). All durable state is the files it writes.

### Command

```bash
export LLM_CMD=claude
```

### Stage-specific args (recommended)

```bash
export LLM_ARGS_STAGE0="--permission-mode plan --max-turns 8 --no-session-persistence"
export LLM_ARGS_STAGE1="--max-turns 12 --no-session-persistence"
```

> Stage 1 requests `--output-format json` + `--json-schema ...` internally and extracts `.structured_output` with `jq`.

---

## Tuning Context Size Limits (Optional)

The script includes caps you can override via env vars:

* `MAX_TEXT_BYTES` (default: `120000`) – per doc/config excerpt
* `MAX_CODE_BYTES` (default: `80000`) – per code excerpt
* `MAX_FILES_DOCS` (default: `45`)
* `MAX_FILES_CODE` (default: `25`)
* `MAX_FILES_IMAGES` (default: `25`)

Example:

```bash
export MAX_FILES_CODE=10
export MAX_CODE_BYTES=40000
./reverse-ralph.sh --ticket-file TICKET.md
```

---

## Typical Workflow

1. Paste/export a Jira ticket or GitHub issue into `TICKET.md`
2. Run Reverse Ralph
3. Review `.ralph/ticket_analysis.md` (fix missing details / clarify unknowns)
4. Review `.ralph/derived_plan.json` (edit steps if needed)
5. Feed plan steps into:

   * A forward “Ralph loop”
   * A task runner
   * A human-driven implementation process

---

## Design Philosophy

* **Tickets are contracts**
* **Assumptions must be explicit**
* **Unknowns should surface early**
* **Plans should be incremental and testable**
* **LLMs should not hold hidden state**

Reverse Ralph exists to turn vague tickets into something an engineer can actually execute.

---

## Usage

This script is intended for internal tooling, experimentation, and developer workflows.
Adapt it freely to fit your planning or execution loops.
