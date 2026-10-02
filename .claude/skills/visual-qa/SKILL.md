---
name: visual-qa
description: "Step-by-step visual QA procedure including visual fidelity checklist, functional flow checklist, responsive behaviour testing at standard breakpoints, accessibility audit, evidence capture, and verdict-grading definitions (DEFECT / DEVIATION / OBSERVATION / PASS)."
---

# Visual QA

## Terminal Phase — Opt-In Only

Ripley is a **terminal QA phase**, not a per-step gate. She runs once, after the final coding step and its paired `@apone` review, and only when explicitly requested. She never appears in a plan by default and is invoked when the operator asks for QA or when rendered work needs verification against a reference. Her review does not gate progress as a per-step automatic check — it is opt-in verification at the end.

## The Process

1. **Confirm the pre-flight gates** — reachable URL, design reference, staged target, non-production environment named. Stop if any is missing.
2. **Select a browser tool** — Claude in Chrome for auth, Playwright for public staging, chrome-devtools for performance/CSP, or screenshots if no server is running.
3. **Walk the visual fidelity checklist** — spacing, type, colour, layout, imagery, alignment against the design.
4. **Walk the functional flow checklist** — navigation, forms, interaction states, workflows.
5. **Test responsive behaviour** — standard widths (mobile, tablet, desktop), reflow, overflow handling, touch targets.
6. **Audit accessibility** — contrast, focus order, landmarks, alt text, keyboard nav, console.
7. **Sort what you found** — DEFECT, DEVIATION, OBSERVATION, PASS.
8. **Cite evidence** — every DEFECT and DEVIATION names its source.

## Visual Fidelity Checklist

Walk through the design reference or supplied mockup and verify each area:

- [ ] **Spacing** — margins, padding, gap measurements. Do they match the design? Are grid lines or keylines visible in the browser, or does the rendered layout pull away?
- [ ] **Typography** — font family, weight, size, line-height. Does text render at the intended hierarchy? Headings distinct from body? Alignment (left, center, right, justified) as designed?
- [ ] **Colour** — background colours, text colours, accent colours, borders, shadows. Match the design palette exactly, or does the browser render a shifted shade? Check light mode and dark mode if both are designed.
- [ ] **Layout** — overall structure, columns, rows, alignment to grid or keylines. Is content centred, full-width, constrained? Does the layout hold or break when you resize?
- [ ] **Imagery** — images present, correct aspect ratio, not stretched, not pixelated. Alt text present and meaningful (covered under Accessibility).
- [ ] **Borders and dividers** — where lines, rules, or borders are shown in the design, are they rendered? Correct colour, weight, style?
- [ ] **Interactive elements** — buttons, links, form fields, cards. Border radius, shadow, padding match the design. State clarity at rest, hover, focus, active (covered under Functional Flow).

## Functional Flow Checklist

- [ ] **Navigation** — menus open and close. Links navigate to the correct destination. Breadcrumbs, tabs, or step indicators work. Back/forward buttons behave as expected.
- [ ] **Forms** — fields are focusable. Labels associate correctly with inputs. Placeholder text clears when typing. Submit button is reachable and clicks without errors.
- [ ] **Error states** — validation errors appear inline, are styled distinctly, and describe the problem. Form does not submit until errors clear.
- [ ] **Loading states** — spinners or skeleton content appears during async operations. Not left blank. Does not stall indefinitely.
- [ ] **Empty states** — empty lists, empty searches, no-results messages render correctly and are helpful rather than blank.
- [ ] **Hover states** — buttons, links, and interactive elements respond visibly to hover. Cursor changes where appropriate. Feedback is immediate.
- [ ] **Focus states** — keyboard focus is visible and logical. Tab order proceeds left-to-right, top-to-bottom, or in a designed sequence. Focus indicators are clear (not invisible or too subtle).
- [ ] **Modal / overlay behaviour** — modals appear, have a way to close (X, Cancel, Escape), trap focus inside, and handle stacking if nested.
- [ ] **Transitions / animations** — if designed, animations perform smoothly without jank. Not disabled when motion is OK. Respect `prefers-reduced-motion` if present.

## Responsive Behaviour Checklist

Test at these standard widths:

| Breakpoint | Width | Device | Test |
|---|---|---|---|
| Mobile | 375px | iPhone SE | Single column, stacked layout, readable without horizontal scroll |
| Tablet | 768px | iPad | Two-column or flexible grid, touch targets ≥ 44x44px |
| Desktop | 1440px | Full-width screen | Multi-column, optimal line length (50-75 chars), utilizes space |

For each breakpoint:

- [ ] **No horizontal overflow** — content fits within viewport width. Scrollbars are vertical only, not horizontal.
- [ ] **Reflow is clean** — columns stack, images scale, navigation collapses to menu (if designed). No content hidden behind other content.
- [ ] **Text is readable** — line length is not too wide (optimal 50-75 characters). Font sizes are not tiny on mobile.
- [ ] **Touch targets are adequate** — buttons, links, form fields are at least 44x44px (or 48x48px recommended). Spacing prevents accidental clicks on mobile.
- [ ] **Images scale appropriately** — not stretched, not pixelated, not loading oversized files on mobile if a responsive image or picture element is used.
- [ ] **No sticky/fixed layout breakage** — headers, footers, sticky elements don't occlude critical content or overflow.

## Accessibility Audit Checklist

