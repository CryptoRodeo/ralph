# Ralph (Work in progress)

<img src="./ralph.jpeg" width="450">

Files, utilities and best practices related to [Ralph loops](https://ghuntley.com/ralph/)

## Quick Start

Initialize Ralph in your project with a single command:

```bash
curl -sSL https://raw.githubusercontent.com/CryptoRodeo/ralph/refs/heads/main/ralph_init.sh | bash
```

This will download `ralph.sh`, create `progress.txt` and `prd.json` files, and set up everything you need to start using Ralph loops.

## Reverse Ralph (Ticket-First Planning)

**Reverse Ralph** is a complementary workflow to a traditional Ralph loop.

While a standard Ralph loop starts with a **PRD or task list** and iterates forward into implementation, Reverse Ralph starts with a **Jira ticket or GitHub issue** and works *backward* to derive a structured, implementation-ready plan.

### Why Reverse Ralph?

In many real projects:
- Requirements live in tickets or repo issues
- Context is scattered across docs, configs, screenshots, and code
- The hardest part is *understanding what needs to be built*, not building it

Reverse Ralph exists to turn vague or overloaded tickets into something an engineer can confidently execute.

### How It Works

Reverse Ralph runs as a small, file-based state machine:

1. **Ticket Analysis**
   - Reconstructs intent, scope, requirements, risks, and open questions
   - Produces a clear `ticket_analysis.md`
   - Explicitly calls out unknowns instead of guessing

2. **Plan Derivation**
   - Converts the analysis into an ordered, incremental plan
   - Outputs a machine and human-readable `derived_plan.json`
   - Each step is small, testable, and suitable for a forward execution loop

The output of Reverse Ralph **is designed to feed directly into a normal Ralph loop**.

### When to Use Reverse Ralph

Use Reverse Ralph when:
- You’re handed a Jira ticket or Github Issue that could use some refinement
- You’re onboarding to an unfamiliar repo
- You want to de-risk work before touching production code
- You want explicit assumptions and acceptance criteria *before* coding

Use a standard Ralph loop when:
- You already have a clear PRD or task list
- You’re iterating on a known design or feature

### Relationship to Ralph Loops

Think of the two together like this:

```

Ticket / Issue
↓
Reverse Ralph
↓
PRD / Plan
↓
Ralph Loop
↓
Implementation

```

Reverse Ralph helps you **figure out what to build**.  
Ralph loops help you **build it safely and incrementally**.
