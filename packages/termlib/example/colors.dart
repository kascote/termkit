import 'package:termlib/termlib.dart';

void main() {
  final term = TermLib();

  final x = Style('ANSI 16 Colors:\n\n')..setBold();
  term.write(x.toString());

  for (var i = 0; i < 16; i++) {
    if (i == 8) term.write('\n');
    final clrNum = i.toString().padLeft(3);

    final style = Style('  $clrNum  ')
      ..setBg(Ansi16Color(i))
      ..setFg(i < 7 ? Ansi16Color(7) : Ansi16Color(0));

    term.write(style.toString());
  }

  term.write((Style('\n\nANSI 256 Colors:\n')..setBold()).toString());

  for (var i = 16; i < 232; i++) {
    if ((i - 16) % 12 == 0) term.write('\n');
    final clrNum = i.toString().padLeft(3);

    final style = Style('  $clrNum  ')
      ..setBg(Ansi256Color(i))
      ..setFg(i < 28 ? Ansi16Color(7) : Ansi16Color(0));

    term.write(style.toString());
  }

  term.write((Style('\n\nGray Scale Colors:\n')..setBold()).toString());

  for (var i = 232; i < 256; i++) {
    if ((i - 232) % 12 == 0) term.write('\n');
    final clrNum = i.toString().padLeft(3);

    final style = Style('  $clrNum  ')
      ..setBg(Ansi256Color(i))
      ..setFg(i < 244 ? Ansi16Color(7) : Ansi16Color(0));

    term.write(style.toString());
  }

  term.write((Style('\n\nTrue Colors:\n')..setBold()).toString());

  const cols = 80;
  const rows = 20;
  const total = cols * rows;

  for (var i = 0; i < total; i++) {
    final r = (255 - (i * 255 / total)).floor();
    var g = (i * 510 / total).floor(); // % 255;
    final b = (i * 255 / total).floor(); // % 255;
    if (g > 255) g = 510 - g;

    final style = Style('·')
      ..setFg(TrueColor(r, g, b))
      ..setBg(TrueColor(255 - r, 255 - g, 255 - b));

    if (i % cols == 0) term.write('\n');

    term.write(style.toString());
  }

  term.write('\n\n');
}