- [ ] **Colour contrast** — text passes WCAG AA at minimum (4.5:1 for normal text, 3:1 for large). Use a contrast checker or browser devtools.
- [ ] **Focus order** — Tab through the page. Focus moves in a logical, visible sequence. No focus traps.
- [ ] **Focus indicators** — focused elements have a visible outline or background change. Not removed with `outline: none` without a replacement.
- [ ] **Landmark structure** — page uses semantic HTML (`<header>`, `<nav>`, `<main>`, `<aside>`, `<footer>`). Screen reader users can navigate by landmark.
- [ ] **Heading hierarchy** — headings use `<h1>`, `<h2>`, `<h3>` in logical order. No skipped levels (e.g., `<h1>` to `<h3>`).
- [ ] **Alt text** — images have alt attributes. Decorative images have `alt=""`. Meaningful images describe the content or purpose.
- [ ] **Labels** — form fields have associated `<label>` elements or `aria-label`. Placeholder text alone is not a label.
- [ ] **Keyboard navigation** — all interactive elements (buttons, links, form fields, modals) are reachable and operable via keyboard alone. No mouse-only interactions.
- [ ] **Skip links** — if a page has multiple sections, a "Skip to main content" link allows keyboard users to bypass repetitive navigation.
- [ ] **ARIA usage** — ARIA attributes are present only where needed. `aria-label`, `aria-labelledby`, `aria-describedby`, `role`, and `aria-live` are correctly applied and not overused.
- [ ] **Console errors** — browser console is clear of errors, warnings about missing attributes, or broken resources. Red X marks in devtools are flagged.
- [ ] **Broken assets** — images load without 404s. External resources (fonts, stylesheets, scripts) are present and not broken.

## Evidence Capture

**For every DEFECT and DEVIATION**, state what you measured it against:

- **Screenshot or region** — if you took a screenshot, name the page, section, or component. Include coordinates or a description if the defect is in a specific area.
- **Design reference** — which Figma frame, mockup page, or specification section defines the expected behaviour?
- **Breakpoint or state** — mobile, tablet, desktop, or a specific interaction state (hover, focus, error, empty)?
- **URL** — the exact page or URL where you found it.
- **Browser and environment** — which tool (Claude in Chrome, Playwright, chrome-devtools, or screenshot), which browser if applicable.

Example:
> DEFECT: Button colour on signup form does not match design. Expected: Figma frame "Signup Form — States", primary button colour #2563EB. Actual (screenshot mobile, 375px): #1e40af. URL: staging.example.com/signup. Tool: Playwright.

## Grading Findings

### DEFECT
The feature is broken or does not work as intended. The brief cannot ship in this state.

- Renders incorrectly (blank, cut off, unreadable).
- Function does not work (button does not submit, link does not navigate, form validation does not block invalid input).
- Interaction is blocked (cannot access content without JavaScript, cannot reach a field via keyboard).
- Fails accessibility critically (no alt text on essential images, no keyboard navigation on critical controls).

### DEVIATION
The feature works, but does not match the design or stated intent. A mismatch, not a malfunction.

- Spacing, colour, or typography does not match the design (but the page is readable and functional).
- Interaction state is missing or unclear (no hover colour defined, or a different shade than the design).
- Responsive layout is different than designed (single column instead of two-column, for example) — but reflows cleanly and is readable.
- Accessibility is suboptimal but not broken (contrast is AA instead of AAA, or focus outline is present but subtle).

### OBSERVATION
Non-blocking note worth recording.

- A performance concern (large image not optimized, slow animation).
- A minor edge case (placeholder text lingers on focus, or a state is not tested).
- Anything worth knowing that does not prevent this from shipping.
- Code-level findings that belong to `@apone` — name them as observations and do not grade them.

### PASS
No defects found. Summarise what you covered.

Example:
> PASS: Visual fidelity matches Figma frame "Dashboard — Desktop" (spacing, type, colour, layout, imagery). Functional flow verified (navigation, forms, error states, empty states). Responsive behaviour tested at mobile (375px), tablet (768px), desktop (1440px) — reflow clean, touch targets adequate. Accessibility audit passed (contrast, focus order, landmarks, alt text, keyboard nav). Console clean. Tested via Playwright on staging.example.com.

## How To Report

**First, the file-naming line** — defined once, in `.claude/agents/ripley.md` under "How To Report": every report opens by naming every workspace file written during the step, each with its full path, or `none`. That line is canonical there and always comes first; it is what lets Bishop verify Ripley stayed inside her write boundary each round.

**Then name which browser tool you used and which environment:**

> Using Playwright against staging.example.com (non-production environment confirmed). Testing against Figma design frame "Feature X — Desktop, Tablet, Mobile".

**Then structure the findings that follow using the canonical heading format** — defined once, in `.claude/agents/ripley.md` under "How To Report", to avoid the two files drifting apart. In short: singular grade headings (`### DEFECT`, `### DEVIATION`, `### OBSERVATION`, `### PASS`), only a grade with findings gets a heading, and no combined or empty heading ever appears.

## Two QA Rounds

A `DEFECT` goes back to `@hicks` for a fix, gets an `@apone` review, then Ripley re-verifies. Ripley gets **two** QA re-verify rounds. Still failing after the second, she stops and reports that the limit is spent — the operator takes it from there.

Ripley never starts a third round. If a brief asks for one, she refuses it and tells Bishop it is a process violation.

Every re-verify brief states its round index — `QA round 1 of 2` or `QA round 2 of 2`. A sub-agent cannot count her own rounds across delegations, so a brief without the index is malformed. Ripley asks Bishop for it before starting.

## Ambiguity and Escalation

If a pre-flight gate is missing, the environment is unknown, or the design is ambiguous, stop and report to Bishop. Do not guess. Do not infer intent. Bishop will ask the operator.
