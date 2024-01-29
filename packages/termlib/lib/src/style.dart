import 'package:termansi/termansi.dart' as ansi;

import './colors.dart';
import './profile.dart';

const _resetSeq = '0';
const _boldSeq = '1';
const _faintSeq = '2';
const _italicSeq = '3';
const _underlineSeq = '4';
const _blinkSeq = '5';
const _reverseSeq = '7';
const _crossOutSeq = '9';
const _overlineSeq = '53';
// const _boldSeqOff = '22';
// const _faintSeqOff = '22';
// const _italicSeqOff = '23';
// const _underlineSeqOff = '24';
// const _blinkSeqOff = '25';
// const _reverseSeqOff = '27';
// const _crossOutSeqOff = '29';
// const _overlineSeqOff = '55';

/// Style is a style that can be applied to text.
class Style {
  late final ProfileEnum _profile;
  final _styles = <String>[];

  /// The text to show when render
  String text = '';

  // dart doesn't support optional and named parameters yet
  // https://github.com/dart-lang/language/issues/1076
  /// Creates a new Style.
  Style(this.text, {ProfileEnum profile = ProfileEnum.ansi16}) : _profile = profile;

  /// Sets the Style's text value.
  ///
  /// This is a convenience method to set the text value.
  // ignore: use_setters_to_change_properties
  void setText(String value) => text = value;

  /// convenience method to return the string
  String get s => toString();

  /// Sets the foreground color.
  void setFg(Color color) => _styles.add(color.sequence());

  /// Sets the background color.
  void setBg(Color color) => _styles.add(color.sequence(background: true));

  /// Sets the bold style.
  void setBold() => _styles.add(_boldSeq);

  /// Sets the faint style.
  void setFaint() => _styles.add(_faintSeq);

  /// Sets the italic style.
  void setItalic() => _styles.add(_italicSeq);

  /// Sets the underline style.
  void setUnderline() => _styles.add(_underlineSeq);

  /// Sets the blink style.
  void setBlink() => _styles.add(_blinkSeq);

  /// Sets the reverse style.
  void setReverse() => _styles.add(_reverseSeq);

  /// Sets the cross out style.
  void setCrossOut() => _styles.add(_crossOutSeq);

  /// Sets the overline style.
  void setOverline() => _styles.add(_overlineSeq);

  @override
  String toString() {
    if (_profile == ProfileEnum.noColor) return text;
    if (_styles.isEmpty) return text;

    final resolvedStyles = _styles.join(';');
    return '${ansi.CSI}${resolvedStyles}m$text${ansi.CSI}${_resetSeq}m';
  }
}
