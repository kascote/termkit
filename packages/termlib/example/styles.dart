import 'package:termlib/termlib.dart';

Future<int> main() async {
  final exitCode = await TermRunner().run(display);
  return exitCode;
}

Future<int> display(InteractiveTerm t) async {
  final colors = [
    [center('black', 10), Color.black, Color.white],
    [center('red', 10), Color.red, Color.white],
    [center('green', 10), Color.green, Color.white],
    [center('yellow', 10), Color.yellow, Color.white],
    [center('blue', 10), Color.blue, Color.white],
    [center('magenta', 10), Color.magenta, Color.white],
    [center('cyan', 10), Color.cyan, Color.white],
    [center('white', 10), Color.white, Color.black],
  ];

  for (final color in colors) {
    final lhs = t.style(fg: color[1] as Color, bg: Color.reset)(color[0] as String, reset: false);
    final rhs = t.style(fg: color[2] as Color, bg: color[1] as Color)(color[0] as String, reset: false);
    t.writeln(t.style(bg: Color.reset)(' $lhs \t $rhs'));
  }

  t.writeln('');

  final styles = [
    [center('bold', 15), TextStyle.bold],
    [center('faint', 15), TextStyle.faint],
    [center('italic', 15), TextStyle.italic],
    [center('underline', 15), TextStyle.underline],
    [center('doubleUnderline', 15), TextStyle.doubleUnderline],
    [center('curlyUnderline', 15), TextStyle.curlyUnderline],
    [center('dottedUnderline', 15), TextStyle.dottedUnderline],
    [center('dashedUnderline', 15), TextStyle.dashedUnderline],
    [center('blink', 15), TextStyle.blink],
    [center('inverse', 15), TextStyle.reverse],
    [center('crossOut', 15), TextStyle.crossOut],
    [center('overline', 15), TextStyle.overline],
  ];

  for (final style in styles) {
    final s = t.style(fg: Color.white).apply(style[1] as TextStyle);

    t.writeln(s(style[0] as String));
  }

  t
    ..writeln(
      ' ${t.style(fg: Color.indexed(160), underline: Underline.curly, underlineColor: Color.indexed(120))('underline color')}',
    )
    ..writeln(
      ' ${t.style(underline: Underline.dotted, underlineColor: Color.indexed(196))('underline color')}',
    );

  return 0;
}

String center(String text, int length) {
  if (text.isEmpty) return ' ' * length;

  final difference = length - text.length;
  if (difference <= 0) return text;

  final leftPadding = difference ~/ 2;
  final rightPadding = difference - leftPadding;

  return ' ' * leftPadding + text + ' ' * rightPadding;
}
