<h1 align="center">fluent_icu</h1>

<p align="center">
  <a href="https://pub.dev/packages/fluent_icu"><img src="https://img.shields.io/pub/v/fluent_icu.svg" alt="pub package"></a>
  <a href="https://pub.dev/packages/fluent_icu/score"><img src="https://img.shields.io/pub/likes/fluent_icu" alt="likes"></a>
  <a href="https://pub.dev/packages/fluent_icu/score"><img src="https://img.shields.io/pub/points/fluent_icu" alt="pub points"></a>
  <a href="https://github.com/whuppi/fluent_icu"><img src="https://img.shields.io/github/stars/whuppi/fluent_bundle?style=flat&logo=github" alt="GitHub stars"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="license: MIT"></a>
</p>

The full-fidelity backend for [`fluent_bundle`](https://pub.dev/packages/fluent_bundle): the complete ECMA-402 `NUMBER` / `DATETIME` option surface — measurement units, 17 calendar systems, IANA time zones, numbering systems, compact notation, sign display — plus cardinal *and* ordinal plural rules for every CLDR locale. The engine is Unicode's **ICU4X**, via [`icu_kit`](https://pub.dev/packages/icu_kit): the same engine, the same output, on every platform.

> **This is a backend — an add-on, not a starting point.** Flutter apps start at [`fluent_flutter`](https://pub.dev/packages/fluent_flutter); pure Dart starts at [`fluent_bundle`](https://pub.dev/packages/fluent_bundle). Between the two backends, [`fluent_intl`](https://pub.dev/packages/fluent_intl) is the lighter default — pure Dart, zero setup, the common formatting surface; this one is for when the options intl has no knob for start mattering, or when byte-identical output across native, web, and server is a requirement. Same FTL, same call sites — the swap is one constructor.

> like it? a [⭐ star](https://github.com/whuppi/fluent_icu) or [👍 like](https://pub.dev/packages/fluent_icu) is the entire marketing budget. [Bugs & features →](https://github.com/whuppi/fluent_icu/issues)

---

<details>
<summary><b>👀 Peek inside</b></summary>

- [Install](#install)
- [Quick start](#quick-start)
- [Usage](#usage)
  - [Numbers](#numbers)
  - [Currency and units](#currency-and-units)
  - [Dates, calendars, time zones](#dates-calendars-time-zones)
  - [Plurals — every locale, both kinds](#plurals--every-locale-both-kinds)
- [Error handling — the degrade contract](#error-handling--the-degrade-contract)
- [Platform support](#platform-support)
- [Not in the box](#not-in-the-box)
- [Docs](#docs)
- [License](#license)

</details>

---

## Install

```yaml
dependencies:
  fluent_bundle:
  fluent_icu:
```

The engine arrives through `icu_kit`. On native platforms its build hook handles everything on first build; on web there's a one-time setup command, and a size dial when the default engine is bigger than you want — [icu_kit's Install section](https://pub.dev/packages/icu_kit#install) is the authority on both.

---

## Quick start

One async init boots the engine; after that, backends are plain constructor arguments:

```dart
import 'package:fluent_icu/fluent_icu.dart';   // re-exports fluent_bundle

Future<void> main() async {
  final backend = await IcuBackend.init();     // once, at startup

  final bundle = FluentBundle('en', backend: backend)..addResource(r'''
speed = { NUMBER($v, style: "unit", unit: "kilometer-per-hour") }
launched = { DATETIME($at, dateStyle: "full") }
''');

  print(bundle.formatMessage('speed', args: {'v': 120}));   // "120 km/h"
  print(bundle.formatMessage('launched', args: {'at': DateTime.utc(2026, 1, 15)}));
  // "Thursday, January 15, 2026"
}
```

That's the whole integration. Everything else — messages, selectors, markup, chains, errors — is `fluent_bundle`'s surface, unchanged; this package only decides how numbers, dates, and plural categories render.

---

## Usage

One `NUMBER` / `DATETIME` option family per section. Every snippet's output is pinned by the example test.

### Numbers

```dart
const ftl = r'''
plain = { NUMBER($n) }
deva = { NUMBER($n, numberingSystem: "deva") }
compact = { NUMBER($n, notation: "compact") }
signed = { NUMBER($delta, signDisplay: "exceptZero") }
pct = { NUMBER($share, style: "percent") }
''';

en.formatMessage('plain', args: {'n': 1234567.89});   // "1,234,567.89"
de.formatMessage('plain', args: {'n': 1234567.89});   // "1.234.567,89"

// Numbering systems — Devanagari digits, lakh/crore grouping:
hi.formatMessage('deva', args: {'n': 1234567.89});    // "१२,३४,५६७.८९"

en.formatMessage('compact', args: {'n': 1234000});    // "1.2M"
en.formatMessage('signed', args: {'delta': 5});       // "+5"

// ECMA-402 percent scales ×100 — pass the fraction, not the percentage:
en.formatMessage('pct', args: {'share': 0.42});       // "42%"
```

### Currency and units

```dart
const ftl = r'''
price = { NUMBER($amount, style: "currency", currency: "USD") }
yen = { NUMBER($amount, style: "currency", currency: "JPY") }
speed = { NUMBER($v, style: "unit", unit: "kilometer-per-hour") }
long = { NUMBER($v, style: "unit", unit: "meter", unitDisplay: "long") }
''';

en.formatMessage('price', args: {'amount': 1234.5});   // "$1,234.50"

// JPY has zero minor units — CLDR's fractions table, no code to write:
en.formatMessage('yen', args: {'amount': 1234.5});     // "¥1,235"

// style: "unit" — this backend is the only one in the family that has it:
en.formatMessage('speed', args: {'v': 120});           // "120 km/h"
en.formatMessage('long', args: {'v': 3});              // "3 meters"  ← the 's' is CLDR's
```

### Dates, calendars, time zones

```dart
const ftl = r'''
styled = { DATETIME($at, dateStyle: "full") }
buddhist = { DATETIME($at, year: "numeric", calendar: "buddhist") }
zoned = { DATETIME($at, hour: "numeric", minute: "2-digit", timeZone: "America/New_York", timeZoneName: "short") }
clock = { DATETIME($at, hour: "2-digit", minute: "2-digit", hourCycle: "h23") }
''';
final at = DateTime.utc(2026, 1, 15, 14, 5);

de.formatMessage('styled', args: {'at': at});
// "Donnerstag, 15. Januar 2026"

// 17 calendar systems — 2026 CE is 2569 in the Buddhist era:
en.formatMessage('buddhist', args: {'at': at});   // "2569 BE"

// IANA zones with DST-correct wall-clock — 14:05 UTC is morning in New York:
en.formatMessage('zoned', args: {'at': at});      // "Jan 15, 2026, 9:05 AM EST"

en.formatMessage('clock', args: {'at': at});      // "14:05"
```

### Plurals — every locale, both kinds

Cardinals and ordinals for every CLDR locale, straight from ICU4X. Welsh is the demo because its ordinals fire categories English never does:

```dart
const ordinalFtl = r'''
place = { NUMBER($pos, type: "ordinal") ->
    [zero] { $pos }fed
    [one] { $pos }af
    [two] { $pos }il
    [few] { $pos }ydd
    [many] { $pos }ed
   *[other] { $pos }fed
}
''';

final cy = FluentBundle('cy', backend: backend, useIsolating: false)
  ..addResource(ordinalFtl);

[1, 2, 3, 5].map((n) => cy.formatMessage('place', args: {'pos': n}));
// "1af", "2il", "3ydd", "5ed"  — four different suffixes, all CLDR's call
```

The translator wrote Welsh grammar in the FTL; the code passed a number. That division of labor is the whole Fluent idea — this backend just makes it true for all locales.

---

## Error handling — the degrade contract

ICU4X has a few walls of its own (scientific notation is the canonical example — no formatter for it upstream yet). This backend never silently drops an option it can't honor: it renders the nearest supported form **and** records a `FluentTypeError` in the caller's error list.

```dart
final en = FluentBundle('en', backend: backend, useIsolating: false)
  ..addResource(r'sci = { NUMBER($n, notation: "scientific") }');

final errors = <FluentError>[];
final out = en.formatMessage('sci', args: {'n': 123456}, errors: errors);
// out:    "123,456"           ← nearest supported rendering
// errors: [FluentTypeError]   ← the gap, on the record
```

Users see reasonable output; QA sees every gap in the error stream. The core's conformance harness proves this in both directions for every declared gap. The full support matrix per option lives in [Capabilities](docs/CAPABILITY_ROADMAP.md).

Everything else about errors is [`fluent_bundle`'s contract](https://pub.dev/packages/fluent_bundle): inert values, never throws.

---

## Platform support

Six platforms through icu_kit's three interchangeable engines — the facade API and this backend are identical over all of them:

| Platform | Engine |
|---|---|
| iOS · Android · macOS · Linux · Windows | `dart:ffi` → ICU4X (icu_kit's build hook bundles the native library) |
| Web | ICU4X compiled to WebAssembly, or the browser's own `Intl` — [icu_kit's Web section](https://pub.dev/packages/icu_kit#web) has the trade-off |

In ICU4X mode, the same input renders byte-identically on every platform — no "works on my browser" formatting drift. That claim is tested literally: the chrome suite runs the showcase over the WASM engine and asserts the same pinned strings the native suite pins.

---

## Not in the box

- **Scientific / engineering notation** — an upstream ICU4X gap; degrades loud (see above). [`fluent_intl`](https://pub.dev/packages/fluent_intl) renders it if you need it today.
- **Everything beyond formatting** — segmentation, collation, casing, bidi analysis, calendars as objects. That's [`icu_kit`](https://pub.dev/packages/icu_kit)'s own API, one import away; this package only wires the `FluentBackend` surface.
- **Message translation workflow** (ARB catalogs, extraction) — different job; this package formats, it doesn't manage translations.

---

## Docs

The README covers the everyday stuff. wanna go deeper?

| Doc | What's inside |
|---|---|
| [Architecture](docs/ARCHITECTURE.md) | How it's built: the backend surface, the option mapping, the style caches |
| [Capabilities](docs/CAPABILITY_ROADMAP.md) | The per-option support matrix: rendered, degraded, or spec-fallback |
| [Updating](docs/UPDATING.md) | Maintenance recipes and the upstream (icu_kit / ICU4X) watchlist |
| [Example](example/) | The whole tour in one runnable file, output pinned by test |

---

## License

MIT. See [LICENSE](LICENSE).
