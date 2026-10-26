---
name: uc-delivery
description: The front door for building a UiPath automation in this estate end to end. Use when asked to implement, build or kick off an automation from a PDD or SDD, to start UC<NN>, to continue or resume an existing UC project, or when someone asks "where do I start" with a UiPath project. Runs preflight, drives the ten delivery stages in order with a check gate per stage, asks the open decisions one at a time in plain language, pauses at the points that need a person, and routes to the skill that owns each piece — standards, project-scaffolding, pdd-sdd-scaffolding, web, security, finnova-library, avaloq-library. Trigger on "build this from the PDD", "implement the SDD", "start a new UC project", "continue UC<NN>", "what's next on this project".
---

# UC delivery — the conductor

This skill holds no estate knowledge of its own. It decides **what happens next**, which skill
owns it, and what counts as finished. Everything else is a link.

If you know exactly which stage you are on, go straight to that skill. This file is for
"build this from the PDD" and for picking up a project someone else left half-done.

## Before anything: preflight and state

```bash
# 1. environment -- read-only, prints a one-line fix per failure
<project-scaffolding skill>/scripts/preflight.sh [<project-dir>]
<project-scaffolding skill>/scripts/preflight.ps1 -ProjectPath <dir> -FolderPath <folder>

# 2. is this a new project or a resumed one?
cat Documentation/Progress.md        # exists -> resume from "next"; absent -> new, create it
```

### Read the preflight result properly — `SKIP` is not `OK`

Preflight prints four states, and the one that gets misread is `SKIP`:

| | Means |
|---|---|
| `OK` | checked, and it passed |
| `FAIL` | checked, and it failed — blocking, with the fix on the next line |
| `WARN` | checked, and it is a problem you may proceed past knowingly |
| **`SKIP`** | **not checked at all.** Nothing is known about it either way |

**A `SKIP` is an open item that a person has to verify.** It is not a pass, and
"0 blocking" in the summary does **not** mean the environment is good — it means nothing
blocking was *found among the checks that ran*.

This matters most for the robot-side prerequisites, which **cannot** be checked from a developer
machine and therefore always `SKIP`: whether the robot version supports the package pins,
whether the robot's own package sources reach both the UiPath packages and the Swisscom
libraries, whether it is an unattended robot with an interactive Windows session, whether the
browser extension is installed for the **service account's** profile, and whether the
application is reachable from the **robot machine**. Every one of those has failed a real run
somewhere, and each fails confusingly — usually as a selector timeout rather than a clear
message.

So: **list every `SKIP` back to the user as something they must confirm**, name who can confirm
it (usually whoever owns the robot or the Orchestrator folder), and say that you are proceeding
with it unverified. Do not report a preflight with SKIPs as "environment ready". Detail: the
`standards` skill, `references/end-to-end-run.md` Part 1.

**`Documentation/Progress.md` is the state of the build.** Update it after **every** item —
done / blocked / next, with the command that proved "done". A restart then resumes instead of
re-deriving, and it is the only place a captured Object Repository reference id survives.

**`git init` and a `.gitignore` before the first change, then commit per item.** Without this
there is no baseline and "what did that stage change?" has no answer.

## The platform, and the project's Environment block

**This estate is UiPath Automation Suite (self-hosted), not Automation Cloud.** Projects run on a
**UiRobot** through an **Orchestrator folder** — e.g. `Modern/RAP-Demo`.

**Do not assume Cloud.** The Orchestrator host is the estate's own Automation Suite URL, never
`cloud.uipath.com`; `uip login` reaches it with `--authority <host>` (that flag's help names
Automation Suite explicitly). Cloud-only features are not available by assumption — if one looks
like the answer, that is a question for the team, not a step.

Every project states its own environment in **its own `AGENTS.md`**, so no agent has to infer
it. Create this block at stage 2 and keep it current:

