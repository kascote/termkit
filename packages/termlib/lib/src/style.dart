import 'package:meta/meta.dart';
import 'package:termansi/termansi.dart' as ansi;

import 'colors.dart';
import 'shared/color_util.dart';
import 'termlib_base.dart';

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

/// Underline rendering variants for a [Style].
enum Underline {
  /// No underline.
  none,

  /// Single underline.
  single,

  /// Double underline.
  double,

  /// Curly underline.
  curly,

  /// Dotted underline.
  dotted,

  /// Dashed underline.
  dashed,
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

/// An immutable description of terminal text appearance: colors and text
/// attributes for a given color [profile].
///
/// A [Style] carries no text. Render text through it with [call] (or [render]),
/// which returns a self-closing ANSI string by default so styling does not
/// bleed into following output:
///
/// ```dart
/// final red = Style(fg: Color.red);
/// term.writeln(red('Hello!'));            // "\x1b[31mHello!\x1b[0m"
/// final warn = red.copyWith(bold: true);  // derive a variant
/// ```
///
/// Pass `reset: false` to render an *open* fragment for composition, where an
/// outer [Style] supplies the trailing reset:
///
/// ```dart
/// final lhs = red('left', reset: false);  // "\x1b[31mleft"
/// term.writeln(Style(bg: Color.blue)(' $lhs '));
/// ```
@immutable
class Style {
  /// The color profile used to resolve colors when rendering.
  final ProfileEnum profile;

  /// Foreground color, or `null` for none.
  final Color? fg;

  /// Background color, or `null` for none.
  final Color? bg;

  /// Bold attribute.
  final bool bold;

  /// Faint attribute.
  final bool faint;

  /// Italic attribute.
  final bool italic;

  /// Blink attribute.
  final bool blink;

  /// Reverse (inverse) attribute.
  final bool reverse;

  /// Cross-out (strikethrough) attribute.
  final bool crossOut;

  /// Overline attribute.
  final bool overline;

  /// Underline variant.
  final Underline underline;

  /// Underline color, or `null` to use the text color.
  final Color? underlineColor;

  /// Creates an immutable [Style].
  const Style({
    this.fg,
    this.bg,
    this.bold = false,
    this.faint = false,
    this.italic = false,
    this.blink = false,
    this.reverse = false,
    this.crossOut = false,
    this.overline = false,
    this.underline = Underline.none,
    this.underlineColor,
    this.profile = ProfileEnum.ansi256,
  });

  /// Returns a copy of this [Style] with the given fields replaced.
  ///
  /// Following the value-type convention, nullable color fields cannot be
  /// cleared back to `null` through [copyWith]; omit them to keep the current
  /// value, or build a fresh [Style] to drop a color.
  Style copyWith({
    Color? fg,
    Color? bg,
    bool? bold,
    bool? faint,
    bool? italic,
    bool? blink,
    bool? reverse,
    bool? crossOut,
    bool? overline,
    Underline? underline,
    Color? underlineColor,
    ProfileEnum? profile,
  }) {
    return Style(
      fg: fg ?? this.fg,
      bg: bg ?? this.bg,
      bold: bold ?? this.bold,
      faint: faint ?? this.faint,
      italic: italic ?? this.italic,
      blink: blink ?? this.blink,
      reverse: reverse ?? this.reverse,
      crossOut: crossOut ?? this.crossOut,
      overline: overline ?? this.overline,
      underline: underline ?? this.underline,
      underlineColor: underlineColor ?? this.underlineColor,
      profile: profile ?? this.profile,
    );
  }

  /// Returns a copy of this [Style] with [style] applied.
  Style apply(TextStyle style) {
    return switch (style) {
      TextStyle.bold => copyWith(bold: true),
      TextStyle.faint => copyWith(faint: true),
      TextStyle.italic => copyWith(italic: true),
      TextStyle.underline => copyWith(underline: Underline.single),
      TextStyle.doubleUnderline => copyWith(underline: Underline.double),
      TextStyle.curlyUnderline => copyWith(underline: Underline.curly),
      TextStyle.dottedUnderline => copyWith(underline: Underline.dotted),
      TextStyle.dashedUnderline => copyWith(underline: Underline.dashed),
      TextStyle.blink => copyWith(blink: true),
      TextStyle.reverse => copyWith(reverse: true),
      TextStyle.crossOut => copyWith(crossOut: true),
      TextStyle.overline => copyWith(overline: true),
    };
  }

