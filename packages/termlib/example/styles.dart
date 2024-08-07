import 'package:termlib/termlib.dart';

void main() {
  final t = TermLib();

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
    t.writeln(' ${t.style(color[0] as String)..fg(color[1] as Color)} \t ${t.style(color[0] as String)
      ..fg(color[2] as Color)
      ..bg(color[1] as Color)}');
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
    t.writeln(' ${t.style(style[0] as String)..apply(style[1] as TextStyle)}');
  }

  t
    ..writeln(' ${t.style('underline color')
      ..fg(Ansi256Color(160))
      ..curlyUnderline(Ansi256Color(120))}')
    ..writeln(' ${t.style('underline color')..dottedUnderline(Ansi256Color(196))}');

  // final col1 = t.style()
  //   ..fg(Color.red)
  //   ..bg(Color.white);
  // final col2 = t.style()
  //   ..fg(Color.white)
  //   ..bg(Color.red);

  // t
  //   ..writeln(col1("ba${col2('na')}${col1('nas')}"))
  //   ..writeln(col1("ba${col2('na')}nas"))
  //   ..writeln(col1("ba${col2('na', reset: false)}nas"))
  //   ..writeln('bananas');
}

String center(String text, int length) {
  if (text.isEmpty) return ' ' * length;

  final difference = length - text.length;
  if (difference <= 0) return text;

  final leftPadding = difference ~/ 2;
  final rightPadding = difference - leftPadding;

  return ' ' * leftPadding + text + ' ' * rightPadding;
}
