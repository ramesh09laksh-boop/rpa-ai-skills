# `folder-name-mismatch`

The folder and `project.json → name` are two halves of one identity: the folder is the
repository name and the working path every script, CI job and relative reference quotes, while
the name is the published package id and the Orchestrator process name. A project renamed in one
place and not the other is worked on under one name and published under another.

Split out of `name-no-whitespace`, which used to report it. The two failures have different
causes and different fixes, and a stale folder name reported under a rule about *whitespace*
reads as cosmetic — which is how it survives a stage gate.

| | |
|---|---|
| `bad` | `project.json` / `project.uiproj` say `TKB-UC11.Kreditverletzung`; the folder is still `Proj` |
| `good` | base, unchanged: name `Proj`, folder `Proj` |

`good` overlays an identical `project.uiproj` only because a case directory needs at least one
committed file; the assertion is that the base already satisfies the rule.
