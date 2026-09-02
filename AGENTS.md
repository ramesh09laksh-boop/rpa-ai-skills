# AGENTS.md

Guidance for coding agents working on UiPath automations in this repository.

This is `rpa-ai-skills`, the central skills repo — not a UC project. The library and sample
process rows below are **source material for maintaining the skills**, not a template for a
new project to copy. A UC project starts from `templates/`, pulls `.claude/skills/` via
`npx skills add`, and implements fresh against the libraries' own activities. See `README.md`.

## Prerequisite: the libraries must be on the feed

**Finnova/Avaloq `.nupkg`s must already be published to `<your feed>` before opening or
restoring any project that references them.** Studio/CLI package restore fails with an
unresolved-dependency error otherwise — publish first, then scaffold or open the project.
Full note, including which packages and why the templates set
`"mustRestoreAllDependencies": true`:
[`README.md`](README.md#prerequisite-publish-the-libraries-to-your-feed).

The library *sources* being in this repo does not put the *packages* on the feed. If a restore
fails on `Swisscom.FinnovaLibrary`, `Swisscom.PHI` or `Swisscom.UiPath.UIAutomation.Avaloq`,
that is the cause — do not work around it by relaxing the dependency pin or the restore flag.

## What this repo holds

| Path | Contents |
|---|---|
| `.claude/skills/` | Agent skills generated from the material below — **the distributable unit**; pulled into UC projects via `npx skills add`. |
| `templates/` | Three REFramework starting points, split by role: `REFramework-Dispatcher-Base`, `REFramework-Performer-Finnova`, `REFramework-Performer-Avaloq`. Copied and adapted per project. See `templates/README.md`. |
| `templates/tools/` | `build-template-workbooks.ps1` — source of truth for the templates' `Config_*.xlsx` and `Tests.xlsx`. Edit the script, not the workbooks. |

## What sits alongside it

The libraries, the sample processes and the reference projects live **one level above this
repo**, as siblings of `rpa-ai-skills/`. Every path below is written relative to this repo's
root and resolves outside it; `.claude/skills/` is what ships, the rest is the evidence it was
derived from.

| Path | Contents |
|---|---|
| `../Finnova/Swisscom FinnovaLibrary/` | UiPath library project — Finnova activities. Ground truth for `finnova-library`; re-verify the skill against it when the library is upgraded. |
| `../Finnova/UC39_BPO_manuelle_Börsenaufträge/` | Sample process — manual stock-exchange orders. Evidence the skills cite, not a starting template. |
| `../Finnova/PJFVA-966_UC81_BPO_VD03_TK _Valoren/` | Sample process — securities master data. Evidence the skills cite, not a starting template. |
| `../Avaloq/Swisscom.UiPath.UIAutomation.Avaloq/` | UiPath library project — Avaloq activities. Ground truth for `avaloq-library`. |
| `../Avaloq/TKB-UC11.Kreditverletzung/` | Sample process — credit-limit violations. Evidence the skills cite, not a starting template. |
| `../REFramework-Dispatcher-Base/` | Reference project — real Studio 23.10 Windows REFramework skeleton. Ground truth for `templates/REFramework-Dispatcher-Base/project.json`. |
| `../REFramework-Performer-Avaloq/` | Reference project — same, with the Avaloq library wired in. |
| `../REFramework-Performer-Finnova/` | Reference project — same, with the Finnova library wired in. |

The three `../REFramework-*/` projects are where the templates' `project.json`,
`project.uiproj` and `entry-points.json` come from. They are **not** the templates: they carry
`Main.xaml`, `Framework/*.xaml` and a stock single `Data/Config.xlsx`, none of which the
templates ship — see `templates/README.md`. When Studio is upgraded, re-open these three,
let Studio rewrite their `project.json`, and carry the diff into `templates/`.

## Skills

Load the skill that matches the work. App-specific detail lives in the skills, not here.

| Skill | Use for |
|---|---|
| [`.claude/skills/standards/`](.claude/skills/standards/SKILL.md) | Project layout, where a new workflow belongs, naming, error handling, **and a reference per application folder** (Finnova, Avaloq, SIX iD, CardOne, Web Nav, UBS KeyTrader, Camunda, AI, Mail, File) |
| [`.claude/skills/project-scaffolding/`](.claude/skills/project-scaffolding/SKILL.md) | Starting a new UC project — picking the right template(s) and fetching just those subfolders out of `templates/`. Carries the fetch scripts, since `templates/` itself does not travel with `npx skills add` |
| [`.claude/skills/finnova-library/`](.claude/skills/finnova-library/SKILL.md) | Calling `Swisscom.FinnovaLibrary` activities |
| [`.claude/skills/avaloq-library/`](.claude/skills/avaloq-library/SKILL.md) | Calling `Swisscom.UiPath.UIAutomation.Avaloq` activities |
| [`.claude/skills/web/`](.claude/skills/web/SKILL.md) | Any browser-based step; Playwright MCP for selector validation during development |
| [`.claude/skills/security/`](.claude/skills/security/SKILL.md) | Credentials, Orchestrator assets, config, never-do list |
| [`.claude/skills/pdd-sdd-scaffolding/`](.claude/skills/pdd-sdd-scaffolding/SKILL.md) | Turning a PDD/SDD — including screenshots annotated only with an arrow — into a first-draft scaffold; and scaffolding when the target application is unavailable |

Start with `.claude/skills/standards/` when translating an SDD into workflows — it routes to
the right application reference and to the library skills.

## Ground rules

- **Every project here is UiPath REFramework.** Keep `Framework/` close to stock; put
  process logic in `<Application>_System/` and `Logic/`.
- **`<Application>_System/` touches the UI. `Logic/` decides.** Never mix them.
- **Use the library, not raw selectors,** for Finnova and Avaloq. UC39 contains zero raw
  Finnova selectors outside `Tests/` — that is the standard.
- **`BusinessRuleException`** for "the application refused"; **`ApplicationException`** for
  technical failures. Carry the application's own message text.
- **No secrets in `.xaml`, config sheets, logs or commits.** See `.claude/skills/security/`.
- **Config is `Data/Config_<ENV>.xlsx`**, selected by the `in_ENV` process argument. Add new
  keys to both `TST` and `PRD`.
- **The project-naming format is proposed, not settled.** `<CustomerCode>-UC<NN>.<Description>`
  (`TKB-UC11.Kreditverletzung`) is this repo's proposal, read off the newest project — three
  formats are live and nothing minutes a decision between them. Ask the team once, record the
  answer, then stop asking. The templates ship `"name": "<PROJECT-NAME-TBD-ask-team>"` rather
  than a plausible-looking default, so an unanswered question cannot ship as an answer.
  Existing folders keep their historical names — renaming breaks Orchestrator process links.
  See `.claude/skills/standards/references/naming-conventions.md`.
- **New projects target Windows, not Legacy.** `"targetFramework": "Windows"` with
  `"modernBehavior": true` — that is what `templates/` and the `../REFramework-*/` reference
  projects ship. An existing project stays on whatever it was published with; migrating one is
  a deliberate piece of work, not a drive-by edit.
- **No whitespace in `project.json → name`.** It propagates verbatim into the published
  package name and the Orchestrator process name. The same name lives in `project.uiproj`,
  and `entryPoints[0].uniqueId` is mirrored in `entry-points.json` — rename all three together.
- **A Dispatcher and its Performer share one Orchestrator queue.** `OrchestratorQueueName`
  must be byte-identical in both `Settings` sheets. A mismatch throws nothing — both jobs
  finish green and no transaction is processed. See
  `templates/README.md#the-queue-name-is-a-contract-between-the-pair`.
- **How a Dispatcher/Performer pair is named is undecided.** No two-project pair exists in the
  estate yet, so there is no observed pattern. Ask the team on first occurrence; do not infer
  a `_Dispatcher`/`_Performer` suffix rule.

## Deployment & review rules

Only what the estate actually evidences. Do not add a rule here that no project follows.

- **A generated scaffold is not a deliverable.** Anything produced by
  `.claude/skills/pdd-sdd-scaffolding/` ships with a `<WorkflowName>.selectors-todo.md`, and
  every `APPROX_SELECTOR` / `TODO_SELECTOR` in it is resolved against the live application
  before UAT. An unresolved marker blocks review.
- **Tests live in `Tests/` and stay there.** `RunAllTests.xaml` + `Tests.xlsx` drive the
  suite; `_`-prefixed workflows are developer scratchpads. **Nothing in `Tests/` may be
  invoked from `Process.xaml`** — UC39 does this in three places and it is a defect, not a
  pattern to copy.
- **Raw selectors are a review finding** outside `Tests/` and the Avaloq `Web_Nav_System/`.
- **Config keys land in both `Config_TST.xlsx` and `Config_PRD.xlsx` in the same change**, or
  the PRD run fails on a key that only TST has.
- **An unreplaced `[UC-SPECIFIC — replace]` blocks review**, the same way an unresolved
  `TODO_SELECTOR` does. The templates ship these markers in `Config_*.xlsx` and `Tests.xlsx`
  deliberately, so a half-instantiated project cannot pass for a finished one.
- **An unreplaced `<PROJECT-NAME-TBD-ask-team>` blocks review too**, and cannot be published —
  the angle brackets fail `^[A-Za-z0-9._-]+$`. Do not relax that check or soften the
  placeholder; replace it with the name the team agreed, in `project.json → name`,
  `project.uiproj → Name` and the folder name together.
- **The templates' workbooks are generated.** Change
  `templates/tools/build-template-workbooks.ps1` and re-run it; a hand-edit to a shipped
  `.xlsx` is lost on the next run. (This applies to `templates/` only — a UC project's own
  `Config_*.xlsx` is hand-maintained as usual.)
- **Library upgrades are re-verified, not assumed.** Bumping a pin means re-checking the
  affected `references/activities.md` against the library project — the skills document exact
  argument names and several load-bearing misspellings. Two pin sets are in play and they do
  **not** agree:

  | | Finnova | Avaloq | PHI |
  |---|---|---|---|
  | Samples under `../Finnova/`, `../Avaloq/` | `[4.0.3]` / `[4.0.7]` | `[2.6.5]` | `[1.0.7]` |
  | `templates/`, from `../REFramework-*/` | `[2026.1.0]` | `[2025.9.1]` | `[24.10.0]` |

  **The skills' `references/activities.md` are verified against the sample pins only.** The
  newer template pins were taken from the reference projects, not re-derived from the library
  sources. Treat an activity signature as unconfirmed on the newer packages until someone
  checks it — that check is outstanding work, not a completed step.
- **No secrets in a commit, ever** — including a "temporary" one later amended away. See
  `.claude/skills/security/`.

## Tooling

Playwright MCP is configured for this project and used **during development only** to
validate web selectors — it is never a runtime dependency of a shipped robot:

```bash
claude mcp add playwright npx @playwright/mcp@latest
```

Requires Node.js 20+. See `.claude/skills/web/`.
