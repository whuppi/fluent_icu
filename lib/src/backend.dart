import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:fluent_icu/src/datetime/datetime_map.dart';
import 'package:fluent_icu/src/number/number_map.dart';
import 'package:fluent_icu/src/plural/plural_map.dart';
import 'package:icu_kit/icu_kit.dart';

/// A [FluentBackend] backed by ICU4X via `icu_kit`: full ECMA-402 number,
/// currency, percent, and unit formatting, date/time across many calendars
/// and numbering systems, and CLDR plural rules for every locale (both
/// cardinal and ordinal).
///
/// icu_kit must be initialized once before formatting. The convenience
/// [IcuBackend.init] does that for you; or call `IcuKit.init(...)` yourself
/// and construct `IcuBackend()`.
///
/// ```dart
/// final backend = await IcuBackend.init();
/// final bundle = FluentBundle('hi', backend: backend);
/// ```
class IcuBackend extends FluentBackend {
  /// Creates the backend. Assumes `IcuKit.init` has already completed.
  IcuBackend()
    : _formatNumber = createIcuNumberFormatter(),
      _formatDateTime = createIcuDateTimeFormatter();

  final String Function(FluentNumber, String, List<FluentError>) _formatNumber;
  final String Function(FluentDateTime, String, List<FluentError>)
  _formatDateTime;

  /// Initializes icu_kit (native / WASM / browser-Intl per [webEngine], with
  /// the given [data]) and returns a ready backend. The one async step is at
  /// this boundary; every format call after it is synchronous.
  static Future<IcuBackend> init({IcuData? data, WebEngine? webEngine}) async {
    await IcuKit.init(
      data: data ?? IcuData.bundled(),
      webEngine: webEngine ?? WebEngine.icu4x,
    );
    return IcuBackend();
  }

  @override
  PluralCategory pluralCategory(
    FluentNumber value,
    PluralRuleType type,
    FluentFormatContext context,
  ) => icuPluralRules(
    value.value,
    context.locale,
    type: type == PluralRuleType.ordinal ? 'ordinal' : 'cardinal',
    // Visible fraction digits (CLDR operand `v`) drive selection —
    // NUMBER($n, minimumFractionDigits: 1) with n=1 selects `other`,
    // not `one`, in English. resolveDigits produces the exact string.
    digits: value.resolveDigits().digits,
  );

  @override
  String formatNumber(FluentNumber value, FluentFormatContext context) =>
      _formatNumber(value, context.locale, context.errors);

  @override
  String formatDateTime(FluentDateTime value, FluentFormatContext context) =>
      _formatDateTime(value, context.locale, context.errors);
}
