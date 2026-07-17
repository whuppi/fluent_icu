/// Per-currency minor-unit digit counts (CLDR supplemental currency
/// fractions, `_digits` attribute), for ECMA-402's `CurrencyDigits(code)`
/// default: JPY renders "¥500", BHD "BD 5.000", everything absent here 2.
///
/// Hand-baked because ICU4X ships no per-currency fraction data — the
/// upstream-watch ledger (this package's docs/UPDATING.md) tracks
/// retiring this table if it ever does. package:intl carries the same
/// CLDR-derived digits internally, so both backends agree.
///
/// Source of truth (re-sync when bumping the CLDR pin):
/// https://github.com/unicode-org/cldr-json/blob/47.0.0/cldr-json/cldr-core/supplemental/currencyData.json
/// — take every `fractions` entry whose `_digits` differs from the
/// DEFAULT of 2. Currently CLDR 47. Historical codes (ITL, LUF, …) are
/// kept: they cost bytes, not correctness.
library;

const Map<String, int> _currencyDigits = {
  // 0 minor-unit digits
  'ADP': 0, 'AFN': 0, 'ALL': 0, 'BIF': 0, 'BYR': 0, 'CLP': 0, 'DJF': 0,
  'ESP': 0, 'GNF': 0, 'IQD': 0, 'IRR': 0, 'ISK': 0, 'ITL': 0, 'JPY': 0,
  'KMF': 0, 'KPW': 0, 'KRW': 0, 'LAK': 0, 'LBP': 0, 'LUF': 0, 'MGA': 0,
  'MGF': 0, 'MMK': 0, 'MRO': 0, 'PYG': 0, 'RSD': 0, 'RWF': 0, 'SLL': 0,
  'SOS': 0, 'STD': 0, 'SYP': 0, 'TMM': 0, 'TRL': 0, 'UGX': 0, 'UYI': 0,
  'VND': 0, 'VUV': 0, 'XAF': 0, 'XOF': 0, 'XPF': 0, 'YER': 0, 'ZMK': 0,
  'ZWD': 0,
  // 3 minor-unit digits
  'BHD': 3, 'JOD': 3, 'KWD': 3, 'LYD': 3, 'OMR': 3, 'TND': 3,
  // 4 minor-unit digits
  'CLF': 4, 'UYW': 4,
};

/// ECMA-402 `CurrencyDigits(code)`: the currency's minor-unit count, or
/// 2 when the code is unknown (including null / malformed — the caller
/// degrades those to decimal separately).
int currencyDigits(String? code) => _currencyDigits[code] ?? 2;
