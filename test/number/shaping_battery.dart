// NumShaping.resolve — the per-call ECMA-402 digit/rounding resolution:
// style-dependent default digit bounds, the roundingIncrement constraint,
// and the string→enum knob mappings. Pure logic, no icu_kit engine needed.

import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:fluent_icu/src/number/shaping.dart';
import 'package:icu_kit/icu_kit.dart';
import 'package:test/test.dart';

void registerShapingTests() {
  NumShaping resolve(
    FluentNumberOptions opts, {
    String style = 'decimal',
    String notation = 'standard',
    List<FluentError>? errors,
  }) => NumShaping.resolve(opts, style, notation, errors ?? <FluentError>[]);

  group('NumShaping.resolve — ECMA default digit bounds', () {
    test('style defaults when no digit options are given', () {
      final dec = resolve(const FluentNumberOptions());
      expect((dec.minFrac, dec.maxFrac), (0, 3));
      final pct = resolve(const FluentNumberOptions(), style: 'percent');
      expect((pct.minFrac, pct.maxFrac), (0, 0));
      final usd = resolve(
        const FluentNumberOptions(currency: 'USD'),
        style: 'currency',
      );
      expect((usd.minFrac, usd.maxFrac), (2, 2));
      // Per-currency minor units: yen has none.
      final jpy = resolve(
        const FluentNumberOptions(currency: 'JPY'),
        style: 'currency',
      );
      expect((jpy.minFrac, jpy.maxFrac), (0, 0));
    });

    test('one explicit bound resolves the other per ECMA', () {
      // mxfd = max(mnfd, mxfdDefault)
      final minOnly = resolve(
        const FluentNumberOptions(minimumFractionDigits: 5),
      );
      expect((minOnly.minFrac, minOnly.maxFrac), (5, 5));
      // mnfd = min(mnfdDefault, mxfd)
      final maxOnly = resolve(
        const FluentNumberOptions(maximumFractionDigits: 1, currency: 'USD'),
        style: 'currency',
      );
      expect((maxOnly.minFrac, maxOnly.maxFrac), (1, 1));
    });

    test('min > max records an error; the explicit maximum wins', () {
      final errors = <FluentError>[];
      final s = resolve(
        const FluentNumberOptions(
          minimumFractionDigits: 4,
          maximumFractionDigits: 2,
        ),
        errors: errors,
      );
      expect((s.minFrac, s.maxFrac), (2, 2));
      expect(errors.single, isA<FluentTypeError>());
    });

    test('significant digits and compact notation skip fraction defaults', () {
      final sig = resolve(
        const FluentNumberOptions(maximumSignificantDigits: 3),
      );
      expect((sig.minFrac, sig.maxFrac), (null, null));
      final compact = resolve(const FluentNumberOptions(), notation: 'compact');
      expect((compact.minFrac, compact.maxFrac), (null, null));
    });
  });

  group('NumShaping.resolve — roundingIncrement constraint', () {
    test('an increment with equal effective bounds survives', () {
      final errors = <FluentError>[];
      final s = resolve(
        const FluentNumberOptions(
          roundingIncrement: 25,
          minimumFractionDigits: 2,
          maximumFractionDigits: 2,
        ),
        errors: errors,
      );
      expect(s.roundingIncrement, 25);
      expect(errors, isEmpty);
    });

    test('an increment against unequal DEFAULT bounds degrades + records', () {
      // Bare decimal defaults are 0/3 — unequal, so the increment drops.
      final errors = <FluentError>[];
      final s = resolve(
        const FluentNumberOptions(roundingIncrement: 5),
        errors: errors,
      );
      expect(s.roundingIncrement, isNull);
      expect(errors.single, isA<FluentTypeError>());
    });
  });

  group('NumShaping.resolve — knob mappings', () {
    test('all nine rounding modes map onto IcuRoundingMode', () {
      const modes = {
        'ceil': IcuRoundingMode.ceil,
        'floor': IcuRoundingMode.floor,
        'expand': IcuRoundingMode.expand,
        'trunc': IcuRoundingMode.trunc,
        'halfCeil': IcuRoundingMode.halfCeil,
        'halfFloor': IcuRoundingMode.halfFloor,
        'halfExpand': IcuRoundingMode.halfExpand,
        'halfTrunc': IcuRoundingMode.halfTrunc,
        'halfEven': IcuRoundingMode.halfEven,
      };
      for (final entry in modes.entries) {
        expect(
          resolve(FluentNumberOptions(roundingMode: entry.key)).roundingMode,
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('trailingZeroDisplay and signDisplay map onto their enums', () {
      final s = resolve(
        const FluentNumberOptions(
          trailingZeroDisplay: 'stripIfInteger',
          signDisplay: 'exceptZero',
        ),
      );
      expect(s.trailingZeroDisplay, IcuTrailingZeroDisplay.stripIfInteger);
      expect(s.signDisplay, IcuSignDisplay.exceptZero);
    });
  });
}
