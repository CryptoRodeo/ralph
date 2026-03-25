# Ralph

<img src="./ralph.jpeg" width="450">

A simple tool for building software with AI, one step at a time. Based on [Ralph loops](https://ghuntley.com/ralph/).

## Quick Start

Initialize Ralph in your project:

```bash
curl -sSL https://raw.githubusercontent.com/CryptoRodeo/ralph/refs/heads/main/ralph_init.sh | bash
```

This downloads `ralph.sh`, creates `progress.txt` and `prd.json`, and sets up everything you need.

### What is Ralph?

**Ralph** is a file-based workflow for turning a written plan into working code — one small step at a time.

A *Ralph loop*:

* Starts from a written plan (`prd.json`)
* Works on **one small, well-defined step at a time**
* Tracks progress in `progress.txt`
* Stops frequently to check for mistakes and scope creep

The goal is **clarity, control, and predictability** when using an LLM to write or modify code.

---

## Reverse Ralph

**Reverse Ralph** turns a vague ticket or issue into a clear, structured plan.

It takes a Jira ticket or GitHub issue and:

* Breaks down the intent, scope, and risks
* Produces a plan ready for a Ralph loop

**Reverse Ralph figures out *what* to build. Ralph builds it.**
