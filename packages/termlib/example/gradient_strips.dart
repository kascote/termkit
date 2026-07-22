import 'package:termlib/color_util.dart';
import 'package:termlib/termlib.dart';

// Demonstrates how the same RGB colors look at each color profile: full
// truecolor, downsampled to the 256-color palette, and downsampled to the
// 16-color palette. Each strip is built once as a list of RGB colors, then
// rendered three times with a different Style.profile -- the profile alone
// drives the downsampling, no manual convert() calls needed.
Future<int> main() async {
  final exitCode = await TermRunner().run(display);
  return exitCode;
}

const _stripWidth = 72;

Future<int> display(InteractiveTerm t) async {
  t.writeln('Gradient strips: truecolor vs 256-color vs 16-color downsampling\n');

  _renderStrip(t, 'Hue sweep, full saturation/value', [
    for (var i = 0; i < _stripWidth; i++) Color.fromHSV(i * 360 / _stripWidth, 1, 1),
  ]);

  _renderStrip(t, 'Hue sweep, low value (dark colors)', [
    for (var i = 0; i < _stripWidth; i++) Color.fromHSV(i * 360 / _stripWidth, 1, 0.4),
  ]);

  _renderStrip(t, 'Desaturated hue sweep', [
    for (var i = 0; i < _stripWidth; i++) Color.fromHSV(i * 360 / _stripWidth, 0.35, 0.8),
  ]);

  _renderStrip(t, 'Grayscale ramp, black to white', [
    for (var i = 0; i < _stripWidth; i++) Color.fromRGBComponent(_level(i), _level(i), _level(i)),
  ]);

  final navyToOrange = colorLerp(Color.fromRGBComponent(0x0a, 0x14, 0x2f), Color.fromRGBComponent(0xff, 0x8c, 0x1a));
  _renderStrip(t, 'Dark navy to warm orange (colorLerp)', [
    for (var i = 0; i < _stripWidth; i++) navyToOrange(i / (_stripWidth - 1)),
  ]);

  return 0;
}

// Maps a strip index to a 0-255 gray level spanning the full strip width.
int _level(int index) => (index * 255 / (_stripWidth - 1)).round();

// Renders one labeled block of three rows: the same colors at truecolor,
// ansi256, and ansi16 fidelity.
void _renderStrip(InteractiveTerm t, String label, List<Color> colors) {
  t.writeln(label);
  _renderRow(t, 'tc ', colors, ProfileEnum.trueColor);
  _renderRow(t, '256', colors, ProfileEnum.ansi256);
  _renderRow(t, '16 ', colors, ProfileEnum.ansi16);
  t.writeln('');
}

void _renderRow(InteractiveTerm t, String rowLabel, List<Color> colors, ProfileEnum profile) {
  t.write('$rowLabel ');
  for (final color in colors) {
    t.write(Style(bg: color, profile: profile)(' '));
  }
  t.writeln('');
}
