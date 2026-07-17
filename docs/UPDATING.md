# Updating fluent_icu

Maintenance recipes for the ICU4X satellite. For how it's wired see
[`ARCHITECTURE.md`](ARCHITECTURE.md); for capability status see
[`CAPABILITY_ROADMAP.md`](CAPABILITY_ROADMAP.md). Core-side maintenance
(corpus source, option contract, spec tracking) lives in
[`fluent_bundle/docs/UPDATING.md`](../../fluent_bundle/docs/UPDATING.md).

This package tracks three upstreams:

| Source | Why |
|---|---|
| `icu_kit` (and through it ICU4X + CLDR) | The rendering engine — every wall in the roadmap is an ICU4X gap |
| CLDR `supplementalData.xml` currency fractions | The baked minor-units table |
| Mozilla's fluent-rs resolver fixtures | The vendored `test/_corpus/bundle/` copy |

---

## When to update

| Trigger | Recipe |
|---|---|
| icu_kit bumps its ICU4X / CLDR version | §1 — The icu_kit bump ritual |
| A new CLDR release changes currency fractions | §2 — Re-sync the fractions table |
| New fluent-rs fixtures | §3 — Refresh the corpus (sync with siblings) |
| A new ECMA option lands in the core | §4 — Wire it here |
| `timezone` package bump (tzdata) | §5 — Standard pub upgrade |

---

## §1 — The icu_kit bump ritual

An icu_kit bump can retire walls. The ritual, in order:

1. Bump the dep, `fvm dart pub upgrade icu_kit`, run the full suite.
2. **Walk the upstream-watch ledger** (§6 below). Every row names a
   hand-rolled compensation, the file that carries it, and the upstream
   change that retires it. Check each trigger against the new ICU4X
   changelog.
3. For each retired wall: delete the compensation, wire the real
   rendering, **flip the satellite's `BackendExpectations` flag ✗→✓**
   in `test/conformance_test.dart` — the harness then demands the
   positive check and stops demanding the degrade.
4. Update the roadmap's walls table and the family matrix cell in the
   core's CAPABILITY_ROADMAP.
5. New facade knobs? Thread them through `number/styles.dart` /
   `datetime/field_mapping.dart` — and into the cache keys.
6. If styles.dart's `@experimental` members graduated, drop the
   `experimental_member_use` severity override in analysis_options.yaml
   and the `test-guards` confinement grep.
7. Full sweep: `make check` here AND in the core AND in fluent_intl
   (the harness is shared).

