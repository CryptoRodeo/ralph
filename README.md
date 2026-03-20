# Ralph

<img src="./ralph.jpeg" width="450">

A simple, file-based workflow for building software one step at a time with an LLM. Based on [Ralph loops](https://ghuntley.com/ralph/).

## Quick Start

Initialize Ralph in your project:

```bash
curl -sSL https://raw.githubusercontent.com/CryptoRodeo/ralph/refs/heads/main/ralph_init.sh | bash
```

This sets up `ralph.sh`, `progress.txt`, and `prd.json` in your project.

### How It Works

Ralph turns a plan into code through small, controlled steps:

* Define your tasks in `prd.json`
* Work on **one task at a time**
* Track what’s done in `progress.txt`
* Stop and check after each step

The focus is on **clarity and control**, not speed.

---

## Reverse Ralph (Ticket-First Planning - Work In Progress)

**Reverse Ralph** turns unclear tickets into clear plans.

Give it a Jira ticket or GitHub issue and it will:

* Identify what needs to be done, what's risky, and what's unclear
* Produce a structured, ready-to-use plan
* Feed that plan into a Ralph loop

**Reverse Ralph figures out *what* to build. Ralph builds it, one step at a time.**

