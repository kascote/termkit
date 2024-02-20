import 'package:termlib/termlib.dart';

void main() {
  final t = TermLib();
  final p16 = Profile(profile: ProfileEnum.ansi16);
  final p256 = Profile();
  final ptc = Profile(profile: ProfileEnum.trueColor);

  final c16 = p16.getColor('#00ffff') as Ansi16Color;
  final c256 = p256.getColor('#00ffff') as Ansi256Color;
  final ctc = ptc.getColor('#00ffff') as TrueColor;

  t.writeLn('ask for the true color ${ctc.hex} on different profiles');

  final out = [
    p16.style('hello world 16 - ${c16.code}')
      ..setFg(c16)
      ..toString(),
    p256.style('Hello World 256 - ${c256.code}')
      ..setFg(c256)
      ..toString(),
    ptc.style('Hello World Tc - ${ctc.hex}')
      ..setFg(ctc)
      ..toString(),
  ];

  t.writeLn(out.toString());
}
