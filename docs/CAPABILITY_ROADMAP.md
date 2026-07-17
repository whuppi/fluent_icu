# fluent_icu — Capabilities

What this backend renders, where it degrades, and why. For how it's wired see [`ARCHITECTURE.md`](ARCHITECTURE.md); for maintenance recipes see [`UPDATING.md`](UPDATING.md).

**The family option matrix is single-sourced.** The full ECMA-402
option × backend table (every NUMBER option, ✓ render / ✗
degrade-with-error per backend, no blank cells) lives in
[`fluent_bundle/docs/CAPABILITY_ROADMAP.md`](../../fluent_bundle/docs/CAPABILITY_ROADMAP.md)
— it is NOT duplicated here. This file adds only what is icu-specific.

---

## Table 1 — The engines

The adapter is engine-blind pure Dart; icu_kit supplies three
interchangeable engines underneath, all behaviorally identical for
everything this backend renders (icu_kit's own parity suites prove it).

| Engine | Platforms | Data | Select with |
|---|---|---|---|
| Native FFI | macOS / iOS / Linux / Windows / Android | vendored ICU4X + CLDR | default off web |
| WASM (ICU4X) | web | same ICU4X, same CLDR — byte-identical output | `IcuBackend.init()` on web |
| Browser Intl | web, zero download | the browser's own `Intl` | `IcuBackend.init(webEngine: WebEngine.browserIntl)` |

Data-size levers (fat/lean binaries, per-locale postcards, `IcuData`
policies) are icu_kit's surface — see its README and docs; nothing in
this package constrains them.

## Table 2 — The walls (icu-side ✗ cells of the family matrix)

Every wall degrades loud: nearest supported rendering + a recorded
`FluentTypeError`, identical on all three engines, harness-proven.

| Wall | Why (verified at ICU4X 2.2 source) | Retire when |
|---|---|---|
| `notation: scientific` / `engineering` | `DecimalSymbols` ships no exponent separator; no scientific formatter logic exists | ICU4X ships exponent data + formatter (fork-level otherwise; gated) |
| `currencySign: accounting` | No accounting patterns in the dimension data | Plausibly upstream PR #7789's currency redesign |
| `notation: compact` on non-decimal styles | ICU4X compact is decimal-only | #7789 territory |
| Flexible `dayPeriod` ("in the morning") | No `'B'` pattern field; width variants render AM/PM | ICU4X supports `'B'` |

The hand-rolled compensations and their retirement triggers are tracked
in ONE place: the upstream-watch ledger in
[`UPDATING.md`](UPDATING.md) §6. Notable closed wall: per-currency
minor units (JPY 0 digits, BHD 3)
via the baked CLDR fractions table — no fork needed.

## Table 3 — icu-specific capabilities beyond the family matrix

| Capability | Status | Notes |
|---|---|---|
| `style: unit` (full CLDR unit identifiers, 3 widths) | DONE | intl has no equivalent — icu-only in the family |
| DATETIME `calendar` (17 systems via `-u-ca-`) | DONE | harness-proven (buddhist year shift) |
| DATETIME `timeZone` (IANA ids, DST-correct) + all 6 `timeZoneName` styles | DONE | tz-database wall-clock + ICU4X zone styles |
| DATETIME `numberingSystem` / `hourCycle` (h11/h12/h23/h24) | DONE | `-u-` folds, option wins over the caller's tag |
| Ordinal plurals, every CLDR locale | DONE | intl covers ~42 locales; icu covers all |
| Per-currency minor-unit digits | DONE | baked CLDR-47 table (`number/currency_digits.dart`) |

## Table 4 — Test coverage

| Coverage | Where |
|---|---|
| Conformance harness (declared flags, both directions) | `test/conformance_test.dart` |
| fluent-rs resolver corpus through IcuBackend (158 asserts) | `test/_corpus/bundle_corpus_test.dart` |
| Behavioral per concern (number matrix, shaping, currency digits, datetime folds, field mapping, zoned, locale_ext, plurals) | `test/{number,datetime,common,plural}/` — mirrors `lib/src` |
| Pub.dev showcase, every output line pinned | `example/main.dart` + `test/example/example_test.dart` |
| Native/WASM parity — the same showcase, same pinned strings, over the WASM engine in real Chrome | `test/web/showcase_chrome_test.dart` (`make test-web`) |
| Engine parity of everything underneath | icu_kit's own matrix (native + WASM + browserIntl, incl. the min2-grouping behavioral row added for this package) |

## Table 5 — Won't do

| Capability | Reason |
|---|---|
| Reimplementing anything ICU4X lacks in Dart | This package adapts; it never competes with its engine. Data gaps go through the gated fork path or wait for upstream. |
| Per-engine behavior branches | The same-behavior-everywhere contract is the point. An engine-specific quirk is an icu_kit bug, not an adapter feature. |
| Silent option drops | The degrade contract forbids it; the harness enforces it. |
