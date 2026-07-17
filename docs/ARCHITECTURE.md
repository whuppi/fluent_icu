# fluent_icu — Architecture

How the package is wired. For capability status see [`CAPABILITY_ROADMAP.md`](CAPABILITY_ROADMAP.md); for maintenance recipes see [`UPDATING.md`](UPDATING.md).

fluent_icu is the ICU4X satellite of the fluent family: the whole
package is the adapter that maps `fluent_bundle`'s ECMA-402 option
contract onto `icu_kit`'s facades. The core's architecture (the
contract, the resolver, the conformance harness, the locked satellite
template this package instantiates) lives in
[`fluent_bundle/docs/ARCHITECTURE.md`](../../fluent_bundle/docs/ARCHITECTURE.md)
and is not restated here.

---

## The contract

1. **The whole package is backend-specific.** Every file may speak
   icu_kit — translating the contract IS the job. Anything
   backend-agnostic sinks to the core (one exception below: the pure
   locale-tag fold, kept here because this backend is its only
   consumer).
2. **Three engines for free.** The adapter is pure Dart over icu_kit's
   facades, so it runs identically on all three icu_kit engines —
   native FFI, WASM, browser Intl. Engine parity is icu_kit's proven
   responsibility; this package never branches on engine.
3. **Walls degrade loud and identically.** Options ICU4X ships no data
   for (scientific/engineering notation, accounting sign, compact on
   non-decimal styles) record `FluentTypeError.unsupportedOption` and
   render the nearest supported form — the same on every engine.
4. **Every construction-affecting option is in every cache key.** A
   field left out of a formatter cache key is a collision bug the day
   the builder starts consuming it. Per-call shaping options never
   enter a key.
5. **Facade throw paths stay unreachable.** The shaping resolver
   enforces every constraint icu_kit would throw on (e.g. the
   roundingIncrement equal-bounds rule) with a degrade + recorded
   error, so formatting never throws.

---

## Source tree

