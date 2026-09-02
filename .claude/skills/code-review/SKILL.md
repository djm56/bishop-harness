---
name: code-review
description: "Step-by-step instructions for performing a structured code review including security checklist, performance checklist, documentation completeness check, and output format (CRITICAL / WARNINGS / SUGGESTIONS / APPROVED)."
---

# Reviewing Code

## The Process

1. **Read the brief** — know what was meant to change, and why.
2. **Read the diff** — changed files and the context immediately around them.
3. **Work the checklists** — security, performance, documentation, below.
4. **Sort what you found** — CRITICAL, WARNINGS, SUGGESTIONS.
5. **Call it** — APPROVED when nothing CRITICAL is open.

## Security Pass

Flag these as you read. A full security audit is a separate exercise; this is the pass that catches the common damage.

- [ ] No raw user input reaching SQL, output, or file operations
- [ ] CSRF tokens or anti-CSRF protection on state-changing requests
- [ ] Authorization checks guarding privileged operations
- [ ] No `eval()`, `extract()`, or `unserialize()` against untrusted data
- [ ] Dependency bumps are expected and reviewable — nothing suspicious pointing at obscure or unmaintained packages
- [ ] New or changed install scripts (`postinstall`, `preinstall`) read for arbitrary-execution risk
- [ ] No secrets or tokens landing in code, config, logs, or committed artifacts
- [ ] New internet-facing surfaces — endpoints, webhooks, portals — called out, with their access controls

## Performance Pass

- [ ] No database queries inside loops
- [ ] Caching applied where it earns its place
- [ ] Static assets loaded through the project's proper mechanism rather than inlined ad hoc
- [ ] Nothing loaded or imported at startup that isn't needed
- [ ] Large datasets paginated or batched

## Documentation Pass

- [ ] Every new or changed public function carries a docblock in the project's convention
- [ ] Parameters, return value, exceptions, and version tags present
- [ ] Inline comments where the logic isn't self-evident
- [ ] README updated if the public API moved

## What The Severities Mean

- **CRITICAL** — must fix. Security hole, data-loss risk, broken logic, breaking change.
- **WARNINGS** — should fix. Performance concern, edge case waiting to happen, style violation.
- **SUGGESTIONS** — worth considering. Refactor opportunity, another approach, a small improvement.
