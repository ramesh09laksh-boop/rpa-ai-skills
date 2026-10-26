# Feasibility: generating `activities.md` argument tables from library XAML

**Asked for: a feasibility report. Nothing implemented.**

Could the `finnova-library` / `avaloq-library` `references/activities.md` argument tables be
generated from the library projects' `x:Members` instead of hand-maintained?

**Verdict: feasible for the mechanical half, and worth doing — but as a drift *check* first,
not as generation.** The part that makes those files valuable cannot be generated.

## What was measured

Extracted `x:Members` from every workflow `.xaml` in both library projects (Finnova
`projectVersion 2026.1.0`, Avaloq `2025.9.1`) on 2026-10-26:

| | Finnova | Avaloq |
|---|---|---|
| Workflow `.xaml` files | 82 | 73 |
| …declaring `x:Members` | **79** | **67** |
| Distinct argument types | 8 | 11 |
| Workflows carrying a top-level annotation | **2** | **1** |
| Arguments carrying their own annotation | **2** | **2** |

Type distribution is narrow and dull, which is good news for a generator — Finnova:
`x:String` 447, `x:Boolean` 23, `x:Int32` 21, `sd:DataTable` 5, plus a handful of
`IEnumerable(UiElement)` and `String[]`. Avaloq adds `ss:SecureString` (3).

## What is generatable — reliably

Per activity: the **name, type and direction** of every argument, and the file it lives in.
That is a complete, exact, machine-checkable table, and it is exactly where the errors found in
the last review were:

- `ConfitmMessage` attributed to the wrong library
- `Idx` vs `idx` casing, which splits by family (`Table/*` + `Tree/*` lowercase, top-level
  capital)
- `Table/Get Cell Attribute` documented with an `ExtractDataTable` argument it does not have
- `ExtractedDataTable` vs `ExtractDataTable` on one activity
- the `ScrollBar*` shorthand never expanded

**Every one of those is a name/type/direction fact.** A generator would have caught all five,
and no human reading would reliably catch any of them.

## What is not generatable

The annotation counts above are the finding: **3 workflows out of 155 carry any prose at all.**
So none of this exists in the XAML to extract:

- what an argument is *for* — `Attribute` selects which attribute to read; `ScrollBarMax` is a
  bound, not a count
- **which activity to prefer** — `Table/Click Cell By Value` over `Table/Click Cell` with a row
  index, because an index breaks on the first user sort
- the **consequence** of a gotcha — that `ConfirmMessage` ignored means the workflow continues
  against a modal window and fails later at an unrelated selector
- that `SearchInColumn` is **0-based** while its neighbours are Strings
- `TabName` vs `PageTabName` differing between top-level and table activities

That is the reason anyone opens `activities.md`, and it is hand-written knowledge derived from
the sample projects, not from the library.

## Recommendation

**Three steps, in this order. Step 1 is most of the value for least of the risk.**

1. **A drift check, not a generator.** A script that extracts `x:Members` and *compares* it
   against the names already in `activities.md`, failing on a documented argument that does not
   exist and on a real argument never mentioned. Add it to `.github/workflows/checks.yml`,
   skipped when the library sources are absent — they live outside this repo and are not on CI.
   This is roughly the script already written ad hoc for the last review; promoting it to a
   committed, CI-run check is a contained change.
2. **Generate the signature tables into a separate file** per library — e.g.
   `references/activities-signatures.md`, marked generated like `config-contents.md` — and have
   the hand-written `activities.md` link to it. Keeps the prose unpolluted and gives one
   regeneration command on a library bump.
3. **Only then** consider merging them, if the split proves annoying in practice.

### Costs and risks, stated

- **A second generated artefact to keep honest.** `templates/tools/build-template-workbooks.ps1`
  already taught this lesson: the CI check must compare the *rendering*, not bytes, or platform
  line endings make it fail on a Linux runner for no reason.
- **The library sources are not in this repo and never will be** (client and employer material).
  So the generator cannot run in CI against real inputs — only the drift check can, and only
  where someone has the siblings checked out. CI must skip-not-fail when they are absent.
- **Encoding.** Both libraries have non-ASCII filenames (`Auftrag Öffnen.xaml`,
  `Börsenabrechnungen`). The last review lost findings to exactly this when `grep` treated
  non-ASCII output as binary. Any script must read and write UTF-8 explicitly and be tested on
  those filenames.
- **It does not remove the need to re-verify on a library bump** — it makes the mechanical part
  free and leaves the prose, which is where judgement is needed, to a person.

## Not recommended

**Generating `activities.md` wholesale.** It would produce a correct, complete, unreadable file
and would delete the gotchas, the preference rules and the consequences — the only content that
stops someone copying `ConfitmMessage` into a Finnova workflow. The errors found were in the
tables; the value is in the prose. Automate the tables.
