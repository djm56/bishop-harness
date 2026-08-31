---
name: wordpress-development
description: Load when planning, reviewing, or implementing WordPress work. Covers coding standards, theme and plugin development, WooCommerce, security, performance, testing, compatibility, accessibility, deployment safety, and specialist handoff guidance for junior and senior developers.
---

## What This Is For

A shared WordPress standard, so junior and senior developers are working from the same expectations. The point is fewer avoidable mistakes, better code, and reviews that go faster because everyone already agrees on the bar.

Reach for it when the work involves:

- Themes
- Plugins
- WooCommerce
- The block editor and Gutenberg
- PHP templates, hooks, filters, shortcodes, REST endpoints, AJAX, WP-CLI-adjacent workflows, and CLI support code
- Performance, security, accessibility, testing, deployment, or release review

## How To Approach WordPress Work

- Small and reversible beats big and clever.
- Treat production as sensitive by default, always.
- Confirm your assumptions before you change behaviour.
- Security, sanitization, escaping, and capability checks are never the thing you skip to save time.
- Keep core, themes, plugins, server expectations, and release impact in view the whole way through.
- Optimise for the person maintaining this in a year, not just for correctness today.
- When a solution is deliberately imperfect, write down the trade-off.
- Core already solves a lot. Use its APIs before building your own.
- Hooks and filters, never edits to core or vendor files.
- Keep business logic out of templates where you reasonably can.
- Choose the least surprising implementation that actually solves the problem.

## Coding Standards

- Follow the WordPress PHP Coding Standards for naming, spacing, and formatting.
- `snake_case` for functions and variables, `Upper_Snake_Case` for classes.
- Prefix everything global with the project or plugin slug — functions, classes, constants, hooks, options, transients, cache groups, REST routes, AJAX actions, cron hooks.
- Never short tags. Always `<?php`.
- Small functions that do one thing.
- Don't duplicate logic across templates, plugins, and theme functions.
- Pick autoloading or explicit includes, then be consistent about it.
- Names should be clear, conventional, and impossible to collide with.
- Comment the intent. The mechanics are already on the screen.

## Plugins And Themes

### Plugins

- The main file carries the standard header comment.
- Split concerns into `admin/`, `includes/`, `public/`, `assets/`, and similar, where it earns its keep.
- Register activation and deactivation hooks explicitly.
- Use `uninstall.php` or `register_uninstall_hook` where cleanup is needed.
- Store only what you actually need.
- Custom database tables only when the data model genuinely calls for them.
- Keep the plugin's scope tight and coherent.
- Make setup, teardown, and migration paths explicit rather than implied.

### Themes

- Semantic HTML, with a heading hierarchy that means something.
- Use the template hierarchy deliberately.
- Load assets only where they're needed.
- Enqueue styles and scripts properly.
- Build responsive from mobile upward.
- Respect the difference between block themes and classic themes.
- Extend a third-party theme through a child theme.
- Skip heavy theme frameworks unless they're clearly earning their weight.
- Keep template overrides few and documented.

### Block Editor

- Prefer block-native patterns where they fit.
- Register blocks and block styles cleanly.
- Keep the editor view and the front end honest with each other.
- Test reusable blocks, patterns, and custom variations properly.
- Don't overengineer a simple editorial need.

### WooCommerce

- Reach for hooks and filters before you override a template.
- Keep checkout changes small, and test them hard.
- Cart, checkout, order status, payment, refund, and subscription flows all deserve caution.
- Verify taxes, shipping, currency, stock, coupons, fees, and transactional emails.
- Check compatibility with payment gateways, subscriptions, memberships, shipping extensions, and third-party add-ons.
- Walk the paths: guest checkout, logged-in checkout, failed payment, cancelled order, refund, re-order.
- Changing a customer-facing flow? Check what it does to accounts, order history, and email templates.

## Security

### Input And Output

- Sanitize input for the type you expect.
- Escape output for the context it's landing in.
- Nonces on anything that changes state.
- Capability checks before anything privileged.
- Trust none of it: request data, query vars, form input, AJAX payloads, REST input, cron input, external integrations.
- Server-side rendered block attributes are untrusted until you've validated them.

### Sanitizing

- `sanitize_text_field()` — plain text
- `sanitize_email()` — email addresses
- `sanitize_url()` / `esc_url_raw()` — URLs
- `absint()` / `intval()` — integers
- `sanitize_file_name()` — filenames
- `wp_kses()` / `wp_kses_post()` — controlled HTML

