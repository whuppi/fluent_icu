// The ECMA-402 → ICU4X constructor decision tables: which field set,
// length, year style, and precision an option bag resolves to. Pure
// functions, no icu_kit engine needed.

import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:fluent_icu/src/datetime/field_mapping.dart';
import 'package:icu_kit/icu_kit.dart';
import 'package:test/test.dart';

void registerFieldMappingTests() {
  group('pickDateFieldSet', () {
    test('dateStyle full forces the weekday-bearing set', () {
      expect(
        pickDateFieldSet(const FluentDateTimeOptions(dateStyle: 'full')),
        DateFieldSet.ymde,
      );
    });

    test('per-field flags pick the smallest covering set', () {
      expect(
        pickDateFieldSet(
          const FluentDateTimeOptions(
            year: 'numeric',
            month: 'long',
            day: 'numeric',
          ),
        ),
        DateFieldSet.ymd,
      );
      expect(
        pickDateFieldSet(
          const FluentDateTimeOptions(month: 'long', day: 'numeric'),
        ),
        DateFieldSet.md,
      );
      expect(
        pickDateFieldSet(const FluentDateTimeOptions(weekday: 'long')),
        DateFieldSet.e,
      );
      expect(
        pickDateFieldSet(const FluentDateTimeOptions(year: 'numeric')),
        DateFieldSet.y,
      );
    });

    test('no fields defaults to the fully-qualified date', () {
      expect(
        pickDateFieldSet(const FluentDateTimeOptions(dateStyle: 'medium')),
        DateFieldSet.ymd,
      );
    });
  });

  group('pickDateTimeFieldSet', () {
    test('dateStyle full forces the weekday-bearing set', () {
      expect(
        pickDateTimeFieldSet(const FluentDateTimeOptions(dateStyle: 'full')),
        DateTimeFieldSet.ymdet,
      );
    });

    test('per-field flags pick the smallest covering set', () {
      expect(
        pickDateTimeFieldSet(
          const FluentDateTimeOptions(
            month: 'long',
            day: 'numeric',
            hour: 'numeric',
          ),
        ),
        DateTimeFieldSet.mdt,
      );
      expect(
        pickDateTimeFieldSet(
          const FluentDateTimeOptions(day: 'numeric', weekday: 'short'),
        ),
        DateTimeFieldSet.det,
      );
    });

    test('style-only bags fall back to ymdt', () {
      expect(
        pickDateTimeFieldSet(const FluentDateTimeOptions(timeStyle: 'short')),
        DateTimeFieldSet.ymdt,
      );
    });
  });

  group('pickLength / pickYearStyle / pickPrecision', () {
    test('style strings map onto IcuDateLength (medium default)', () {
      expect(pickLength('full'), IcuDateLength.full);
      expect(pickLength('long'), IcuDateLength.long);
      expect(pickLength('short'), IcuDateLength.short);
      expect(pickLength('medium'), IcuDateLength.medium);
      expect(pickLength(null), IcuDateLength.medium);
    });

    test('era requests the with-era year style', () {
      expect(
        pickYearStyle(const FluentDateTimeOptions(era: 'short')),
        IcuYearStyle.withEra,
      );
      expect(pickYearStyle(const FluentDateTimeOptions()), isNull);
    });

    test('fractionalSecondDigits overrides everything else', () {
      expect(
        pickPrecision(
          const FluentDateTimeOptions(
            fractionalSecondDigits: 3,
            timeStyle: 'short',
          ),
        ),
        IcuTimePrecision.subsecond3,
      );
    });

    test('field flags then timeStyle decide the precision', () {
      expect(
        pickPrecision(const FluentDateTimeOptions(second: 'numeric')),
        IcuTimePrecision.second,
      );
      expect(
        pickPrecision(const FluentDateTimeOptions(hour: 'numeric')),
        IcuTimePrecision.minute,
      );
      expect(
        pickPrecision(const FluentDateTimeOptions(timeStyle: 'medium')),
        IcuTimePrecision.second,
      );
      expect(
        pickPrecision(const FluentDateTimeOptions(timeStyle: 'short')),
        IcuTimePrecision.minute,
      );
    });
  });
}
