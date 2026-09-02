---
name: project-scaffolding
description: Use when starting a new UC project — determines which Dispatcher/Performer template(s) to pull from rpa-ai-skills and fetches just that subfolder, without requiring a full clone of the templates repo. Trigger on "start a new UC project", "scaffold a new automation", "kick off UC<NN>", "which template do I use", "get the REFramework template", or when an SDD names its target application (Finnova, Avaloq, or both) and no project folder exists yet.
---

# Fetching a project template

`templates/` in `rpa-ai-skills` has no `SKILL.md` of its own, so `npx skills add` never brings
it along — that command only carries `.claude/skills/` folders. This skill is the fetch step,
wrapped so it travels like any other skill: install it, and `scripts/fetch-template.*` comes
with it.

## What to fetch

Ask, or read it off the SDD: **which application does this UC drive?**

| The UC… | Fetch |
|---|---|
| always | `REFramework-Dispatcher-Base` |
| drives Finnova | `+ REFramework-Performer-Finnova` |
| drives Avaloq | `+ REFramework-Performer-Avaloq` |
| drives both | `+` both Performers |

The Dispatcher is always fetched. Its job — read the upstream source, apply the selection
rule, enqueue — touches neither banking library, so one skeleton fits every project. If the
SDD describes no queue at all and the process is a single self-contained run, say so and fetch
only the Performer; do not invent a Dispatcher the process does not need.

**If `rpa-ai-skills` is already checked out locally, skip the script and copy the folder.**
The script exists for the case where it isn't — it is not the only sanctioned route.

## Fetching

No setup needed — the canonical repo is the default:

```bash
scripts/fetch-template.sh REFramework-Dispatcher-Base REFramework-Performer-Finnova
```

```powershell
scripts\fetch-template.ps1 -Template REFramework-Dispatcher-Base,REFramework-Performer-Finnova
```

Both do a blobless, depth-1 sparse checkout of only the matched `templates/<name>/` paths, then
move them into place. Neither will overwrite an existing folder — that is deliberate, so a
re-run cannot silently discard work in progress. `-d` / `-Destination` sets where they land
(default: the current directory); `-b` / `-Ref` pins a branch or tag.

### Pointing at a fork or an internal mirror

The default is `https://github.com/ramesh09laksh-boop/rpa-ai-skills`. Override it per
invocation, or once per developer:

```bash
scripts/fetch-template.sh -r https://git.internal/rpa-ai-skills.git REFramework-Dispatcher-Base
export RPA_SKILLS_REPO=https://git.internal/rpa-ai-skills.git   # or set it once
```

Precedence is `-r` / `-RepoUrl` > `$RPA_SKILLS_REPO` > default. Each run prints which of the
three it used, so a stale mirror is visible in the output rather than something you discover
later.

If the clone fails against the default, the likely causes are that the repo is private and
git is not authenticated (`gh auth login`, an SSH key, or a PAT), or that your team works from
a mirror — GitHub returns "not found" for both. The scripts say so when they fail.

### Fetched files have CRLF line endings — this is expected

A fetched template will differ from the source in `rpa-ai-skills` on **every text file** if you
diff it naively:

```
$ diff -r rpa-ai-skills/templates/REFramework-Dispatcher-Base ./REFramework-Dispatcher-Base
   ... every .md, .json and .uiproj reported as changed
```

**That is line endings, not content.** Git's `core.autocrlf` normalises LF to CRLF on checkout
on Windows, so the fetched copy is CRLF where the repo stores LF. Confirm it before chasing it:

```bash
diff -r --strip-trailing-cr <source> <fetched>   # exits clean if only line endings differ
md5sum <source>/Data/Config_TST.xlsx <fetched>/Data/Config_TST.xlsx   # binaries are untouched
```

Verified on the real repo: content identical, all three `.xlsx` workbooks match by md5. It has
no effect on UiPath — Studio and the Excel activities do not care — so **there is nothing to
fix here.** Do not add a `.gitattributes` to force LF or re-normalise a fetched template; the
only cost is a noisy diff, and the two commands above settle it in seconds.

## After fetching — this is not a finished project

The template is project-level scaffolding only. Three things still have to happen, in order:

1. **Generate `Main.xaml` and `Framework/*.xaml` from Studio.** File → New →
   **Robotic Enterprise Process**, Compatibility: **Windows** (not *Windows – Legacy*). The
   templates deliberately ship no `.xaml` — Studio is the authoritative source for those and
   stays in step with your Studio version. Then copy the fetched `project.json`,
   `project.uiproj`, `entry-points.json`, `Data/` and `Tests/` over what Studio produced.
2. **Apply the "Deltas to apply to the generated skeleton" section** from the fetched
   template's own `README.md`. That section is what turns a stock REFramework skeleton into a
   Dispatcher or a Finnova/Avaloq Performer — it is the substance of the template, not an
   appendix.
3. **Work the instantiation checklist** in `templates/README.md` — project name, fresh GUIDs,
   every `[UC-SPECIFIC — replace]` in `Config_TST.xlsx` *and* `Config_PRD.xlsx`, and the shared
   queue name.

## Two decisions to settle before the first publish

Both are painful to change afterwards and neither has a default this repo will pick for you.

**The project name.** The templates ship `"name": "<PROJECT-NAME-TBD-ask-team>"`, which fails
the publishability check on purpose. There are three naming formats live in the estate and no
minuted decision between them — ask the team, then apply the answer to `project.json → name`,
`project.uiproj → Name` and the folder name together. See
`.claude/skills/standards/references/naming-conventions.md`.

**How the Dispatcher and Performer relate.** There is no working pair in this estate yet, so
a `_Dispatcher`/`_Performer` suffix rule would be an assumption. When a UC first needs both
halves, ask all three parts in one go — how the project names relate, how they are packaged
and published, and what queue name they share — and record the answer.

The queue name is the one that bites silently: `OrchestratorQueueName` must be
**byte-identical** in both projects' `Settings` sheets. A mismatch throws nothing. The
Dispatcher enqueues, the Performer polls a queue that is empty or does not exist, and both
jobs finish green in Orchestrator with no work done.

## Related skills

- `.claude/skills/standards/` — where each workflow goes, naming, project layout, error handling
- `.claude/skills/security/` — wiring the `Assets` sheet rows to real Orchestrator assets
- `.claude/skills/pdd-sdd-scaffolding/` — turning the SDD into first-draft workflows once the skeleton exists
- `.claude/skills/finnova-library/`, `.claude/skills/avaloq-library/` — the activity APIs the Performers call
