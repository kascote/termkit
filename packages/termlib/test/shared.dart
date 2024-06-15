import 'dart:convert';

import 'package:termlib/src/shared/terminal_overrides.dart';
import 'package:termlib/termlib.dart';

import 'termlib_mock.dart';

Stream<List<int>> streamString(String value) async* {
  final buffer = value.replaceAll('π', '\x1b');
  yield utf8.encode(buffer);
}

typedef AssertFunction = void Function(MockStdout stdout, MockStdin? stdin, TermOsMock termOsMock);

Future<void> mockedTest(
  AssertFunction fx, {
  MockStdout? stdout,
  MockStdin? stdin,
  TermOsMock? termOsMock,
  EnvironmentData? env,
}) async {
  final iStdout = stdout ?? MockStdout();
  final iStdin = stdin ?? MockStdin(streamString(''));
  final iTermOsMock = termOsMock ?? TermOsMock();

  await TerminalOverrides.runZoned(
    () async {
      fx(iStdout, iStdin, iTermOsMock);
    },
    stdout: iStdout,
    stdin: iStdin,
    termOs: iTermOsMock,
    environmentData: env,
  );
}
