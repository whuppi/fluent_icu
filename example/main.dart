// fluent_icu showcase — the full-fidelity ICU4X backend, every capability
// in one runnable file.
//
// The whole tour lives in this one file because pub.dev renders it on the
// package's Example tab. `test/example/example_test.dart` runs this exact
// showcase and pins its output, so every line below is proven.
//
// `IcuBackend.init()` boots icu_kit — the same code renders through three
// interchangeable engines (native FFI, WASM, browser Intl) with identical
// output; this tour runs on the native engine (the VM default). On first
// run the icu_kit build hook compiles ICU4X from vendored Rust — later
// runs hit the cargo cache.
//
// Where ICU4X lacks data for an ECMA-402 option, the backend degrades
// loud: nearest supported rendering plus a recorded `FluentTypeError` —
// never a silent drop.
//
// Run with: dart run example/main.dart

import 'package:fluent_icu/fluent_icu.dart';

/// Every section of the tour, as `label: value` lines. The example test
/// asserts on these — keep labels stable.
Future<List<String>> runShowcase() async {
  final backend = await IcuBackend.init();
  return [
    ...numberShowcase(backend),
    ...currencyAndUnitShowcase(backend),
    ...datetimeShowcase(backend),
    ...pluralShowcase(backend),
    ...degradeShowcase(backend),
  ];
}

/// A bundle for [locale] with [ftl] loaded, formatting through ICU4X.
FluentBundle bundleFor(String locale, String ftl, IcuBackend backend) =>
    FluentBundle(locale, backend: backend, useIsolating: false)
      ..addResource(ftl);

// ── §1 Numbers — grouping, numbering systems, compact, sign display ────

List<String> numberShowcase(IcuBackend backend) {
  const ftl = r'''
plain = { NUMBER($n) }
deva = { NUMBER($n, numberingSystem: "deva") }
compact = { NUMBER($n, notation: "compact") }
signed = { NUMBER($delta, signDisplay: "exceptZero") }
pct = { NUMBER($share, style: "percent") }
''';
  final en = bundleFor('en', ftl, backend);
  final de = bundleFor('de', ftl, backend);
  final hi = bundleFor('hi', ftl, backend);
  return [
    'number.en: ${en.formatMessage('plain', args: {'n': 1234567.89})}',
    'number.de: ${de.formatMessage('plain', args: {'n': 1234567.89})}',
    // Devanagari digits via the -u-nu- fold — the option wins over the tag.
    'number.deva: ${hi.formatMessage('deva', args: {'n': 1234567.89})}',
    'number.compact: ${en.formatMessage('compact', args: {'n': 1234000})}',
    'number.signed: ${en.formatMessage('signed', args: {'delta': 5})}',
    // ECMA percent scales ×100: 0.42 renders as 42%.
    'number.percent: ${en.formatMessage('pct', args: {'share': 0.42})}',
  ];
}

// ── §2 Currency + units — minor-unit digits, CLDR unit identifiers ─────

List<String> currencyAndUnitShowcase(IcuBackend backend) {
  const ftl = r'''
price = { NUMBER($amount, style: "currency", currency: "USD") }
yen = { NUMBER($amount, style: "currency", currency: "JPY") }
speed = { NUMBER($v, style: "unit", unit: "kilometer-per-hour") }
long = { NUMBER($v, style: "unit", unit: "meter", unitDisplay: "long") }
''';
  final en = bundleFor('en', ftl, backend);
  return [
    'currency.usd: ${en.formatMessage('price', args: {'amount': 1234.5})}',
    // JPY has zero minor units — the baked CLDR fractions table.
    'currency.jpy: ${en.formatMessage('yen', args: {'amount': 1234.5})}',
    // style: unit is icu-only in the family — intl has no equivalent.
    'unit.speed: ${en.formatMessage('speed', args: {'v': 120})}',
    'unit.long: ${en.formatMessage('long', args: {'v': 3})}',
  ];
}

// ── §3 Dates — styles, calendars, time zones, hour cycles ──────────────

List<String> datetimeShowcase(IcuBackend backend) {
  const ftl = r'''
styled = { DATETIME($at, dateStyle: "full") }
buddhist = { DATETIME($at, year: "numeric", calendar: "buddhist") }
zoned = { DATETIME($at, hour: "numeric", minute: "2-digit", timeZone: "America/New_York", timeZoneName: "short") }
clock = { DATETIME($at, hour: "2-digit", minute: "2-digit", hourCycle: "h23") }
''';
  final at = DateTime.utc(2026, 1, 15, 14, 5);
  final en = bundleFor('en', ftl, backend);
  final de = bundleFor('de', ftl, backend);
  return [
    'datetime.styled.de: ${de.formatMessage('styled', args: {'at': at})}',
    // 17 calendar systems via -u-ca-: 2026 CE is 2569 BE.
    'datetime.buddhist: ${en.formatMessage('buddhist', args: {'at': at})}',
    // IANA zones with DST-correct wall-clock: 14:05 UTC is 9:05 AM EST.
    'datetime.zoned: ${en.formatMessage('zoned', args: {'at': at})}',
    'datetime.h23: ${en.formatMessage('clock', args: {'at': at})}',
  ];
}

// ── §4 Plurals — cardinals + ordinals for EVERY CLDR locale ────────────

List<String> pluralShowcase(IcuBackend backend) {
  const cardinalFtl = r'''
items = { $count ->
    [one] { $count } item
   *[other] { $count } items
}
''';
  // Welsh ordinals fire zero and many — categories English ordinals
  // never do. intl covers ~42 ordinal locales; ICU4X covers them all.
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
  final en = bundleFor('en', cardinalFtl, backend);
  final cy = bundleFor('cy', ordinalFtl, backend);
  String items(num n) => en.formatMessage('items', args: {'count': n});
  String place(num n) => cy.formatMessage('place', args: {'pos': n});
  return [
    'plural.cardinal: ${items(1)} / ${items(2)}',
    'plural.ordinal.cy: ${place(1)}, ${place(2)}, ${place(3)}, ${place(5)}',
  ];
}

// ── §5 The degrade contract — walls fail LOUD ───────────────────────────

List<String> degradeShowcase(IcuBackend backend) {
  // ICU4X ships no scientific-notation formatter (a wall in the family
  // matrix). The backend renders the nearest supported form AND records
  // a FluentTypeError — the conformance harness proves this both
  // directions for every declared gap.
  final en = bundleFor(
    'en',
    r'sci = { NUMBER($n, notation: "scientific") }',
    backend,
  );
  final errors = <FluentError>[];
  final output = en.formatMessage('sci', args: {'n': 123456}, errors: errors);
  return [
    'degrade.output: $output',
    'degrade.errors: ${errors.length}',
    'degrade.kind: ${errors.single.runtimeType}',
  ];
}

Future<void> main() async => (await runShowcase()).forEach(print);
