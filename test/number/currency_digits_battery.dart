// The baked CLDR fractions table behind ECMA-402's CurrencyDigits(code).

import 'package:fluent_icu/src/number/currency_digits.dart';
import 'package:test/test.dart';

void registerCurrencyDigitsTests() {
  group('currencyDigits', () {
    test('zero-digit currencies (JPY class)', () {
      for (final code in ['JPY', 'KRW', 'VND', 'CLP', 'ISK']) {
        expect(currencyDigits(code), 0, reason: code);
      }
    });

    test('three- and four-digit currencies', () {
      for (final code in ['BHD', 'JOD', 'KWD', 'OMR', 'TND']) {
        expect(currencyDigits(code), 3, reason: code);
      }
      expect(currencyDigits('CLF'), 4);
      expect(currencyDigits('UYW'), 4);
    });

    test('everything else defaults to 2 (the CLDR DEFAULT)', () {
      expect(currencyDigits('USD'), 2);
      expect(currencyDigits('EUR'), 2);
      expect(currencyDigits('XXX'), 2);
      expect(currencyDigits(null), 2);
      expect(currencyDigits('nonsense'), 2);
    });
  });
}
