// VM lane — every battery on the native FFI engine (icu_kit's build hook
// provisions it). The web showcase is Chrome-only and lives in the web
// runner; `test-guards` enforces the battery/runner membership rules.
@TestOn('vm')
library;

import 'package:test/test.dart';

import '../_corpus/bundle_corpus_battery.dart';
import '../backend_battery.dart';
import '../common/locale_ext_battery.dart';
import '../conformance_battery.dart';
import '../datetime/datetime_map_battery.dart';
import '../datetime/field_mapping_battery.dart';
import '../datetime/zoned_battery.dart';
import '../example/example_battery.dart';
import '../number/currency_digits_battery.dart';
import '../number/number_map_battery.dart';
import '../number/shaping_battery.dart';
import '../plural/plural_map_battery.dart';

void main() {
  group('bundle_corpus', registerBundleCorpusTests);
  group('backend', registerBackendTests);
  group('locale_ext', registerLocaleExtTests);
  group('conformance', registerConformanceTests);
  group('datetime_map', registerDatetimeMapTests);
  group('field_mapping', registerFieldMappingTests);
  group('zoned', registerZonedTests);
  group('example', registerExampleTests);
  group('currency_digits', registerCurrencyDigitsTests);
  group('number_map', registerNumberMapTests);
  group('shaping', registerShapingTests);
  group('plural_map', registerPluralMapTests);
}
