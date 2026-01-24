# Ralph (Work in progress)

<img src="./ralph.jpeg" width="450">

Files, utilities and best practices related to [Ralph loops](https://ghuntley.com/ralph/)

## Quick Start

Initialize Ralph in your project with a single command:

```bash
curl -sSL https://raw.githubusercontent.com/CryptoRodeo/ralph/refs/heads/main/ralph_init.sh | bash
```

This will download `ralph.sh`, create `progress.txt` and `prd.json` files, and set up everything you need to start using Ralph loops.

## Reverse Ralph (Work in progress)

**Reverse Ralph** is the inverse of a traditional Ralph loop.

Instead of starting with a spec (`prd.json`) and iteratively implementing features, Reverse Ralph starts with **existing artifacts** (code, commits, diffs, screenshots, designs, logs, or tickets) and incrementally **reconstructs understanding, intent, and structure**.

Think of it as using an LLM to *reverse-engineer* clarity.

---

### What problem does Reverse Ralph solve?

Reverse Ralph is useful when:

- You inherit an unfamiliar codebase
- A feature already exists but has no clear spec
- A PR or diff is large and hard to reason about
- Requirements evolved informally (Slack, Jira comments, tribal knowledge)
- You want to document *what was actually built*, not what was planned

Traditional Ralph answers:
> “What should I build next?”

Reverse Ralph answers:
> “What **is** this, why does it exist, and how does it work?”

---

### Core idea

Reverse Ralph flips the direction of reasoning:

| Traditional Ralph | Reverse Ralph |
|-------------------|--------------|
| Spec → Steps → Code | Code → Meaning → Spec |
| Forward planning | Backward reconstruction |
| Goal-driven | Evidence-driven |
| “What to do next?” | “What already exists?” |

The loop still follows the same principles:
- One step at a time
- State lives in files, not model memory
- Human-in-the-loop
- Deterministic and restartable

Only the **inputs and outputs are reversed**.

---

### Typical Reverse Ralph loop

A Reverse Ralph loop might look like:

1. Provide inputs:
   - A code directory
   - A PR diff
   - Screenshots or mockups
   - Logs or runtime output
   - Partial tickets or comments

2. Ask the LLM to:
   - Identify the **intent** of the code/change
   - Infer **implicit requirements**
   - Detect assumptions, invariants, and constraints
   - Highlight unclear or risky areas

3. Emit exactly **one artifact per iteration**, such as:
   - A reconstructed user story
   - An inferred feature spec
   - A design explanation
   - A list of unanswered questions
   - A proposed ADR
   - A migration or refactor plan

4. Persist the output (e.g. `reverse_progress.txt`, `reverse_prd.json`)

5. Repeat until understanding stabilizes

---

### Example use cases

- **PR review at scale**  
  Feed a large diff and have Reverse Ralph explain *what changed* and *why* in human terms.

- **Post-hoc documentation**  
  Generate specs and design docs *after* a feature is already merged.

- **Onboarding**  
  Walk a new developer through an unfamiliar subsystem step by step.

- **Incident analysis**  
  Start from logs and behavior, reconstruct causal chains and assumptions.

- **Refactor preparation**  
  Extract the “true contract” of existing code before changing it.

---

### Relationship to normal Ralph loops

Reverse Ralph is not a replacement for Ralph loops.

They are complementary:

- **Reverse Ralph** is for understanding and reconstruction
- **Ralph** is for planning and execution

A common workflow is:

1. Use **Reverse Ralph** to derive a clean spec from messy reality
2. Convert that spec into `prd.json`
3. Switch to a normal **Ralph loop** to implement improvements

---

### Design philosophy

Reverse Ralph follows the same core constraints as Ralph:

- No hidden model memory
- All state is explicit and reviewable
- One focused output per iteration
- Human judgment always overrides the loop

The difference is purely **direction of reasoning**.

---

### Status

Reverse Ralph is experimental and evolving.

Expect:
- New patterns
- Specialized prompts
- Dedicated tooling (diff-aware, image-aware, log-aware loops)

If Ralph is about *building deliberately*,
Reverse Ralph is about *understanding precisely*.
