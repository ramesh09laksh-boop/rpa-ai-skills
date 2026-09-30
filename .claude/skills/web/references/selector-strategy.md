# Web selector strategy

Derived from every `<html>` / `<webctrl>` selector in the three reference projects (96
distinct selectors), plus what `uip rpa uia` reports for the same pages.

## Selector anatomy

```
<html app='chrome.exe' [htmlwindowname='…'] title='<page title>' />
  <webctrl [id='…'] [name='…'] [tag='…'] [type='…'] [aaname='…']
           [parentid='…'] [parentclass='…'] [parentname='…']
           [tableRow='…'] [tableCol='…'] [rowName='…'] [colName='…'] [idx='…'] />
```

## Attribute preference

Ranked by how well each survives an application release. Use the highest that is unique.

| Rank | Attribute | Example | Notes |
|---|---|---|---|
| 1 | `id` | `id='header.menu.actions.creditcard.block.bank'` | Semantic and stable. CardOne is rich in these. |
| 2 | `name` | `name='j_username'`, `name='email'` | Form field names — stable, framework-generated. |
| 3 | `type` (with `tag`) | `tag='INPUT' type='password'` | Good disambiguator, rarely unique alone. |
| 4 | `parentid` / `parentclass` | `parentid='grid1' parentclass='objbox'` | Anchors a region; combine with `tag`. |
| 5 | `rowName` + `tableCol` | `rowName='ISIN ' tableCol='2'` | For data tables — survives row reordering. |
| 6 | `aaname` | `aaname=' Login '` | Visible text. Breaks with language and copy changes. |
| 7 | `idx` | `idx='3'` | Positional. Last resort; only inside a `parentid` scope. |

### Never use

- Absolute `idx` at page level without a parent scope.
- Full CSS-path-style chains of `<webctrl>` with no identifying attributes.
- `aaname` on anything whose text is localised, unless the app is single-language.

## Whitespace is significant

Three live examples where a space is part of the selector:

```
<webctrl tag='BUTTON' aaname=' Login ' />
<webctrl tag='BUTTON' aaname=' Next ' />
<webctrl tag='TD' rowName='ISIN ' tableCol='2' />
```

Trailing spaces come from the page markup (`<td>ISIN </td>`). `selector-intelligence
get-selector-attributes` prints values double-quoted so the padding is visible — copy what is
between the quotes verbatim, and do not trim.

**Better still, wildcard it.** Measured on SIX iD 2026-09-30, the real padding is *two*
trailing spaces (`rowName="Versammlungsdatum  "`) where this estate's reference docs say one.
`rowName='Versammlungsdatum*'` removes the whole class of error.

Where the text is unreliable, wildcard instead: `aaname='*Login anyway*'`.

## Scoping with `parentid` / `parentclass`

The most durable pattern in the estate: anchor on a stable container, then locate within it.

```
<webctrl parentid='pageMessages' tag='SPAN' />                          ' CardOne messages
<webctrl parentid='linkContainer' tag='I' idx='{0}' />                   ' CardOne card list
<webctrl parentid='grid1' tag='TABLE' parentclass='objbox' />            ' Avaloq report grid
<webctrl aaname='Fonds Zusammensetzung' parentid='vdb_page' parentname='Top' />   ' SIX iD
```

`idx` is acceptable *inside* such a scope — `parentid='linkContainer' tag='I' idx='3'` is
the third icon in a known container, not the third icon on the page.

## Distinguishing windows and frames

Same application, different pages, need different `<html>` roots:

```
<html app='chrome.exe' title='SIX Login' />                              ' login
<html app='chrome.exe' title='SIX iD HTML' />                            ' search
<html app='chrome.exe' htmlwindowname='vdb' title='SIX iD HTML VDB' />   ' detail frame
<html app='chrome.exe' title='SIX - Server Error' />                     ' error page
```

`htmlwindowname` selects a named frame — use it rather than hoping `title` alone resolves.

Do **not** use `<html app='chrome.exe' title='*' />` in production logic; it matches any
Chrome window. The sample project uses it only to detect "is a browser open at all" before
closing one.

## Building a selector — never by hand

Do not translate a snapshot into a selector yourself. The selector is produced by
`target-anchorable resolve-defaults`, hardened with `selector-intelligence get-ancestors` /
`get-selector-attributes`, and accepted only once `selector-intelligence evaluate` reports
your target as the sole matching candidate.

The page tree (`tree.yml` from `uip rpa uia snapshot capture <bN>`) is for **choosing which
element** to configure — its `eN` ref — not for reading attributes into a selector. Attributes
lifted from a tree, a screenshot or `interact get-all` are exactly the guesses this file
exists to prevent.

What the tree is good for:

| `tree.yml` line | What it tells you |
|---|---|
| `InputBox "Suchbegriff" [ref=e507]` | the ref to configure, and that it is a text input |
| `DropDown "Suchtyp" [ref=e5837]: ISIN - GLOBAL` | a real `<select>` — `SelectItem` is viable |
| `[invisible]` on a `DropDown` | a hidden select behind a custom widget — see below |
| `Link "15.06.2026"` + `/url: …EventID=6714613` | the discriminator lives in the href |

**Two dropdowns that look identical can behave differently.** On SIX iD, `Suchtyp` is a plain
`<select>` and `SelectItem` sticks; `Suche in` is a hidden `<select>` behind a custom widget
that silently reverted a `SelectItem` back to its default while the CLI reported success. Query
`interact get <eN> items` and, when in doubt, drive it click-to-open then click-the-option.

## Verification checklist

Before committing a selector:

- [ ] Produced by `resolve-defaults` and accepted by `selector-intelligence evaluate` — never hand-written
- [ ] `evaluate` listed your target and nothing else (unless it is a deliberate set)
- [ ] Uses the highest-ranked attribute available
- [ ] Unique — no second match on the page
- [ ] Any leading/trailing whitespace preserved verbatim
- [ ] Scoped by `parentid`/`parentclass` if it uses `idx`
- [ ] The `<html>` root names the right page/frame, not `title='*'`
- [ ] The flow's error/interstitial pages are handled too
- [ ] Recorded in `verified-flows.md` with the date and how it was checked