```markdown
## Environment

| | |
|---|---|
| Platform            | UiPath Automation Suite (self-hosted) — **not** Automation Cloud |
| Orchestrator host   | <https://orchestrator.example.internal> |
| Tenant              | <TenantName> |
| Folder path         | Modern/RAP-Demo |
| Robot machine       | <MACHINE-NAME> |
| Windows account     | <DOMAIN\svc-rpa-account> (unattended, interactive session) |
| Package feed        | the feed this folder uses — <name or URL> |
| Environment         | TST  ·  production is <folder path>, separate approval required |
| uip login           | `uip login --authority <host> --tenant <tenant> --profile <tst|prd>` |
```

**Non-secret facts only.** Names, hosts, paths, accounts, folder paths. **Never** a password,
token, client secret, API key or connection string — those live in Orchestrator assets, and
`AGENTS.md` is a committed file. If a field cannot be filled without a secret, leave it out.

Keep **TST and production as separate login profiles** so a command cannot hit the wrong one by
default. Detail: the `standards` skill, `references/decisions.md` §0.

## The ten stages, and the gate on each

A stage is not done until its gate is met. Gates use the evidence ladder — **L1** static,
**L2** compiles + analyzer, **L2b** packs, **L3** Studio Error List empty, **L4** a real job on
TST in the Orchestrator folder, on a robot, with the SDD acceptance table (the
`project-scaffolding` skill, `references/evidence-ladder.md`). A local run or a mocked run is
**L3 at most**.

| # | Stage | Load | Gate |
|---|---|---|---|
| 1 | PDD → SDD | `standards`, `security` | Every transaction type and its work-item columns defined; Open Questions listed |
| 2 | SDD → Project | `project-scaffolding` | **L3** |
| 3 | Wire the Framework | `standards` (`references/wiring-the-framework.md`), `security` | **L3**, and the 0-transaction guard observed firing |
| 4 | Capture targets | `web` | Every `TODO_SELECTOR` resolved or recorded with a reason; `.objects/` committed |
| 5 | Develop leaf workflows | `standards` + the app skill(s), `pdd-sdd-scaffolding` | **L2**, `_System` contract met |
| 6 | Test data → tests | `standards` (`references/test-data.md`), `security` | `Tests.xlsx` built; no case marked passed without a run |
| 7 | Review | `standards`, `security`, app skill(s) | Analyzer clean, **and the report names which rule set ran** |
| 8 | UAT readiness | all of the above | **L4** — a real job, with state, logs and the SDD acceptance table |
| 9 | Deployment readiness | `standards` (`references/deployment.md`), `security` | TST first, at **L2b** and **L4**. PRD only with named approval |
| 10 | Change / enhancement | whatever the project already uses | Re-run 6–8 for what the change touches |

Stages 3 and 4 are the ones most often skipped, and both fail silently: an unwired Framework
runs green on **zero** transactions, and an unresolved selector fails only when the robot runs.

## Ask the decisions one at a time, in plain language

Six decisions are genuinely the team's: config format, credential mechanism, queue or no queue,
project name, Dispatcher/Performer naming, and where work items really come from. Each one's
options, consequences, recommended default and owner:
the `standards` skill, `references/decisions.md`.

- **One question per message.** A list of six gets one answer and five shrugs.
- **A recommended default is not an answer.** Until a person confirms it, the decision stays an
  **Open Question** in the SDD and any placeholder it touches stays a placeholder. The templates
  ship `"name": "<PROJECT-NAME-TBD-ask-team>"`, which fails the publishability check *on purpose*
  — an unanswered question must not be able to ship as an answer.
- **Record every answer in the SDD's Decisions table**, with who confirmed it.

## Pause properly at a human checkpoint

Five things need a person: the Studio Error List, a TST run, the Orchestrator job/queue/logs, an
asset, and a live capture session. Steps, what "good" looks like, and **what to paste back**:
the `standards` skill, `references/studio-checkpoints.md`.

When you reach one, say the level you reached, the command that proved it, exactly what you need,
and **what you are doing meanwhile** — then carry on with the next item that does not depend on
it. Do not stop the run.

"Needs Studio" on its own is not acceptable. Give the command and its error. Most apparent
Studio blockers are a missing Studio *session*, which `uip rpa studio start` provides.

## Working rules

