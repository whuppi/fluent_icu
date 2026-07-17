/// ICU4X backend for Project Fluent — full ECMA-402 formatting and
/// every-locale plural rules for `fluent_bundle`, via `icu_kit`.
///
/// This barrel re-exports the entire `fluent_bundle` runtime, so a single
/// import gives you `FluentBundle` plus `IcuBackend`:
///
/// ```dart
/// import 'package:fluent_icu/fluent_icu.dart';
///
/// final backend = await IcuBackend.init();
/// final bundle = FluentBundle('hi', backend: backend);
/// ```
///
/// Works across all icu_kit engines (native FFI, full or lean WASM, or the
/// browser's built-in Intl) with the same API. Numbers, currencies,
/// percents, units, dates across many calendars and numbering systems, and
/// CLDR plurals for every locale.
library;

export 'package:fluent_bundle/fluent_bundle.dart';

export 'src/backend.dart' show IcuBackend;
