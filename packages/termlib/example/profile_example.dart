import 'package:termlib/termlib.dart';

Future<int> main() async {
  final exitCode = await TermRunner().run(display);
  return exitCode;
}

Future<int> display(InteractiveTerm term) async {
  final c16 = Color.fromString('#00ffff').convert(ColorKind.ansi);
  final c256 = Color.fromString('#00ffff').convert(ColorKind.indexed);
  final ctc = Color.fromString('#00ffff');

  term.writeln('ask for the true color $ctc on different profiles');

  final out = [
    term.style(fg: c16)('hello world 16 - $c16'),
    term.style(fg: c256)('Hello World 256 - $c256'),
    term.style(fg: ctc)('Hello World Tc - $ctc'),
  ];

  term.writeln(out.toString());
  return 0;
}
