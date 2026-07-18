library;

// §8.8 datetime mapping — the FluentDateTimeOptions fields that ICU4X reads
// from the locale's `-u-` extension (calendar, hour12, numberingSystem) take
// effect end-to-end via applyDateTimeLocaleExtensions. Other axes
// (dateStyle/timeStyle, fractionalSeconds) are covered by the facade tests;
// the zoned path (timeZone / timeZoneName) is covered in zoned_test.dart.

import 'package:fluent_icu/fluent_icu.dart';
import 'package:test/test.dart';

void registerDatetimeMapTests() {
  group('IcuBackend — DATETIME locale-extension options (§8.8)', () {
    late IcuBackend backend;
    setUpAll(() async {
      backend = await IcuBackend.init();
    });

    // A fixed local DateTime so the clock time is stable within one run.
    String render(FluentDateTimeOptions opts) {
      final b = FluentBundle('en-US', backend: backend, useIsolating: false)
        ..addResource('m = { DATETIME(\$d) }');
      return b.formatMessage(
        'm',
        args: {'d': FluentDateTime(DateTime(2026, 4, 29, 15, 4, 5), opts)},
      );
    }

    test('hour12: true renders a day-period marker; false does not', () {
      final twelve = render(
        const FluentDateTimeOptions(timeStyle: 'short', hour12: true),
      );
      final twentyFour = render(
        const FluentDateTimeOptions(timeStyle: 'short', hour12: false),
      );
      expect(
        RegExp(r'[AP]M').hasMatch(twelve),
        isTrue,
        reason: 'hour12:true should show AM/PM, got "$twelve"',
      );
      expect(
        RegExp(r'[AP]M').hasMatch(twentyFour),
        isFalse,
        reason: 'hour12:false should be 24h, got "$twentyFour"',
      );
    });

    test('numberingSystem: arab renders Arabic-Indic digits', () {
      final out = render(
        const FluentDateTimeOptions(
          dateStyle: 'short',
          numberingSystem: 'arab',
        ),
      );
      // Arabic-Indic digits occupy U+0660..U+0669.
      final hasArabicDigit = out.runes.any((r) => r >= 0x0660 && r <= 0x0669);
      expect(
        hasArabicDigit,
        isTrue,
        reason: 'expected Arabic-Indic digits, got "$out"',
      );
    });

    test('calendar: japanese changes the rendering vs gregorian', () {
      final gregorian = render(const FluentDateTimeOptions(dateStyle: 'long'));
      final japanese = render(
        const FluentDateTimeOptions(dateStyle: 'long', calendar: 'japanese'),
      );
      expect(
        japanese,
        isNot(equals(gregorian)),
        reason: 'japanese calendar should differ from gregorian',
      );
    });

    test('era shows the era designator (IcuYearStyle.withEra)', () {
      // A year-bearing set with era set renders "AD" (or the locale era);
      // without era, the default gregorian long date omits it.
      final withEra = render(
        const FluentDateTimeOptions(
          year: 'numeric',
          month: 'long',
          day: 'numeric',
          era: 'short',
        ),
      );
      expect(
        withEra,
        contains('AD'),
        reason: 'era: short should render the AD designator, got "$withEra"',
      );
    });
  });
}
