import 'package:termansi/termansi.dart' as ansi;
import 'package:termlib/color_util.dart';
import 'package:termlib/termlib.dart';

// test to see how 256 colors downgrades to 16 colors
Future<int> main() async {
  final exitCode = await TermRunner().run(display);
  return exitCode;
}

Future<int> display(InteractiveTerm term) async {
  final t = term;
  const black = Color.black;
  const white = Color.darkGray;

  t.writeln('How 256 colors downgrades to 16 colors\n');

  for (var i = 0; i < 256; i++) {
    final c256 = Color.indexed(i);
    final c16 = c256.convert(ColorKind.ansi);
    final lum16 = colorLuminance(Color.fromRGB(ansi.ansiHex[c16.value]));

    if (i % 12 == 0) t.writeln('');

    final style16 = Style(bg: c16, fg: lum16 < 0.2 ? white : black);

    final lum256 = colorLuminance(Color.fromRGB(ansi.ansiHex[c256.value]));
    final style256 = Style(bg: c256, fg: lum256 < 0.2 ? white : black);

    t
      ..write(style16('[${c16.value.toString().padLeft(2)}]'))
      ..write(style256(' ${i.toString().padLeft(3)} '))
      ..write(' ');
  }

  t.writeln('');
  return 0;
}
