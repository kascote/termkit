import 'package:termlib/termlib.dart';

Future<void> main() async {
  final t = TermLib()..write('Type something: ');
  final input = await t.readLine();

  t.writeln('${t.newLine}You typed: [$input]${t.newLine}');

  return t.flushThenExit(0);
}
