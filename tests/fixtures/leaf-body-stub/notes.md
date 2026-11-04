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

## `good-declared-mock` — the carve-out, which came from calibration

| | |
|---|---|
| `good-declared-mock` | `Mock_System/Mock-Acme_Login.xaml`, body a `Comment` and a `LogMessage`. The rule must be **silent** |

A workflow under `Mock*/` or named `Mock-*` / `Mock_*` is a **declared** mock: doing nothing is
its entire job, and the declaration is in the path rather than in the text.

This is not a hypothetical. Run against UC252 — a real Windows project — the rule fired **7**
times: 6 under `Mock_System/`, and **1** on `Bottomline_System/Bottomline_Logout.xaml`, a real
leaf whose body is a `Comment` and a `LogMessage`. Only the last is this rule's business. The
other six are six findings telling a reader that a mock is a mock, which is how a rule gets
blanket-suppressed — and that suppression would have hidden the one true positive sitting next
to them. After the carve-out: **1 finding, the true one.**

The mock layer is `unresolved-mock`'s to report, and that rule now recognises the same declared
shape — see `../unresolved-mock/notes.md`.