import 'package:termlib/color_util.dart';
import 'package:termlib/termlib.dart';

// test to see how 256 colors downgrades to 16 colors
void main() {
  final t = TermLib();
  final black = Ansi16Color(0);
  final white = Ansi16Color(7);
  final resetCR = '${Style('')..reset()}\n';

  t.writeln('How 256 colors downgrades to 16 colors\n');

  for (var i = 0; i < 256; i++) {
    final c16 = Ansi256Color(i).convert(ProfileEnum.ansi16);
    final lum16 = colorLuminance(c16.convert(ProfileEnum.trueColor) as TrueColor);

    if (i % 12 == 0) t.write(resetCR);

    final style16 = Style('[${c16.toString().padLeft(2)}]')
      ..bg(c16)
      ..fg(lum16 < 0.2 ? white : black);

    final c256 = Ansi256Color(i);
    final lum256 = colorLuminance(c256.convert(ProfileEnum.trueColor) as TrueColor);
    final style256 = Style(' ${i.toString().padLeft(3)} ')
      ..bg(c256)
      ..fg(lum256 < 0.2 ? white : black);

    t
      ..write(style16)
      ..write(style256)
      ..write(' ');
  }

  t.write(resetCR);
}
