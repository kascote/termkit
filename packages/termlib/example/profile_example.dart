import 'package:termlib/termlib.dart';

Future<int> main() async {
  final exitCode = await TermRunner().run(display);
  return exitCode;
}

Future<int> display(TermLib term) async {
  final c16 = Color.fromString('#00ffff').convert(ColorKind.ansi);
  final c256 = Color.fromString('#00ffff').convert(ColorKind.indexed);
  final ctc = Color.fromString('#00ffff');

  term.writeln('ask for the true color $ctc on different profiles');

  final out = [
    term.style('hello world 16 - $c16')
      ..fg(c16)
      ..toString(),
    term.style('Hello World 256 - $c256')
      ..fg(c256)
      ..toString(),
    term.style('Hello World Tc - $ctc')
      ..fg(ctc)
      ..toString(),
  ];

  term.writeln(out.toString());
  return 0;
}