  /// Renders [value] through this style.
  ///
  /// See [render]. This is the shorthand call form:
  /// ```dart
  ///   final red = termlib.style(fg: Color.red);
  ///   termlib.write(red('Hello!'));
  /// ```
  String call(Object value, {bool reset = true}) => render(value.toString(), reset: reset);

  /// Renders [text] through this style and returns the ANSI string.
  ///
  /// By default the result is self-closing (a trailing SGR reset is appended
  /// whenever styling was emitted) so it does not bleed into following output.
  /// Pass `reset: false` to leave it open for composition.
  ///
  /// In the [ProfileEnum.noColor] profile the colors are dropped but the text
  /// attributes (bold, faint, reverse, …) still render — NO_COLOR forbids
  /// color, not styling. When the style emits no sequences at all (e.g. a
  /// color-only style under noColor), [text] is returned unchanged with no
  /// reset.
  String render(String text, {bool reset = true}) {
    if (text.isEmpty) return text;

    final seqs = _sequences();
    if (seqs.isEmpty) return text;

    final prefix = '${ansi.CSI}${seqs.join(';')}m';
    final postfix = reset ? '${ansi.CSI}${_resetSeq}m' : '';
    return '$prefix$text$postfix';
  }

  /// Builds the ordered list of SGR parameters for this style.
  ///
  /// In the [ProfileEnum.noColor] profile the color parameters (foreground,
  /// background, underline color) are skipped, but the text-attribute
  /// parameters still emit — NO_COLOR strips color, not styling.
  List<String> _sequences() {
    final kind = colorKindFromProfile(profile);
    final withColor = profile != ProfileEnum.noColor;
    final seqs = <String>[];

    final fgColor = fg;
    if (withColor && fgColor != null) {
      seqs.add(fgColor == Color.reset ? fgColor.sequence() : fgColor.convert(kind).sequence());
    }
    final bgColor = bg;
    if (withColor && bgColor != null) {
      seqs.add(
        bgColor == Color.reset ? bgColor.sequence(background: true) : bgColor.convert(kind).sequence(background: true),
      );
    }
    if (bold) seqs.add(_boldSeq);
    if (faint) seqs.add(_faintSeq);
    if (italic) seqs.add(_italicSeq);

    final uColor = underlineColor;
    if (withColor && uColor != null) {
      var colorSeq = uColor.convert(kind).sequence();
      if (colorSeq.isNotEmpty) colorSeq = '5${colorSeq.substring(1)}';
      if (colorSeq.isNotEmpty) seqs.add(colorSeq);
    }
    final uSeq = _underlineSeq2(underline);
    if (uSeq.isNotEmpty) seqs.add(uSeq);

    if (blink) seqs.add(_blinkSeq);
    if (reverse) seqs.add(_reverseSeq);
    if (crossOut) seqs.add(_crossOutSeq);
    if (overline) seqs.add(_overlineSeq);

    return seqs;
  }

  String _underlineSeq2(Underline u) {
    return switch (u) {
      Underline.none => '',
      Underline.single => _underlineSeq,
      Underline.double => _doubleUnderlineSeq,
      Underline.curly => _curlyUnderlineSeq,
      Underline.dotted => _dottedUnderlineSeq,
      Underline.dashed => _dashedUnderlineSeq,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Style &&
          runtimeType == other.runtimeType &&
          fg == other.fg &&
          bg == other.bg &&
          bold == other.bold &&
          faint == other.faint &&
          italic == other.italic &&
          blink == other.blink &&
          reverse == other.reverse &&
          crossOut == other.crossOut &&
          overline == other.overline &&
          underline == other.underline &&
          underlineColor == other.underlineColor &&
          profile == other.profile;

  @override
  int get hashCode => Object.hash(
    fg,
    bg,
    bold,
    faint,
    italic,
    blink,
    reverse,
    crossOut,
    overline,
    underline,
    underlineColor,
    profile,
  );

  /// A debug representation of the style's SGR parameters. Not for terminal
  /// output — render text with [call]/[render] instead.
  @override
  String toString() => 'Style(${_sequences().join(';')})';
}
