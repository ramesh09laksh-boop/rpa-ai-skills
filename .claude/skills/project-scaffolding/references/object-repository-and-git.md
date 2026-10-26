# `.objects/` is git-ignored — and it probably should not be

**Status: open decision.** The evidence below is strong but one step short of conclusive, and the
change it implies has not been made. Do not "fix" the `.gitignore` files on the strength of this
page; finish the verification first (bottom of this file) and get the call made.

## The claim

All four `.gitignore` files in this repo — the root one and all three in `templates/*/` — list
`.objects/` under this heading:

```
# UiPath Studio local state — machine-specific, never shared
.local/
.settings/
.objects/
.project/
.entities/
.tmh/
```

`.objects/` is the folder Studio uses for the **Object Repository**. If captured applications,
screens and element descriptors are stored there, then a project started from these templates
commits its workflows but **not its captured selectors**. A fresh clone, a teammate, or a new
agent session would open activities whose element references resolve to nothing — and the
failure would look like a selector problem rather than a source-control problem.

## What has been verified

| # | Check | Result |
|---|---|---|
| 1 | `.objects/` appears under "machine-specific, never shared" in all four `.gitignore` files | **Confirmed** |
| 2 | What an empty project's `.objects/` contains | `.metadata` + `.type` only |
| 3 | What `.objects/.metadata` holds | `{"Type":"Library","Id":"BThTHHGJhkW0u3ZKT2wLCQ","Created":…,"CreatedBy":["UiPath.Platform, Version=23.10.0.0"]}` |
| 4 | Does the CLI treat it as project content? | **Yes.** `uip rpa get-object-repository` is documented as *"Return the **project's own** Object Repository as a JSON tree of applications, screens and elements. Excludes entries inherited from referenced libraries."* |
| 5 | `get-object-repository` against the empty reference project | `"Data": []` — consistent with the empty root above |
| 6 | Any populated `.objects/` anywhere in the local estate? | **No.** Neither library project, none of the three sample processes (which have no `.objects/` at all), and the reference projects have only the two marker files |

**The "machine-specific" premise looks false for this folder.** `.metadata` is a content root
with a *stable identity* (`Id`, `Created`, `CreatedBy`) — the root node of a tree, not a cache.
`.local/` and `.settings/` genuinely are machine-specific; `.objects/` is in the wrong list.

Finding 6 also explains why nobody has hit this: **no project in this estate has ever populated
an Object Repository.** The capture workflow in the `web` skill is new. The first project to use
it is the first project that can lose work this way.

## What is still missing

One step, and it needs a live capture session:

```bash
# in a project after capturing at least one element
git check-ignore -v .objects/<some captured file>   # does the ignore rule actually match it?
find .objects -type f                               # what did capture write, and where?
```

Then clone that project to a scratch folder, open it in Studio, and check whether the captured
targets still resolve. If they do not, the hypothesis is confirmed.

Why it cannot be settled here: `uip rpa uia` lists **zero subcommands** unless a project with
matching `UiPath.UIAutomation.Activities` / `UiPath.UIAutomation.CLI` versions is open (that is
the documented version-mismatch symptom — see the `web` skill), and no project in this checkout
has a populated repository to inspect.

## If confirmed, the change is

1. Remove `.objects/` from the root `.gitignore` and all three `templates/*/.gitignore`. Keep
   `.local/` and `.settings/` — those are genuinely local.
2. Add a comment saying `.objects/` is **source**, so nobody re-adds it as tidy-up.
3. Re-check `.entities/`, `.project/` and `.templates/` the same way, rather than assuming the
   same answer. `.project/design.json` in particular carries test-case ids, which look like
   content too.
4. Add a `validate-project` rule: a XAML references the Object Repository while `.objects/` is
   empty or ignored → **error**. That is a silent failure in the same family as every other rule
   in that script.
5. Commit the first real project's `.objects/`.

## The counter-argument, stated fairly

An Object Repository descriptor captured on one machine against one app version is not
guaranteed to be portable, and committing it could mean a stale descriptor is shared instead of
recaptured. That is an argument for *reviewing* descriptors like any other source, not for
leaving them untracked — an uncommitted selector is not recaptured either, it is just missing.
But it is the reason this is a decision and not a bug fix.
