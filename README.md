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

Ralph gives you a repeatable way to go from a plan to working code using an LLM. Instead of tackling everything at once, it breaks work into small steps and tracks each one.

How it works:

* You write a plan in `prd.json`
* Ralph works through **one step at a time**
* Progress is tracked in `progress.txt`
* After each step, it stops so you can review before moving on

The focus is on **staying in control** and avoiding mistakes, not going fast.

---

## Reverse Ralph

**Reverse Ralph** turns a vague ticket or issue into a clear, structured plan.

It takes a Jira ticket or GitHub issue and:

* Breaks down the intent, scope, and risks
* Produces a plan ready for a Ralph loop

**Reverse Ralph figures out *what* to build. Ralph builds it.**
