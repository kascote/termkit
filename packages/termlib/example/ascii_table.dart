import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';

import './shared.dart';

const lhsCursor = '▌';
const rhsCursor = '▐';

Future<int> main() async {
  final exitCode =
      await TermRunner(
        alternateScreen: true,
        rawMode: true,
        hideCursor: true,
        title: 'ASCII Table',
      ).run((term) async {
        final table = AsciiTable(term);
        await table.loop();
        return 0;
      });

  return exitCode;
}

typedef Point = ({int x, int y});
typedef Theme = ({
  Style codes,
  Style text,
  Style cursor,
  Style cursorSide,
  Style muted,
  Style hotKeys,
});
typedef Range = ({int start, int end});

class AsciiTable {
  final TermLib _term;

  Point pos = (x: 0, y: 0);
  final blockSize = 5;
  final ({int x, int y}) winOffset = (x: 2, y: 2);
  final ({int x, int y}) axisOffset = (x: 4, y: 6); // blockSize + 1
  final ({int height, int width}) table = (height: 9, width: 17);
  Range range = (start: 0, end: 128);
  late Theme colors;

  AsciiTable(TermLib term) : _term = term {
    final s = _term.style;

    colors = (
      codes: s()
        ..fg(Color.fromString('aqua'))
        ..bg(Color.reset),
      text: s()
        ..fg(Color.fromString('darkGray'))
        ..bg(Color.reset),
      cursor: s()
        ..fg(Color.fromString('white'))
        ..bg(Color.fromString('darkRed')),
      cursorSide: s()
        ..fg(Color.fromString('red'))
        ..bg(Color.fromString('darkRed')),
      muted: s()
        ..fg(Color.fromString('dimGray'))
        ..bg(Color.reset),
      hotKeys: s()
        ..fg(Color.fromString('white'))
        ..bg(Color.fromString('dimGray')),
    );
  }

  void draw() {
    drawTable();
    drawAxis();
    navigator();
    drawInfo();
  }

  Future<void> loop() async {
    draw();
    while (true) {
      final event = await _term.pollTimeout<KeyEvent>();
      if (event is KeyEvent) {
        if (event.code.name == KeyCodeName.escape) break;

        if (event.code.name == KeyCodeName.left || event.code.char == 'h') {
          pos = (x: pos.x, y: pos.y == 0 ? 15 : pos.y - 1);
        } else if (event.code.name == KeyCodeName.right || event.code.char == 'l') {
          pos = (x: pos.x, y: pos.y == 15 ? 0 : pos.y + 1);
        } else if (event.code.name == KeyCodeName.up || event.code.char == 'k') {
          pos = (x: pos.x == 0 ? 7 : pos.x - 1, y: pos.y);
        } else if (event.code.name == KeyCodeName.down || event.code.char == 'j') {
          pos = (x: pos.x == 7 ? 0 : pos.x + 1, y: pos.y);
        } else if (event.code.char.toLowerCase() == 'r') {
          range = (start: range.start == 0 ? 128 : 0, end: range.end == 128 ? 256 : 128);
        }

        draw();
      }
    }
  }

  void drawInfo() {
    final baseLine = winOffset.x + (table.height * 2) + 2;
    final baseCol = winOffset.y;
    final codePoint = range.start + (pos.x * 16) + pos.y;

    _term
      ..writeAt(
        winOffset.x,
        baseCol,
        colors.muted('-' * (table.width * (blockSize + 1))),
      )
      ..writeAt(winOffset.x, baseCol + 5, colors.hotKeys(' ESC exit '))
      ..writeAt(winOffset.x, baseCol + 20, colors.hotKeys(' R change range '))
      ..writeAt(
        baseLine,
        baseCol,
        colors.muted('-' * (table.width * (blockSize + 1))),
      )
      ..writeAt(baseLine + 1, baseCol + 15, colors.muted('dec: '))
      ..write(colors.text(codePoint.toString().padLeft(3)))
      ..write(colors.muted('  hex: '))
      ..write(colors.text(codePoint.toRadixString(16).padLeft(2, '0')))
      ..write(colors.muted('  bin: '))
      ..write(colors.text(codePoint.toRadixString(2).padLeft(8, '0')))
      ..write(colors.muted('  oct: '))
      ..write(colors.text(codePoint.toRadixString(8).padLeft(3)))
      ..write(colors.muted('  '))
      ..write(colors.text(codePoint < 33 ? lowCodes[codePoint].$2 : ''))
      ..eraseLineFromCursor()
      ..writeAt(
        baseLine + 2,
        baseCol,
        colors.muted('-' * (table.width * (blockSize + 1))),
      );
  }

