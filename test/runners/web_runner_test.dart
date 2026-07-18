// Chrome lane — the WASM-engine showcase (byte-identical output vs the
// VM lane's native run). Needs `make web-assets` first; the wasm module
// URL inside the battery is relative to this page's depth.
@TestOn('chrome')
library;

import 'package:test/test.dart';

import '../web/showcase_chrome_battery.dart';

void main() {
  group('showcase_chrome', registerShowcaseChromeTests);
}
