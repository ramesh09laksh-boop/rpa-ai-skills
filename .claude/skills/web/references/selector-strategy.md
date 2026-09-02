# Web selector strategy

Derived from every `<html>` / `<webctrl>` selector in the three reference projects (96
distinct selectors), plus the shape Playwright MCP accessibility snapshots return.

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

Trailing spaces come from the page markup (`<td>ISIN </td>`). When you read a name off a
Playwright snapshot, copy it verbatim — do not trim.

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

## Building a selector from a Playwright snapshot

Playwright's accessibility snapshot gives roles and accessible names. Map them:

| Snapshot | UiPath |
|---|---|
| `button "Login"` | `<webctrl tag='BUTTON' aaname='Login' />` |
| `textbox "Email"` with `name=email` | `<webctrl tag='INPUT' name='email' />` |
| element with `id=j_password` | `<webctrl tag='INPUT' type='password' id='j_password' />` |
| `link "Back to home"` | `<webctrl tag='A' aaname='Back to home' />` |
| `cell` in row "ISIN", column 2 | `<webctrl tag='TD' rowName='ISIN ' tableCol='2' />` |

Snapshots normalise whitespace in accessible names. **Confirm the raw attribute in the DOM**
(via the snapshot's element handle or `page.getAttribute`) before relying on an exact
`aaname` — this is exactly where the ` Login ` spaces hide.

Prefer whatever `id` or `name` the snapshot exposes over the accessible name.

## Parameterising selectors

Where a selector varies, the estate uses `String.Format`:

```vb
String.Format("<webctrl parentid='linkContainer' tag='I' idx='{0}' />", IdxValue)
String.Format("<webctrl aaname=' *{0}*' tag='LABEL' />", User)
```

Keep the variable part minimal and always inside a scoped selector.

## Verification checklist

Before committing a selector:

- [ ] Confirmed against the live page (Playwright snapshot or UiExplorer), not guessed
- [ ] Uses the highest-ranked attribute available
- [ ] Unique — no second match on the page
- [ ] Any leading/trailing whitespace preserved verbatim
- [ ] Scoped by `parentid`/`parentclass` if it uses `idx`
- [ ] The `<html>` root names the right page/frame, not `title='*'`
- [ ] The flow's error/interstitial pages are handled too
- [ ] Recorded in `verified-flows.md` with the date and how it was checked
