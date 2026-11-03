# `logic-workflow-no-arguments`

A `Logic/` workflow declaring no arguments cannot be passed anything or return anything, so
callers reimplement the rule inline and the two drift apart. The inline-`If`-in-`Process.xaml`
smell is downstream of exactly this.

| | |
|---|---|
| `bad` | no `x:Members` at all |
| `good` | a business key in, an outcome out |