### Escaping

- `esc_html()` — text in an HTML context
- `esc_attr()` — HTML attributes
- `esc_url()` — URLs in `href` and `src`
- `esc_js()` — inline JavaScript
- `wp_kses()` — controlled HTML output

### Who's Allowed To Do What

- Check roles and capabilities explicitly.
- Grant the least privilege that works.
- Admin-only data stays out of frontend endpoints.
- Guard sensitive settings screens and actions.
- Custom login, registration, password reset, and account flows get extra scrutiny.
- Every REST permission callback and AJAX permission check gets verified.

### The Database

- `$wpdb->prepare()` on any query carrying a variable.
- Never concatenate user input into SQL. Not once.
- `$wpdb->insert()`, `$wpdb->update()`, `$wpdb->delete()` for CRUD wherever practical.
- Index custom table columns used in `WHERE`, `JOIN`, `ORDER BY`, and frequent lookups.
- Raw SQL is a last resort, not a starting point.
- Schema changes, migrations, and backfills all deserve a careful read.

### Web Security

- Watch for XSS, CSRF, SQL injection, file upload abuse, open redirects, SSRF, privilege escalation, unsafe deserialization.
- File uploads, external URLs, and remote requests are high risk by default.
- Weigh a third-party library's risk before you add it.
- External APIs and webhooks are untrusted input.
- Strict validation and minimal token scopes on every integration.
- Secrets never get committed. A leaked token is an incident: escalate immediately, revoke first, rotate after.
- Any code path that writes files, sends mail, or makes outbound requests gets verified.

### Handling Data

- Protect personally identifiable information.
- Don't store sensitive data you don't need.
- Keep retention short.
- Export, import, sync, backup, and migration paths all need a careful look.
- Think about how data gets deleted, anonymized, or moved.
- Suspicious dependency changes, unusual traffic, and unexpected commits are compromise indicators until proven otherwise.

## Performance

### Queries

- Never query inside a loop. Batch with `WHERE IN` or equivalent.
- `'fields' => 'ids'` on `WP_Query` when IDs are all you need.
- `'no_found_rows' => true` when you don't need pagination data.
- `'update_post_meta_cache' => false` and `'update_post_term_cache' => false` when those caches are dead weight.
- Don't run queries you don't need.
- When performance matters, measure the query count and the cost of the request.
- Be deliberate about query shape, joins, ordering, and result size.
- Paginate or use cursors on large result sets.

### Caching

**Transients** — for expensive computed data, external API calls, and heavy query results. Set a sensible expiry (`HOUR_IN_SECONDS`, `DAY_IN_SECONDS`). Invalidate on the hooks that matter. Keep keys contextual and predictable.

**Object cache** — `wp_cache_get()` and `wp_cache_set()` for request-scoped or shared caching. Group related keys. A persistent backend like Redis or Memcached raises the value a lot, but never assume one is there.

**Fragment caching** — cache rendered HTML for expensive template parts. Key it by whatever actually varies: user role, locale, page type. Then verify it invalidates when the underlying content moves.

### Assets

- Enqueue scripts and styles only on pages that need them.
- `wp_register_script()` and `wp_register_style()` for conditional loading.
- Footer where you can.
- `defer` or `async` where it's safe.
- Combine and minify for production when the build supports it.
- Don't load everything everywhere.
- Fewer requests and smaller payloads beat broad convenience.

### Profiling

- Query Monitor for slow queries, hooks, and template bottlenecks.
- `$wpdb->num_queries` and `timer_stop()` for a baseline.
- Xdebug, Blackfire, or similar when you need to go deeper.
- Watch autoloaded options — keep the total under 1 MB.
- Look at page weight, render cost, and request frequency before you optimise anything.
- Confirm your improvement didn't buy speed with stale cache or a correctness regression.

## REST And AJAX

- Clear namespaces and versioning on REST routes.
- An explicit permission callback on every protected endpoint.
- Validate and sanitize every incoming parameter.
- Consistent response shapes and error codes that mean something.
- Private data stays out of public endpoints.
- Think about rate limiting, abuse potential, and payload size.
- Test unauthenticated, authenticated, and insufficient-permission paths.
- Keep the endpoint thin — push the work into reusable service functions.

## Multisite And Localization

