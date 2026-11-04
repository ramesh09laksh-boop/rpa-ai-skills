# `project-folder-not-renamed`

`fetch-template` lands each template in a folder named after the **template**, because that is
the only name it has. Renaming it to the agreed project name is step 1 of the instantiation
checklist and it is the step that gets skipped, because nothing downstream needs it: the project
compiles, packs and runs with `REFramework-Dispatcher-Base` on the folder.

| | |
|---|---|
| `bad` | the project folder is still `REFramework-Dispatcher-Base` |
| `good` | the folder, `project.json → name` and `project.uiproj → Name` all read `TKB-UC11.Kreditverletzung` |

The folder name is set by `fixture.json → projects`, which is what names the directory the
overlay is materialised into — the rule reads the folder, so the folder *is* the fixture here.

`good` carries a `project.json` and `project.uiproj` as well, so that a correctly instantiated
project is the exemplar: renaming the folder alone would leave `folder-name-mismatch` firing,
and the two rules are meant to be answered by one value in three places.
