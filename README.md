# Ralph

<img src="./ralph.jpeg" width="450">

A simple workflow for building software one step at a time with an LLM. Based on [Ralph loops](https://ghuntley.com/ralph/).

## Quick Start

```bash
curl -sSL https://raw.githubusercontent.com/CryptoRodeo/ralph/refs/heads/main/ralph_init.sh | bash
```

This sets up `ralph.sh`, `progress.txt`, and `prd.json` in your project.

### How it works

1. Define your plan in `prd.json`
2. The LLM picks one task, implements it, and validates it
3. Progress is tracked in `progress.txt`
4. Repeat until done

Ralph keeps things small and focused. One task at a time, no scope creep.

---

## Reverse Ralph

**Reverse Ralph** turns a vague ticket or issue into a clear, structured plan.

It takes a Jira ticket or GitHub issue and:

* Breaks down the intent, scope, and risks
* Produces a plan ready for a Ralph loop

**Reverse Ralph figures out *what* to build. Ralph builds it.**
