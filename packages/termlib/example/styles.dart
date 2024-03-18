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
    [center('blink', 15), TextStyle.blink],
    [center('inverse', 15), TextStyle.reverse],
    [center('crossOut', 15), TextStyle.crossOut],
    [center('overline', 15), TextStyle.overline],
  ];

  for (final style in styles) {
    t.writeln(' ${t.style(style[0] as String)..apply(style[1] as TextStyle)}');
  }
}

String center(String text, int length) {
  if (text.isEmpty) return ' ' * length;

  final difference = length - text.length;
  if (difference <= 0) return text;

  final leftPadding = difference ~/ 2;
  final rightPadding = difference - leftPadding;

  return ' ' * leftPadding + text + ' ' * rightPadding;
}
