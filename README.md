# rpa-ai-skills

Central agent-skills repo for the UiPath RPA estate (Finnova, Avaloq and the systems around
them). UC projects do **not** carry their own copy of these skills — they pull the ones they
need from here.

- Skills live in [`.claude/skills/`](.claude/skills/).
- Project templates live in [`templates/`](templates/).
- [`AGENTS.md`](AGENTS.md) is the entry point for an agent working *in this repo*.

## Prerequisite: publish the libraries to your feed

> The Finnova/Avaloq `.nupkg`s must already be published to `<your feed>` **before** opening
> or restoring any project that references them. Studio/CLI package restore will fail with an
> unresolved-dependency error otherwise — publish first, then scaffold or open the project.

This bites hardest on a brand-new project: the templates in [`templates/`](templates/) set
`"mustRestoreAllDependencies": true`, so a missing package fails loudly at restore rather than
leaving a project that half-loads and misbehaves later. That is the intended behaviour — fix
the feed, don't relax the flag.

The packages in question:

| Package | Template pin | Also pinned in |
|---|---|---|
| `Swisscom.FinnovaLibrary` | `[2026.1.0]` in `templates/REFramework-Performer-Finnova/` | both Finnova sample processes, at `[4.0.3]` / `[4.0.7]` |
| `Swisscom.PHI` | `[24.10.0]` in both Performer templates | both Finnova sample processes, at `[1.0.7]` |
| `Swisscom.UiPath.UIAutomation.Avaloq` | `[2025.9.1]` in `templates/REFramework-Performer-Avaloq/` | `../Avaloq/TKB-UC11.Kreditverletzung`, at `[2.6.5]` |

The library **sources** live one level above this repo (`../Finnova/Swisscom FinnovaLibrary/`,
`../Avaloq/Swisscom.UiPath.UIAutomation.Avaloq/`); having the source available is not the same as
having the package on the feed, and only the latter makes a restore succeed.

