/// The five per-style formatters: each constructs (and caches, keyed by
/// the caller-owned cache) an icu_kit formatter and applies the per-call
/// [NumShaping]. Construction failures record a [FluentTypeError] and
/// fall back to an `en` formatter so formatting never throws.
///
/// IcuPercentFormat / IcuCurrencyFormat / IcuUnitFormat / IcuCompactFormat
/// are deliberately marked `@experimental` in icu_kit because they wrap
/// ICU4X's `icu_experimental` crate (or icu_decimal's `unstable` feature).
/// The instability is API-only, not data-only - upstream PR #7789 will
/// land a unified percent/currency/unit redesign and our adapter will
/// adapt to it. Until then, we wrap them so consumers don't have to opt
/// in to `@experimental` themselves. The diagnostic is downgraded in
/// analysis_options.yaml (no suppression comments in this family); the
/// `make test-guards` grep confines usage to THIS file.
library;

import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:fluent_icu/src/number/shaping.dart';
import 'package:icu_kit/icu_kit.dart';

/// The per-style formatter caches, owned by one `createIcuNumberFormatter`
/// closure. Keys include the folded locale + every construction-affecting
/// option; per-call shaping options never enter a key.
final class StyleCaches {
  /// `style: decimal` formatters.
  final decimal = <String, IcuNumberFormat>{};

  /// `style: percent` formatters.
  final percent = <String, IcuPercentFormat>{};

  /// `style: currency` formatters (incl. the long-name path).
  final currency = <String, IcuCurrencyFormat>{};

  /// `style: unit` formatters.
  final unit = <String, IcuUnitFormat>{};

  /// `notation: compact` formatters.
  final compact = <String, IcuCompactFormat>{};
}

/// Map the core's ECMA-402 v3 grouping strategy string onto icu_kit's
/// enum. The facades resolve strategy-wins-over-useGrouping, so both are
/// always passed through together.
IcuGroupingStrategy? _groupingOf(FluentNumberOptions opts) =>
    switch (opts.groupingStrategy) {
      'auto' => IcuGroupingStrategy.auto,
      'always' => IcuGroupingStrategy.always,
      'min2' => IcuGroupingStrategy.min2,
      _ => null,
    };

/// Render `style: decimal` through [IcuNumberFormat], cached per
/// locale + grouping.
String formatDecimal(
  StyleCaches caches,
  FluentNumber value,
  String locale,
  NumShaping s,
  List<FluentError> errors,
) {
  final opts = value.options;
  final key = '$locale|${opts.useGrouping}|${opts.groupingStrategy}';
  final fmt = caches.decimal.putIfAbsent(
    key,
    () => _safeDecimal(locale, opts, errors),
  );
  return fmt.format(
    value.value,
    minimumIntegerDigits: s.minInt,
    minimumFractionDigits: s.minFrac,
    maximumFractionDigits: s.maxFrac,
    minimumSignificantDigits: s.minSig,
    maximumSignificantDigits: s.maxSig,
    roundingMode: s.roundingMode,
    roundingIncrement: s.roundingIncrement,
    trailingZeroDisplay: s.trailingZeroDisplay,
    signDisplay: s.signDisplay,
  );
}

IcuNumberFormat _safeDecimal(
  String locale,
  FluentNumberOptions opts,
  List<FluentError> errors,
) {
  try {
    return IcuNumberFormat.decimal(
      locale: locale,
      useGrouping: opts.useGrouping,
      groupingStrategy: _groupingOf(opts),
    );
  } on IcuError catch (e) {
    errors.add(
      FluentTypeError('Decimal formatter unavailable for $locale: $e'),
    );
    // Last-resort: ASCII en formatter to avoid throwing.
    return IcuNumberFormat.decimal(locale: 'en');
  }
}

