import 'package:termlib/termlib.dart';

Future<void> main() async {
  final t = TermLib();

  final c16 = Color.fromString('#00ffff').convert(ColorKind.ansi);
  final c256 = Color.fromString('#00ffff').convert(ColorKind.indexed);
  final ctc = Color.fromString('#00ffff');

  t.writeln('ask for the true color $ctc on different profiles');

  final out = [
    t.style('hello world 16 - $c16')
      ..fg(c16)
      ..toString(),
    t.style('Hello World 256 - $c256')
      ..fg(c256)
      ..toString(),
    t.style('Hello World Tc - $ctc')
      ..fg(ctc)
      ..toString(),
  ];

  t.writeln(out.toString());
  await t.dispose();
  await t.flushThenExit(0);
}