The vendored-Rust side (rebasing the `icu_kit/2.2.0-patches` branch,
walking icu_kit's own patch ledger) is icu_kit's release ritual — see
`icu_kit/docs/UPDATING.md`. This package's ritual starts after icu_kit
ships.

---

## §2 — Re-sync the CLDR currency fractions table

`lib/src/number/currency_digits.dart` bakes CLDR's
`supplementalData.xml` → `<currencyData><fractions>` (the ECMA-402
`CurrencyDigits` AO input). The full recipe is in the file header;
short form:

```sh
# 1. Fetch the current table
curl -sL https://raw.githubusercontent.com/unicode-org/cldr/main/common/supplemental/supplementalData.xml \
  | grep -A2 '<fractions>' > /tmp/fractions.xml   # or open in a browser

# 2. Diff the <info iso4217=... digits=...> entries against the const
#    maps in currency_digits.dart (only digits != 2 are listed; the
#    default-2 fallback covers the rest). cashDigits/rounding are
#    deliberately NOT modeled — ECMA CurrencyDigits ignores them.

# 3. Update the maps + the CLDR version in the header comment.
fvm dart test test/number/currency_digits_test.dart test/number/number_map_test.dart
```

Currency fraction changes are rare (a currency redenominates). Check on
each CLDR major that icu_kit adopts (§1 step 2 covers this — the table
has its own ledger row in §6).

---

## §3 — Refresh the fluent-rs corpus

`test/_corpus/bundle/` is one of THREE pinned copies (core's syntax
fixtures + both satellites' resolver fixtures). They refresh together,
same session, same upstream commit — the recipe and the sync-together
rule live in the core's
[`UPDATING.md`](../../fluent_bundle/docs/UPDATING.md) §1. Never refresh
this copy alone; never hand-edit a vendored fixture. Bump
`test/_corpus/PROVENANCE.md` with the new commit.

---

## §4 — Wire a new ECMA option

The end-to-end recipe (value field → builtin validation →
resolveDigits → satellite → harness flag → roadmap row) is the core's
[`UPDATING.md`](../../fluent_bundle/docs/UPDATING.md) §2. The
icu-side step:

1. Render it in the right `*_map.dart` pipeline stage — locale fold
   (`common/locale_ext.dart`), per-call shaping (`number/shaping.dart`),
   or formatter construction (`number/styles.dart` /
   `datetime/field_mapping.dart`).
2. If construction-affecting: **into the cache key.** Both cache-miss
   bugs this family has had (compactDisplay, hourCycle) were missing
   key fields.
3. If ICU4X can't render it: per-call
   `FluentTypeError.unsupportedOption` degrade (never inside a cached
   builder), flag `false` in `conformance_test.dart`, wall row in the
   roadmap, ledger row in §6 if a compensation exists.

---

## §5 — Refresh `package:timezone` (tzdata)

```sh
fvm dart pub upgrade timezone
fvm dart test test/datetime/zoned_test.dart
```

tzdata releases several times a year (political zone changes). A stale
tzdata gives wrong wall-clock times for recently-changed zones — bump
when a zone this package's users care about changes, or on each
release.

---

## §6 — The upstream-watch ledger

The single table of everything hand-rolled BECAUSE upstream lacks it,
with the signal that retires each row. The family's compensations live
here (some rows sit in fluent_intl or the core — one table beats a
split; the walk happens during THIS package's bump ritual).
Vendored-patch rows are NOT duplicated here — icu_kit's own patch
ledger (its `docs/ARCHITECTURE.md`) owns those.

| Hand-rolled piece | Where | Retire when |
|---|---|---|
| Per-currency minor-unit table (CLDR-47 fractions, baked const map — JPY 0, BHD 3, default 2; wall CLOSED 2026-07-16) | `lib/src/number/currency_digits.dart` (sync recipe in its header) | ICU4X ships per-currency minor-unit data — then delete the table and read it from the formatter |
| Scientific/engineering degrade | `lib/src/number/number_map.dart` wall block | ICU4X ships exponent symbols in `DecimalSymbols` + a scientific formatter |
| Accounting-sign degrade | `lib/src/number/number_map.dart` wall block | ICU4X ships accounting patterns (plausibly via upstream PR #7789's currency redesign) |
| Compact-on-non-decimal-style degrade | `lib/src/number/number_map.dart` wall block | ICU4X ships compact currency/percent/unit (#7789 territory) |
| Flexible dayPeriod best-fit (bare `dayPeriod` implies h12; no "in the morning" forms) | `lib/src/common/locale_ext.dart` + datetime_map | ICU4X supports the `'B'` pattern field |
| `experimental_member_use: ignore` severity override (+ the `make test-guards` confinement grep) | `analysis_options.yaml` / `Makefile` | #7789 lands and percent/currency/unit graduate from `icu_experimental` |
| ECMA compact 1-2 sig-digit default pinned by hand | fluent_intl + this package's compact paths | Never (ECMA semantics are ours to implement) — listed so nobody "fixes" it |
| Percent ×100 scaling, ECMA default digits, `resolveDigits`, `-u-` fold | core + both adapters | Never — spec behavior, not gap shims |
| `l10n_currencies` name path, intl degrade set (signDisplay etc.) | fluent_intl | Only if package:intl grows the knobs (not ICU4X-related; effectively permanent — this backend is the answer) |

**The full-closure path for the three data walls (fork-level, GATED —
never start without DC's explicit go in-session):** extending ICU4X's
data schema (exponent symbols in `DecimalSymbols`, accounting patterns
in currency essentials, `'B'` flexible day periods as new markers)
requires running `icu4x-datagen` against downloaded CLDR sources and
re-baking data for all locales, plus (for dayPeriod) new field symbols
+ pattern matching in `components/datetime`. Multi-day each, permanent
upstream-sync burden. If green-lit, plan that work as its own document
first. Upstream watch: ICU4X PR #7789 (unified CurrencyDisplay) will
eventually collide with icu_kit's currency patches — its patch ledger
names this.

**On each ICU4X release:** (1) rebase `icu_kit/2.2.0-patches` per
icu_kit's UPDATING, (2) walk icu_kit's patch ledger — drop absorbed
patches, (3) walk THIS table — retire satisfied rows and convert the
wall from degrade to render (flip the harness flag, update the family
matrix row).

---

## Reading the failure modes

| Failure | First check |
|---|---|
| Conformance fails after an icu_kit bump | A wall silently retired (degrade check fails because the option now renders) — that's the ritual's step 3 telling you to flip the flag. Or icu_kit changed rendering — diff against its changelog. |
| Corpus fixture fails | Same triage as the core's §1: new spec feature vs regression. Confirm the sibling copies are on the same commit first. |
| A currency's decimals change under you | CLDR moved — §2. Explicit digit options in FTL are unaffected (they always win). |
| Zoned output shifts unexpectedly | tzdata drift (§5) or a DST rule change — compare against `zdump` for the zone. |
| `make test-guards` flags experimental-facade use outside styles.dart | The confinement broke — route the new usage through `StyleCaches` in styles.dart; never widen the severity override's reach. |