/// Render `notation: compact` through [IcuCompactFormat], cached per
/// locale + grouping + compactDisplay.
String formatCompact(
  StyleCaches caches,
  FluentNumber value,
  String locale,
  NumShaping s,
  List<FluentError> errors,
) {
  final opts = value.options;
  final display = opts.compactDisplay == 'long'
      ? IcuCompactDisplay.long
      : IcuCompactDisplay.short;
  final key =
      '$locale|${display.name}|${opts.useGrouping}|${opts.groupingStrategy}';
  final fmt = caches.compact.putIfAbsent(key, () {
    try {
      return IcuCompactFormat(
        locale: locale,
        display: display,
        useGrouping: opts.useGrouping,
        groupingStrategy: _groupingOf(opts),
      );
    } on IcuError catch (e) {
      errors.add(
        FluentTypeError('Compact formatter unavailable for $locale: $e'),
      );
      return IcuCompactFormat(locale: 'en', display: display);
    }
  });
  return fmt.format(
    value.value,
    minimumIntegerDigits: s.minInt,
    minimumFractionDigits: s.minFrac,
    maximumFractionDigits: s.maxFrac,
    minimumSignificantDigits: s.minSig,
    maximumSignificantDigits: s.maxSig,
    roundingMode: s.roundingMode,
    roundingIncrement: s.roundingIncrement,
    trailingZeroDisplay: s.trailingZeroDisplay,
    signDisplay: s.signDisplay,
  );
}

/// Render `style: percent` through [IcuPercentFormat] (scaled x100 to
/// match ECMA), cached per locale + grouping.
String formatPercent(
  StyleCaches caches,
  FluentNumber value,
  String locale,
  NumShaping s,
  List<FluentError> errors,
) {
  final opts = value.options;
  // Display option not exposed via FluentNumberOptions; grouping is.
  final key = '$locale|standard|${opts.useGrouping}|${opts.groupingStrategy}';
  final fmt = caches.percent.putIfAbsent(key, () {
    try {
      return IcuPercentFormat(
        locale: locale,
        useGrouping: opts.useGrouping,
        groupingStrategy: _groupingOf(opts),
      );
    } on IcuError catch (e) {
      errors.add(
        FluentTypeError('Percent formatter unavailable for $locale: $e'),
      );
      return IcuPercentFormat(locale: 'en');
    }
  });
  // ECMA-402 percent semantics: multiply by 100. ICU4X's percent formatter
  // does not auto-scale - 0.12 renders as "0.12%" rather than "12%". The
  // intl adapter does the same scaling; matching here keeps the two
  // backends drop-in interchangeable.
  return fmt.format(
    value.value * 100,
    minimumIntegerDigits: s.minInt,
    minimumFractionDigits: s.minFrac,
    maximumFractionDigits: s.maxFrac,
    minimumSignificantDigits: s.minSig,
    maximumSignificantDigits: s.maxSig,
    roundingMode: s.roundingMode,
    roundingIncrement: s.roundingIncrement,
    trailingZeroDisplay: s.trailingZeroDisplay,
    signDisplay: s.signDisplay,
  );
}

/// Render `style: currency` through [IcuCurrencyFormat] (or the
/// per-currency long-name formatter for `currencyDisplay: name`),
/// cached per locale + grouping + display + code where the code is
/// construction-affecting.
String formatCurrency(
  StyleCaches caches,
  FluentNumber value,
  String locale,
  NumShaping s,
  List<FluentError> errors,
) {
  final opts = value.options;
  final code = opts.currency;
  if (!isValidCurrencyCode(code)) {
    errors.add(FluentTypeError.invalidCurrencyCode(code));
    // Fall through to decimal.
    return IcuNumberFormat.decimal(
      locale: locale,
      useGrouping: opts.useGrouping,
      groupingStrategy: _groupingOf(opts),
    ).format(
      value.value,
      minimumIntegerDigits: s.minInt,
      minimumFractionDigits: s.minFrac,
      maximumFractionDigits: s.maxFrac,
      minimumSignificantDigits: s.minSig,
      maximumSignificantDigits: s.maxSig,
      roundingMode: s.roundingMode,
      roundingIncrement: s.roundingIncrement,
      trailingZeroDisplay: s.trailingZeroDisplay,
      signDisplay: s.signDisplay,
    );
  }
  final display = opts.currencyDisplay ?? 'symbol';
  final width = switch (display) {
    'narrowSymbol' => IcuCurrencyWidth.narrow,
    'code' => IcuCurrencyWidth.code,
    _ => IcuCurrencyWidth.short,
  };
  // For `currencyDisplay: name` ICU4X needs the LongCurrencyFormatter,
  // pinned per currency. Cache by (locale, code, name) so the long
  // formatter is reused.
  if (display == 'name') {
    final key =
        '$locale|$code|name|${opts.useGrouping}|${opts.groupingStrategy}';
    final fmt = caches.currency.putIfAbsent(key, () {
      try {
        return IcuCurrencyFormat.long(
          locale: locale,
          currencyCode: code!,
          useGrouping: opts.useGrouping,
          groupingStrategy: _groupingOf(opts),
        );
      } on IcuError catch (e) {
        errors.add(
          FluentTypeError(
            'Long currency formatter unavailable for $locale + $code: $e',
          ),
        );
        return IcuCurrencyFormat.long(locale: 'en', currencyCode: code!);
      }
    });
    return fmt.format(
      value.value,
      minimumIntegerDigits: s.minInt,
      minimumFractionDigits: s.minFrac,
      maximumFractionDigits: s.maxFrac,
      minimumSignificantDigits: s.minSig,
      maximumSignificantDigits: s.maxSig,
      roundingMode: s.roundingMode,
      roundingIncrement: s.roundingIncrement,
      trailingZeroDisplay: s.trailingZeroDisplay,
      signDisplay: s.signDisplay,
    );
  }
  // Symbol-style. Cache by (locale, width, grouping); code is per-call.
  final key =
      '$locale|symbol|${width.name}|${opts.useGrouping}|${opts.groupingStrategy}';
  final fmt = caches.currency.putIfAbsent(key, () {
    try {
      return IcuCurrencyFormat.symbol(
        locale: locale,
        width: width,
        useGrouping: opts.useGrouping,
        groupingStrategy: _groupingOf(opts),
      );
    } on IcuError catch (e) {
      errors.add(
        FluentTypeError('Currency formatter unavailable for $locale: $e'),
      );
      return IcuCurrencyFormat.symbol(locale: 'en');
    }
  });
  return fmt.format(
    value.value,
    currencyCode: code,
    minimumIntegerDigits: s.minInt,
    minimumFractionDigits: s.minFrac,
    maximumFractionDigits: s.maxFrac,
    minimumSignificantDigits: s.minSig,
    maximumSignificantDigits: s.maxSig,
    roundingMode: s.roundingMode,
    roundingIncrement: s.roundingIncrement,
    trailingZeroDisplay: s.trailingZeroDisplay,
    signDisplay: s.signDisplay,
  );
}

