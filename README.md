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

**Ralph** is a simple workflow for building software with an LLM, one small step at a time.

A *Ralph loop*:

* Reads a plan from `prd.json`
* Works on **one step at a time**
* Logs what was done in `progress.txt`
* Stops after each step to avoid mistakes and scope creep

The goal is **clarity and control** when using AI to write code.

---

## Reverse Ralph (Ticket-First Planning - Work In Progress)

**Reverse Ralph** turns unclear tickets into clear plans.

Give it a Jira ticket or GitHub issue and it will:

* Identify what needs to be done, what's risky, and what's unclear
* Produce a structured, ready-to-use plan
* Feed that plan into a Ralph loop

**Reverse Ralph figures out *what* to build. Ralph builds it, one step at a time.**

