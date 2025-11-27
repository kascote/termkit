import 'package:termlib/color_util.dart';
import 'package:termlib/termlib.dart';

// test to see how 256 colors downgrades to 16 colors
Future<int> main() async {
  final exitCode = await TermRunner().run(display);
  return exitCode;
}

Future<int> display(TermLib t) async {
  final colors = [
    [
      // https://vscodethemes.com/e/ryanolsonx.solarized
      (name: 'solarized', color: '#052B36'),
      // https://vscodethemes.com/e/ryanolsonx.solarized/solarized-light
      (name: 'solarized', color: '#FDF6E3'),
    ],
    [
      // https://vscodethemes.com/e/catppuccin.catppuccin-vsc/catppuccin-mocha
      (name: 'catppuccin', color: '#1E1E2E'),
      // https://vscodethemes.com/e/alexdauenhauer.catppuccin-noctis/catppuccin-noctis-latte
      (name: 'catppuccin', color: '#EFF1F5'),
    ],
    [
      // https://vscodethemes.com/e/mvllow.rose-pine/rose-pine
      (name: 'rosePine', color: '#191724'),
      // https://vscodethemes.com/e/mvllow.rose-pine/rose-pine-dawn
      (name: 'rosePine', color: '#FAF4EC'),
    ],
    [
      // https://vscodethemes.com/e/jdinhlife.gruvbox/gruvbox-dark-soft
      (name: 'gruvbox', color: '#32302F'),
      // https://vscodethemes.com/e/jdinhlife.gruvbox/gruvbox-light-hard
      (name: 'gruvbox', color: '#F9F5D7'),
    ],
    [
      // https://vscodethemes.com/e/zhuangtongfa.material-theme
      (name: 'oneDarkPro', color: '#282C35'),
      // https://vscodethemes.com/e/enkia.tokyo-night/tokyo-night-light
      (name: 'tokyoNight', color: '#D5D6DB'),
    ],
    [
      //https://vscodethemes.com/e/equinusocio.vsc-community-material-theme
      (name: 'monokai', color: '#272822'),
      // https://vscodethemes.com/e/shopify.ruby-extensions-pack/spinel-light
      (name: 'ruby', color: '#E2DFF5'),
    ],
    [
      // https://vscodethemes.com/e/sdras.night-owl
      (name: 'nightOwl', color: '#031627'),
      // https://vscodethemes.com/e/benbusby.earthbound-themes/earthbound-cave-of-the-past
      (name: 'earthBound', color: '#B0D0B9'),
    ],
    [
      // https://vscodethemes.com/e/ahmadawais.shades-of-purple
      (name: 'shadesPurple', color: '#2D2B55'),
      // https://vscodethemes.com/e/transcode.transcode/transcode
      (name: 'transcode', color: '#C6EFFF'),
    ],
    [
      // https://vscodethemes.com/e/arcticicestudio.nord-visual-studio-code
      (name: 'nord', color: '#2E3440'),
      // https://vscodethemes.com/e/iconical.rawreme/angelic-beta-rawreme
      (name: 'rawreme', color: '#EBE5F7'),
    ],
  ];

  t.writeln(
    t.style("${'Dark'.padRight(35)}${'Light'.padRight(26)}")
      ..underline(Color.yellow)
      ..bg(Color.reset)
      ..resetStyle(),
  );
  for (final entry in colors) {
    showColor(t, entry[0].name, entry[0].color);
    t.write(' ' * 9);
    showColor(t, entry[1].name, entry[1].color);
    t.writeln('');
  }

  return 0;
}

void showColor(TermLib t, String name, String color) {
  final clr = Color.fromString(color);
  final luminance = colorLuminance(clr);
  t
    ..write(
      t.style(name.padRight(15))
        ..faint()
        ..bg(Color.reset)
        ..resetStyle(),
    )
    ..write(t.style('     ')..bg(clr))
    ..write(t.style(' ')..bg(Color.reset))
    ..write(
      t.style(luminance.toStringAsFixed(3))
        ..faint()
        ..bg(Color.reset)
        ..resetStyle(),
    );
}
