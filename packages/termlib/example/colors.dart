import 'package:termlib/termlib.dart';

Future<int> main() async {
  final exitCode = await TermRunner().run(display);
  return exitCode;
}

Future<int> display(InteractiveTerm term) async {
  term.writeln(const Style(bold: true)('ANSI 16 Colors:\n'));

  for (var i = 0; i < 16; i++) {
    if (i == 8) term.writeln('');
    final clrNum = i.toString().padLeft(3);

    final style = Style(
      bg: Color.ansi(i),
      fg: i < 7 ? Color.gray : Color.black,
      profile: ProfileEnum.ansi16,
    );

    term.write(style('  $clrNum  '));
  }
  term
    ..writeln('')
    ..writeln('')
    ..writeln(
      const Style(bold: true, fg: Color.white, bg: Color.reset)('ANSI 256 Colors:'),
    );

  for (var i = 16; i < 232; i++) {
    if ((i - 16) % 12 == 0) term.writeln('');
    final clrNum = i.toString().padLeft(3);

    final style = Style(
      bg: Color.indexed(i),
      fg: i < 28 ? Color.gray : Color.black,
    );

    term.write(style('  $clrNum  '));
  }
  term
    ..writeln('')
    ..writeln('')
    ..writeln(
      const Style(bold: true, fg: Color.white, bg: Color.reset)('Gray Scale Colors:'),
    );

  for (var i = 232; i < 256; i++) {
    if ((i - 232) % 12 == 0) term.writeln('');
    final clrNum = i.toString().padLeft(3);

    final style = Style(
      bg: Color.indexed(i),
      fg: i < 244 ? Color.gray : Color.black,
    );

    term.write(style('  $clrNum  '));
  }

  term
    ..writeln('')
    ..writeln('')
    ..writeln(
      const Style(bold: true, fg: Color.white, bg: Color.reset)('True Colors:'),
    );

  const cols = 80;
  const rows = 20;
  const total = cols * rows;

  for (var i = 0; i < total; i++) {
    final r = (255 - (i * 255 / total)).floor();
    var g = (i * 510 / total).floor(); // % 255;
    final b = (i * 255 / total).floor(); // % 255;
    if (g > 255) g = 510 - g;

    final style = Style(
      fg: Color.fromRGBComponent(r, g, b),
      bg: Color.fromRGBComponent(255 - r, 255 - g, 255 - b),
      profile: ProfileEnum.trueColor,
    );

    if (i % cols == 0) term.writeln('');

    term.write(style('·'));
  }

  term.writeln('');
  return 0;
}
