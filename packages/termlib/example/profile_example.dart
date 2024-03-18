import 'package:termlib/termlib.dart';

void main() {
  final t = TermLib();

  final c16 = Color('#00ffff').convert(ProfileEnum.ansi16);
  final c256 = Color('#00ffff').convert(ProfileEnum.ansi256);
  final ctc = Color('#00ffff');

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
}
