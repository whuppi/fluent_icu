import 'package:fluent_bundle/testing.dart';
import 'package:fluent_icu/fluent_icu.dart';
import 'package:test/test.dart';

void registerConformanceTests() {
  group('IcuBackend conformance', () {
    // icu_kit must be initialized once before any format call.
    setUpAll(IcuBackend.init);

    // ICU4X gives real CLDR categories AND — via icu_kit's categoryOfDecimal
    // (E1) fed with core's resolveDigits string — honors visible fraction
    // digits (the F8 case). Both plural flags stay at their default true.
    //
    // Every ECMA-402 option this backend supports is declared true and
    // proven by the harness. scientificNotation and accountingCurrencySign
    // stay false — ICU4X ships no exponent-symbol / accounting-pattern
    // data — and recordsUnsupportedOptionErrors proves both degrade with
    // a recorded error instead of failing silently.
    const expectations = BackendExpectations(
      recordsUnsupportedOptionErrors: true,
    );
    for (final check in fluentBackendConformanceChecks(
      IcuBackend.new,
      expectations: expectations,
    )) {
      test(check.name, check.run);
    }
  });
}
