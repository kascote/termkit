import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:termlib/color_util.dart';
import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';

extension StrUtil on String {
  // get a random character from the alphabet range (33-126)
  static String rndChar() {
    final rnd = Random();
    return String.fromCharCode(rnd.nextInt(93) + 33);
  }
}

Future<void> main(List<String> arguments) async {
  final t = TermLib()
    ..eraseClear()
    ..cursorHide()
    ..enableRawMode()
    ..enableAlternateScreen();

  void closeTerm() {
    t
      ..disableAlternateScreen()
      ..disableRawMode()
      ..cursorShow()
      ..softReset();
  }

  late final MatrixApp app;

  await runZonedGuarded(
    () async {
      app = MatrixApp(t);
      final rc = await app.run();
      closeTerm();
      return rc;
    },
    (e, st) {
      app.stop();
      closeTerm();
      stderr
        ..writeln(e)
        ..writeln(st);
    },
  );

  await t.flushThenExit(0);
}

class MatrixApp {
  late final Matrix matrix;
  late final Completer<bool> completer;
  late final StreamSubscription<int> tickStream;
  late final StreamSubscription<KeyEvent> eventStream;

  MatrixApp(TermLib t) {
    matrix = Matrix(t, t.terminalColumns ~/ 2, t.terminalLines);
    completer = Completer<bool>();
    tickStream = Stream.periodic(const Duration(milliseconds: 1000 ~/ 30), (tick) => tick).listen(null);
    eventStream = t.eventStreamer<KeyEvent>().listen(null);
  }

  Future<bool> run() async {
    eventStream.onData((key) async {
      if (key.code.name == KeyCodeName.escape) {
        await tickStream.cancel();
        await eventStream.cancel();
        completer.complete(true);
      }
      if (key.code.char.toLowerCase() == 'p') {
        tickStream.isPaused ? tickStream.resume() : tickStream.pause();
      }
    });
    tickStream.onData(matrix.rainMaker);

    return completer.future;
  }

  Future<void> stop() async {
    await tickStream.cancel();
    await eventStream.cancel();
    completer.complete(false);
  }
}

class Matrix {
  final TermLib t;
  final int width;
  final int height;
  late List<Rain> rain;

  Matrix(this.t, this.width, this.height) {
    rain = List.generate(width, (i) => Rain(t, i * 2, 1, height));
  }

  void rainMaker(int tick) {
    t.startSyncUpdate();
    try {
      for (final r in rain) {
        r.fall(tick);
      }
    } catch (e) {
      t.endSyncUpdate();
      rethrow;
    }
    t.endSyncUpdate();
  }
}

final _headColor = Color.fromString('#007676');
final _tailColor = Color.fromString('#001414');

class Rain {
  final TermLib t;
  final int x;
  int y;
  final rnd = Random();
  late int length;
  late int speed;
  int height;
  late List<String> tail;
  final cl = colorLerp(_headColor, _tailColor);
  bool isFailing = false;

  Rain(this.t, this.x, this.y, this.height) {
    length = rnd.nextInt(15) + 5;
    tail = List.generate(length, (i) => i < length - 1 ? ' ' : StrUtil.rndChar());
    speed = newSpeed();
  }

  int newSpeed() => rnd.nextInt(3) + 1;

  void fall(int tick) {
    if (tick % speed != 0) {
      return;
    }
    if (!isFailing) {
      rnd.nextInt(10) + 1 == 1 ? isFailing = true : isFailing = false;
      if (!isFailing) return;
    }
    final style = t.style;

    final llen = y < length ? y : length - 1;
    var r = 0;
    for (var i = llen; i > 0; i--) {
      final charStyle = style(tail[length - i]);
      final char = i == llen ? (charStyle..fg(Color.white)) : (charStyle..fg(Color.fromString(cl(r / llen).hex)));
      t.writeAt(y - r, x, char);
      r++;
    }

    if (y > length) {
      t.writeAt(y - length, x, ' ');
    }

    y += 1;
    tail = tail.sublist(1)..add(StrUtil.rndChar());

    if (y - length > height) {
      y = 0;
      speed = newSpeed();
    }
  }
}
