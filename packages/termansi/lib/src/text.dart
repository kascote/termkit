import './escape_codes.dart';

/// Text style escape sequences
abstract class Text {
  /// Bold text style
  static const String bold = '${CSI}1m';

  /// Dim text style
  static const String dim = '${CSI}2m';

  /// Italic text style
  static const String italic = '${CSI}3m';

  /// Underline text style
  static const String underline = '${CSI}4m';

  /// Double underline
  static const String doubleUnderline = '${CSI}4:2m';

  /// Curly underline
  static const String curlyUnderline = '${CSI}4:3m';

  /// Dotted underline
  static const String dottedUnderline = '${CSI}4:4m';

  /// Dashed underline
  static const String dashedUnderline = '${CSI}4:5m';

  /// Blink text style
  static const String blink = '${CSI}5m';

  /// Invert text style
  static const String invert = '${CSI}7m';

  /// Hidden text style
  static const String hidden = '${CSI}8m';

  /// Strike through text style
  static const String strikeThrough = '${CSI}9m';

  /// Overline text style
  static const String overline = '${CSI}53m';

  /// Reset text style
  static const String reset = '${CSI}0m';

  /// Reset bold text style
  static const String resetBold = '${CSI}22m';

  /// Reset dim text style
  static const String resetDim = '${CSI}22m';

  /// Reset italic text style
  static const String resetItalic = '${CSI}23m';

  /// Reset underline text style
  static const String resetUnderline = '${CSI}24m';

  /// Reset double underline
  static const String resetCurlyUnderline = '${CSI}4:0m';

  /// Reset double underline
  static const String resetDoubleUnderline = '${CSI}4:0m';

  /// Reset dotted underline
  static const String resetDottedUnderline = '${CSI}4:0m';

  /// Reset dashed underline
  static const String resetDashedUnderline = '${CSI}4:0m';

  /// Reset blink text style
  static const String resetBlink = '${CSI}25m';

  /// Reset invert text style
  static const String resetInvert = '${CSI}27m';

  /// Reset hidden text style
  static const String resetHidden = '${CSI}28m';

  /// Reset strike through text style
  static const String resetStrikeThrough = '${CSI}29m';

  /// Reset overline text style
  static const String resetOverline = '${CSI}55m';
}
