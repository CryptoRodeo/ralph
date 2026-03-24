# Ralph (Plan to Implementation - Work in progress)

<img src="./ralph.jpeg" width="450">

Files, utilities and best practices related to [Ralph loops](https://ghuntley.com/ralph/)

## Quick Start

Initialize Ralph in your project with a single command:

```bash
curl -sSL https://raw.githubusercontent.com/CryptoRodeo/ralph/refs/heads/main/ralph_init.sh | bash
```

This will download `ralph.sh`, create `progress.txt` and `prd.json` files, and set up everything you need to start using Ralph loops.

### What is Ralph?

**Ralph** is a file-based workflow that helps you turn a plan into working code, one small step at a time, using an LLM. You define your tasks in a plan file (PRD), and Ralph ensures each step is implemented safely with clear progress tracking.

At its core, a *Ralph loop*:

* Starts from a written plan (`prd.json`)
* Works on **one small, well-defined step at a time**
* Tracks progress explicitly (`progress.txt`)
* Stops and re-evaluates frequently to reduce mistakes and scope creep

The goal isn’t speed, it’s **clarity, control, and predictability** when using AI to write or modify code.

---

## Reverse Ralph (Ticket-First Planning - Work In Progress)

**Reverse Ralph** solves the opposite problem: unclear requirements.

It takes a messy Jira ticket or GitHub issue and:

* Analyzes intent, scope, risks, and unknowns
* Produces a clean, execution-ready plan
* Feeds that plan directly into a normal Ralph loop

**Reverse Ralph helps you figure out *what* to build. Ralph loops help you build it safely, one step at a time.**

Where a Ralph loop starts from a ready-made plan and moves forward into code, Reverse Ralph starts from a ticket or issue and works backward — extracting requirements, resolving ambiguity, and producing a structured plan you can feed into a Ralph loop.

