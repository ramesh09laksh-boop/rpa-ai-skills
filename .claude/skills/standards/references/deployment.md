# Deployment

The repo had a deployment **checklist** — what must be true — and nothing on how to do it. This
file is the how. It deliberately does **not** duplicate Orchestrator mechanics: use UiPath's own
`uipath-platform` / Orchestrator skill for those, and this file for the estate's rules around
them.

Commands verified against `uip` **1.204.0**. Run `--help` before relying on a flag.

## Order

**TST first, always. PRD only with named, explicit approval** — a person, by name, for this
release. "We usually deploy on Thursdays" is not approval.

```
pack → publish to TST → create/confirm the process, queue, assets, trigger → run on TST (L4)
     → approval → publish to PRD → confirm PRD config → first PRD run watched
```

## 1. Pack

```bash
uip rpa pack <project-dir> --output-path <dir>
```

`pack` **compiles, validates and runs the analyzer**, so it is the gate that catches what
`validate` alone does not — `ST-SEC-008` SecureString scope being the usual one.

- Do **not** pass `--ignored-rules` or a policy file to get a green pack. Fix the finding.
- The package name comes from `project.json → name` **verbatim**, including any whitespace or
  placeholder. `<PROJECT-NAME-TBD-ask-team>` cannot be published — the angle brackets fail
  `^[A-Za-z0-9._-]+$`, by design.
- Pack from a **clean checkout at the commit you intend to ship.** A package built from a dirty
  working tree cannot be reproduced, and "which version is in PRD?" then has no answer.

## 2. Publish

```bash
uip rpa publish <path-to-.nupkg>      # takes a PACKAGE, not a project folder
```

Publishing to a **folder's** feed rather than the tenant feed scopes the process to that folder.
Match whatever the estate already does for the target folder; do not introduce a second pattern.

## 3. What has to exist in the Orchestrator folder

Publishing a package is not deploying a process. All five, in the **right folder**:

| | Must be true |
|---|---|
| **Process** | Created from the published package, in the folder the robots run in |
| **Queue** | Exists, with the **byte-identical** name in both `Settings` sheets. This is the mismatch that throws nothing and leaves both jobs green |
| **Assets** | Every row of the `Assets` sheet exists, with the exact name, right type, right scope. `InitAllSettings` resolves **all** of them at startup — one missing row fails Initialization |
| **Trigger** | Time or queue trigger as the SDD specifies. A queue trigger on the Performer and a time trigger on the Dispatcher is the usual pair |
| **Robot / machine** | Has access to the applications, the shares and the credentials. A process that works in Studio and not unattended is almost always this |

**A once-per-period trigger has no recovery.** A `1W` cron fires exactly once; if the robot is
down that morning the period is never processed and nothing complains. It also knows nothing
about the configured holiday calendar. Gate on *"on or after the due point, and not already
done"* inside the process instead — `silent-failure-traps.md`.

## 4. Before PRD

Everything in the README's Definition of Done, plus specifically:

- [ ] `Config_PRD.xlsx` carries the **same key set** as `Config_TST.xlsx`, no
      `[UC-SPECIFIC — replace]` left. A key only TST has fails the PRD run and nothing warns.
- [ ] Every PRD `Assets` row points at a **PRD** asset — not a TST asset that happens to resolve.
- [ ] `runtimeOptions.excludedLoggedData` excludes anything carrying a secret or customer data.
- [ ] **L4 on TST**, with the log excerpt, and a transaction count greater than zero.
- [ ] The analyzer is clean, and the report says **which rule set ran** — `code-quality.md`.
- [ ] Named approval recorded, for this release.

## 5. The first PRD run is watched

Not fire-and-forget. Someone reads the job log and the queue counts while it runs, and the
rollback is known **before** it starts: the previous package version is still in Orchestrator,
so rolling back means pointing the process at it. Confirm it is there first.

PRD touches real customer data. A failure there is not a test result.

## What this file does not own

- **Orchestrator mechanics** — creating folders, processes, queues, assets, triggers, robots
  and permissions. Use the official UiPath platform skill; this estate has no special rules for
  the clicks, only for what must be true afterwards.
- **The libraries being on the feed.** That is a prerequisite for the project to *restore* at
  all, long before deployment — `README.md`.
- **Who runs the test suite and how.** Open question: whether this repo or `test-ai-skills`
  owns that. Until it is settled, link to whichever the team actually uses rather than
  describing a second process here.
