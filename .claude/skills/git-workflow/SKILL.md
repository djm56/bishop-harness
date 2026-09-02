---
name: git-workflow
description: "Git workflow conventions covering branch naming, mission branches, pull requests, merge conflict resolution, commit guidelines, and the boundary where merging and deploying stop being the agent's job. Works with trunk-based development, GitHub Flow, GitFlow, or any other model. Used by the junior developer (hicks) and senior developer (vasquez)."
---

# Working With Git

## Branches

Branch names are **always lowercase**.

**Protected branches** — the default branch (usually `main`), production branches, and any long-lived branches the project maintains such as `develop`, `staging`, or release branches. Nothing is pushed straight to them. Every change arrives through a PR or MR.

**Mission branches** — prefixed `mission/`, one per mission, merged in through a PR or MR.

## Branch Naming

| Situation | Pattern |
|-----------|---------|
| Mission branch | `mission/{mission-id}/{short-title}/{target-branch}` |
| Sub-mission branch | `mission/{mission-id}/{short-title}/{sub-title}` |

`{target-branch}` is the branch you intend to merge into — `main`, `develop`, or whatever the project uses. Naming it keeps the branch self-documenting.

A sub-mission branch carries no target segment. It is cut from its parent and its PR targets the parent, and the shared prefix already says which parent that is. Pull from the parent often so you don't drift.

## Starting A Mission Branch

1. Check the project's branching model first. If it maintains long-lived branches beyond the default, follow that convention rather than assuming one.
2. Check out the target branch, pull, then cut your branch.

```bash
git checkout {target-branch}
git pull origin {target-branch}
git checkout -b mission/{mission-id}/{short-title}/{target-branch}
```

## Opening A PR Or MR

- **Title** — what changed, and the branch it targets
- **Description** — what changed, why, and anything a reviewer needs to know
- **Reviewer** — follow the project's review process
- PR on GitHub, MR on GitLab. Same thing.

Keep it small enough to actually review. A PR that has outgrown its mission brief is two PRs.

If the project has a PR or MR template, follow it.

## Handling Conflicts

Clear conflicts before you send anything for review.

1. Fetch, then merge the target branch into your mission branch.
2. Resolve locally.
3. Check the resolution — read the diff, run the tests if they are quick.
4. Commit and push.

```bash
git fetch origin
git merge origin/{target-branch}
# resolve conflicts
git add .
git commit
git push
```

### Reading Conflict Markers

- `<<<<<<<` — start of your changes, the receiving branch
- `=======` — the divider
- `>>>>>>>` — end of the incoming changes

Keep what you need, drop what you don't, or write something new.

**Never push an unresolved conflict** — anything still carrying `<<<<<<<`.

A genuinely ambiguous conflict — competing logic, clashing values — is a decision, not a merge. Stop and ask.

## Commits

- **Conventional Commits** format. It keeps history readable.
- `feat: add login form`, `fix: correct null check in user service`, `chore: update dependencies`
- Run `git diff --staged` before every commit. Check for secrets, `.env` files, and dependency or lockfile changes you didn't intend.
- **Treat a dependency change as a security-relevant change.** Where it came from, why it moved, what its install scripts do.
- Small, focused commits — one logical change each. Easier to review, easier to revert.

## Never Rewrite Published History

Do not force-push a shared or protected branch. To undo something already published, revert it with a new commit.

```bash
git revert <commit-hash>
```

Force-pushing your own mission branch while you are still working on it is fine. Force-pushing anything others have pulled is not.

## Merging And Deploying

**Critical**: you may open PRs, resolve conflicts, and push. You **never** perform the final merge, and you **never** deploy. Both are the operator's call.

This is not a convenience. It is a safety property — the operator confirms environment, backup and rollback before anything ships.

## When To Stop

Report to Bishop when:

- A merge breaks tests.
- A conflict is genuinely ambiguous and needs a decision rather than a resolution.
- A token or credential may have leaked. Revoke it, rotate it, and report immediately — do not wait for anything else.
- A dependency looks wrong: unexpected upgrades, unfamiliar transitive changes, install scripts doing more than they should. Pause and ask for a security review.
- You aren't sure which branch to target. Confirm against the project's conventions before pushing.
