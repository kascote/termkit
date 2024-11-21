import 'package:termlib/termlib.dart';

void main() {
  final term = TermLib()..writeln(Style('ANSI 16 Colors:\n')..bold());
  final resetCR = '${Style('')..resetStyle()}\n';

  for (var i = 0; i < 16; i++) {
    if (i == 8) term.write(resetCR);
    final clrNum = i.toString().padLeft(3);

    final style = Style('  $clrNum  ', profile: ProfileEnum.ansi16)
      ..bg(Color.ansi(i))
      ..fg(i < 7 ? Color.gray : Color.black);

    term.write(style);
  }
  term
    ..write('$resetCR$resetCR')
    ..writeln(
      Style('ANSI 256 Colors:')
        ..bold()
        ..fg(Color.white)
        ..bg(Color.reset)
        ..resetStyle(),
    );

  for (var i = 16; i < 232; i++) {
    if ((i - 16) % 12 == 0) term.write(resetCR);
    final clrNum = i.toString().padLeft(3);

    final style = Style('  $clrNum  ')
      ..bg(Color.indexed(i))
      ..fg(i < 28 ? Color.gray : Color.black);

    term.write(style);
  }
  term
    ..write('$resetCR$resetCR')
    ..writeln(
      Style('Gray Scale Colors:')
        ..bold()
        ..fg(Color.white)
        ..bg(Color.reset)
        ..resetStyle(),
    );

  for (var i = 232; i < 256; i++) {
    if ((i - 232) % 12 == 0) term.write(resetCR);
    final clrNum = i.toString().padLeft(3);

    final style = Style('  $clrNum  ')
      ..bg(Color.indexed(i))
      ..fg(i < 244 ? Color.gray : Color.black);

    term.write(style);
  }

  term
    ..write('$resetCR$resetCR')
    ..writeln(
      Style('True Colors:')
        ..bold()
        ..fg(Color.white)
        ..bg(Color.reset)
        ..resetStyle(),
    );

  const cols = 80;
  const rows = 20;
  const total = cols * rows;

  for (var i = 0; i < total; i++) {
    final r = (255 - (i * 255 / total)).floor();
    var g = (i * 510 / total).floor(); // % 255;
    final b = (i * 255 / total).floor(); // % 255;
    if (g > 255) g = 510 - g;

    final style = Style('·', profile: ProfileEnum.trueColor)
      ..fg(Color.fromRGBComponent(r, g, b))
      ..bg(Color.fromRGBComponent(255 - r, 255 - g, 255 - b));

    if (i % cols == 0) term.write(resetCR);

    term.write(style);
  }

  term.write(resetCR);
}
