/// The ECMA-402 → ICU4X constructor mapping: option bags resolve to the
/// closest icu_kit field-set constructor plus length / precision /
/// year-style knobs. Pure decision tables — no formatting happens here.
library;

import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:icu_kit/icu_kit.dart';

/// Field-set discriminant for [IcuDateFormat]'s 10 constructors.
/// Letters follow ICU4X's own naming: y year, m month, d day,
/// e weekday.
enum DateFieldSet {
  /// Year + month + day.
  ymd,

  /// Year + month + day + weekday.
  ymde,

  /// Month + day + weekday.
  mde,

  /// Month + day.
  md,

  /// Day + weekday.
  de,

  /// Year + month.
  ym,

  /// Year only.
  y,

  /// Month only.
  m,

  /// Day only.
  d,

  /// Weekday only.
  e,
}

/// Pick the smallest [DateFieldSet] covering every date field the
/// option bag sets (dateStyle acts as a hint; `full` implies the
/// weekday).
DateFieldSet pickDateFieldSet(FluentDateTimeOptions opts) {
  // Use dateStyle as a hint: full implies weekday + ymd; medium/long
  // imply ymd; short implies ymd. The per-field flags refine.
  if (opts.dateStyle == 'full') {
    // weekday + ymd
    return DateFieldSet.ymde;
  }
  // Per-field: pick the smallest field-set that covers everything set.
  final hasY = opts.year != null;
  final hasM = opts.month != null;
  final hasD = opts.day != null;
  final hasE = opts.weekday != null;
  if (hasY && hasM && hasD && hasE) return DateFieldSet.ymde;
  if (hasY && hasM && hasD) return DateFieldSet.ymd;
  if (hasM && hasD && hasE) return DateFieldSet.mde;
  if (hasM && hasD) return DateFieldSet.md;
  if (hasD && hasE) return DateFieldSet.de;
  if (hasY && hasM) return DateFieldSet.ym;
  if (hasY) return DateFieldSet.y;
  if (hasM) return DateFieldSet.m;
  if (hasD) return DateFieldSet.d;
  if (hasE) return DateFieldSet.e;
  // Default: a fully-qualified date is the safest sentinel for
  // dateStyle-only callers without per-field overrides.
  return DateFieldSet.ymd;
}

/// Construct the [IcuDateFormat] for the picked field set, falling back
/// to English ymd (+ a recorded [FluentTypeError]) when icu_kit has no
/// data for the locale — formatting never throws.
IcuDateFormat safeDateFormat(
  String locale,
  DateFieldSet fs,
  IcuDateLength length,
  IcuYearStyle? yearStyle,
  List<FluentError> errors,
) {
  try {
    // yearStyle only applies to the year-bearing sets (ymd, ymde, ym, y).
    return switch (fs) {
      DateFieldSet.ymd => IcuDateFormat.ymd(
        locale: locale,
        length: length,
        yearStyle: yearStyle,
      ),
      DateFieldSet.ymde => IcuDateFormat.ymde(
        locale: locale,
        length: length,
        yearStyle: yearStyle,
      ),
      DateFieldSet.mde => IcuDateFormat.mde(locale: locale, length: length),
      DateFieldSet.md => IcuDateFormat.md(locale: locale, length: length),
      DateFieldSet.de => IcuDateFormat.de(locale: locale, length: length),
      DateFieldSet.ym => IcuDateFormat.ym(
        locale: locale,
        length: length,
        yearStyle: yearStyle,
      ),
      DateFieldSet.y => IcuDateFormat.y(
        locale: locale,
        length: length,
        yearStyle: yearStyle,
      ),
      DateFieldSet.m => IcuDateFormat.m(locale: locale, length: length),
      DateFieldSet.d => IcuDateFormat.d(locale: locale, length: length),
      DateFieldSet.e => IcuDateFormat.e(locale: locale, length: length),
    };
  } on IcuError catch (e) {
    errors.add(FluentTypeError('Date formatter unavailable for $locale: $e'));
    return IcuDateFormat.ymd(locale: 'en');
  }
}

/// Field-set discriminant for [IcuDateTimeFormat]'s 7 constructors
/// (ICU4X 2.2). The trailing `t` is the time side; the date letters
/// match [DateFieldSet].
enum DateTimeFieldSet {
  /// Day + time.
  dt,

  /// Month + day + time.
  mdt,

  /// Year + month + day + time.
  ymdt,

  /// Day + weekday + time.
  det,

  /// Month + day + weekday + time.
  mdet,

  /// Year + month + day + weekday + time.
  ymdet,

  /// Weekday + time.
  et,
}

