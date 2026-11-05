# `card-instance-unbound`

An Application Card in an `<App>_System/` workflow that identifies the **application** but not the
**instance**. It attaches by selector, so it takes whichever matching window it finds first — and
can drive or close one the operator already had open.

Silent at every level. On the Google run the Performer opened its own browser window, drove the
operator's, and closed a window it never opened, with `validate-project`, `uip rpa validate`,
`build`, `pack`, an empty Studio Error List and a `Successful` L4-local run of 1 transaction of 1
all green. Nothing in the toolchain looks at *which* window.

Full contract: the `standards` skill, `references/wiring-the-framework.md`, *Carrying the
application instance between workflows*.

| | |
|---|---|
| `bad` | a downstream card — `OpenMode="Never"` — with **no** `InUiElement` / `OutUiElement` attribute at all |
| `bad-explicit-null` | the same card as Studio actually serialises it: `InUiElement="{x:Null}" OutUiElement="{x:Null}"`, among six other explicit nulls |
| `bad-property-element-null` | the **property-element** form carrying nothing: `<uix:NApplicationCard.InUiElement><InArgument …><x:Null /></InArgument>` and an `OutUiElement` holding a bare `<x:Null />` |
| `bad-second-card-unbound` | **two cards in one file** — the first correctly bound through the property-element form, the second bound to nothing. The second must still be reported |
| `good` | the `bad` card with `InUiElement="[in_AcmeElement]"` and the matching `InArgument(ui:UiElement)` |
| `good-opener` | the **carve-out**: the card that *opens* the application has no `InUiElement` and must not be reported. It is identifiable because it declares `OutUiElement` to hand the instance on |
| `good-property-element` | `InUiElement` bound as a **property element**, which is what Studio emits for a non-trivial expression. Must be silent |

`good-opener` is a separate case rather than a second card in `good`, because the carve-out is the
rule's whole precision. Folded into one fixture, the assertion would be satisfied by the
`InUiElement` branch alone and a broken carve-out would report every opening card in the estate
with CI still green.

`bad-explicit-null` is a separate **shape**, not a cosmetic variant, and it is the one that
matters on real Studio output. **Studio serialises an unset argument explicitly**, so a card it
has round-tripped carries `InUiElement="{x:Null}"` and `OutUiElement="{x:Null}"` even though
nothing is bound. A rule keyed on the attribute's *presence* therefore carves out exactly the
cards that most need reporting.

That was the first draft's behaviour, and the fixtures did not catch it — all three used the
hand-written form. It was caught by running the rule against the **real** project it came from:
presence-only matching reported 5 of the 7 unbound cards in the pre-fix package and silently
missed `Google-Browser_Kill.xaml` and `Google-Results_Verify.xaml` — the latter being the file
that threw in both failed runs. The rule now matches the *value*. Calibration, repeatable:

```powershell
# all 7 cards reported on the pre-fix package, 0 on the fixed one
pwsh -NoProfile -File validate-project.ps1 <extracted-package>/content
```

**`presence` was wrong twice, in two different places.** The attribute fix above left the same
hole one level down, in the property-element branch, plus a second one:

| Hole | Why it mattered |
|---|---|
| `<uix:NApplicationCard.InUiElement>` holding only `<x:Null />` | presence of the *element* carved the card out, exactly as presence of the attribute had |
| The property-element search was **file-scoped** | one correctly bound card carved out **every** card in the same file |

Both are now fixtured (`bad-property-element-null`, `bad-second-card-unbound`) and both were
confirmed to **fail against the previous rule** before the fix went in — the suite's own
non-vacuousness check, applied to the cases rather than to the harness. Each card now gets a
disjoint region (its own tag up to the next card's tag) and the element's *content* is tested,
not its presence: strip `x:Null`, strip the tags, and see whether an expression is left.

Known limitation, not fixtured: a card **nested inside another card's `Body`**. The outer card's
region ends where the inner one begins, so an outer binding written *after* the inner card would
not be seen. One card per leaf workflow is the estate's shape and nesting cards is its own
anti-pattern, so this is recorded rather than engineered around.

## Property names

`OutUiElement` is declared on `NApplicationCard`; **`InUiElement` is inherited** from
`RecoverableNativeActivity`. Both are settable on the card. Verified 2026-11-05 by reading the
assembly metadata of `UiPath.UIAutomation.Activities.Runtime 26.10.4`
(`lib/net6.0-windows7.0/UiPath.UIAutomationNext.Activities.dll`) — the type's declared properties
and its base chain. The fixtures use the attribute form; the rule also accepts the
property-element form (`<uix:NApplicationCard.InUiElement>`) that Studio emits for a non-trivial
expression.
