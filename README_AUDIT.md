# README.md Clarity Audit

This document records the findings from auditing `README.md` for clarity issues.

---

## Issues Identified

### 1. Line 1 — Title heading

**Current text:**
```
# Ralph (PRD to Implementation - Work in progress)
```

**Issue:** The parenthetical `(PRD to Implementation - Work in progress)` is informal and vague. "Work in progress" belongs in a badge or a dedicated status section, not the main heading. "PRD to Implementation" is jargon-heavy and unexplained for first-time readers.

---

### 2. Line 5 — Repository description

**Current text:**
```
Files, utilities and best practices related to Ralph loops
```

**Issue:** Too vague. "Files, utilities and best practices" communicates nothing about what Ralph *does* or what problem it solves. A reader arriving here for the first time gains no useful context about the tool's purpose.

---

### 3. Line 16 — "What is Ralph?" heading level

**Current text:**
```
### What is Ralph?
```

**Issue:** This subsection uses `###` (h3) but appears under `## Quick Start` (h2), which makes it read as a sub-topic of the Quick Start guide rather than a standalone concept. Given its importance, it should be promoted to a `##` (h2) top-level section.

---

### 4. Line 18 — Run-on sentence with undefined acronym

**Current text:**
```
**Ralph** is a structured, file-based workflow for turning a clear plan (PRD or task list) into safe, incremental implementation using tight feedback loops with an LLM.
```

**Issue:** This is a single long run-on sentence. The phrase "using tight feedback loops with an LLM" is appended at the end and reads as an afterthought. The acronym "LLM" is introduced without any prior definition or context, which may confuse readers unfamiliar with the term.

---

### 5. Lines 40–41 — Multi-sentence bold block

**Current text:**
```
**Reverse Ralph helps you figure out *what* to build.
Ralph loops help you build it safely, one step at a time.**
```

**Issue:** Two separate sentences are wrapped inside a single `**bold**` block spanning a line break. This breaks standard Markdown rendering on many platforms and makes the block hard to parse visually. Each sentence should be bolded independently.

---

### 6. Lines 42–47 — Redundant closing paragraphs

**Current text:**
```
**Reverse Ralph** is a complementary workflow to a traditional Ralph loop.

While a standard Ralph loop starts with a **PRD or task list** and iterates forward into implementation, Reverse Ralph starts with a **Jira ticket or GitHub issue** and works *backward* to derive a structured, implementation-ready plan.
```

**Issue:** These two paragraphs repeat information already stated in the bullet list immediately above them (lines 35–38):
- "analyzes intent, scope, risks, and unknowns" → restated as "works *backward* to derive a structured, implementation-ready plan"
- "Feeds that plan directly into a normal Ralph loop" → restated as "complementary workflow to a traditional Ralph loop"

This redundancy adds length without adding clarity and should be removed or consolidated.

---

## Summary

| Line(s) | Section                         | Issue Type                                        |
|---------|---------------------------------|---------------------------------------------------|
| 1       | Title heading                   | Informal WIP label; jargon in main heading        |
| 5       | Repository description          | Too vague; does not describe the tool's purpose   |
| 16      | "What is Ralph?" heading        | Wrong heading level (`###` should be `##`)        |
| 18      | "What is Ralph?" body           | Run-on sentence; undefined acronym (LLM)          |
| 40–41   | Reverse Ralph call-out block    | Broken bold formatting spanning two sentences     |
| 42–47   | Reverse Ralph closing paragraphs| Verbatim repetition of bullet-point content above |
