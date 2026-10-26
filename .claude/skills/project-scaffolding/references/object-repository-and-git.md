# `.objects/` was git-ignored, and that lost captured selectors

**Status: CONFIRMED and fixed.** `.objects/` has been removed from the root `.gitignore` and all
three `templates/*/.gitignore`, and `validate-project` now reports
`object-repository-not-shared` as an **error**. This page records the evidence, because the
ignore line looked entirely reasonable and will look reasonable again to the next person tidying
up a `.gitignore`.

## What was wrong

All four `.gitignore` files listed `.objects/` under this heading:

```
# UiPath Studio local state — machine-specific, never shared
.local/
.settings/
.objects/      <- wrong list
.project/
.entities/
.tmh/
```

`.objects/` is the folder Studio uses for the **Object Repository**: captured applications,
screens and element descriptors. So a project started from these templates committed its
workflows but **not its captured selectors**. A fresh clone, a teammate, or a new agent session
opens activities whose element references resolve to nothing — and the failure looks like a
selector problem rather than a source-control problem.

## The confirming case

A real project that had completed selector capture:

```
$ find .objects -type f | wc -l
134
$ git ls-files .objects | wc -l
0
$ git check-ignore -v ".objects/…/ObjectRepositoryTargetData/.content"
.gitignore:6:.objects/   .objects/…/ObjectRepositoryTargetData/.content
```

134 files, **zero tracked**, every one matched by the `.objects/` line inherited from this
repo's own templates. The tree held `ObjectRepositoryScreenData` and
`ObjectRepositoryTargetData` nodes, and each `.content` file held the real captured selector:

```xml
<ObjectRepositoryTargetData ContentHash="…">
  <TargetAnchorable ElementType="Button"
    FullSelectorArgument="&lt;webctrl aria-label='To Do' tag='SECTION' /&gt;…" />
```

That is the selector itself, not a pointer to it. Days of capture work, present on one laptop
and in no commit.

## What has been verified

| # | Check | Result |
|---|---|---|
| 1 | `.objects/` appears under "machine-specific, never shared" in all four `.gitignore` files | **Confirmed** |
| 2 | What an empty project's `.objects/` contains | `.metadata` + `.type` only |
| 3 | What `.objects/.metadata` holds | `{"Type":"Library","Id":"BThTHHGJhkW0u3ZKT2wLCQ","Created":…,"CreatedBy":["UiPath.Platform, Version=23.10.0.0"]}` |
| 4 | Does the CLI treat it as project content? | **Yes.** `uip rpa get-object-repository` is documented as *"Return the **project's own** Object Repository as a JSON tree of applications, screens and elements. Excludes entries inherited from referenced libraries."* |
| 5 | `get-object-repository` against the empty reference project | `"Data": []` — consistent with the empty root above |
| 6 | Why had nobody hit it? | **No older project uses the Object Repository at all.** Neither library project nor any of the three sample processes has a `.objects/` folder; the reference projects have only the two marker files. The capture workflow is new, so the first project to use it is the first that could lose work this way |

**The "machine-specific" premise was simply false for this folder.** `.metadata` is a content
root with a *stable identity* (`Id`, `Created`, `CreatedBy`) — the root node of a tree, not a
cache. `.local/` (264 files) and `.settings/` (18) genuinely are machine-specific; `.objects/`
was in the wrong list.

## What was changed

1. `.objects/` removed from the root `.gitignore` and all three `templates/*/.gitignore`, each
   with a comment saying it is **source** so it is not re-added as tidy-up. `.local/` and
   `.settings/` stay ignored.
2. New `validate-project` rule **`object-repository-not-shared`** (error), which fires when a
   workflow references the Object Repository and either `.objects/` holds no descriptors, or it
   holds descriptors that `git check-ignore` says are ignored. Verified: it reports the error on
   the confirming project above (86 descriptors once the `.metadata`/`.type` markers are
   excluded) and stays silent on the templates and the three reference projects.

## Still open

- **The confirming project's `.objects/` is still uncommitted.** It lives in a different repo,
  so committing it was not done here. Whoever owns that project should commit it now that the
  ignore rule is gone — until they do, the capture work exists on one machine only.
- **`.entities/`, `.project/` and `.templates/` have not been re-checked properly.** In the
  confirming project `.entities/` and `.templates/` were empty and `.project/` held a single
  untracked `design.json` — not enough to judge. `.project/design.json` carries test-case ids,
  which look like content; treat it as an open question rather than settled by analogy.
- **`.screenshots/` was tracked (24 files) in that project.** Not part of this change, but
  screenshots of a logged-in session are a data-protection concern in this estate — see the
  `security` skill, `references/prohibited-practices.md`.

## The counter-argument, stated fairly

An Object Repository descriptor captured on one machine against one app version is not
guaranteed to be portable, and committing it could mean a stale descriptor is shared instead of
recaptured. That is an argument for *reviewing* descriptors like any other source, not for
leaving them untracked — an uncommitted selector is not recaptured either, it is just missing.
But it is the reason this is a decision and not a bug fix.