The skills' activity references are verified against the older sample pins. The template pins
come from the reference projects and have not been re-checked against the library sources —
see [`AGENTS.md`](AGENTS.md#deployment--review-rules).

## Start a new project

Three REFramework templates, split by role — see [`templates/`](templates/):

| Template | Role |
|---|---|
| `REFramework-Dispatcher-Base` | Reads the upstream source, filters, enqueues. No banking-library dependency; one skeleton fits every project. |
| `REFramework-Performer-Finnova` | Consumes the shared queue, drives Finnova. |
| `REFramework-Performer-Avaloq` | Consumes the shared queue, drives Avaloq. |

A Dispatcher and its Performer **share one Orchestrator queue**, and a mismatched queue name
throws nothing — both jobs go green and no work is done. Settle the queue name when you
instantiate the pair: [the pairing contract](templates/README.md#the-queue-name-is-a-contract-between-the-pair).

## Install into a UC project

Run from the root of the UC project.

**Everything:**

```bash
npx skills add ramesh09laksh-boop/rpa-ai-skills --agent claude-code
```

**Only what the project needs:**

```bash
npx skills add ramesh09laksh-boop/rpa-ai-skills --skill finnova-library --skill security --agent claude-code
```

Swap `--agent claude-code` for the agent you use — `--agent copilot`, `--agent codex`, or
`--agent '*'` for all of them.

> **The `owner/repo` prefix is required.** `npx skills add rpa-ai-skills` fails with
> `fatal: repository 'rpa-ai-skills' does not exist` — the CLI resolves a source as
> `owner/repo` or a full URL, never as a bare package name. The full URL form
> (`https://github.com/ramesh09laksh-boop/rpa-ai-skills`) works too.
>
> The repo is **private**, so git must be authenticated — a GitHub sign-in through VS Code, or
> `gh auth login`, is enough. Verified working: all seven skills install, including
> `project-scaffolding` with its fetch scripts intact.

### Available skills

| `--skill` | Use for |
|---|---|
| `standards` | Project layout, where a workflow belongs, naming, error handling, and a reference per application folder (Finnova, Avaloq, SIX iD, CardOne, Web Nav, UBS KeyTrader, Camunda, AI, Mail, File) |
| `project-scaffolding` | Starting a new UC project — picks the right template(s) and fetches just those subfolders out of `templates/` |
| `finnova-library` | Calling `Swisscom.FinnovaLibrary` activities |
| `avaloq-library` | Calling `Swisscom.UiPath.UIAutomation.Avaloq` activities |
| `web` | Any browser-based step; Playwright MCP for selector validation |
| `security` | Credentials, Orchestrator assets, config, never-do list |
| `pdd-sdd-scaffolding` | PDD/SDD (incl. screenshots) → first-draft workflow scaffold; also covers scaffolding while the target application is unavailable |

`standards` routes to the others — take it in every project.

Typical picks:

| Project talks to | Skills |
|---|---|
| Finnova | `standards` `project-scaffolding` `finnova-library` `security` `pdd-sdd-scaffolding` |
| Avaloq | `standards` `project-scaffolding` `avaloq-library` `security` `pdd-sdd-scaffolding` |
| …plus any web portal (SIX iD, CardOne) | add `web` |

### `templates/` does not travel with `npx skills add`

That command carries `.claude/skills/` folders only, and `templates/` has no `SKILL.md` of its
own — so a UC project that installs the skills still has no template. That is what
`project-scaffolding` is for: it ships `scripts/fetch-template.sh` and a `.ps1` twin that
sparse-checkout just the matched `templates/<name>/` subfolder(s), so the fetch step travels
like any other skill.

The scripts need no setup — they default to `https://github.com/ramesh09laksh-boop/rpa-ai-skills`:

```bash
scripts/fetch-template.sh REFramework-Dispatcher-Base REFramework-Performer-Finnova
```

Working from a fork or an internal mirror? Override per invocation with `-r` / `-RepoUrl`, or
once per developer with `$RPA_SKILLS_REPO`. Precedence is flag > env var > default, and each
run prints which one it used.

### Put this in your project kickoff checklist

Pulling the right skills should not be something each developer remembers unprompted. Add
the `npx skills add` line to whatever scaffolding/kickoff checklist new UC projects already
follow, next to "create the repo" and "wire up Orchestrator".

**The project name is an open question, not a default.** Three formats are live in the estate
and none is minuted; the templates ship `"name": "<PROJECT-NAME-TBD-ask-team>"`, which fails
the publishability check on purpose. Ask the team, then apply the answer —
[`naming-conventions.md`](.claude/skills/standards/references/naming-conventions.md).

## Why the library and sample projects are still kept

They sit **one level above this repo**, as siblings of `rpa-ai-skills/`:

| Sibling | What it is |
|---|---|
| `../Finnova/`, `../Avaloq/` | Two UiPath library projects and three real UC processes |
| `../REFramework-Dispatcher-Base/`, `../REFramework-Performer-Avaloq/`, `../REFramework-Performer-Finnova/` | Three reference projects — real Studio 23.10 Windows REFramework skeletons |

`../Finnova/` and `../Avaloq/` are the **source-of-truth evidence the skills were derived
from** — the skills cite real activity signatures, real workflow sequences and real bugs from
these specific projects. When a library is upgraded, having the source to hand is what makes it
possible to regenerate or verify the affected skill content against ground truth.

The three `../REFramework-*/` projects are the **ground truth for the templates' project
metadata**. `templates/*/project.json`, `project.uiproj` and `entry-points.json` were taken from
them rather than hand-written, which is why the templates target Windows on Studio 23.10.8.0.

None of them is a template — [`templates/`](templates/) is. A new UC project starts from a
template, pulls `.claude/skills/`, and implements fresh against the library's own activities;
it does not clone the sample workflow files.

## Maintaining a skill

1. Edit under `.claude/skills/<name>/`. `SKILL.md` is the always-loaded summary; put detail
   in `references/*.md` so it loads only when needed.
2. Keep the frontmatter `description` trigger-shaped — it is the only thing an agent sees
   when deciding whether to load the skill.
3. Cite the estate. Every claim should be traceable to a file under `../Finnova/` or `../Avaloq/`.
   No invented activities, no invented selectors.
4. Opening `rpa-ai-skills` itself in Claude Code or Copilot picks the skills up
   automatically — `.claude/skills/` is auto-discovered, so you can test a change in place.

### If Copilot doesn't pick a skill up

Claude Code and Copilot both auto-discover `.claude/skills/`. If Copilot doesn't surface a
skill for a test prompt (try: *"implement a new Finnova commission workflow"* — it should
reach for `standards` and `finnova-library` before writing code), mirror the tree to
`.github/skills/` **in addition to** `.claude/skills/`, not instead of it. Keep
`.claude/skills/` as the source; a mirror that drifts is worse than no mirror.
