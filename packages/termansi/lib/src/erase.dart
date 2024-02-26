import './escape_codes.dart';

/// Erase sequences.
abstract class Erase {
  /// Erase from cursor to end of the screen
  static String get screenFromCursor => '${CSI}0J';

  /// Erase from cursor to beginning of screen
  static String get screenToCursor => '${CSI}1J';

  /// Erase entire screen
  static String get screenAll => '${CSI}2J';

  /// Erase saved lines
  static String get screenSaved => '${CSI}3J';

  /// Erase from cursor to end of line
  static String get lineFromCursor => '${CSI}0K';

  /// Erase from cursor to beginning of line
  static String get lineToCursor => '${CSI}1K';

  /// Erase entire line
  static String get lineAll => '${CSI}2K';

  /// Erase saved lines
  static String get lineSaved => '${CSI}3K';

  /// Erase the screen and moves the cursor the top left position
  static String get clear => '${CSI}2J${CSI}H';
}
