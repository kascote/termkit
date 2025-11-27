import 'package:termlib/termlib.dart';

Future<void> main() async {
  final t = TermLib()..write('Type something: ');
  final input = await t.readLine();

  if (input == null) {
    t.writeln('${t.newLine}Cancelled${t.newLine}');
  } else {
    t.writeln('${t.newLine}You typed: [$input]${t.newLine}');
  }

  await t.dispose();
  return t.flushThenExit(0);
}
