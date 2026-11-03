# `negative-active-filter`

Filtering a business table with `Active <> "FALSE"` lets explanatory and footnote rows — whose
`Active` cell is blank — through the filter. It let two footnote rows into a real bank list.

| | |
|---|---|
| `bad` | `Active <> "FALSE"` |
| `good` | `Active = "TRUE"` |