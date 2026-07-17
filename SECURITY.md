# Security Policy

## Reporting a vulnerability

Report privately via [GitHub Security Advisories](https://github.com/whuppi/fluent_icu/security/advisories/new). Do not open a public issue.

## What's in scope

- **Value misrepresentation** — a formatter output that misrepresents the input (a currency amount rendering as a different quantity, a sign flip, digits dropped beyond documented rounding) is a security report: apps put these strings in front of users making decisions.

- **The degrade contract failing silently** — an unsupported option must render the nearest supported form AND record a `FluentTypeError`. A path that drops an option without the recorded error defeats the auditability the contract exists for.

## What's NOT in scope

- **The ICU4X engine itself** — memory-safety or data issues inside icu_kit / ICU4X belong to [icu_kit's policy](https://github.com/whuppi/icu_kit/blob/dev/SECURITY.md) and upstream.

- **Untrusted-FTL handling** — parsing and resolution guards are [fluent_bundle's scope](https://github.com/whuppi/fluent_bundle/blob/dev/SECURITY.md); this package only formats values.

- **CLDR correctness disputes** — the data is Unicode's; fidelity bugs are [regular issues](https://github.com/whuppi/fluent_icu/issues).

## Response

Valid reports are fixed and shipped as patch versions.
