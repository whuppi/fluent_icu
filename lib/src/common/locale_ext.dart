import 'package:fluent_bundle/fluent_bundle.dart';

/// Fold the DATETIME options that ICU4X reads from a locale's BCP-47 `-u-`
/// extension — calendar, hour cycle (`hour12`), numbering system — into an
/// extended locale tag, e.g. `en-US` + `{calendar: japanese, hour12: true}`
/// → `en-US-u-ca-japanese-hc-h12`.
///
/// ICU4X honors these keywords directly on the parsed locale, so building the
/// tag is the entire mechanism — no separate facade plumbing. Keys are emitted
/// in canonical alphabetical order (`ca`, `hc`, `nu`). Option keywords WIN
/// over any value [locale] already carries for the same key.
String applyDateTimeLocaleExtensions(
  String locale,
  FluentDateTimeOptions opts,
) {
  final keywords = <String, String>{};
  if (opts.calendar != null) {
    keywords['ca'] = opts.calendar!;
  }
  // Hour-cycle precedence: an explicit `hourCycle` (h11/h12/h23/h24) wins
  // over the coarser `hour12`. Requesting `dayPeriod` means "show the
  // day-period marker"; that only renders under a 12-hour cycle, so a bare
  // dayPeriod implies h12 (best-fit — ICU4X 2.2 has no standalone dayPeriod
  // width knob).
  if (opts.hourCycle != null) {
    keywords['hc'] = opts.hourCycle!;
  } else {
    final hour12 = opts.hour12 ?? (opts.dayPeriod != null ? true : null);
    if (hour12 != null) {
      keywords['hc'] = hour12 ? 'h12' : 'h23';
    }
  }
  if (opts.numberingSystem != null) {
    keywords['nu'] = opts.numberingSystem!;
  }
  return _setUnicodeKeywords(locale, keywords);
}

/// Fold the NUMBER options ICU4X reads from a locale's `-u-` extension —
/// today just the numbering system — into an extended tag, e.g. `en` +
/// `{numberingSystem: arab}` → `en-u-nu-arab`. Every number-style
/// formatter constructs against the folded locale, so the digits render
/// in the requested system on all engines. The option WINS over a `nu`
/// value [locale] already carries.
String applyNumberLocaleExtensions(String locale, FluentNumberOptions opts) {
  final ns = opts.numberingSystem;
  if (ns == null) return locale;
  return _setUnicodeKeywords(locale, {'nu': ns});
}

/// Set (or override) keywords in [locale]'s BCP-47 `-u-` extension.
///
/// Option-provided keywords WIN over any value the caller's tag already
/// carries: `fa-u-nu-arabext` + `{nu: latn}` → `fa-u-nu-latn` — never the
/// duplicate-key `fa-u-nu-arabext-nu-latn`, whose FIRST value wins at
/// parse time and would silently ignore the option. Keys are emitted in
/// canonical alphabetical order; keys the options don't touch (and any
/// non-`u` extensions like `-t-` / `-x-`) pass through untouched.
String _setUnicodeKeywords(String locale, Map<String, String> keywords) {
  if (keywords.isEmpty) return locale;
  final parts = locale.split('-');

  // Locate the `u` singleton's section: it runs from the subtag after
  // `u` until the next singleton (another extension or private use).
  var uPos = -1;
  var uEnd = parts.length;
  for (var i = 1; i < parts.length; i++) {
    if (parts[i].length != 1) continue;
    if (uPos < 0) {
      if (parts[i].toLowerCase() == 'u') uPos = i;
    } else {
      uEnd = i;
      break;
    }
  }

  // Parse the existing section into attributes + key→value (a key is a
  // 2-char subtag; its value is every following subtag until the next
  // key, dash-joined — multi-subtag values like `ca-islamic-civil` stay
  // intact).
  final merged = <String, String>{};
  final attributes = <String>[];
  if (uPos >= 0) {
    String? key;
    final valueBuf = <String>[];
    void flush() {
      final k = key;
      if (k != null) merged[k] = valueBuf.join('-');
      valueBuf.clear();
    }

    for (var i = uPos + 1; i < uEnd; i++) {
      final p = parts[i];
      if (p.length == 2) {
        flush();
        key = p;
      } else if (key == null) {
        attributes.add(p);
      } else {
        valueBuf.add(p);
      }
    }
    flush();
  }
  merged.addAll(keywords);

  final keys = merged.keys.toList()..sort();
  final section = [
    ...attributes,
    for (final k in keys) ...[k, if (merged[k]!.isNotEmpty) merged[k]!],
  ].join('-');

  if (uPos < 0) return '$locale-u-$section';
  final prefix = parts.sublist(0, uPos + 1).join('-');
  final suffix = uEnd < parts.length ? '-${parts.sublist(uEnd).join('-')}' : '';
  return '$prefix-$section$suffix';
}