  void navigator() {
    final x = pos.x * 2;
    final y = pos.y * 6;
    final char = _getCursor((pos.x * 16) + pos.y);

    _term.writeAt(
      x + winOffset.x + axisOffset.x,
      y + winOffset.y + axisOffset.y,
      char,
    );
  }

  void drawAxis() {
    for (var y = 0; y < 16; y++) {
      _term.writeAt(
        winOffset.x + 2,
        axisOffset.y + winOffset.y + (y * 6),
        colors.text(_centerString(y.toRadixString(16).toUpperCase(), blockSize)),
      );
    }

    for (var x = 0; x < 8; x++) {
      final value = range.start == 0 ? x : x + 8;
      _term.writeAt(
        (x * 2) + winOffset.x + axisOffset.x,
        winOffset.y,
        colors.text(value.toRadixString(16).toUpperCase().padLeft(blockSize)),
      );
    }
  }

  void drawTable() {
    var x = 0;

    for (var code = range.start; code < range.end; code++) {
      final y = code % 16;
      x = y == 0 ? x + 2 : x;
      _term.writeAt(
        x + winOffset.x + axisOffset.x - 2,
        y + winOffset.y + axisOffset.y + (y * blockSize),
        colors.codes(_getCode(code)),
      );
    }
  }

  String _centerString(String value, int width) {
    final pad = (width - value.length) / 2;
    return value.padLeft(pad.ceil() + value.length).padRight(width);
  }

  String _getCursor(int code) {
    final codePoint = range.start + code;
    final sb = StringBuffer()
      ..write(colors.cursorSide(lhsCursor))
      ..write(colors.cursor(_centerString(_getChar(codePoint), 3)))
      ..write(colors.cursorSide(rhsCursor));

    return sb.toString();
  }

  String _getCode(int code) {
    return _centerString(_getChar(code), blockSize);
  }

  String _getChar(int code) {
    return switch (code) {
      < 33 => lowCodes[code].$1,
      127 => 'DEL',
      _ => printable(code),
    };
  }
}

const lowCodes = [
  ('NUL', 'Null character'),
  ('SOH', 'Start of Heading'),
  ('STX', 'Start of Text'),
  ('ETX', 'End of Text'),
  ('EOT', 'End of Transmission'),
  ('ENQ', 'Enquiry'),
  ('ACK', 'Acknowledgment'),
  ('BEL', 'Bell'),
  ('BS', 'Backspace'),
  ('TAB', 'Horizontal Tab'),
  ('LF', 'Line Feed'),
  ('VT', 'Vertical Tab'),
  ('FF', 'Form Feed'),
  ('CR', 'Carriage Return'),
  ('SO', 'Shift Out / X-On'),
  ('SI', 'Shift In / X-Off'),
  ('DLE', 'Data Line Escape'),
  ('DC1', 'Device Control 1 (oft. XON)'),
  ('DC2', 'Device Control 2'),
  ('DC3', 'Device Control 3 (oft. XOFF)'),
  ('DC4', 'Device Control 4'),
  ('NAK', 'Negative Acknowledgement'),
  ('SYN', 'Synchronous Idle'),
  ('ETB', 'End of Transmission Block'),
  ('CAN', 'Cancel'),
  ('EM', 'End of Medium'),
  ('SUB', 'Substitute'),
  ('ESC', 'Escape'),
  ('FS', 'File Separator'),
  ('GS', 'Group Separator'),
  ('RS', 'Record Separator'),
  ('US', 'Unit Separator'),
  ('SPC', 'Space'),
];
