# `config-parity`

`Config_TST` and `Config_PRD` must carry the same key set from the first commit, or the PRD run
fails on a key only TST has. Values differ per environment; keys never do.

| | |
|---|---|
| `bad` | TST has a `Settings` key PRD does not |
| `good` | identical key sets |

`Assets` differences are deliberately NOT this rule — see `assets-parity`.