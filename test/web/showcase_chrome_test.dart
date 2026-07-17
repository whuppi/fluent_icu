// The SAME showcase, in a real browser — the byte-identical-output claim,
// tested literally. The VM lane runs example/main.dart over native FFI
// (test/example/); this lane runs the identical showcase over the WASM
// engine in Chrome and asserts the identical pinned strings. One line of
// drift between the engines fails here before any user sees it.
//
// Assets: `make web-assets` installs icu_kit's wasm + JS bindings into
// web/icu_kit/ (gitignored) via `dart run icu_kit:setup web` — the
// released prebuilt on a hosted icu_kit dep, the sibling checkout's
// build on the path dep. The moduleUrl below is relative to this test
// PAGE (served at test/web/), not the package root.
@TestOn('chrome')
library;

import 'package:icu_kit/icu_kit.dart' show IcuKit;
import 'package:test/test.dart';

import '../../example/main.dart';

void main() {
  late Map<String, String> lines;

  setUpAll(() async {
    IcuKit.moduleUrl = '../../web/icu_kit/lib/index.mjs';
    final showcase = await runShowcase();
    lines = {
      for (final line in showcase)
        line.substring(0, line.indexOf(': ')): line.substring(
          line.indexOf(': ') + 2,
        ),
    };
  });

  test('numbers render identically to the native lane', () {
    expect(lines['number.en'], '1,234,567.89');
    expect(lines['number.de'], '1.234.567,89');
    expect(lines['number.deva'], '१२,३४,५६७.८९');
    expect(lines['number.compact'], '1.2M');
    expect(lines['number.signed'], '+5');
    expect(lines['number.percent'], '42%');
  });

  test('currency and units render identically to the native lane', () {
    expect(lines['currency.usd'], r'$1,234.50');
    expect(lines['currency.jpy'], '¥1,235');
    expect(lines['unit.speed'], '120 km/h');
    expect(lines['unit.long'], '3 meters');
  });

  test('dates render identically to the native lane', () {
    expect(lines['datetime.styled.de'], 'Donnerstag, 15. Januar 2026');
    expect(lines['datetime.buddhist'], '2569 BE');
    // CLDR separates the time from the day period with U+202F (narrow
    // no-break space) — escaped so the invisible byte is visible here.
    expect(lines['datetime.zoned'], 'Jan 15, 2026, 9:05\u202FAM EST');
    expect(lines['datetime.h23'], '14:05');
  });

  test('plurals render identically to the native lane', () {
    expect(lines['plural.cardinal'], '1 item / 2 items');
    expect(lines['plural.ordinal.cy'], '1af, 2il, 3ydd, 5ed');
  });

  test('the degrade contract holds on the wasm engine', () {
    expect(lines['degrade.output'], '123,456');
    expect(lines['degrade.errors'], '1');
    expect(lines['degrade.kind'], 'FluentTypeError');
  });
}
