// Runs the pub.dev showcase (example/main.dart) and pins its output —
// every claim on the Example tab stays proven. Values are CLDR renderings
// through ICU4X; a pin moving on an icu_kit bump means the showcase text
// moved too — re-verify, then re-pin.

import 'package:test/test.dart';

import '../../example/main.dart';

void registerExampleTests() {
  late List<String> showcase;
  late Map<String, String> lines;

  setUpAll(() async {
    showcase = await runShowcase();
    lines = {
      for (final line in showcase)
        line.substring(0, line.indexOf(': ')): line.substring(
          line.indexOf(': ') + 2,
        ),
    };
  });

  test('showcase covers every section with unique labels', () {
    expect(
      lines.keys,
      hasLength(showcase.length),
      reason: 'duplicate showcase labels would hide a pinned line',
    );
  });

  test('numbers — grouping, numbering systems, compact, sign, percent', () {
    expect(lines['number.en'], '1,234,567.89');
    expect(lines['number.de'], '1.234.567,89');
    expect(lines['number.deva'], '१२,३४,५६७.८९');
    expect(lines['number.compact'], '1.2M');
    expect(lines['number.signed'], '+5');
    expect(lines['number.percent'], '42%');
  });

  test('currency and units — minor-unit digits, CLDR unit identifiers', () {
    expect(lines['currency.usd'], r'$1,234.50');
    expect(lines['currency.jpy'], '¥1,235');
    expect(lines['unit.speed'], '120 km/h');
    expect(lines['unit.long'], '3 meters');
  });

  test('dates — styles, buddhist calendar, IANA zones, h23', () {
    expect(lines['datetime.styled.de'], 'Donnerstag, 15. Januar 2026');
    expect(lines['datetime.buddhist'], '2569 BE');
    // CLDR separates the time from the day period with U+202F (narrow
    // no-break space) — escaped so the invisible byte is visible here.
    expect(lines['datetime.zoned'], 'Jan 15, 2026, 9:05\u202FAM EST');
    expect(lines['datetime.h23'], '14:05');
  });

  test('plurals — cardinals plus full-CLDR ordinals (Welsh)', () {
    expect(lines['plural.cardinal'], '1 item / 2 items');
    expect(lines['plural.ordinal.cy'], '1af, 2il, 3ydd, 5ed');
  });

  test('degrade contract — nearest rendering plus a recorded error', () {
    expect(lines['degrade.output'], '123,456');
    expect(lines['degrade.errors'], '1');
    expect(lines['degrade.kind'], 'FluentTypeError');
  });
}
