# `leaf-body-stub`

A leaf workflow whose body does nothing. Both fixtures declare the IDENTICAL contract —
`in_Config`, a business key, an `out_` outcome — so no contract rule can tell them apart. Only
this rule can, and that is the point: the four contract rules check the signature, this one
checks the body.

| | |
|---|---|
| `bad` | body is one `ui:LogMessage` |
| `good` | the same plus a real `uix:NClick` |

Deliberately narrow: one real activity is enough to silence it. Partial work is not its
business.