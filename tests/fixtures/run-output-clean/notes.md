# `run-output-clean`

Run output committed to the repository. `Exceptions_Screenshots/` is the serious one — those are
screenshots of logged-in banking sessions, so it is reported as an ERROR while `Data/Output` and
`Data/Temp` are warnings.

| | |
|---|---|
| `bad` | a stray file in `Exceptions_Screenshots/`, **created at test time** via `fixture.json` → `touch` |
| `good` | `.gitkeep` only |

The stray file cannot be committed, and that is correct rather than inconvenient: this repo's
`.gitignore` has `**/Exceptions_Screenshots/*` as a data-protection backstop, because those
screenshots are of logged-in banking sessions. Weakening the rule so a fixture could live there
would trade a real protection for a test convenience, so the runner creates the file instead.
Found by the suite's own check that every fixture file is trackable by git.