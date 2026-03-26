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

**Ralph** is a simple way to turn your plan into working code using AI, one small piece at a time.

Here's how it works:

1. **Write your plan** - List what you want to build in `prd.json`
2. **Pick one task** - Work on just one small, clear task at a time
3. **Get feedback** - Let the AI help you build it
4. **Check your progress** - Update `progress.txt` and move forward

The key idea: break big tasks into small ones. This keeps things focused, reduces mistakes, and gives you clear control over what the AI is doing.

---

## Reverse Ralph (Ticket-First Planning)

### The Problem

You have a Jira ticket or GitHub issue, but it's vague or scattered. You don't have a clear step-by-step plan yet.

### The Solution

**Reverse Ralph** takes a messy ticket and automatically creates a clear, executable plan. It:

1. Analyzes the ticket to understand intent, scope, and unknowns
2. Looks at your repository structure and code
3. Produces a clean, step-by-step implementation plan

### How It Works with Ralph

- **Reverse Ralph** turns a fuzzy ticket into a solid plan
- **Ralph** then executes that plan safely, one step at a time

They complement each other: Reverse Ralph answers "what should we build?" and Ralph answers "how do we build it?"

### When to Use Reverse Ralph

- Your Jira ticket is unclear or incomplete
- You need to break down a large feature into concrete steps
- You want to identify risks and unknowns *before* coding
