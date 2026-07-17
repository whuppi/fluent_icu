import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:fluent_icu/src/common/locale_ext.dart';
import 'package:fluent_icu/src/datetime/field_mapping.dart';
import 'package:fluent_icu/src/datetime/zoned.dart';
import 'package:icu_kit/icu_kit.dart';

/// Build a date-time formatter backed by `icu_kit` (ICU4X).
///
/// fluent_bundle (and ECMA-402's `Intl.DateTimeFormat`) takes a wide
/// option bag: `dateStyle` / `timeStyle` shorthand, plus per-field
/// flags (`year`, `month`, `day`, `weekday`, `hour`, `minute`,
/// `second`). icu_kit's stable surface is field-set-shaped: pick
/// [IcuDateFormat] / [IcuTimeFormat] / [IcuDateTimeFormat] with one
/// of the published constructors (`ymd`, `ymdt`, `et`, ...).
///
/// This adapter resolves the field bag to the closest icu_kit
/// constructor (the decision tables live in `field_mapping.dart`), picks
/// an appropriate length from `dateStyle` / `timeStyle`, and formats.
///
/// The full DATETIME option surface renders: `calendar`, `hour12`,
/// `hourCycle`, and `numberingSystem` fold into BCP47 `-u-` locale
/// extensions (`en-u-ca-japanese-hc-h23-nu-arab` — icu_kit honors them
/// natively); `era` maps to the with-era year style; `timeZone` /
/// `timeZoneName` route through the zoned path in `zoned.dart`
/// (tz-database wall-clock + zone label); `dayPeriod` renders the AM/PM
/// marker under the 12-hour cycle it implies (best-fit — ICU4X ships no
/// flexible "in the morning" day periods, so the width variants all
/// render as AM/PM).
String Function(FluentDateTime, String, List<FluentError>)
createIcuDateTimeFormatter() {
  // One cache per field-set discriminant; format calls hit the same
  // formatter when the option discriminants match.
  final dateOnlyCache = <String, IcuDateFormat>{};
  final timeOnlyCache = <String, IcuTimeFormat>{};
  final dateTimeCache = <String, IcuDateTimeFormat>{};

  return (FluentDateTime value, String baseLocale, List<FluentError> errors) {
    final opts = value.options;

    // calendar / hour12 / numberingSystem are applied by folding them into
    // the locale's `-u-` extension (ICU4X reads them from there).
    final locale = applyDateTimeLocaleExtensions(baseLocale, opts);

    // era → IcuYearStyle.withEra (see pickYearStyle). dayPeriod → the marker
    // renders under the 12-hour cycle applyDateTimeLocaleExtensions folds in.

    // timeZone → the zoned path: convert the instant to the target zone's
    // wall-clock + offset (via the tz database), then render with the zone
    // name. Works identically on all three icu_kit engines (each renders the
    // wall-clock we hand it + the zone label).
    if (opts.timeZone != null) {
      return formatZoned(value, locale, opts, errors);
    }

    // Decide which kind of formatter to use:
    //   - `timeStyle` set + no date fields -> time-only
    //   - `dateStyle` set + no time fields -> date-only
    //   - both -> combined date+time
    //   - neither + only time fields -> time-only
    //   - neither + only date fields -> date-only
    //   - mixed fields -> combined
    final hasDateField =
        opts.year != null ||
        opts.month != null ||
        opts.day != null ||
        opts.weekday != null;
    final hasTimeField =
        opts.hour != null || opts.minute != null || opts.second != null;
    final wantsDate = opts.dateStyle != null || hasDateField;
    final wantsTime = opts.timeStyle != null || hasTimeField;

    if (wantsTime && !wantsDate) {
      return _formatTimeOnly(timeOnlyCache, value, locale, opts, errors);
    }
    if (wantsDate && !wantsTime) {
      return _formatDateOnly(dateOnlyCache, value, locale, opts, errors);
    }
    if (wantsDate && wantsTime) {
      return _formatCombined(dateTimeCache, value, locale, opts, errors);
    }
    // Neither side asked for anything: render the locale's default
    // ymdt medium so output remains useful.
    return _formatCombined(dateTimeCache, value, locale, opts, errors);
  };
}

String _formatDateOnly(
  Map<String, IcuDateFormat> cache,
  FluentDateTime value,
  String locale,
  FluentDateTimeOptions opts,
  List<FluentError> errors,
) {
  final fieldSet = pickDateFieldSet(opts);
  final length = pickLength(opts.dateStyle);
  final yearStyle = pickYearStyle(opts);
  final key = '$locale|$fieldSet|${length.name}|${yearStyle?.name}';
  final fmt = cache.putIfAbsent(
    key,
    () => safeDateFormat(locale, fieldSet, length, yearStyle, errors),
  );
  return fmt.format(value.value);
}

String _formatTimeOnly(
  Map<String, IcuTimeFormat> cache,
  FluentDateTime value,
  String locale,
  FluentDateTimeOptions opts,
  List<FluentError> errors,
) {
  final length = pickLength(opts.timeStyle);
  final precision = pickPrecision(opts);
  // hour12 is already folded into [locale] as `-u-hc-h12` / `-u-hc-h23` by
  // the caller (applyDateTimeLocaleExtensions), so ICU4X picks the cycle up
  // from the locale here.
  final key = '$locale|${length.name}|${precision.name}';
  final fmt = cache.putIfAbsent(key, () {
    try {
      return IcuTimeFormat(
        locale: locale,
        length: length,
        precision: precision,
      );
    } on IcuError catch (e) {
      errors.add(FluentTypeError('Time formatter unavailable for $locale: $e'));
      return IcuTimeFormat(locale: 'en');
    }
  });
  return fmt.format(value.value);
}

String _formatCombined(
  Map<String, IcuDateTimeFormat> cache,
  FluentDateTime value,
  String locale,
  FluentDateTimeOptions opts,
  List<FluentError> errors,
) {
  // Map the per-field flags to the closest IcuDateTimeFormat constructor.
  final fieldSet = pickDateTimeFieldSet(opts);
  final length = pickLength(opts.dateStyle ?? opts.timeStyle);
  final precision = pickPrecision(opts);
  final yearStyle = pickYearStyle(opts);
  // hour12 is already folded into [locale] via applyDateTimeLocaleExtensions.
  final key =
      '$locale|$fieldSet|${length.name}|${precision.name}|${yearStyle?.name}';
  final fmt = cache.putIfAbsent(
    key,
    () => safeDateTimeFormat(
      locale,
      fieldSet,
      length,
      precision,
      yearStyle,
      errors,
    ),
  );
  return fmt.format(value.value);
}
