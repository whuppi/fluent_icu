import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:fluent_icu/src/number/currency_digits.dart';
import 'package:icu_kit/icu_kit.dart';

/// The per-call shaping bundle every style formatter hands to icu_kit —
/// digit bounds plus the ECMA-402 rounding/sign knobs, resolved once per
/// format call.
class NumShaping {
  /// Bundles already-resolved knobs; [NumShaping.resolve] is the entry
  /// that applies the ECMA-402 style defaults first.
  const NumShaping({
    this.minInt,
    this.minFrac,
    this.maxFrac,
    this.minSig,
    this.maxSig,
    this.roundingMode,
    this.roundingIncrement,
    this.trailingZeroDisplay,
    this.signDisplay,
  });

  /// Resolve [opts] for [style] under [notation]. The core parser already
  /// validated value sets and the unambiguous roundingIncrement
  /// constraints; two style-dependent halves resolve here:
  ///
  /// 1. **ECMA-402 default digit bounds** (SetNumberFormatDigitOptions):
  ///    with no significant-digit options, unset fraction bounds resolve
  ///    to the style defaults — decimal/unit min 0 / max 3, percent
  ///    min 0 / max 0, currency min 2 / max 2. Without this, bare
  ///    `NUMBER($n)` would render round-trip digits ("1.23456789") while
  ///    plural selection and the intl backend both use the 3-digit
  ///    default — an engine divergence AND a render/plural mismatch.
  ///    Currency resolves per-currency via `currencyDigits` (CLDR
  ///    fractions: JPY 0, BHD 3, default 2 — ICU4X ships no minor-unit
  ///    data, so the table is baked adapter-side; package:intl carries
  ///    the same digits, keeping the backends in agreement). Compact
  ///    notation skips this: its significand rounding IS the ECMA
  ///    compact default.
  /// 2. **roundingIncrement's default-dependent constraint**: after the
  ///    defaults, an increment needs equal fraction bounds. Violations
  ///    degrade + record, so the icu_kit facade's throw path stays
  ///    unreachable.
  factory NumShaping.resolve(
    FluentNumberOptions opts,
    String style,
    String notation,
    List<FluentError> errors,
  ) {
    var minFrac = opts.minimumFractionDigits;
    var maxFrac = opts.maximumFractionDigits;

    final hasSig =
        opts.minimumSignificantDigits != null ||
        opts.maximumSignificantDigits != null;
    if (!hasSig && notation != 'compact') {
      final defMin = style == 'currency' ? currencyDigits(opts.currency) : 0;
      final defMax = switch (style) {
        'currency' => currencyDigits(opts.currency),
        'percent' => 0,
        _ => 3,
      };
      if (minFrac == null && maxFrac == null) {
        minFrac = defMin;
        maxFrac = defMax;
      } else if (maxFrac == null) {
        // ECMA: mxfd = max(mnfd, mxfdDefault).
        maxFrac = minFrac! > defMax ? minFrac : defMax;
      } else if (minFrac == null) {
        // ECMA: mnfd = min(mnfdDefault, mxfd).
        minFrac = defMin < maxFrac ? defMin : maxFrac;
      } else if (minFrac > maxFrac) {
        // ECMA throws a RangeError; Fluent records and lets the explicit
        // maximum win.
        errors.add(
          const FluentTypeError(
            'NUMBER minimumFractionDigits exceeds maximumFractionDigits; '
            'using the maximum for both',
          ),
        );
        minFrac = maxFrac;
      }
    }

    var increment = opts.roundingIncrement;
    if (increment != null && increment != 1) {
      if (maxFrac == null || (minFrac ?? 0) != maxFrac || hasSig) {
        errors.add(
          const FluentTypeError(
            'NUMBER roundingIncrement requires equal effective minimum and '
            'maximum fraction digits and no significant-digit options; '
            'ignoring the increment',
          ),
        );
        increment = null;
      }
    }
    return NumShaping(
      minInt: opts.minimumIntegerDigits,
      minFrac: minFrac,
      maxFrac: maxFrac,
      minSig: opts.minimumSignificantDigits,
      maxSig: opts.maximumSignificantDigits,
      roundingMode: switch (opts.roundingMode) {
        'ceil' => IcuRoundingMode.ceil,
        'floor' => IcuRoundingMode.floor,
        'expand' => IcuRoundingMode.expand,
        'trunc' => IcuRoundingMode.trunc,
        'halfCeil' => IcuRoundingMode.halfCeil,
        'halfFloor' => IcuRoundingMode.halfFloor,
        'halfExpand' => IcuRoundingMode.halfExpand,
        'halfTrunc' => IcuRoundingMode.halfTrunc,
        'halfEven' => IcuRoundingMode.halfEven,
        _ => null,
      },
      roundingIncrement: increment,
      trailingZeroDisplay: switch (opts.trailingZeroDisplay) {
        'stripIfInteger' => IcuTrailingZeroDisplay.stripIfInteger,
        _ => null,
      },
      signDisplay: switch (opts.signDisplay) {
        'auto' => IcuSignDisplay.auto,
        'never' => IcuSignDisplay.never,
        'always' => IcuSignDisplay.always,
        'exceptZero' => IcuSignDisplay.exceptZero,
        'negative' => IcuSignDisplay.negative,
        _ => null,
      },
    );
  }

  /// Minimum integer digits (ECMA `minimumIntegerDigits`).
  final int? minInt;

  /// Minimum fraction digits, after style-default resolution.
  final int? minFrac;

  /// Maximum fraction digits, after style-default resolution.
  final int? maxFrac;

  /// Minimum significant digits (mutually exclusive with the fraction
  /// bounds per ECMA — the parser enforced it).
  final int? minSig;

  /// Maximum significant digits.
  final int? maxSig;

  /// ECMA `roundingMode`, mapped onto icu_kit's enum.
  final IcuRoundingMode? roundingMode;

  /// ECMA `roundingIncrement` (the 15-value set).
  final int? roundingIncrement;

  /// ECMA `trailingZeroDisplay` (`stripIfInteger`).
  final IcuTrailingZeroDisplay? trailingZeroDisplay;

  /// ECMA `signDisplay`, mapped onto icu_kit's enum.
  final IcuSignDisplay? signDisplay;
}
