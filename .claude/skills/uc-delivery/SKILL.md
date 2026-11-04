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
| **UiRobot path**    | C:\Program Files\UiPath\Studio\UiRobot.exe |
| **Robot user**      | <DOMAIN\account the robot service runs as> |
| **Robot connected to Orchestrator?** | yes / no — asked, not probed |
```

The last three are what an **L4-local** run needs, and they are **asked for once, together**, at
the start of stage 7b — not one question per step. Without the folder path a credential asset has
nowhere to resolve from; without knowing whether the robot is connected at all, an asset failure
is unreadable. `UiRobot` has no status verb and `connect`/`disconnect` rebind the machine's robot
service, so this is a question, not a probe. The `standards` skill,
`references/end-to-end-run.md` Part 0.

**Non-secret facts only.** Names, hosts, paths, accounts, folder paths. **Never** a password,
token, client secret, API key or connection string — those live in Orchestrator assets, and
`AGENTS.md` is a committed file. If a field cannot be filled without a secret, leave it out.

Keep **TST and production as separate login profiles** so a command cannot hit the wrong one by
default. Detail: the `standards` skill, `references/decisions.md` §0.

## The ten stages, and the gate on each

A stage is not done until its gate is met. Gates use the evidence ladder — **L1** static,
**L2** compiles + analyzer, **L2b** packs, **L3** Studio Error List empty, **L4-local** the
packed package run by the UiRobot on this machine in an Orchestrator folder, **L4** a real job on
TST in the Orchestrator folder, on a robot, with the SDD acceptance table (the
`project-scaffolding` skill, `references/evidence-ladder.md`). A **sources** run
(`uip rpa run`, Studio Debug) or a mocked run is **L3 at most**. L4-local is the default
end-to-end run and needs no `uip login`; L4 is **ask-first**.

| # | Stage | Load | Gate |
|---|---|---|---|
| 1 | PDD → SDD | `standards`, `security` | Every transaction type and its work-item columns defined; Open Questions listed |
| 2 | SDD → Project | `project-scaffolding` | **L3**, and the project folder renamed off the template's name |
| 3 | Wire the Framework | `standards` (`references/wiring-the-framework.md`), `security` | **L3**, and the 0-transaction guard observed firing |
| 4–5 | Capture **and** develop, one workflow at a time | `web` + `standards` + the app skill(s); `pdd-sdd-scaffolding` only in OFFLINE mode | Every row of `Documentation/Leaf_Ledger.md` reads `yes`, **and** each workflow was run once against the live application with the command recorded. `.objects/` committed |
| 6 | Test data → tests | `standards` (`references/test-data.md`), `security` | `Tests.xlsx` built; no case marked passed without a run |
| 7 | Review | `standards`, `security`, app skill(s) | Analyzer clean, **and the report names which rule set ran** |
| 7b | End-to-end run | `standards` (`references/end-to-end-run.md`), `security` | **L4-local (folder: …)** by default — the packed package run by the local UiRobot in a folder, with the acceptance table. Then **L4** (**ask first**) — a real job on a robot. A Successful run that processed 0 transactions is a failure at either level |
| 8 | UAT readiness | all of the above | **L4** — a real job, with state, logs and the SDD acceptance table. L4-local does not substitute |
| 9 | Deployment readiness | `standards` (`references/deployment.md`), `security` | TST first, at **L2b** and **L4**. PRD only with named approval |
| 10 | Change / enhancement | whatever the project already uses | Re-run 6–8 for what the change touches |

**Stage 2 is not done while the project folder still carries the template's name.** The fetch
lands each template in a folder named after the *template* — `REFramework-Dispatcher-Base` —
because that is the only name it has. The rename is the one instantiation step with **no
symptom**: the project compiles, packs and runs perfectly well under the template's name, so
nothing downstream forces it and it survives to review. Apply the agreed project name to all
three places in one commit — the **folder**, `project.json → name`, `project.uiproj → Name` —
and treat `project-folder-not-renamed` (error) or `folder-name-mismatch` (warning) from
`validate-project` as blocking the stage. Checklist: the `project-scaffolding` skill,
`references/instantiating-templates.md`.

**Stages 4 and 5 are one loop, not two stages.** Per workflow: place and name → capture →
author → run once → pack → ledger row → commit → next workflow. Capturing every screen first and
authoring afterwards is what let a project with a live session ship `TODO_SELECTOR` placeholders
and no capture at all. In LIVE mode a whole workflow is never deferred to `TODO_SELECTOR`; only
an individual target that fails the registration gate is, with the reason recorded. Ledger
template and column meanings: the `standards` skill, `references/leaf-ledger.md`.

**Name each leaf before authoring it, not after.** The folder is `<Application>_System/` — one
per application the SDD names — and the file is `<Application>-<Subject>_<Verb>.xaml` with the
prefix **derived from the folder**: `Web_Nav_System/Web_Nav-Table_Extract.xaml`,
`Finnova_System/Finnova-Valoren_Search.xaml`. Nothing downstream cares about the name either, so
this is the same class of step as the folder rename above — and it is worse to postpone: once a
workflow is wired, every rename costs an edit to each `Invoke Workflow File` pointing at it,
which is why a wrong name stays wrong. `validate-project` reports an unprefixed leaf as
`leaf-name-prefix`. Rules: the `standards` skill, `references/naming-conventions.md`; folder
choice: the `standards` skill, `references/where-does-it-go.md`.

Stages 3 and 4–5 are the ones most often skipped, and both fail silently: an unwired Framework
runs green on **zero** transactions, and an unresolved selector fails only when the robot runs.
A Framework wired to leaf workflows whose bodies are stubs does both at once.

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
L2b uip rpa pack, L3 Studio Error List clean, L4-local the packed package run by the UiRobot on
this machine in an Orchestrator folder (quote it as "L4-local (folder: <folder>)"), L4 a real job
on TST in the Orchestrator folder on a robot with the SDD acceptance table. A sources run or a
mocked run is L3 at most; L4-local is never reported as L4. "Needs Studio" only with the exact
command and its error. Commit locally after each item; keep Documentation/Progress.md updated.
Do not stop between items — log a blocker and continue with the next.

ASK ME FIRST before anything that authenticates to, or changes, Orchestrator — naming the exact
command and why, then wait. That includes `uip login`, ANY `uip or ...` command (even a read),
`uip rpa publish`, `uip or packages upload`, `uip or jobs start`, creating or changing a
process/asset/queue/trigger/folder, `UiRobot connect` or `disconnect`, `uip rpa restore` where
the feed is Orchestrator-hosted, and installing anything. Reading files and `--help` are always
fine, as are `uip --version`, `uip tools list`, `uip login status`, validate-project, and
`uip rpa validate`/`build`/`pack`/`analyze`. Do not run it and tell me afterwards.
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
- **Ask before anything that authenticates to, or changes, Orchestrator.** See below.

### Ask before touching the tenant

The line is not read-versus-write. It is *"does this authenticate to Orchestrator, or change
it?"* — a read still signs in, under whoever's identity the local token holds, and lands in the
tenant's audit log under their name.

**Always fine, never ask:** reading files; `--help` at any depth; `uip --version`,
`uip tools list`, `uip login status` (reads the **local** token, authenticates nothing);
`validate-project`, `lint-skills`, the rule fixtures, `preflight` without `-FolderPath`;
`uip rpa validate` / `build` / `pack` / `analyze`; `UiRobot version`, `UiRobot pack`.

**Ask first, naming the exact command and why:** `uip login` · **any** `uip or …`, including a
pure read like `or folders list` · `uip rpa publish` / `uip or packages upload` ·
`uip or jobs start` · creating or updating a process, asset, queue, trigger or folder ·
`UiRobot connect` / `disconnect` (this rebinds **the machine's** robot service) ·
`uip rpa restore` where the feed is Orchestrator-hosted · `uip skills install` /
`npx skills add` · anything else that reaches the tenant.

Name the command verbatim, say whether it only reads or also changes something, say what you
need it for, and **wait**. Do not run it and report afterwards: "I ran it and it was fine" is
not consent, and on a bank tenant it is not recoverable either.

`preflight -FolderPath` runs `uip or …` reads — **passing the switch is the asking.** Its
library-feed check runs `uip rpa restore`, an authenticated read against an Orchestrator-hosted
feed; `-SkipFeedCheck` turns it off. Full list: `AGENTS.md` in this repo.

### The official `uipath-rpa` skill

Every `uip rpa` invocation asks for it, and this estate's skills now route CLI mechanics there
on purpose — the `web` skill deliberately carries no `uia` command table. `preflight` reports
whether it is installed for this agent, and warns when a copy's `targetCli` does not match the
installed host.

**If it is missing: ask once, then install it.** Installing software is on the ask-first list.

```bash
npx skills add https://github.com/uipath/skills --skill uipath-rpa --agent <id> -y
```

Confirm `<id>` with `npx skills add --help` — `claude-code`, `github-copilot`, `codex`,
`opencode`, or `'*'`; **`copilot` is not valid**. `uip skills install` is the alternative and
keeps itself updated. Record which route was used and the version it landed, in
`Documentation/Progress.md`.

Stop and ask before any action that touches data outside TST throwaway data, needs a credential
you were not given, or authenticates to the tenant.

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