```
Working rules: never invent a selector, activity, argument, API, config value, credential or
business rule — if the source is silent it is an Open Question / TODO. Report the highest
check level reached, with the command used: L1 validate-project, L2 uip rpa validate+build,
L2b uip rpa pack, L3 Studio Error List clean, L4 a real job on TST in the Orchestrator folder
on a robot with the SDD acceptance table. A local run or a mocked run is L3 at most, never L4.
"Needs Studio" only with the exact command and its error. Commit locally after each item; keep
Documentation/Progress.md updated. Do not stop between items — log a blocker and continue with
the next.
```

When something breaks, start at the `standards` skill, `references/troubleshooting.md` — the
symptom is usually not the problem.

## Safety rails

Not decisions, and not negotiable:

- **TST only. Never PRD** without named, explicit approval.
- **No real customer data** in a run, a screenshot, a log or a commit.
- **Never type or paste a credential** — not into a prompt, a snapshot, a definition file or a
  chat. Credentials come from the Orchestrator asset. If one is missing, that is a checkpoint.
- **Destructive actions only on data you have been told is throwaway.**

Stop and ask before any action that touches data outside TST throwaway data, or needs a
credential you were not given. Those are the only two reasons to stop mid-run.

## Working alongside the official UiPath skills

**The CLI tells you to load the official `uipath-rpa` skill, and it means it.** Every
`uip rpa` invocation prints:

> *Before using this tool, make sure you have loaded the **uipath-rpa** skill and read its
> documentation. `uipath-rpa/SKILL.md` is the canonical reference. Direct CLI use without
> loading the skill bypasses authoring rules that catch errors early.*

So: **load `uipath-rpa` for CLI mechanics** — verb names, flags, activity authoring, what a
command actually does. It ships with the tool and is updated with it, which is exactly what this
repo cannot promise about command names.

**This estate's rules win on structure, naming and security** — where a workflow goes, how it is
named, the `_System` contract, credentials and assets, what must never be logged or committed.
Those are not UiPath's to decide.

Teams install the rest of UiPath's set too (`npx skills add UiPath/skills --list`). Both sets
load.

**Precedence:** this repo's skills win for project creation, the estate's conventions,
Finnova/Avaloq UI automation, REFramework structure and testing. The official skills own generic
activity authoring, the CLI surface and Orchestrator operations.

When the two disagree, **follow the estate and note the conflict in `Progress.md`** so it can be
settled rather than re-decided per project.

## CLI rules that are not negotiable

- **`uip` is a host plus separately-versioned tools.** `uip --version` tells you about the host,
  not about `rpa`. Run **`uip tools list`** and record the versions in
  `Documentation/Progress.md` at the start of the project. Command names have already moved
  under this repo once.
- **Never run `uip tools update` mid-project.** It changes verb names and flags underneath work
  in progress. Update between projects, deliberately, and record the new versions. Preflight
  prints `uip tools list` and warns when `rpa-tool` differs from the version recorded in
  `Progress.md`.
- **`rpa cleanup` only with `--dry-run`.** Its own description: *"Remove unused items from a
  UiPath project (**modifies the project sources in place**)"*. Without `--dry-run` it edits
  your sources. Run it bare only on a clean, committed tree, never as a side effect.
- **`run` likely needs a Studio instance with the project open — UNVERIFIED.** The help text
  describes `--project-dir` as matching *running Studio instances*, and `rpa instances list` can
  report a live Studio with `"ProjectDirectory": "(none)"`. That is suggestive and has not been
  tested. Do not present it as the cause of a failed run; test it, then record the answer.

Full map, keyed by tool and version: the `project-scaffolding` skill,
`references/cli-command-map.md`.

## Related skills

- `standards` — layout, naming, wiring, error handling, decisions, checkpoints, troubleshooting
- `project-scaffolding` — preflight, templates, skeleton generation, `validate-project`, the ladder
- `pdd-sdd-scaffolding` — PDD/SDD → first-draft workflows, `TODO_SELECTOR` discipline
- `web` — browser capture with `uip rpa uia`
- `security` — credentials, assets, config, the never-do list
- `finnova-library`, `avaloq-library` — the banking activity APIs
