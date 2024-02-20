import 'package:termlib/termlib.dart';

// test to see how 256 colors downgrades to 16 colors
void main() {
  final t = TermLib();
  final black = Ansi16Color(0);

  t.writeLn('How 256 colors downgrades to 16 colors\n');

  for (var i = 0; i < 256; i++) {
    final c = Ansi256Color(i).toAnsi16Color();

    if (i % 12 == 0) t.write('\n');

    final style16 = Style('[${c.code.toString().padLeft(2)}]')
      ..setBg(c)
      ..setFg(black);
    final style256 = Style(' ${i.toString().padLeft(3)} ')
      ..setBg(Ansi256Color(i))
      ..setFg(black);

    t
      ..write(style16.toString())
      ..write(style256.toString())
      ..write(' ');
  }
}
