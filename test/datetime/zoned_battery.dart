library;

// The zoned path (timeZone set): instant conversion through the tz
// database is DST-correct, every timeZoneName style renders, and unknown
// zone ids degrade with a recorded error instead of throwing.

import 'package:fluent_icu/fluent_icu.dart';
import 'package:test/test.dart';

void registerZonedTests() {
  group('IcuBackend — DATETIME zoned path', () {
    late IcuBackend backend;
    setUpAll(() async {
      backend = await IcuBackend.init();
    });

    String render(FluentDateTimeOptions opts, DateTime dt) {
      final b = FluentBundle('en-US', backend: backend, useIsolating: false)
        ..addResource('m = { DATETIME(\$d) }');
      return b.formatMessage('m', args: {'d': FluentDateTime(dt, opts)});
    }

    test('timeZone converts the instant + shows the zone (DST-correct)', () {
      // Noon UTC on 2026-07-15: New York is EDT (UTC-4) → 08:00, Tokyo is
      // GMT+9 → 21:00. The tz database supplies the DST-correct offset.
      final noonUtc = DateTime.utc(2026, 7, 15, 12, 0);
      final ny = render(
        const FluentDateTimeOptions(
          timeStyle: 'short',
          timeZone: 'America/New_York',
          timeZoneName: 'short',
        ),
        noonUtc,
      );
      expect(ny, contains('8:00'));
      expect(ny, contains('EDT'));

      final tokyo = render(
        const FluentDateTimeOptions(
          timeStyle: 'short',
          timeZone: 'Asia/Tokyo',
          timeZoneName: 'shortOffset',
        ),
        noonUtc,
      );
      expect(tokyo, contains('9:00'));
      expect(tokyo, contains('GMT+9'));
    });

    test('timeZoneName long renders the full zone name', () {
      final ny = render(
        const FluentDateTimeOptions(
          timeStyle: 'short',
          timeZone: 'America/New_York',
          timeZoneName: 'long',
        ),
        DateTime.utc(2026, 7, 15, 12, 0),
      );
      expect(ny, contains('Eastern'));
    });

    test('unknown timeZone id degrades, does not throw', () {
      final errs = <FluentError>[];
      final b = FluentBundle('en-US', backend: backend, useIsolating: false)
        ..addResource(r'm = { DATETIME($d, timeZone: "Not/AZone") }');
      final out = b.formatMessage(
        'm',
        args: {'d': DateTime.utc(2026, 7, 15, 12)},
        errors: errs,
      );
      expect(out, isNotEmpty);
      expect(errs, isNotEmpty);
    });
  });
}
