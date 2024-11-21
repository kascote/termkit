import 'dart:math';

import 'package:termlib/color_util.dart';
import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';

const snakeBody = ['▓', '▒', '░'];
const boardLines = ['═', '║', '╔', '╗', '╚', '╝'];
// most terminals render emojis as 2 chars wide and mess up the game
const fruitIcon = '@';

void main() async {
  final t = TermLib()
    ..enableAlternateScreen()
    ..eraseClear()
    ..cursorHide()
    ..setTerminalTitle('S N A K E S');

  try {
    final game = SnakeGame(t);
    t.writeAt(1, 30, t.profile.name);

    await t.withRawModeAsync<void>(() async {
      game.drawBoard();
      final letsPlay = await game.startPage();

      if (letsPlay) await gameLoop(t, game);
    });
  } finally {
    t
      ..disableAlternateScreen()
      ..cursorShow();
  }

  await t.flushThenExit(0);
}

Future<void> gameLoop(TermLib t, SnakeGame game) async {
  game.drawBoard();

  while (true) {
    final event = await t.readEvent<Event>();
    var heading = game.heading;

    if (event is KeyEvent) {
      if (event.code.name == KeyCodeName.escape) {
        break;
      }

      if (event.code.name == KeyCodeName.up) {
        heading = Direction.up;
      } else if (event.code.name == KeyCodeName.right) {
        heading = Direction.right;
      } else if (event.code.name == KeyCodeName.down) {
        heading = Direction.down;
      } else if (event.code.name == KeyCodeName.left) {
        heading = Direction.left;
      }
    }

    if (game.status != Finish.none) {
      continue;
    }

    game
      ..update(heading)
      ..redraw();
  }
}

enum Direction { up, right, down, left }

enum Finish { none, win, lose }

enum Tile { empty, snake, food }

typedef Pos = ({int row, int col});

class SnakeGame {
  final int cols;
  final int rows;
  final List<Pos> snake = [];
  final _rnd = Random();
  final _headColor = Color.fromString('springGreen');
  final _tailColor = Color.fromString('darkGreen');
  late final TermLib _term;
  int winCol = 0;
  int winRow = 0;
  int curCol = 0;
  int curRow = 0;
  Direction _heading = Direction.right;
  Finish status = Finish.none;
  Pos _lastTailPos = (row: 0, col: 0);
  Pos _fruitPos = (row: 0, col: 0);
  int score = 0;

  SnakeGame(
    TermLib term, {
    this.cols = 40,
    this.rows = 20,
    this.winCol = 3,
    this.winRow = 3,
  }) {
    _term = term;
    curCol = winCol + 10;
    curRow = winRow + 10;
    newFruitPos();

    snake
      ..add((row: curRow, col: curCol))
      ..add((row: curRow, col: curCol - 1))
      ..add((row: curRow, col: curCol - 2));
  }

  Direction get heading => _heading;

  void update(Direction newHeading) {
    switch (newHeading) {
      case Direction.up:
        if (_heading != Direction.down) {
          _heading = newHeading;
          curRow--;
        } else {
          curRow++;
        }
      case Direction.right:
        if (_heading != Direction.left) {
          _heading = newHeading;
          curCol++;
        } else {
          curCol--;
        }
      case Direction.down:
        if (_heading != Direction.up) {
          _heading = newHeading;
          curRow++;
        } else {
          curRow--;
        }
      case Direction.left:
        if (_heading != Direction.right) {
          _heading = newHeading;
          curCol--;
        } else {
          curCol++;
        }
    }

    if (curCol == winCol || curCol == winCol + cols || curRow == winRow || curRow == winRow + rows) {
      status = Finish.lose;
      drawBoard();
      return;
    }

    if (Set<Pos>.from(snake.sublist(2)).contains(snake[0])) {
      status = Finish.lose;
      drawBoard();
      return;
    }

    if (curCol == _fruitPos.col && curRow == _fruitPos.row) {
      newFruitPos();
    }

    _lastTailPos = move((row: curRow, col: curCol));
  }

