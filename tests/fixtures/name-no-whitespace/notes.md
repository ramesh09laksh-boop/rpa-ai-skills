# `name-no-whitespace`

`project.json → name` propagates verbatim into the published package id and the Orchestrator
process name, so whitespace in it breaks publishing. The same rule also reports a `project.json`
/ `project.uiproj` / folder-name disagreement, because a half-renamed project publishes under
the wrong package name.

| | |
|---|---|
| `bad` | name `Proj With Spaces`, which is also out of step with the folder |
| `good` | name `Proj` in both files, matching the folder |