/// Render `style: unit` through [IcuUnitFormat], cached per locale +
/// grouping + unit + unitDisplay.
String formatUnit(
  StyleCaches caches,
  FluentNumber value,
  String locale,
  NumShaping s,
  List<FluentError> errors,
) {
  final opts = value.options;
  final unit = opts.unit;
  if (unit == null) {
    errors.add(
      const FluentTypeError(
        'NUMBER style: "unit" requires a `unit` option (e.g. "kilometer"); degrading to decimal',
      ),
    );
    return IcuNumberFormat.decimal(
      locale: locale,
      useGrouping: opts.useGrouping,
      groupingStrategy: _groupingOf(opts),
    ).format(
      value.value,
      minimumIntegerDigits: s.minInt,
      minimumFractionDigits: s.minFrac,
      maximumFractionDigits: s.maxFrac,
      minimumSignificantDigits: s.minSig,
      maximumSignificantDigits: s.maxSig,
      roundingMode: s.roundingMode,
      roundingIncrement: s.roundingIncrement,
      trailingZeroDisplay: s.trailingZeroDisplay,
      signDisplay: s.signDisplay,
    );
  }
  final widthName = opts.unitDisplay ?? 'short';
  final width = switch (widthName) {
    'long' => IcuUnitWidth.long,
    'narrow' => IcuUnitWidth.narrow,
    _ => IcuUnitWidth.short,
  };
  final key =
      '$locale|$unit|${width.name}|${opts.useGrouping}|${opts.groupingStrategy}';
  final fmt = caches.unit.putIfAbsent(key, () {
    try {
      return IcuUnitFormat(
        locale: locale,
        unit: unit,
        width: width,
        useGrouping: opts.useGrouping,
        groupingStrategy: _groupingOf(opts),
      );
    } on IcuError catch (e) {
      errors.add(
        FluentTypeError('Unit formatter unavailable for $locale + "$unit": $e'),
      );
      return IcuUnitFormat(locale: 'en', unit: 'meter');
    }
  });
  return fmt.format(
    value.value,
    minimumIntegerDigits: s.minInt,
    minimumFractionDigits: s.minFrac,
    maximumFractionDigits: s.maxFrac,
    minimumSignificantDigits: s.minSig,
    maximumSignificantDigits: s.maxSig,
    roundingMode: s.roundingMode,
    roundingIncrement: s.roundingIncrement,
    trailingZeroDisplay: s.trailingZeroDisplay,
    signDisplay: s.signDisplay,
  );
}