  Pos move(Pos pos) {
    var lastPos = snake[0];
    for (var i = 0; i < snake.length; i++) {
      if (i == 0) {
        snake[i] = pos;
      } else {
        final tmp = snake[i];
        snake[i] = lastPos;
        lastPos = tmp;
      }
    }

    return lastPos;
  }

  void newFruitPos() {
    _fruitPos = (row: _rnd.nextInt(rows - winRow - 1) + winRow + 1, col: _rnd.nextInt(cols - winCol - 1) + winCol + 1);
    score += 10;
    snake
      ..add(_lastTailPos)
      ..add(_lastTailPos);
  }

  void redraw() {
    final s = _term.style;
    final dataStyle = s()..fg(Color.fromString('webGray'));
    final fruitStyle = s(fruitIcon)..fg(Color.fromString('orangeRed'));
    final scoreStyle = s('Score: ${score.toString().padLeft(4)}')..fg(Color.fromString('gold'));
    final cl = colorLerp(_headColor, _tailColor);

    for (var i = 0; i < snake.length; i++) {
      _term.moveTo(snake[i].row, snake[i].col);
      var body = snakeBody[1];

      if (i == 0) body = snakeBody[0];
      if (i == snake.length - 1) body = snakeBody[2];

      final c = Color.fromString(cl(i / (snake.length - 1)).hex);
      _term.write(s(body)..fg(c));
    }
    _term
      ..startSyncUpdate()
      ..writeAt(_lastTailPos.row, _lastTailPos.col, ' ')
      ..writeAt(_fruitPos.row, _fruitPos.col, fruitStyle)
      ..writeAt(winRow, winCol + 5, dataStyle('╡ '))
      ..write(scoreStyle)
      ..write(dataStyle(' ╞'))
      ..writeAt(
        winRow + rows,
        winCol + 5,
        dataStyle('╡ ${(curCol - winCol).toString().padLeft(3)}, ${(curRow - winRow).toString().padLeft(3)} ╞'),
      )
      ..endSyncUpdate();
  }

  void drawBoard() {
    final ts = _term.style;
    final c = status == Finish.lose ? Color.fromString('indianRed') : Color.fromString('webGray');
    final s = ts()..fg(c);

    for (var i = 0; i < cols; i++) {
      _term
        ..writeAt(winRow, winCol + i, s(boardLines[0]))
        ..writeAt(winRow + rows, winCol + i, s(boardLines[0]));
    }

    for (var i = 0; i < rows; i++) {
      _term
        ..writeAt(winRow + i, winCol, s(boardLines[1]))
        ..writeAt(winRow + i, winCol + cols, s(boardLines[1]));
    }
    _term
      ..writeAt(winRow, winCol, s(boardLines[2]))
      ..writeAt(winRow, winCol + cols, s(boardLines[3]))
      ..writeAt(winRow + rows, winCol, s(boardLines[4]))
      ..writeAt(winRow + rows, winCol + cols, s(boardLines[5]));
  }

  Future<bool> startPage() async {
    final s = _term.style;
    final white = s()..fg(Color.white);
    final gray = s()..fg(Color.fromString('webGray'));
    final red = s()..fg(Color.red);

    _term
      ..writeAt(10, 10, white('S N A K E S'))
      ..writeAt(12, 10, gray('press'))
      ..writeAt(14, 10, red('[ '))
      ..write(white('space'))
      ..write(red(' ]'))
      ..write(white(' to start'))
      ..writeAt(16, 10, red('[ '))
      ..write(white(' esc '))
      ..write(red(' ]'))
      ..write(white(' to exit'));

    while (true) {
      final event = await _term.readEvent<KeyEvent>();
      if (event is! KeyEvent) continue;

      if (event.code.name == KeyCodeName.escape) {
        _term
          ..eraseClear()
          ..writeln('Bye!');
        return false;
      }

      if (event.code.char == ' ') {
        _term.eraseClear();
        drawBoard();

        return true;
      }
    }
  }
}
