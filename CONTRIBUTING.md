# Contributing

Contributions are welcome.

---

## Setup

```bash
git clone https://github.com/whuppi/fluent_icu.git
cd fluent_icu
make hooks               # activates commit-msg + pre-commit (run once)
fvm install              # downloads the SDK version pinned in .fvmrc
fvm dart pub get

# icu_kit's build hook fetches its prebuilt engine on the first test run
# (it compiles from vendored source only if the download is unavailable).
fvm dart test
```

**Requires:** [FVM](https://fvm.app) (`.fvmrc` pins the exact SDK
version).

**Without FVM:** all Makefile commands accept `DART` and `FLUTTER`
overrides:

```bash
make check DART=dart FLUTTER=flutter
```

---

## Before submitting a PR

```bash
make check
```

Runs `lint-shell` + `analyze` + `analyze-floor` + `platforms` (the
same pana pub.dev runs) + `test-guards` (experimental-facade
confinement) + `test` (VM, native engine) + `test-web` (the same
showcase over the WASM engine in real Chrome) + `test-example` (the
pinned showcase).
Must pass. Don't suppress with `// ignore:` — fix the underlying
issue.

---

## PR workflow

All PRs target `dev`. That's the only branch contributors touch.

```
your fork / feature branch ──PR──► dev
                                    ↓ CI: make targets via the make-target action
                                    ↓ PR title: Conventional Commits (feat: / fix: / etc.)
                                    ↓ squash-merge when green
                                    ↓ Full test suite via "ready-to-test" label
                                      (suites × OS matrix)
```

CI calls Makefile targets — same commands locally and in CI.

You don't write changelog entries, bump versions, or touch `prod`.
The maintainer handles releases.

---

## Code style

- Match existing code in the repo.
- The degrade contract is sacred: an option ICU4X can't honor renders
  the nearest supported form AND records a `FluentTypeError` — never a
  silent drop, never a throw. The conformance harness pins both
  directions for every declared gap.
- icu_kit's `@experimental` facades are wrapped ONLY in
  `lib/src/number/styles.dart` — `make test-guards` enforces the
  confinement.
- The chrome lane asserts the SAME pinned strings as the native lane —
  a new pinned output goes in both suites, invisible characters as
  `\uXXXX` escapes.

---

## Maintenance recipes

Step-by-step recipes (icu_kit bumps, the upstream-watch ledger) live
in [`docs/UPDATING.md`](docs/UPDATING.md).

---

## Releases

Handled by the maintainer, via the family release checklist
(the fluent_bundle repo's `docs/UPDATING.md`).