- Work out whether the code runs network-wide or per site.
- Use the right blog context when switching.
- Don't assume single-site storage or permissions.
- Verify both network activation and site-level activation.
- Shared media, shared uploads, and cross-site data access all need care.
- Check translation readiness, text domains, and locale-aware formatting.
- Confirm multilingual plugin compatibility where the project relies on it.

## Testing

- Test the happy path and the failure path.
- Verify input, permissions, and edge cases.
- Add automated tests where the project supports them.
- Cover critical business logic, security-sensitive logic, and anything prone to regressing.
- Test somewhere that resembles production, where you can.
- Read the console, PHP, and web server logs when behaviour is off.
- Make sure cache clearing, data seeding, and fixtures are reproducible.
- WooCommerce: checkout, cart persistence, stock changes, refunds, order emails.
- REST: schema validation and permission failures both.

## Deploying And Rolling Back

- Confirm the environment before anything touches production.
- Define the rollback before the deploy, not after.
- Keep migrations compatible and reversible where you can.
- Destructive migrations need explicit confirmation. No exceptions.
- Back up before schema changes, imports, and bulk updates.
- Check plugin and theme versioning, and the order things deploy in.
- Look for configuration drift between local, staging, and production.
- Write down any manual post-deploy steps.
- Prefer release steps you can watch and undo.

## Accessibility

- Keep the structure semantic.
- Keyboard navigation stays intact.
- Focus states stay visible.
- Labels, descriptions, and controls that mean something.
- Check colour contrast and readable typography.
- Test forms, modals, menus, tables, and interactive components with assistive tech in mind.
- Make sure dynamic updates are announced or otherwise perceivable when they need to be.

## Compatibility

- Check the WordPress versions you're supporting.
- Verify PHP version compatibility.
- Confirm the active theme still works.
- Confirm common plugins still work, where relevant.
- Know your browser support expectations.
- Consider multisite impact if the project might run there.
- Check multilingual and localization readiness where it applies.
- Check whether lock files are committed, and avoid unreviewed auto-upgrades in production.
- Factor in hosting constraints, memory limits, and available PHP extensions.

## Before You Approve

- Behaviour matches the requirement.
- Security checks are done.
- Output escaped, input sanitized.
- Performance impact is acceptable.
- Accessibility hasn't gone backwards.
- Compatibility risks are known.
- The rollback path is clear.
- Test coverage matches the size of the change.
- Documentation and handoff notes are good enough for the next person.

## For The Junior Developer

- Use this as the checklist before you write code, not after.
- Unclear requirement? Ask before implementing.
- Keep changes narrow and reviewable.
- Give it a real attempt, then escalate rather than grinding.
- Clear and conventional beats clever.
- Don't add abstraction you don't need.
- Check your output against security, performance, and compatibility before handing it over.
- An unclear edge case is a question, not an assumption.

## For The Senior Developer

- Use this as the review baseline and the architectural guardrail.
- Challenge assumptions early — especially on security, scale, performance, compatibility, and maintainability.
- Look for edge cases, regressions, operational risk, and deployment risk.
- Prefer refactors that improve clarity without widening the blast radius.
- Confirm junior work is testable, documented, and safe to ship.
- Vet plugins, dependencies, and external APIs before they're adopted.
- Be explicit about migration cost, rollback cost, and support cost.

## How This Usually Goes Wrong

- Editing core or vendor files.
- Skipping sanitization or escaping.
- Reaching for custom queries or hooks where a core API already fits.
- Loading everything everywhere.
- Breaking checkout, auth, account, or REST flows.
- Hiding risk behind convenience.
- Shipping without a confirmed rollback.
- Letting autoloaded options quietly grow.
- Missing a cache invalidation path.
- Replacing core behaviour without a strong reason.
- Shipping permission changes nobody tested.
- Forgetting multisite or localization.
- Not thinking about deploy order or whether a migration can be undone.

## Handing Work Over

Include:

- What's changing.
- Why.
- What must not break.
- Security expectations.
- Performance expectations.
- Compatibility constraints.
- What testing is expected.
- Rollback and recovery notes.
- What you're assuming about the environment.
- Anything still unknown that needs verifying.

## Done Means

- It behaves correctly.
- Security checks pass.
- The performance impact is understood.
- Accessibility is acceptable.
- Compatibility has been thought about.
- Testing matches the risk.
- Deployment and rollback are both understood.
- Documentation or handoff notes are current.
- The risk level is stated, not implied.

## Revision Log

Use this section for later refinements, additions, and team-specific conventions.
