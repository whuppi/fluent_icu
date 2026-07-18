library;

// §8.6 number mapping — every FluentNumberOptions digit field renders through
// the icu backend end-to-end (FTL → NUMBER builtin → IcuBackend → ICU4X). The
// digit fields go through icu_kit's shapeDecimalDigits (E2): locale-correct,
// ECMA-402 halfExpand rounding, no hand-rolled string padding.

import 'package:fluent_icu/fluent_icu.dart';
import 'package:test/test.dart';

void registerNumberMapTests() {
  group('IcuBackend — NUMBER digit options (§8.6)', () {
    late IcuBackend backend;
    setUpAll(() async {
      backend = await IcuBackend.init();
    });

    String fmt(String ftl, {Map<String, Object> args = const {}}) {
      final b = FluentBundle('en-US', backend: backend, useIsolating: false)
        ..addResource(ftl);
      return b.formatMessage('m', args: args);
    }

    test('ECMA default digit resolution (no explicit digit options)', () {
      // SetNumberFormatDigitOptions defaults: decimal max 3 fraction
      // digits, percent 0, currency 2/2. Regression: the icu backend once
      // rendered round-trip digits ("1.23456789") — diverging from the
      // intl backend AND from the 3-digit default plural operands use.
      expect(fmt(r'm = { NUMBER($n) }', args: {'n': 1.23456789}), '1.235');
      expect(
        fmt(r'm = { NUMBER($n, style: "percent") }', args: {'n': 0.1234}),
        '12%',
      );
      expect(
        fmt(
          r'm = { NUMBER($n, style: "currency", currency: "USD") }',
          args: {'n': 5},
        ),
        r'$5.00',
      );
    });

    test('per-currency minor units (CLDR fractions table)', () {
      // Yen has no minor unit — bare JPY must render "¥500", never
      // "¥500.00". Dinar carries three.
      expect(
        fmt(
          r'm = { NUMBER($n, style: "currency", currency: "JPY") }',
          args: {'n': 500},
        ),
        '¥500',
      );
      expect(
        fmt(
          r'm = { NUMBER($n, style: "currency", currency: "BHD") }',
          args: {'n': 5},
        ).replaceAll(RegExp('[^0-9.]'), ''),
        '5.000',
      );
      // Explicit digit options still win over the table.
      expect(
        fmt(
          r'm = { NUMBER($n, style: "currency", currency: "JPY", '
          r'minimumFractionDigits: 2) }',
          args: {'n': 500},
        ),
        '¥500.00',
      );
    });

    test('minimumFractionDigits pads trailing zeros', () {
      expect(
        fmt(r'm = { NUMBER($n, minimumFractionDigits: 2) }', args: {'n': 5}),
        '5.00',
      );
    });

    test('maximumFractionDigits rounds half away from zero', () {
      expect(
        fmt(
          r'm = { NUMBER($n, maximumFractionDigits: 2) }',
          args: {'n': 1.005},
        ),
        '1.01',
      );
      expect(
        fmt(r'm = { NUMBER($n, maximumFractionDigits: 0) }', args: {'n': 2.5}),
        '3',
      );
    });

    test('minimumIntegerDigits left-pads with zeros', () {
      expect(
        fmt(r'm = { NUMBER($n, minimumIntegerDigits: 4) }', args: {'n': 42}),
        '0,042',
      );
    });

    test('grouping on by default, off when useGrouping: false', () {
      expect(fmt(r'm = { NUMBER($n) }', args: {'n': 1234567}), '1,234,567');
      expect(
        fmt(r'm = { NUMBER($n, useGrouping: "false") }', args: {'n': 1234567}),
        '1234567',
      );
    });

    test('min + max fraction digits combine', () {
      expect(
        fmt(
          r'm = { NUMBER($n, minimumFractionDigits: 2, maximumFractionDigits: 2) }',
          args: {'n': 1.5},
        ),
        '1.50',
      );
    });

    test('percent scales by 100 and honors fraction digits', () {
      expect(
        fmt(
          r'm = { NUMBER($n, style: "percent", minimumFractionDigits: 1) }',
          args: {'n': 0.5},
        ),
        '50.0%',
      );
    });

    test('maximumSignificantDigits rounds to N figures', () {
      expect(
        fmt(
          r'm = { NUMBER($n, maximumSignificantDigits: 2) }',
          args: {'n': 1234},
        ),
        '1,200',
      );
    });

    test('minimumSignificantDigits pads to N figures', () {
      expect(
        fmt(r'm = { NUMBER($n, minimumSignificantDigits: 3) }', args: {'n': 5}),
        '5.00',
      );
    });

    test('currencyDisplay: code renders the ISO code with spacing', () {
      final out = fmt(
        r'm = { NUMBER($n, style: "currency", currency: "USD", currencyDisplay: "code") }',
        args: {'n': 1234.5},
      );
      expect(out, contains('USD'));
      expect(out, contains('1,234'));
      expect(out, isNot(contains('USD1')));
    });

    test('useGrouping: false drops separators on percent/currency/unit', () {
      expect(
        fmt(
          r'm = { NUMBER($n, style: "percent", useGrouping: "false") }',
          args: {'n': 12.34},
        ),
        isNot(contains('1,234')),
      );
      final cur = fmt(
        r'm = { NUMBER($n, style: "currency", currency: "USD", useGrouping: "false") }',
        args: {'n': 1234567},
      );
      expect(cur, contains('1234567'));
      expect(cur, isNot(contains('1,234')));
      final unit = fmt(
        r'm = { NUMBER($n, style: "unit", unit: "meter", useGrouping: "false") }',
        args: {'n': 1234567},
      );
      expect(unit, contains('1234567'));
      expect(unit, isNot(contains('1,234')));
    });

    test(
      'numberingSystem folds into every style (currency proves non-decimal)',
      () {
        final out = fmt(
          r'm = { NUMBER($n, style: "currency", currency: "USD", numberingSystem: "arab") }',
          args: {'n': 5},
        );
        expect(out, contains('٥'));
      },
    );

    test('compact long spells the magnitude word', () {
      final out = fmt(
        r'm = { NUMBER($n, notation: "compact", compactDisplay: "long") }',
        args: {'n': 1234567},
      );
      expect(out.toLowerCase(), contains('million'));
    });

    test('wall options degrade with a recorded error, never silently', () {
      final backendLocal = backend;
      final b = FluentBundle(
        'en-US',
        backend: backendLocal,
        useIsolating: false,
      )..addResource(r'm = { NUMBER($n, notation: "scientific") }');
      final errors = <FluentError>[];
      final out = b.formatMessage('m', args: {'n': 123456}, errors: errors);
      expect(out, contains('123,456')); // standard-notation fallback
      expect(errors.whereType<FluentTypeError>(), isNotEmpty);
    });

    test('significant digits take priority over fraction digits', () {
      expect(
        fmt(
          r'm = { NUMBER($n, maximumSignificantDigits: 2, maximumFractionDigits: 4) }',
          args: {'n': 1.2345},
        ),
        '1.2',
      );
    });
  });
}
