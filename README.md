# Ralph

<img src="./ralph.jpeg" width="450">

A simple workflow for building code with AI — one step at a time. Based on [Ralph loops](https://ghuntley.com/ralph/).

## Quick Start

Initialize Ralph in your project:

```bash
curl -sSL https://raw.githubusercontent.com/CryptoRodeo/ralph/refs/heads/main/ralph_init.sh | bash
```

This downloads `ralph.sh`, creates `progress.txt` and `prd.json`, and sets up everything you need.

### How It Works

Ralph is a way to turn a plan into working code using an LLM, one small step at a time.

A Ralph loop:

* Reads from a plan (`prd.json`)
* Works on **one step at a time**
* Tracks what's done in `progress.txt`
* Stops after each step to keep things on track

The goal is **control and predictability**, not speed.

---

## Reverse Ralph

Reverse Ralph helps when requirements are unclear. It takes a Jira ticket or GitHub issue and turns it into a clear plan you can feed into a Ralph loop.

It:

* Breaks down what the ticket is really asking for
* Identifies risks and unknowns
* Produces a ready-to-use plan

**Reverse Ralph figures out *what* to build. Ralph loops build it, one step at a time.**
