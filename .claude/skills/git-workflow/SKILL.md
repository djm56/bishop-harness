---
name: git-workflow
description: "Git workflow conventions covering branch naming, task branch creation, dual PR workflow (master + staging), merge conflict resolution including staging-specific branching, and commit guidelines. Used by the junior developer (hicks) and senior developer (vasquez)."
---

# Working With Git

## Two Kinds Of Branch

- **Environment branches** — `master`/`main` (production), `staging`, and optionally `development`/`develop`. PROTECTED. Nothing is ever pushed straight to them.
- **Task branches** — prefixed `task/`, one per task, merged in through a PR or MR.

## Naming

Branch names are **always lowercase**.

| Situation | Pattern |
|-----------|---------|
| One developer | `task/{task-id}/{task-title}/{username}/{environment-branch}` |
| Multi-dev release | `task/{task-id}/{task-title}/release/{environment-branch}` |
| Sub-task | `task/{task-id}/{task-title}/{sub-task-title}/{username}/{environment-branch}` |
| Shared multi-dev sub-task | `task/{task-id}/{task-title}/{sub-task-title}/{environment-branch}` |

Sub-branches come off their parent and their MRs target that parent. Pull from the parent often so you don't drift.

## Starting A Task Branch

1. Branch from `master`/`main`.
2. Get the branch name from the team lead.
3. Check out the target, pull, then cut your branch.

```bash
git checkout master
git pull origin master
git checkout -b task/{id}/{title}/{username}/master
```

## Opening PRs

Every task needs **at least two PRs, opened together**:

1. One into `master`/`main`
2. One into `staging`

- **Title** — task title plus destination, e.g. "Add login form → master"
- **Description** — what changed overall, plus the Asana task link
- **Reviewer** — the team lead, usually the Lead Developer
- PR on GitHub, MR on GitLab. Same thing.

## Conflicts

Clear conflicts before you send anything for review.

### Against master/main

1. Merge master into your task branch.
2. Resolve locally.
3. Push — then check **both** PRs.

```bash
git checkout task/{branch}
git merge origin/master
# resolve conflicts
git add .
git commit
git push
```

### Against staging

**Do not merge staging into your task branch.** Instead:

1. Close the original staging PR.
2. Cut a **fresh** branch from `staging`:
   ```bash
   git checkout staging
   git pull origin staging
   git checkout -b task/{id}/{title}/{username}/staging
   ```
3. Merge your original task branch into it:
   ```bash
   git merge task/{id}/{title}/{username}/master
   ```
4. Resolve, push, open a new PR to staging.

**Why the extra step**: it keeps the master-targeting branch free of staging history.

### Reading The Markers

- `<<<<<<<` — start of the receiving (current) changes
- `=======` — the divider
- `>>>>>>>` — end of the incoming changes

Keep receiving, keep incoming, keep both, or write something new.

**Never push an unresolved conflict** — anything still carrying `<<<<<<<`.

Unsure how a conflict should resolve? Take it to the team lead.

## Commits

- **Conventional Commits** format; commitizen is a good way to stay honest.
- `feat: add login form`, `fix: correct null check in user service`, `chore: update dependencies`
- Run `git diff --staged` before you commit and check for secrets, `.env` files, and dependency or lockfile changes you didn't intend.
- Treat a dependency update as a security-relevant change. Check where it came from, why it moved, and what its install scripts do.

## Merging And Deploying

**Critical**: you may open PRs and resolve conflicts. You **never** perform the final merge. That and deployment belong to the team lead.

Once the lead has reviewed and approved, they deploy.

## The Sequence

1. Get the release or sub-task branch name from the team lead.
2. Check it out.
3. Pull.
4. Cut your developer branch.
5. Code, commit, push.
6. Open the MR/PR to the target branch and assign the lead.
7. Assign the Asana task to the lead with the MR link.

## When To Stop

Report to Bishop when:

- A conflict is genuinely ambiguous — clashing values, changed logic — and needs the team lead's call.
- A merge breaks tests.
- You aren't sure which branch to target. Ask the lead.
- A token or credential may have leaked. Revoke it, rotate it, and report immediately — do not wait.
- A dependency looks wrong: unexpected upgrades, unfamiliar transitive changes, install scripts doing more than they should. Pause and ask for a security review.
