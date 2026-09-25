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

### Non-queue REFramework

Both Performer templates assume an Orchestrator queue in two places, and neither is flagged in
their deltas. Fetch a Performer for a process that has no queue and it will run green having
processed nothing — the same silent failure the repo warns about for a mismatched queue name.

Three things must change together:

| What | Stock | With no queue |
|---|---|---|
| `Framework/GetTransactionData.xaml` | Get Transaction Item against `in_Config("OrchestratorQueueName")` | Read the source **once** on the first pass (`in_TransactionNumber = 1`), hold it in a `DataTable`/collection, then hand out one item per call and `Nothing` when exhausted |
| `Constants!MaxRetryNumber` | `0` — "must be 0 when working with Orchestrator queues" | **Non-zero.** With no queue there is no queue definition to carry the retry count, so `0` means a transient failure is never retried at all |
| `Settings!OrchestratorQueueName` | `[UC-SPECIFIC — replace]` | `(not used - no queue)`. An explicit value shows the key is deliberately unused; an empty cell is indistinguishable from one nobody filled in |

`in_TransactionItem` stops being a `QueueItem` and becomes whatever your source yields — a
`DataRow`, a mail, a file path. `SetTransactionStatus.xaml` must lose its queue calls while
keeping the retry and circuit-breaker counters and the failure screenshot. `validate-project`
will not flag a non-zero `MaxRetryNumber`, but it *will* flag a queue name left at stock.

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
4. **Run the conformance checker and get it to zero errors.**

   ```bash
   .claude/skills/project-scaffolding/scripts/validate-project.sh  <project-dir> [<project-dir>]
   pwsh -File .claude/skills/project-scaffolding/scripts/validate-project.ps1 <project-dir>
   ```

   Pass a Dispatcher and its Performer together and it also checks the queue name is
   byte-identical across the pair. Every rule it enforces catches a failure that is otherwise
   **silent** — a stock `ProcessABCQueue`, a disabled circuit breaker, `ShouldMarkJobAsFaulted`
   false, a `Main.xaml` still pointing at the non-existent `Data\Config.xlsx`. Non-zero exit on
   any error, so it drops straight into CI. An unreplaced marker is a review finding; this is
   what finds it.

   A rule that is genuinely not applicable yet goes in a `validate-project.ignore` beside
   `project.json`, one `rule: reason` per line, indented lines continuing the reason:

   ```
   assets-parity: The credential Orchestrator assets do not exist yet, so the TST Assets sheet
     carries only the rows that resolve today. InitAllSettings resolves every Assets row at
     startup, so shipping rows for assets nobody has created fails Initialization.
   ```

   A suppressed finding is **still printed**, with its reason — it just stops failing the run.
   That is the point: a rule you can switch off silently is a rule nobody trusts six months
   later. `-SkipRule <name>` does the same thing ad hoc, without the written reason, and is
   meant for experimenting rather than for committing.

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
