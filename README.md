# Ralph (PRD to Implementation - Work in progress)

<img src="./ralph.jpeg" width="450">

Files, utilities and best practices related to [Ralph loops](https://ghuntley.com/ralph/)

## Quick Start

Initialize Ralph in your project with a single command:

```bash
curl -sSL https://raw.githubusercontent.com/CryptoRodeo/ralph/refs/heads/main/ralph_init.sh | bash
```

This will download `ralph.sh`, create `progress.txt` and `prd.json` files, and set up everything you need to start using Ralph loops.

### What is Ralph?

**Ralph** is a system for building software from a clear plan step by step using AI assistance.

A Ralph loop works like this:

* Start with a written plan (`prd.json`)
* Do one small task at a time
* Track what you've done (`progress.txt`)
* Stop and check your work frequently

The key benefits are: clarity, control, and fewer mistakes.

---

## Reverse Ralph (Ticket-First Planning - Work In Progress)

**Reverse Ralph** solves the opposite problem: unclear requirements.

It takes a messy Jira ticket or GitHub issue and:

* Analyzes intent, scope, risks, and unknowns
* Produces a clean, execution-ready plan
* Feeds that plan directly into a normal Ralph loop

**Reverse Ralph helps you figure out *what* to build.
Ralph loops help you build it safely, one step at a time.**
**Reverse Ralph** is a complementary workflow to a traditional Ralph loop.

While a standard Ralph loop starts with a **PRD or task list** and iterates forward into implementation, Reverse Ralph starts with a **Jira ticket or GitHub issue** and works *backward* to derive a structured, implementation-ready plan.
