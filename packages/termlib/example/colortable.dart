import 'package:termlib/color_util.dart';
import 'package:termlib/termlib.dart';

// test to see how 256 colors downgrades to 16 colors
Future<void> main() async {
  final t = TermLib();
  const black = Color.black;
  const white = Color.darkGray;
  final resetCR = '${Style('')..resetStyle()}\n';

  t.writeln('How 256 colors downgrades to 16 colors\n');

  for (var i = 0; i < 256; i++) {
    final c256 = Color.indexed(i);
    final c16 = c256.convert(ColorKind.ansi);
    final lum16 = colorLuminance(c16.convert(ColorKind.rgb));

    if (i % 12 == 0) t.write(resetCR);

    final style16 = Style('[${c16.value.toString().padLeft(2)}]')
      ..bg(c16)
      ..fg(lum16 < 0.2 ? white : black);

    final lum256 = colorLuminance(c256.convert(ColorKind.rgb));
    final style256 = Style(' ${i.toString().padLeft(3)} ')
      ..bg(c256)
      ..fg(lum256 < 0.2 ? white : black);

    t
      ..write(style16)
      ..write(style256)
      ..write(' ');
  }

  t.write(resetCR);
  await t.dispose();
  await t.flushThenExit(0);
}
