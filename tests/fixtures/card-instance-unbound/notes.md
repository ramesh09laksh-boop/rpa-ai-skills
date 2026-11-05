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
| `bad` | a downstream card — `OpenMode="Never"` — with neither `InUiElement` nor `OutUiElement` |
| `good` | the same card with `InUiElement="[in_AcmeElement]"` and the matching `InArgument(ui:UiElement)` |
| `good-opener` | the **carve-out**: the card that *opens* the application has no `InUiElement` and must not be reported. It is identifiable because it declares `OutUiElement` to hand the instance on |

`good-opener` is a separate case rather than a second card in `good`, because the carve-out is the
rule's whole precision. Folded into one fixture, the assertion would be satisfied by the
`InUiElement` branch alone and a broken carve-out would report every opening card in the estate
with CI still green.

## Property names

`OutUiElement` is declared on `NApplicationCard`; **`InUiElement` is inherited** from
`RecoverableNativeActivity`. Both are settable on the card. Verified 2026-11-05 by reading the
assembly metadata of `UiPath.UIAutomation.Activities.Runtime 26.10.4`
(`lib/net6.0-windows7.0/UiPath.UIAutomationNext.Activities.dll`) — the type's declared properties
and its base chain. The fixtures use the attribute form; the rule also accepts the
property-element form (`<uix:NApplicationCard.InUiElement>`) that Studio emits for a non-trivial
expression.
