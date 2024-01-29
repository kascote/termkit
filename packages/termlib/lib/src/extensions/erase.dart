import 'package:termansi/termansi.dart' as ansi;

import '../termlib_base.dart';

/// Eraser handling functions
extension EraseUtils on TermLib {
  /// Erase the screen from the current line down to the bottom of the screen.
  void eraseDown() => write(ansi.Erase.screenFromCursor());

  /// Erase the screen from the current line up to the top of the screen.
  void eraseUp() => write(ansi.Erase.screenToCursor());

  /// Erase the entire screen.
  void eraseScreen() => write(ansi.Erase.screenAll());

  /// Erase from the current cursor position to the end of the current line.
  void eraseLineFromCursor() => write(ansi.Erase.lineFromCursor());

  /// Erase from the current cursor position to the start of the current line.
  void eraseLineToCursor() => write(ansi.Erase.lineToCursor());

  /// Erase the entire current line, including the character at the cursor position.
  void eraseLine() => write(ansi.Erase.lineAll());

  /// Erase the saved line.
  void eraseLineSaved() => write(ansi.Erase.lineSaved());

  /// Erase the saved lines.
  void eraseSaved() => write(ansi.Erase.screenSaved());

  /// erase the screen and moves the cursor the top left position
  void eraseClear() => write(ansi.Erase.clear());
}
