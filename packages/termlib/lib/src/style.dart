import 'package:termansi/termansi.dart' as ansi;

import './colors.dart';
import './shared/color_util.dart';
import './termlib_base.dart';

/// Text Styles that can be applied to a [Style] object.
enum TextStyle {
  /// Bold
  bold,

  /// Faint
  faint,

  /// Italic
  italic,

  /// Underline
  underline,

  /// Double underline
  doubleUnderline,

  /// Curly underline
  curlyUnderline,

  /// Dotted underline
  dottedUnderline,

  /// Dashed underline
  dashedUnderline,

  /// Blink
  blink,

  /// Reverse
  reverse,

  /// Crossout
  crossOut,

  /// Overline
  overline,
}

const _resetSeq = '0';
const _boldSeq = '1';
const _faintSeq = '2';
const _italicSeq = '3';
const _underlineSeq = '4';
const _doubleUnderlineSeq = '4:2';
const _curlyUnderlineSeq = '4:3';
const _dottedUnderlineSeq = '4:4';
const _dashedUnderlineSeq = '4:5';
const _blinkSeq = '5';
const _reverseSeq = '7';
const _crossOutSeq = '9';
const _overlineSeq = '53';
const _boldSeqOff = '22';
const _faintSeqOff = '22';
const _italicSeqOff = '23';
const _underlineSeqOff = '24';
const _blinkSeqOff = '25';
const _reverseSeqOff = '27';
const _crossOutSeqOff = '29';
const _overlineSeqOff = '55';
const _defaultFgSeq = '39';
const _defaultBgSeq = '49';

/// Represents a text string that could have some properties as color and text
/// styles.
class Style {
  late final ProfileEnum _profile;
  final _styles = <String>[];
  bool _sendReset = false;

  /// The text to show when render
  String text = '';

  // Dart doesn't support optional and named parameters yet
  // https://github.com/dart-lang/language/issues/1076
  /// Creates a new Style.
  Style(this.text, {ProfileEnum profile = ProfileEnum.ansi256}) : _profile = profile;

  /// The profile used by the Style.
  ProfileEnum get profile => _profile;

  /// Allows calling directly the Style to set the text value.
  ///
  /// ex:
  /// ```dart
  ///   final red = termlib.style()..fg(Color.red);
  ///   termlib.write(red('Hello!'));
  /// ```
  String call(Object value) {
    setText(value.toString());
    return toString();
  }

  /// Sets the Style's text value.
  ///
  /// This is a convenience method to set the text value.
  // ignore: use_setters_to_change_properties
  void setText(String value) => text = value;

  /// Sets the foreground color.
  void fg(Color color) {
    if (color == Color.reset) {
      _styles.add(color.sequence());
    } else {
      _styles.add(color.convert(colorKindFromProfile(_profile)).sequence());
    }
  }

  /// Sets the background color.
  void bg(Color color) {
    if (color == Color.reset) {
      _styles.add(color.sequence(background: true));
    } else {
      _styles.add(color.convert(colorKindFromProfile(_profile)).sequence(background: true));
    }
  }

  /// Resets the Style. Resets all styles and colors.
  void resetStyle() => _sendReset = true;

  /// Sets the bold style.
  void bold() => _styles.add(_boldSeq);

  /// Sets the bold off style.
  void boldOff() => _styles.add(_boldSeqOff);

  /// Sets the faint style.
  void faint() => _styles.add(_faintSeq);

  /// Sets the faint off style.
  void faintOff() => _styles.add(_faintSeqOff);

  /// Sets the italic style.
  void italic() => _styles.add(_italicSeq);

  /// Sets the italic off style.
  void italicOff() => _styles.add(_italicSeqOff);

  // /// Sets the default foreground color.
  // void setFgDefault() => _styles.add(_defaultFgSeq);

  // /// Sets the default background color.
  // void setBgDefault() => _styles.add(_defaultBgSeq);

  /// Sets the underline style.
  void underline([Color? color]) {
    if (color case final ucolor?) underlineColor(ucolor);
    _styles.add(_underlineSeq);
  }

  /// Sets the underline off style.
  void underlineOff() => _styles.add(_underlineSeqOff);

  /// Sets the double underline style.
  void doubleUnderline([Color? color]) {
    if (color case final ucolor?) underlineColor(ucolor);
    _styles.add(_doubleUnderlineSeq);
  }

  /// Sets the curly underline style.
  void curlyUnderline([Color? color]) {
    if (color case final ucolor?) underlineColor(ucolor);
    return _styles.add(_curlyUnderlineSeq);
  }

  /// Sets the dotted underline style.
  void dottedUnderline([Color? color]) {
    if (color case final ucolor?) underlineColor(ucolor);
    _styles.add(_dottedUnderlineSeq);
  }

  /// Sets the dashed underline style.
  void dashedUnderline([Color? color]) {
    if (color case final ucolor?) underlineColor(ucolor);
    _styles.add(_dashedUnderlineSeq);
  }

  /// Set underline color
  void underlineColor(Color color) {
    var colorSeq = color.convert(colorKindFromProfile(_profile)).sequence();
    if (colorSeq.isNotEmpty) colorSeq = '5${colorSeq.substring(1)}';
    return _styles.add(colorSeq);
  }

  /// Sets the blink style.
  void blink() => _styles.add(_blinkSeq);

  /// Sets the blink off style.
  void blinkOff() => _styles.add(_blinkSeqOff);

  /// Sets the reverse style.
  void reverse() => _styles.add(_reverseSeq);

  /// Sets the reverse off style.
  void reverseOff() => _styles.add(_reverseSeqOff);

  /// Sets the cross out style.
  void crossout() => _styles.add(_crossOutSeq);

  /// Sets the cross out off style.
  void crossoutOff() => _styles.add(_crossOutSeqOff);

  /// Sets the overline style.
  void overline() => _styles.add(_overlineSeq);

  /// Sets the overline off style.
  void overlineOff() => _styles.add(_overlineSeqOff);

  /// Apply a TextStyle to the Style object
  void apply(TextStyle style) {
    return switch (style) {
      TextStyle.bold => bold(),
      TextStyle.faint => faint(),
      TextStyle.italic => italic(),
      TextStyle.underline => underline(),
      TextStyle.doubleUnderline => doubleUnderline(),
      TextStyle.curlyUnderline => curlyUnderline(),
      TextStyle.dottedUnderline => dottedUnderline(),
      TextStyle.dashedUnderline => dashedUnderline(),
      TextStyle.blink => blink(),
      TextStyle.reverse => reverse(),
      TextStyle.crossOut => crossout(),
      TextStyle.overline => overline(),
    };
  }

  /// Returns the ANSI representation of the Style.
  @override
  String toString() {
    if (_profile == ProfileEnum.noColor) return text;
    if (_styles.isEmpty && !_sendReset) return text;

    final resolvedStyles = _styles.join(';');
    final prefix = resolvedStyles.isEmpty || text.isEmpty ? '' : '${ansi.CSI}${resolvedStyles}m';
    final postfix = _sendReset ? '${ansi.CSI}${_resetSeq}m' : '';
    return '$prefix$text$postfix';
  }
}
