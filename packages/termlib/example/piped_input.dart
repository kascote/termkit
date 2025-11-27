import 'dart:convert';
import 'dart:io';

import 'package:termlib/termlib.dart';

Future<void> main() async {
  final term = TermLib();

  if (term.hasTerminal) {
    term
      ..writeln('Running in interactive mode. Use piped input instead:')
      ..writeln(r'  echo "hello\nworld" | dart run example/piped_input.dart');
    exit(1);
  }

  term.writeln('Processing piped input line-by-line:');

  await for (final line in term.stdinStream.transform(utf8.decoder).transform(const LineSplitter())) {
    term.writeln('Received: $line');
  }

  term.writeln('Done processing piped input.');
  await term.dispose();
  await term.flushThenExit(0);
}
