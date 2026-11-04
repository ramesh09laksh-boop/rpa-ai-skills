# `unresolved-mock`

A `[MOCK]` stand-in left in the project. Legitimate mid-build — a mocked run reaches L3 at most
— but an unreplaced one blocks review, so it is a warning rather than an error.

**Two trigger shapes, one case each** — a single fixture carrying both would stay green when
one of them broke:

| | |
|---|---|
| `bad` | the `[MOCK]` text marker in a workflow |
| `bad-declared-mock` | `Mock_System/Mock-Acme_Login.xaml` with **no `[MOCK]` text at all** — declared by its folder and file name |
| `good` | the real call |

### Why the second shape exists

The marker alone missed an entire mock layer. Measured on UC252, a real Windows project: **22**
workflows under `Mock_System/`, every one named `Mock-*.xaml`, and **not one** carrying the
`[MOCK]` string. This rule saw none of them, so `mocking.md`'s *"a mocked run reaches L3 at
most"* cap could not be applied to anything — the project had a mock layer the checker was blind
to. After adding the declared shape: **26** findings where there were 0.

A folder called `Mock_System/` holding `Mock-Finnova_Login.xaml` *is* a declaration; it simply
lives in the path rather than in the text. The finding asks for the marker to be added as well,
so a `grep` finds it too.