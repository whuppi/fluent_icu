library;

// F8 end-to-end on the icu backend: visible fraction digits (CLDR operand
// `v`) drive plural selection. `1` and `1.0` are the SAME numeric value but
// different categories in English — the backend must feed the display digit
// string (via icu_kit's categoryOfDecimal, E1) so ICU4X sees v>0.

import 'package:fluent_icu/fluent_icu.dart';
import 'package:test/test.dart';

void registerPluralMapTests() {
  group('IcuBackend — operand v (visible fraction digits)', () {
    late IcuBackend backend;
    setUpAll(() async {
      backend = await IcuBackend.init();
    });

    FluentBundle en() =>
        FluentBundle('en', backend: backend, useIsolating: false)
          ..addResource('p = { \$n ->\n [one] one\n *[other] other\n}');

    FluentValue withFrac(num v, int minFrac) =>
        FluentNumber(v, FluentNumberOptions(minimumFractionDigits: minFrac));

    test('bare 1 selects one', () {
      expect(en().formatMessage('p', args: {'n': 1}), 'one');
    });

    test('1 with minimumFractionDigits:1 ("1.0") selects other', () {
      expect(en().formatMessage('p', args: {'n': withFrac(1, 1)}), 'other');
    });

    test('1 with minimumFractionDigits:2 ("1.00") selects other', () {
      expect(en().formatMessage('p', args: {'n': withFrac(1, 2)}), 'other');
    });

    test('2 stays other regardless of fraction digits', () {
      expect(en().formatMessage('p', args: {'n': 2}), 'other');
      expect(en().formatMessage('p', args: {'n': withFrac(2, 1)}), 'other');
    });
  });
}
