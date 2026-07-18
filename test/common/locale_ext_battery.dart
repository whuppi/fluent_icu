import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:fluent_icu/src/common/locale_ext.dart';
import 'package:test/test.dart';

void registerLocaleExtTests() {
  group('applyDateTimeLocaleExtensions', () {
    test('no relevant options → locale unchanged', () {
      expect(
        applyDateTimeLocaleExtensions('en-US', const FluentDateTimeOptions()),
        'en-US',
      );
      expect(
        applyDateTimeLocaleExtensions(
          'en-US',
          const FluentDateTimeOptions(dateStyle: 'short'),
        ),
        'en-US',
      );
    });

    test('single keyword opens a -u- extension', () {
      expect(
        applyDateTimeLocaleExtensions(
          'en-US',
          const FluentDateTimeOptions(hour12: true),
        ),
        'en-US-u-hc-h12',
      );
      expect(
        applyDateTimeLocaleExtensions(
          'en-US',
          const FluentDateTimeOptions(hour12: false),
        ),
        'en-US-u-hc-h23',
      );
    });

    test('keywords emit in canonical order ca < hc < nu', () {
      expect(
        applyDateTimeLocaleExtensions(
          'en-US',
          const FluentDateTimeOptions(
            numberingSystem: 'arab',
            hour12: true,
            calendar: 'japanese',
          ),
        ),
        'en-US-u-ca-japanese-hc-h12-nu-arab',
      );
    });

    test('dayPeriod implies 12-hour cycle (best-fit)', () {
      expect(
        applyDateTimeLocaleExtensions(
          'en-US',
          const FluentDateTimeOptions(dayPeriod: 'short'),
        ),
        'en-US-u-hc-h12',
      );
    });

    test('explicit hour12:false wins over dayPeriod', () {
      expect(
        applyDateTimeLocaleExtensions(
          'en-US',
          const FluentDateTimeOptions(hour12: false, dayPeriod: 'short'),
        ),
        'en-US-u-hc-h23',
      );
    });

    test('existing -u- extension is appended to, not doubled', () {
      expect(
        applyDateTimeLocaleExtensions(
          'en-US-u-ca-buddhist',
          const FluentDateTimeOptions(numberingSystem: 'arab'),
        ),
        'en-US-u-ca-buddhist-nu-arab',
      );
    });

    test('explicit hourCycle folds directly and wins over hour12', () {
      expect(
        applyDateTimeLocaleExtensions(
          'en-US',
          const FluentDateTimeOptions(hourCycle: 'h24'),
        ),
        'en-US-u-hc-h24',
      );
      expect(
        applyDateTimeLocaleExtensions(
          'en-US',
          const FluentDateTimeOptions(hourCycle: 'h23', hour12: true),
        ),
        'en-US-u-hc-h23',
      );
    });
  });

  group('applyNumberLocaleExtensions', () {
    test('numberingSystem folds as -u-nu-', () {
      expect(
        applyNumberLocaleExtensions(
          'en-US',
          const FluentNumberOptions(numberingSystem: 'arab'),
        ),
        'en-US-u-nu-arab',
      );
      expect(
        applyNumberLocaleExtensions('en-US', const FluentNumberOptions()),
        'en-US',
      );
    });

    test('existing -u- extension is appended to, not doubled', () {
      expect(
        applyNumberLocaleExtensions(
          'en-US-u-ca-buddhist',
          const FluentNumberOptions(numberingSystem: 'deva'),
        ),
        'en-US-u-ca-buddhist-nu-deva',
      );
    });

    test('option overrides an existing key instead of duplicating it', () {
      // A duplicate key (fa-u-nu-arabext-nu-latn) parses FIRST-wins, so
      // the option would silently lose to the caller's tag.
      expect(
        applyNumberLocaleExtensions(
          'fa-u-nu-arabext',
          const FluentNumberOptions(numberingSystem: 'latn'),
        ),
        'fa-u-nu-latn',
      );
    });
  });

  group('keyword override across the -u- extension', () {
    test('DATETIME options override matching existing keys only', () {
      expect(
        applyDateTimeLocaleExtensions(
          'en-US-u-ca-buddhist-hc-h23',
          const FluentDateTimeOptions(hourCycle: 'h12'),
        ),
        'en-US-u-ca-buddhist-hc-h12',
      );
    });

    test('multi-subtag calendar values survive an override', () {
      expect(
        applyDateTimeLocaleExtensions(
          'ar-u-ca-islamic-civil',
          const FluentDateTimeOptions(numberingSystem: 'latn'),
        ),
        'ar-u-ca-islamic-civil-nu-latn',
      );
      expect(
        applyDateTimeLocaleExtensions(
          'ar-u-ca-islamic-civil',
          const FluentDateTimeOptions(calendar: 'gregory'),
        ),
        'ar-u-ca-gregory',
      );
    });

    test('non-u extensions pass through untouched', () {
      expect(
        applyNumberLocaleExtensions(
          'en-u-nu-arab-x-private',
          const FluentNumberOptions(numberingSystem: 'latn'),
        ),
        'en-u-nu-latn-x-private',
      );
    });
  });
}
