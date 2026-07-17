import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:fluent_icu/src/common/locale_ext.dart';
import 'package:fluent_icu/src/number/shaping.dart';
import 'package:fluent_icu/src/number/styles.dart';

/// Build a number formatter backed by `icu_kit` (ICU4X).
///
/// Each formatter caches `(locale, opts)` pairs so repeated formats
/// don't re-construct ICU4X formatters. The cache is per-formatter -
/// re-create the formatter to drop it.
///
/// Style coverage:
///   * `decimal` (default) - via `IcuNumberFormat.decimal`
///   * `percent`           - via `IcuPercentFormat` (multiplies input by
///     100 to match ECMA-402 semantics; ICU4X percent does NOT auto-scale)
///   * `currency`          - via `IcuCurrencyFormat`
///   * `unit`              - via `IcuUnitFormat`
///   * `notation: compact` (decimal style) - via `IcuCompactFormat`
///
/// The ECMA-402 option surface flows through end to end: digit options,
/// `roundingMode`, `roundingIncrement`, `trailingZeroDisplay`,
/// `signDisplay` shape the value per call; `useGrouping` (booleans AND
/// the v3 strategy strings "auto"/"always"/"min2"), `numberingSystem`
/// (locale `-u-nu-` fold), and `notation`/`compactDisplay` pick the
/// constructed formatter.
///
/// Unsupported options degrade uniformly: the nearest supported rendering
/// plus a recorded [FluentTypeError]. On this backend that covers
/// `notation: scientific`/`engineering` (ICU4X ships no exponent-symbol
/// data), `currencySign: accounting` (no accounting patterns), and
/// `notation: compact` on non-decimal styles.
String Function(FluentNumber, String, List<FluentError>)
createIcuNumberFormatter() {
  // Per-formatter caches. Keys include style + the option fields each
  // style uses for CONSTRUCTION (folded locale, grouping, width/display).
  // Per-call shaping options don't enter the cache key.
  final caches = StyleCaches();

  return (FluentNumber value, String locale, List<FluentError> errors) {
    final opts = value.options;
    final style = opts.style ?? 'decimal';
    // numberingSystem renders via the locale's -u-nu- extension, so the
    // folded tag IS the construction locale (and thus the cache key).
    final loc = applyNumberLocaleExtensions(locale, opts);

    // Wall options - data ICU4X does not ship. Degrade + record, never
    // silently drop (identical behavior on native / WASM / browserIntl,
    // keeping the three engines in lockstep).
    void unsupported(String option, String effect) {
      errors.add(
        FluentTypeError.unsupportedOption(
          builtin: 'NUMBER',
          option: option,
          backend: 'icu',
          effect: effect,
        ),
      );
    }

    var notation = opts.notation ?? 'standard';
    if (notation == 'scientific' || notation == 'engineering') {
      unsupported(
        'notation "$notation"',
        'using standard notation (ICU4X ships no exponent-symbol data)',
      );
      notation = 'standard';
    }
    if (opts.currencySign == 'accounting') {
      unsupported(
        'currencySign "accounting"',
        'using the standard sign (ICU4X ships no accounting patterns)',
      );
    }
    if (notation == 'compact' && style != 'decimal') {
      unsupported(
        'notation "compact" with style "$style"',
        'using standard notation (compact is decimal-only on this backend)',
      );
      notation = 'standard';
    }

    final shaping = NumShaping.resolve(opts, style, notation, errors);

    if (notation == 'compact') {
      return formatCompact(caches, value, loc, shaping, errors);
    }
    switch (style) {
      case 'decimal':
        return formatDecimal(caches, value, loc, shaping, errors);
      case 'percent':
        return formatPercent(caches, value, loc, shaping, errors);
      case 'currency':
        return formatCurrency(caches, value, loc, shaping, errors);
      case 'unit':
        return formatUnit(caches, value, loc, shaping, errors);
      default:
        unsupported('style "$style"', 'degrading to decimal');
        return formatDecimal(caches, value, loc, shaping, errors);
    }
  };
}
