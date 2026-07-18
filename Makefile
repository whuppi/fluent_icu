.PHONY: check hooks lint-shell analyze analyze-floor platforms test-guards format test web-assets test-web test-example clean

# ═══════════════════════════════════════════════════════════════════
# SDK resolution
#
# Uses fvm by default. Contributors without fvm can override:
# make check DART=dart
# fluent_icu is pure Dart — but its icu_kit dependency's build hook
# compiles ICU4X from vendored Rust on first test run (needs the Rust
# toolchain); incremental cargo caches make later runs fast.
# ═══════════════════════════════════════════════════════════════════

DART    ?= fvm dart
# analyze_core.sh requires FLUTTER even in pure-Dart packages (it
# analyzes a Flutter example when one exists; ours are bare files).
FLUTTER ?= fvm flutter
TEST_RESULTS_DIR ?= test-results
TIMEOUT := $(if $(CI),--timeout=30x,)
VERBOSE := $(if $(CI),--verbose,)

# ═══════════════════════════════════════════════════════════════════
# § 1 — Gate
# ═══════════════════════════════════════════════════════════════════
#
# make check    Full local gate before handing work over.

check: lint-shell analyze analyze-floor platforms test-guards test test-web test-example

# make hooks    Activate the repo's git hooks (commit-msg, pre-commit).
#               Run once after cloning — they stay dormant otherwise.
#               Idempotent. The hooks live at the repo root
#               (.githooks/), stamped from the shared whuppi set.
hooks:
	@git config core.hooksPath .githooks
	@echo "✓ git hooks active (core.hooksPath → .githooks)"

# make lint-shell  Shell portability gate: shellcheck + a bash-version scan
#                  over the repo's shell scripts. Shared gate
#                  tool/lint_shell.sh (canonical in whuppi/ci, stamped).
lint-shell:
	@bash tool/lint_shell.sh


# make platforms  Gate pub.dev platform support: pana (the exact analyzer
#                 pub.dev runs, pinned via tool/versions.env) must report all
#                 6 platforms, else a regression like an unconditional dart:io
#                 import in the wrong layer silently drops a platform. Shared
#                 gate tool/platforms_gate.sh (canonical in whuppi/ci, stamped).
platforms:
	@DART="$(DART)" EXPECTED_PLATFORMS="android ios linux macos windows web" bash tool/platforms_gate.sh

# ═══════════════════════════════════════════════════════════════════
# § 2 — Analyze
# ═══════════════════════════════════════════════════════════════════
#
# make analyze  Resolve, format, analyze at --fatal-infos. Resolve runs
#               FIRST because `dart format` reads the resolved language
#               version — an unresolved tree formats differently.
#               Locally format fixes in place; under CI a diff fails.

analyze:
	@echo "=== Dart: pub get ==="
	@$(DART) pub get
	@echo "=== Dart: format ==="
	@if [ -n "$$CI" ]; then \
	  $(DART) format --set-exit-if-changed lib test example; \
	else \
	  $(DART) format lib test example; \
	fi
	@echo "=== Dart: analyze (shared core) ==="
	@DART="$(DART)" FLUTTER="$(FLUTTER)" ANALYZE_DIRS="lib test tool example" EXAMPLE_DIR="" bash tool/analyze_core.sh

# make analyze-floor  Resolve to the OLDEST in-range dependencies and
#                     analyze the shipped code (lib). The wide lower
#                     bounds are only honest if the code analyzes against
#                     them, not just the newest a fresh resolve picks.
#                     Tests are excluded on purpose — a consumer sees
#                     lib, never your tests. Snapshots and restores the
#                     lock so a local run leaves the tree clean.
analyze-floor:
	@$(DART) pub get >/dev/null
	@cp pubspec.lock pubspec.lock.floorbak; \
	$(DART) pub downgrade >/dev/null && $(DART) analyze --fatal-infos lib; rc=$$?; \
	mv pubspec.lock.floorbak pubspec.lock; \
	$(DART) pub get >/dev/null 2>&1 || true; \
	exit $$rc

# make format   Format in place (analyze also formats; this is the
#               standalone entry).
format:
	@$(DART) format lib test example

# make test-guards  Mechanical confinement rule: icu_kit's @experimental
#                   facades (percent / currency / unit / compact) are wrapped
#                   ONLY in lib/src/number/styles.dart — the file the
#                   analysis_options severity override is documented against.
#                   Code usage anywhere else means the confinement broke;
#                   route it through StyleCaches instead. Doc-comment
#                   mentions don't count.
test-guards:
	@bad=$$(grep -rnE "Icu(Percent|Currency|Unit|Compact)Format" lib --include="*.dart" \
	  | grep -v "lib/src/number/styles.dart" \
	  | grep -vE ":[0-9]+:\s*///?" \
	  || true); \
	if [ -n "$$bad" ]; then \
	  echo "experimental icu_kit facade used outside styles.dart:"; \
	  echo "$$bad"; exit 1; fi
	@echo "✓ test guards clean"

# ═══════════════════════════════════════════════════════════════════
# § 3 — Test
# ═══════════════════════════════════════════════════════════════════
#
# make test     The full VM suite: conformance harness, fluent-rs corpus
#               through IcuBackend, and the behavioral per-concern suites.

test:
	@echo "=== VM suite (icu_kit's hook compiles ICU4X on first run) ==="
	@mkdir -p $(TEST_RESULTS_DIR)
	@$(DART) test $(TIMEOUT) --file-reporter json:$(TEST_RESULTS_DIR)/vm.json

# make web-assets  Install icu_kit's web engine (WASM + JS bindings) into
#                  web/icu_kit/ (gitignored) via icu_kit's own setup command
#                  — the released prebuilt on a hosted dep, the sibling
#                  checkout's build on the path dep. Hash-verified either
#                  way. Re-run after an icu_kit bump.
web-assets:
	@$(DART) run icu_kit:setup web

# make test-web  The showcase over the WASM engine in real Chrome — the
#                byte-identical-output claim, asserted against the same
#                pinned strings the native lane uses.
test-web: web-assets
	@echo "=== Chrome suite (dart test -p chrome) ==="
	@mkdir -p $(TEST_RESULTS_DIR)
	@$(DART) test -p chrome $(TIMEOUT) test/web --file-reporter json:$(TEST_RESULTS_DIR)/web.json

# make test-example  The pub.dev showcase (example/main.dart) run with
#                    its output pinned — every Example-tab claim proven.
test-example:
	@echo "=== Example showcase (pinned output) ==="
	@mkdir -p $(TEST_RESULTS_DIR)
	@$(DART) test $(TIMEOUT) test/example --file-reporter json:$(TEST_RESULTS_DIR)/example.json

# ═══════════════════════════════════════════════════════════════════
# § 4 — Clean
# ═══════════════════════════════════════════════════════════════════

clean:
	@rm -rf .dart_tool $(TEST_RESULTS_DIR)
	@echo "✓ clean (icu_kit's cargo caches are its own — clean there if you mean it)"
