---
description: Run QA verification on a rendered target against a design or acceptance criteria
argument-hint: <target URL> [design reference or criteria location]
---

> **Ripley drives the browser.** You do not. QA verification is a specialist step, delegated just like any other. Bishop does the gate-keeping; @ripley does the work.

> **Full rules**: `.claude/skills/visual-qa/SKILL.md` covers the step-by-step process. `.claude/agents/ripley.md` covers her bearing, constraints, and reporting format.

---

## The Four-Part Pre-Flight Gate (Blocking)

Ripley does not start until all four hold. If any is missing, stop and work it out before delegating.

### 1. A Reachable Target URL

**Ask:**
> What is the URL to test? (Staging, development, or localhost — never production. State it now and I'll confirm it's reachable.)

- Confirm it's resolvable right now. Try it: `curl -I <url>`.
- Must be non-production. Staging, development, localhost, a preview URL — anything except the live site.
- Accept only a specific, complete URL. Nothing vague. If the operator offers `example.com`, ask which exact path or subdomain.

**If missing:** Stop. You cannot delegate to Ripley without a target.

### 2. A Design Reference or Written Acceptance Criteria

**Ask:**
> What are you comparing this against? A Figma link, a screenshot, a spec, or an explicit statement of what it should do?

- Figma link — ask for the specific frame or page.
- Screenshot or mockup — ask for the location (local file path, shared drive, etc.).
- Written spec or acceptance criteria — ask for a link or quote the relevant part.
- Explicit intent — ask them to state it plainly.

**If the brief requests QA with no design supplied, this is a stop.** Do not infer intent. Ask the operator for the reference. Tell them Ripley cannot guess what "correct" means.

**If missing:** Stop. You cannot delegate to Ripley without a standard to measure against.

### 3. The Target Is Staged and Ready

**Ask:**
> Is the target fully built and ready to test right now? (Page built, content in place, forms wired, authentication done if needed — not "almost ready".)

- Not "almost ready". Not "we'll finish it while you're testing". Ready now.
- Forms, if present, should be wired to something that won't break the target (a test endpoint, a staging backend, or a harmless confirmation — not production).

**If the operator says "almost":** Tell them to come back when it's ready. Stop here.

**If missing:** Stop. You cannot delegate to a target that isn't staged.

### 4. Environment Named and Confirmed Non-Production

**Ask:**
> Say the name of the environment: `staging`, `development`, `localhost`, a preview URL — confirm it's not production.

- State it plainly so Ripley knows what she's testing against.
- No ambiguity. Not "mostly staging". Not "dev-like". The actual environment name.

**If production:** Stop. Ripley does not test production. Safety rule.

**If missing or ambiguous:** Stop. Ask again until you have a clear, non-production environment name.

---

## All Four Present — Delegate to Ripley

Once all four gates hold, hand the work to `@ripley`:

```
Step [N]: @ripley — QA verification

Target URL: [exact, complete, confirmed non-production URL]
Design reference: [Figma link / screenshot path / spec link / explicit intent statement]
Environment: [staging / development / localhost / preview URL]

Full brief:
Verify the rendered work at [URL] against [design/intent]. 

Walk these four areas:
- Visual fidelity: spacing, type, colour, layout, imagery, alignment. Match the design exactly.
- Functional flow: navigation, forms, interaction states (hover, focus, error, empty, loading). Sequences work.
- Responsive behaviour: test at mobile (375px), tablet (768px), desktop (1440px). Reflow clean, touch targets adequate.
- Accessibility: contrast, focus order, landmarks, alt text, keyboard nav, console errors.

Grade each finding as DEFECT (broken, intent not met), DEVIATION (works, doesn't match design), OBSERVATION (non-blocking note), or PASS (all covered, meets intent).

Do not fix anything. Report findings only.

When done, end your output with two lines:
IMPROVEMENT-NOTE: none | <one concrete, actionable observation>
STEP [N] COMPLETE — state-sync required before next step.
```

---

## After Ripley Reports

Read her verdict and next action:

- **PASS** — verified. Work is ready.
- **DEVIATION** — works, but differs from the design. Decide: ship as-is, or fix and re-verify. If you decide to fix, `@hicks` takes the follow-up, then `@apone` reviews, then Ripley re-verifies at `QA round 1 of 2`. If you ship as-is, note the deviation and move on.
- **DEFECT** — broken. Goes back to `@hicks` for a fix, then `@apone` for review, then Ripley re-verifies. That's `QA round 1 of 2`. If a DEFECT persists after the second round, Ripley stops and the operator takes it from there.
- **OBSERVATION** — something worth knowing, but not blocking. Record it in the DEBRIEF and move on.

Ripley's verdict is final. Do not override it.

---

## Quick Reference: Ripley's Constraints

- **Does not fix.** She reports, never changes code.
- **Two QA rounds max.** First findings, one fix-verify cycle, then that's it.
- **No production testing.** Safety rule — the target must be non-production.
- **Cannot ask the operator.** (`AskUserQuestion` is filtered from sub-agents.) Her questions come back to you. You ask the operator.
- **No design means stop.** "Check it anyway" is not an option. Design reference is required.

---

## No Mission Context

This command runs outside the mission lifecycle — it's a standalone QA check on something that already exists, not part of the formal mission machinery. No PROGRESS.md is created, and no FLIGHT-RECORDER row is appended automatically. When Ripley is done, you choose what to do with her findings — fix, ship as-is, or escalate. If you wish to record the QA step formally, you may optionally hand a state-sync to @lambert (doc writer) to append a FLIGHT-RECORDER.md row with event=step-sync — this is optional, not required.

To integrate QA into a formal mission, use `/mission` and include Ripley as the final step before closing.

