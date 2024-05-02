import './escape_codes.dart';

/// Text style escape sequences
abstract class Text {
  /// Bold text style
  static String get bold => '${CSI}1m';

  /// Dim text style
  static String get dim => '${CSI}2m';

  /// Italic text style
  static String get italic => '${CSI}3m';

  /// Underline text style
  static String get underline => '${CSI}4m';

  /// Double underline
  static String get doubleUnderline => '${CSI}4:2m';

  /// Curly underline
  static String get curlyUnderline => '${CSI}4:3m';

  /// Dotted underline
  static String get dottedUnderline => '${CSI}4:4m';

  /// Dashed underline
  static String get dashedUnderline => '${CSI}4:5m';

  /// Blink text style
  static String get blink => '${CSI}5m';

  /// Invert text style
  static String get invert => '${CSI}7m';

  /// Hidden text style
  static String get hidden => '${CSI}8m';

  /// Strike through text style
  static String get strikeThrough => '${CSI}9m';

  /// Overline text style
  static String get overline => '${CSI}53m';

  /// Reset text style
  static String get reset => '${CSI}0m';

  /// Reset bold text style
  static String get resetBold => '${CSI}22m';

  /// Reset dim text style
  static String get resetDim => '${CSI}22m';

  /// Reset italic text style
  static String get resetItalic => '${CSI}23m';

  /// Reset underline text style
  static String get resetUnderline => '${CSI}24m';

  /// Reset double underline
  static String get resetCurlyUnderline => '${CSI}4:0m';

  /// Reset double underline
  static String get resetDoubleUnderline => '${CSI}4:0m';

  /// Reset dotted underline
  static String get resetDottedUnderline => '${CSI}4:0m';

  /// Reset dashed underline
  static String get resetDashedUnderline => '${CSI}4:0m';

  /// Reset blink text style
  static String get resetBlink => '${CSI}25m';

  /// Reset invert text style
  static String get resetInvert => '${CSI}27m';

  /// Reset hidden text style
  static String get resetHidden => '${CSI}28m';

  /// Reset strike through text style
  static String get resetStrikeThrough => '${CSI}29m';

  /// Reset overline text style
  static String get resetOverline => '${CSI}55m';
}