The locked satellite template (see the core's ARCHITECTURE §7) filled
with the icu-specific guts:

```
lib/
  fluent_icu.dart              — barrel: re-exports fluent_bundle + IcuBackend
  src/
    backend.dart               — IcuBackend (+ IcuBackend.init: the one async
                                 step; wraps IcuKit.init for engine/data setup)
    common/
      locale_ext.dart          — BCP-47 -u- keyword folds (set-or-OVERRIDE:
                                 option wins over an existing key; multi-subtag
                                 values + non-u extensions pass through)
    datetime/
      datetime_map.dart        — router: style/field bag → date-only /
                                 time-only / combined / zoned; caches
      field_mapping.dart       — the ECMA→ICU4X decision tables: field sets
                                 (10 date + 7 datetime ctors), length,
                                 year-style, time-precision pickers +
                                 fallback-safe constructors
      zoned.dart               — the timeZone path: tz-database wall-clock
                                 conversion (DST-correct) + zone-name styles
    number/
      number_map.dart          — router: wall degrades + style/notation
                                 routing; owns the StyleCaches instance
      shaping.dart             — NumShaping: per-call ECMA digit/rounding
                                 resolution (style defaults incl. per-currency
                                 digits; increment constraint; knob → enum maps)
      styles.dart              — the five style formatters (decimal / percent /
                                 currency / unit / compact) + StyleCaches; the
                                 ONLY file touching icu_kit's @experimental
                                 members (rationale in its header)
      currency_digits.dart     — baked CLDR fractions table (ECMA
                                 CurrencyDigits): JPY 0, BHD 3, default 2;
                                 sync recipe in the file header
    plural/
      plural_map.dart          — icuPluralRules: digit-string operands into
                                 ICU4X plural rules (cardinal + ordinal,
                                 every CLDR locale)
example/
  main.dart                    — the pub.dev showcase: every backend
                                 capability in one runnable file
test/
  _corpus/bundle/              — vendored fluent-rs resolver fixtures
                                 (byte-identical with fluent_intl's
                                 copy; sync together)
  _corpus/PROVENANCE.md        — the pinned upstream commit
  _corpus/bundle_corpus_test.dart — the corpus against IcuBackend
  conformance_test.dart        — the shared harness, icu's declared flags
  backend_test.dart
  example/example_test.dart    — runs the showcase, pins every output line
  common/ datetime/ number/ plural/  — mirror lib/src file-for-file
Makefile                       — the gate: `make check` = analyze + floor +
                                 VM suite + example showcase
```

---

## 1. The number pipeline

```
FluentNumber (value + options)
  ↓ number_map.dart — the router
  ├─ fold numberingSystem into the locale (-u-nu-, common/locale_ext)
  ├─ WALL degrades (scientific/engineering, accounting, compact-on-
  │    non-decimal) → FluentTypeError.unsupportedOption + nearest form
  ├─ NumShaping.resolve(opts, style, notation)      shaping.dart
  │    ECMA default digit bounds (decimal 0/3, percent 0/0, currency
  │    per-currency via currency_digits); one-bound resolution
  │    (mxfd = max(mnfd, default), mnfd = min(default, mxfd));
  │    increment needs equal effective bounds; string knobs → icu enums
  └─ route by style/notation                        styles.dart
       formatDecimal / formatPercent / formatCurrency / formatUnit /
       formatCompact — each constructs (cached by locale + grouping +
       width/display) and formats with the full shaping bundle
```

Notes the code can't show at a glance:

- **Percent scales ×100** — ICU4X's percent formatter does not
  auto-scale; ECMA (and the intl satellite) do. Matching keeps the
  backends drop-in interchangeable.
- **The currency guard** uses the core's `isValidCurrencyCode` +
  `invalidCurrencyCode` and falls through to decimal.
- **`currencyDisplay: name`** pins a per-currency long formatter
  (ICU4X's `LongCurrencyFormatter`), cached by `(locale, code)`.
- **Grouping**: booleans AND the v3 strategy strings both pass through
  (`IcuGroupingStrategy`; strategy wins over the boolean, resolved in
  icu_kit's facades). Both are in every style's cache key.

## 2. The datetime pipeline

```
FluentDateTime (value + options)
  ↓ datetime_map.dart — the router
  ├─ fold calendar / hourCycle (hour12, dayPeriod-implied) /
  │    numberingSystem into the locale (-u- extensions; ICU4X honors
  │    them natively) — common/locale_ext.dart, option-wins override
  ├─ timeZone set? → zoned.dart: tz-database converts the instant to
  │    the zone's wall-clock + offset (DST-correct); ICU4X renders the
  │    wall-clock + the requested zone-name style. Unknown IANA ids
  │    degrade + record.
  └─ else route: time-only / date-only / combined — field_mapping.dart
       picks the smallest covering ICU4X field-set constructor, the
       length from dateStyle/timeStyle, precision from
       fractionalSecondDigits/fields, withEra from `era`
```

`dayPeriod` renders the AM/PM marker under the 12-hour cycle it implies
— best-fit, because ICU4X ships no flexible "in the morning" day
periods (a wall; see the roadmap).

## 3. Plurals

`IcuBackend.pluralCategory` → `plural/plural_map.dart` → ICU4X plural
rules per `(locale, type)`, cached. Selection consumes the DIGIT STRING
from the core's `resolveDigits()`, so visible fraction digits (CLDR
operand `v`) and the full rounding-option surface drive category
selection — `NUMBER($n, minimumFractionDigits: 1)` with n=1 selects
`other` in English, and `floor`-rounded values select what they render.

## 4. The one file without icu_kit

`common/locale_ext.dart` is pure BCP-47 string work (parse the `-u-`
extension, override keywords, rebuild). It stays satellite-side by the
one-consumer rule: only this backend reads options out of locale tags
(ICU4X is the thing that honors them). If another backend ever needs
the fold, it promotes to the core that day.

---

## Test architecture

| Where | What it proves |
|---|---|
| `test/conformance_test.dart` | The shared harness against icu's declared `BackendExpectations` — every ✓ flag positively, every ✗ flag's degrade (render + error, twice on one bundle). |
| `test/_corpus/bundle_corpus_test.dart` | fluent-rs resolver conformance THROUGH this backend — 158 asserts, same pristine fixtures as fluent_intl. |
| `test/number/number_map_test.dart` | The digit-option matrix end to end (FTL → builtin → backend → ICU4X), incl. ECMA defaults + per-currency minor units. |
| `test/number/shaping_test.dart` | `NumShaping.resolve` as a pure function: defaults, increment constraint, knob maps. |
| `test/number/currency_digits_test.dart` | The baked fractions table. |
| `test/datetime/datetime_map_test.dart` | The `-u-` fold options end to end (hour12, numberingSystem, calendar, era). |
| `test/datetime/field_mapping_test.dart` | The decision tables as pure functions. |
| `test/datetime/zoned_test.dart` | DST-correct conversion, zone-name styles, unknown-zone degrade. |
| `test/common/locale_ext_test.dart` | Keyword folds + the option-wins override (no duplicate `-u-` keys). |
| `test/plural/plural_map_test.dart` | Digit-string operands into ICU4X. |

All suites run on the VM against the native engine. Three-engine parity
of everything underneath is icu_kit's own test matrix (its facades run
native + WASM + browserIntl); this adapter is engine-blind pure Dart on
top.

---

### The web lane

`make test-web` runs the showcase over icu_kit's WASM engine in real
Chrome and asserts the SAME pinned strings the native lane pins — the
byte-identical-output claim, tested literally. Assets are installed by
`make web-assets` (`dart run icu_kit:setup web`) into `web/icu_kit/`
(gitignored): the released prebuilt on a hosted icu_kit dep, the sibling
checkout's build on the path dep. The test overrides `IcuKit.moduleUrl`
to the page-relative asset path; CLDR's invisible characters (U+202F
before the day period) are pinned as escapes, never raw bytes.

## Where to look when X happens

| Symptom | First place to look |
|---|---|
| An option renders on intl but degrades here (or vice versa) | The family matrix in the core's CAPABILITY_ROADMAP — the two backends have different ceilings by design; the degrade error names the wall. |
| A currency renders the wrong number of decimals | `number/currency_digits.dart` — is the code in the table? Explicit digit options always win over it. |
| A locale extension seems ignored | `common/locale_ext.dart` — the fold must OVERRIDE an existing key, never append a duplicate (first-wins parsing would silently drop the option). |
| timeZone output is off by an hour seasonally | `datetime/zoned.dart` — the tz database supplies DST; check the IANA id and the tzdata dependency version. |
| A new icu_kit facade knob isn't reachable | `number/styles.dart` / `datetime/field_mapping.dart` — thread it through AND add it to the cache keys. |
| Formatting throws | It must never — a facade throw path became reachable. Check `NumShaping.resolve`'s constraint enforcement against the facade's documented throws. |

---

## The one-line summary

> **One whole-package adapter: option contract in, icu_kit facades out.
> Router → shaping → styles for numbers; -u- folds → field-set tables →
> zoned path for datetimes; digit-string operands for plurals. Walls
> degrade loud and identically on all three engines. Every
> construction-affecting option is in every cache key; every facade
> throw path is made unreachable; corpus- and harness-proven.**