/// Pick the smallest [DateTimeFieldSet] covering every date field the
/// option bag sets (the time side always rides along).
DateTimeFieldSet pickDateTimeFieldSet(FluentDateTimeOptions opts) {
  if (opts.dateStyle == 'full') {
    // weekday + ymdt
    return DateTimeFieldSet.ymdet;
  }
  final hasY = opts.year != null;
  final hasM = opts.month != null;
  final hasD = opts.day != null;
  final hasE = opts.weekday != null;
  // No dateStyle and no date fields, only timeStyle/time fields:
  // shouldn't reach here (caller routes to time-only). But if dateStyle
  // is non-null without per-field flags, fall back to ymdt.
  if (!hasY && !hasM && !hasD && !hasE) {
    return DateTimeFieldSet.ymdt;
  }
  if (hasY && hasM && hasD && hasE) return DateTimeFieldSet.ymdet;
  if (hasY && hasM && hasD) return DateTimeFieldSet.ymdt;
  if (hasM && hasD && hasE) return DateTimeFieldSet.mdet;
  if (hasM && hasD) return DateTimeFieldSet.mdt;
  if (hasD && hasE) return DateTimeFieldSet.det;
  if (hasD) return DateTimeFieldSet.dt;
  if (hasE) return DateTimeFieldSet.et;
  // Otherwise the safest combined shape is ymdt.
  return DateTimeFieldSet.ymdt;
}

/// Construct the [IcuDateTimeFormat] for the picked field set, falling
/// back to English ymdt (+ a recorded [FluentTypeError]) when icu_kit
/// has no data for the locale — formatting never throws.
IcuDateTimeFormat safeDateTimeFormat(
  String locale,
  DateTimeFieldSet fs,
  IcuDateLength length,
  IcuTimePrecision precision,
  IcuYearStyle? yearStyle,
  List<FluentError> errors,
) {
  try {
    // yearStyle only applies to the year-bearing sets (ymdt, ymdet).
    return switch (fs) {
      DateTimeFieldSet.dt => IcuDateTimeFormat.dt(
        locale: locale,
        length: length,
        precision: precision,
      ),
      DateTimeFieldSet.mdt => IcuDateTimeFormat.mdt(
        locale: locale,
        length: length,
        precision: precision,
      ),
      DateTimeFieldSet.ymdt => IcuDateTimeFormat.ymdt(
        locale: locale,
        length: length,
        precision: precision,
        yearStyle: yearStyle,
      ),
      DateTimeFieldSet.det => IcuDateTimeFormat.det(
        locale: locale,
        length: length,
        precision: precision,
      ),
      DateTimeFieldSet.mdet => IcuDateTimeFormat.mdet(
        locale: locale,
        length: length,
        precision: precision,
      ),
      DateTimeFieldSet.ymdet => IcuDateTimeFormat.ymdet(
        locale: locale,
        length: length,
        precision: precision,
        yearStyle: yearStyle,
      ),
      DateTimeFieldSet.et => IcuDateTimeFormat.et(
        locale: locale,
        length: length,
        precision: precision,
      ),
    };
  } on IcuError catch (e) {
    errors.add(
      FluentTypeError('DateTime formatter unavailable for $locale: $e'),
    );
    return IcuDateTimeFormat.ymdt(locale: 'en');
  }
}

/// ECMA-402 dateStyle/timeStyle → [IcuDateLength] (medium when unset).
IcuDateLength pickLength(String? style) => switch (style) {
  'full' => IcuDateLength.full,
  'long' => IcuDateLength.long,
  'short' => IcuDateLength.short,
  _ => IcuDateLength.medium,
};

/// ECMA-402 `era` maps to ICU4X's [IcuYearStyle.withEra] — "always show the
/// era" (e.g. "AD 2026", "令和8年"). The era WIDTH (narrow/short/long) follows
/// the format length, not a separate knob — spec-faithful best-fit.
IcuYearStyle? pickYearStyle(FluentDateTimeOptions opts) =>
    opts.era != null ? IcuYearStyle.withEra : null;

/// Resolve the time side's [IcuTimePrecision] — `fractionalSecondDigits`
/// wins, then the finest-grained time field set, then timeStyle.
IcuTimePrecision pickPrecision(FluentDateTimeOptions opts) {
  // ECMA-402's `fractionalSecondDigits` overrides everything else.
  switch (opts.fractionalSecondDigits) {
    case 1:
      return IcuTimePrecision.subsecond1;
    case 2:
      return IcuTimePrecision.subsecond2;
    case 3:
      return IcuTimePrecision.subsecond3;
  }
  // If `second` is set, second-precision; if `minute` is set, minute;
  // if `hour` only, hour-only. timeStyle implies a default precision.
  if (opts.second != null) return IcuTimePrecision.second;
  if (opts.minute != null) return IcuTimePrecision.minute;
  if (opts.hour != null) return IcuTimePrecision.minute;
  // timeStyle hints
  switch (opts.timeStyle) {
    case 'full':
    case 'long':
    case 'medium':
      return IcuTimePrecision.second;
    case 'short':
      return IcuTimePrecision.minute;
  }
  // Default
  return IcuTimePrecision.minute;
}
