/// The zoned rendering path (`timeZone` set): convert the instant to the
/// target IANA zone's wall-clock via the tz database, then render with
/// icu_kit's zoned formatters and the requested zone-name style.
library;

import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:fluent_icu/src/datetime/field_mapping.dart';
import 'package:icu_kit/icu_kit.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

bool _tzInitialized = false;

/// Load the IANA tz database once (embedded, works on every platform). Needed
/// before any `timeZone` conversion; harmless when `timeZone` is never used.
void _ensureTzInitialized() {
  if (_tzInitialized) return;
  tzdata.initializeTimeZones();
  _tzInitialized = true;
}

/// Render a `timeZone`-bearing DATETIME: the tz database converts the
/// instant to the zone's wall clock (DST-correct), icu_kit renders the
/// wall clock + the requested `timeZoneName` style. Unknown IANA ids
/// degrade to local time with a recorded error.
String formatZoned(
  FluentDateTime value,
  String locale,
  FluentDateTimeOptions opts,
  List<FluentError> errors,
) {
  _ensureTzInitialized();
  final tz.Location location;
  try {
    location = tz.getLocation(opts.timeZone!);
  } catch (e) {
    errors.add(
      FluentTypeError(
        'DATETIME timeZone "${opts.timeZone}" is not a known IANA zone id: $e; '
        'rendering in the host zone',
      ),
    );
    // Fall back to the non-zoned combined path so output stays useful.
    final fs = pickDateTimeFieldSet(opts);
    final len = pickLength(opts.dateStyle ?? opts.timeStyle);
    return safeDateTimeFormat(
      locale,
      fs,
      len,
      pickPrecision(opts),
      pickYearStyle(opts),
      errors,
    ).format(value.value);
  }
  // TZDateTime carries the target zone's wall-clock fields AND its UTC offset
  // at this exact instant (DST-correct). The formatter renders those
  // wall-clock fields + the zone label.
  final zoned = tz.TZDateTime.from(value.value, location);
  final offsetSeconds = zoned.timeZoneOffset.inSeconds;
  final fieldSet = pickDateTimeFieldSet(opts);
  final length = pickLength(opts.dateStyle ?? opts.timeStyle);
  final precision = pickPrecision(opts);
  final yearStyle = pickYearStyle(opts);
  final zoneStyle = _pickZoneStyle(opts.timeZoneName);
  final fmt = _safeZonedFormat(
    locale,
    fieldSet,
    length,
    precision,
    yearStyle,
    zoneStyle,
    errors,
  );
  return fmt.format(
    zoned,
    ianaTimeZoneId: opts.timeZone!,
    utcOffsetSeconds: offsetSeconds,
  );
}

/// ECMA-402 `timeZoneName` → ICU4X zone style. When a `timeZone` is set but no
/// name, default to the specific-short form ("PDT").
IcuZoneStyle _pickZoneStyle(String? timeZoneName) => switch (timeZoneName) {
  'long' => IcuZoneStyle.specificLong,
  'short' => IcuZoneStyle.specificShort,
  'longOffset' => IcuZoneStyle.localizedOffsetLong,
  'shortOffset' => IcuZoneStyle.localizedOffsetShort,
  'longGeneric' => IcuZoneStyle.genericLong,
  'shortGeneric' => IcuZoneStyle.genericShort,
  _ => IcuZoneStyle.specificShort,
};

IcuZonedDateTimeFormat _safeZonedFormat(
  String locale,
  DateTimeFieldSet fs,
  IcuDateLength length,
  IcuTimePrecision precision,
  IcuYearStyle? yearStyle,
  IcuZoneStyle zoneStyle,
  List<FluentError> errors,
) {
  try {
    // The zoned facade has 6 field sets (no `et`); route `et` through `dt`.
    return switch (fs) {
      DateTimeFieldSet.dt || DateTimeFieldSet.et => IcuZonedDateTimeFormat.dt(
        locale: locale,
        zoneStyle: zoneStyle,
        length: length,
        precision: precision,
      ),
      DateTimeFieldSet.mdt => IcuZonedDateTimeFormat.mdt(
        locale: locale,
        zoneStyle: zoneStyle,
        length: length,
        precision: precision,
      ),
      DateTimeFieldSet.ymdt => IcuZonedDateTimeFormat.ymdt(
        locale: locale,
        zoneStyle: zoneStyle,
        length: length,
        precision: precision,
        yearStyle: yearStyle,
      ),
      DateTimeFieldSet.det => IcuZonedDateTimeFormat.det(
        locale: locale,
        zoneStyle: zoneStyle,
        length: length,
        precision: precision,
      ),
      DateTimeFieldSet.mdet => IcuZonedDateTimeFormat.mdet(
        locale: locale,
        zoneStyle: zoneStyle,
        length: length,
        precision: precision,
      ),
      DateTimeFieldSet.ymdet => IcuZonedDateTimeFormat.ymdet(
        locale: locale,
        zoneStyle: zoneStyle,
        length: length,
        precision: precision,
        yearStyle: yearStyle,
      ),
    };
  } on IcuError catch (e) {
    errors.add(
      FluentTypeError('Zoned datetime formatter unavailable for $locale: $e'),
    );
    return IcuZonedDateTimeFormat.ymdt(locale: 'en', zoneStyle: zoneStyle);
  }
}
