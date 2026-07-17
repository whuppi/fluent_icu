import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:icu_kit/icu_kit.dart';

/// CLDR plural category backed by ICU4X via `icu_kit`. Consumed by
/// `IcuBackend.pluralCategory`; not wired directly by app code.
///
/// Both cardinal (`type: 'cardinal'`, the default) and ordinal
/// (`type: 'ordinal'`) categories come from ICU4X's full CLDR data set —
/// no per-locale predicates are inlined here. Every locale CLDR ships
/// with works on first use.
///
/// [digits] is the display-shaped decimal string (from core's
/// `FluentNumber.resolveDigits().digits`) — its visible fraction digits
/// (CLDR operand `v`) drive selection so `1` and `1.0` classify
/// differently. When null, [value] is stringified (loses trailing zeros).
PluralCategory icuPluralRules(
  num value,
  String locale, {
  String type = 'cardinal',
  String? digits,
}) {
  // Cache rules instances per (locale, type) so back-to-back resolves
  // don't recreate ICU4X PluralRules each call. Tiny memory cost,
  // meaningful per-format-call savings on hot bundles.
  final rules = (type == 'ordinal')
      ? _ordinalCache.putIfAbsent(locale, () => _safeOrdinal(locale))
      : _cardinalCache.putIfAbsent(locale, () => _safeCardinal(locale));

  // Locales without CLDR plural data (rare) fall back to `other` so the
  // `*[other]` default variant always wins.
  if (rules == null) return PluralCategory.other;

  // Feed the display-shaped digit string when the caller has one so
  // visible fraction digits reach ICU4X's operands (the F8 case); fall
  // back to the bare value otherwise.
  final icuCat = digits != null
      ? rules.categoryOfDecimal(digits)
      : rules.category(value);
  return _toFluent(icuCat);
}

final Map<String, IcuPluralRules?> _cardinalCache = {};
final Map<String, IcuPluralRules?> _ordinalCache = {};

IcuPluralRules? _safeCardinal(String locale) {
  try {
    return IcuPluralRules.cardinal(locale);
  } on IcuError {
    return null;
  }
}

IcuPluralRules? _safeOrdinal(String locale) {
  try {
    return IcuPluralRules.ordinal(locale);
  } on IcuError {
    return null;
  }
}

PluralCategory _toFluent(IcuPluralCategory cat) => switch (cat) {
  IcuPluralCategory.zero => PluralCategory.zero,
  IcuPluralCategory.one => PluralCategory.one,
  IcuPluralCategory.two => PluralCategory.two,
  IcuPluralCategory.few => PluralCategory.few,
  IcuPluralCategory.many => PluralCategory.many,
  IcuPluralCategory.other => PluralCategory.other,
};
