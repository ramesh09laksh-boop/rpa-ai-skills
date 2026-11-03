# `assets-parity`

Fires when the `Assets` rows differ between `Config_TST` and `Config_PRD`. Split out from
`config-parity` because Assets is the one sheet where a project can legitimately sit
asymmetric for a while — so it needs its own suppression.

| | |
|---|---|
| `bad` | TST has an Assets row PRD does not |
| `good` | both workbooks carry the same Assets keys |