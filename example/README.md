# fluent_icu example

A console tour exercising every backend capability — locale-grouped
numbers, numbering systems, sign display, compact notation, currency
with real minor-unit digits, CLDR unit identifiers, date styles,
non-Gregorian calendars, IANA time zones, hour cycles, full-CLDR
ordinal plurals, and the degrade contract for the walls ICU4X can't
render. Formatting runs through `IcuBackend.init()` on the native
engine (the VM default); the same code produces identical output on
the WASM and browser-Intl engines.

## Run

```bash
# from the package root — the icu_kit build hook compiles ICU4X from
# vendored Rust on first run (needs the Rust toolchain); later runs
# hit the cargo cache
fvm dart run example/main.dart
```

## Tests

```bash
# from the package root
make test-example

# or directly
fvm dart test test/example
```

The test runs this exact showcase and pins every output line, so every
claim in the tour is proven on every run. The pins are CLDR renderings
through a pinned icu_kit — if one moves on an icu_kit bump, the
showcase text moved too: re-verify, then re-pin (the bump ritual in
`docs/UPDATING.md` §1 walks this).

## What's inside

Five sections, one per capability area:

| Section | Surface | What it covers |
|---|---|---|
| **Numbers** | `NUMBER` | Grouping per locale (en / de / hi lakh-crore), Devanagari digits via `numberingSystem`, compact notation, `signDisplay: exceptZero`, ECMA percent ×100 |
| **Currency + units** | `NUMBER` | USD symbol placement, JPY's zero minor units (the baked CLDR fractions table), `style: unit` with CLDR identifiers — icu-only in the family |
| **Dates** | `DATETIME` | `dateStyle: full` in German, the buddhist calendar (2026 CE → 2569 BE), IANA zones with DST-correct wall clock + `timeZoneName`, `hourCycle: h23` |
| **Plurals** | select expressions | CLDR cardinals, and Welsh ordinals — including `zero` and `many`, which English ordinals never fire; intl covers ~42 ordinal locales, ICU4X covers them all |
| **Degrade** | the walls | `notation: scientific` (no ICU4X formatter): nearest supported rendering PLUS a recorded `FluentTypeError` — never a silent drop |

## One file on purpose

The whole tour lives in `main.dart` because pub.dev renders that file
as the package's Example tab — splitting it would hide everything else
from that page.

## Same output on three engines

The adapter is engine-blind: native FFI, WASM, and browser Intl render
everything in this tour identically (icu_kit's own parity suites prove
it). The tour runs native because that's the VM default; on web,
`IcuBackend.init()` picks the WASM engine, or
`IcuBackend.init(webEngine: WebEngine.browserIntl)` for zero-download.
