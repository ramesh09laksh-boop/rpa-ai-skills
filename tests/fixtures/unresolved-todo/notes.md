# `unresolved-todo`

A workflow carrying `TODO_SELECTOR` / `APPROX_SELECTOR` with no companion `.selectors-todo.md`.
The marker on its own records that something is unfinished but not WHAT was tried or what it
matched instead, so the next person starts from zero.

| | |
|---|---|
| `bad` | `TODO_SELECTOR` with no companion file |
| `good` | the same marker, with `Acme-Edit.selectors-todo.md` beside it |

Note what `good` is NOT: it is not "the TODO was resolved". The rule is about the companion
file, so the fixture keeps the marker and adds the document.