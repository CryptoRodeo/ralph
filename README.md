# Ralph

<img src="./ralph.jpeg" width="450">

A simple, file-based workflow for building software one step at a time with an LLM. Based on [Ralph loops](https://ghuntley.com/ralph/).

Give Ralph a plan (`prd.json`), and it works through each task individually, tracking progress in `progress.txt`, and stopping between steps to keep things predictable.

## Quick Start

Initialize Ralph in your project:

```bash
curl -sSL https://raw.githubusercontent.com/CryptoRodeo/ralph/refs/heads/main/ralph_init.sh | bash
```

This downloads `ralph.sh`, creates `progress.txt` and `prd.json`, and sets up everything you need.

---

## Reverse Ralph

**Reverse Ralph** turns a vague ticket or issue into a clear, structured plan.

It takes a Jira ticket or GitHub issue and:

* Breaks down the intent, scope, and risks
* Produces a plan ready for a Ralph loop

**Reverse Ralph figures out *what* to build. Ralph builds it.**
