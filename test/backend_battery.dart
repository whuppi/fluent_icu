library;

import 'package:fluent_icu/fluent_icu.dart';
import 'package:test/test.dart';

void registerBackendTests() {
  group('IcuBackend (native)', () {
    late IcuBackend backend;
    setUpAll(() async {
      backend = await IcuBackend.init();
    });

    test('locale-aware NUMBER with grouping', () {
      final b = FluentBundle('en', backend: backend, useIsolating: false)
        ..addResource('m = { NUMBER(\$n) }');
      expect(b.formatMessage('m', args: {'n': 1234567}), '1,234,567');
    });

    test('plural selection (cardinal) for Polish', () {
      final b = FluentBundle('pl', backend: backend, useIsolating: false)
        ..addResource(
          'n = { \$x ->\n [one] one\n [few] few\n [many] many\n *[other] other\n}',
        );
      expect(b.formatMessage('n', args: {'x': 1}), 'one');
      expect(b.formatMessage('n', args: {'x': 2}), 'few');
      expect(b.formatMessage('n', args: {'x': 5}), 'many');
    });

    test('ordinal plural selection for English', () {
      final b = FluentBundle('en', backend: backend, useIsolating: false)
        ..addResource(
          'o = { NUMBER(\$x, type: "ordinal") ->\n [one] st\n [two] nd\n [few] rd\n *[other] th\n}',
        );
      expect(b.formatMessage('o', args: {'x': 1}), 'st');
      expect(b.formatMessage('o', args: {'x': 2}), 'nd');
      expect(b.formatMessage('o', args: {'x': 3}), 'rd');
      expect(b.formatMessage('o', args: {'x': 4}), 'th');
    });
  });
}
