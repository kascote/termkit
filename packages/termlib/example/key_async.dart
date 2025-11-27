import 'dart:async';
import 'dart:io';

import 'package:termlib/color_util.dart';
import 'package:termlib/termlib.dart';
import 'package:termparser/termparser.dart';
import 'package:termparser/termparser_events.dart';

// Configuration
class KeyViewerConfig {
  final bool withKitty;
  final bool withMouse;

  KeyViewerConfig({this.withKitty = false, this.withMouse = false});

  factory KeyViewerConfig.fromArgs(List<String> args) {
    if (args.isEmpty) {
      return KeyViewerConfig();
    }

    var withKitty = false;
    var withMouse = false;
    var help = false;

    for (final arg in args) {
      switch (arg) {
        case '--kitty':
        case '-k':
          withKitty = true;
        case '--mouse':
        case '-m':
          withMouse = true;
        case '--help':
        case '-h':
          help = true;
        default:
          stderr.writeln('Error: Unknown argument: $arg\n');
          _printHelp();
          exit(1);
      }
    }

    if (help) {
      _printHelp();
      exit(0);
    }

    return KeyViewerConfig(
      withKitty: withKitty,
      withMouse: withMouse,
    );
  }

  static void _printHelp() {
    stdout.writeln('''
Key Event Viewer - Display terminal key and mouse events

Usage: key_async [OPTIONS]

Options:
  -k, --kitty    Enable Kitty keyboard protocol enhancements
  -m, --mouse    Enable mouse event reporting
  -h, --help     Show this help message

Press ESC to exit the viewer.
''');
  }
}

// Theme definition
typedef Theme = ({
  Color primary, // For modifiers
  Color secondary, // For keys (char and named)
  Color accent, // For raw sequence
  Color muted, // For event type labels
  Color error, // For errors
});

// Parsed event data structure
class KeyEventData {
  final List<String> modifiers;
  final String keyValue;
  final KeyEventType? eventType;

  KeyEventData({
    required this.modifiers,
    required this.keyValue,
    this.eventType,
  });
}

class MouseEventData {
  final List<String> modifiers;
  final String button;
  final String action;
  final int x;
  final int y;

  MouseEventData({
    required this.modifiers,
    required this.button,
    required this.action,
    required this.x,
    required this.y,
  });
}

// Main viewer class
class KeyViewer {
  final TermLib t;
  final KeyViewerConfig config;
  final Theme baseColors;
  final List<String> displayHistory = [];

  int _lastTerminalLines = 0;
  List<Theme> _fadeThemes = [];

  KeyViewer(this.t, {required this.config}) : baseColors = _createTheme();

  static Theme _createTheme() {
    return (
      primary: Color.fromString('#719AFC'), // for modifiers
      secondary: Color.fromString('#00A4FF'), // for keys
      accent: Color.fromString('#12C78F'), // for raw sequence
      muted: Color.fromString('#FF6E63'), // Gray for event types
      error: Color.fromString('#E23080'), // Red for errors
    );
  }

  Future<void> run() async {
    t.eraseClear();

    final caps = await t.queryKeyboardCapabilities();
    final capsText = _formatCapabilities(caps);

    t
      ..writeln('# Key Event Viewer - Press ESC to exit')
      ..writeln(' ')
      ..writeln(capsText)
      ..writeln(' ');

    // Enable mouse events if requested
    if (config.withMouse) {
      t.enableMouseEvents();
    }

    // Generate fade palette based on terminal height
    _updateFadePalette();

    try {
      await _mainLoop();
    } on Object catch (e, st) {
      final s = t.style;
      t
        ..write(s()..fg(baseColors.error))
        ..writeln('Error: $e')
        ..writeln('$st');
    } finally {
      await _cleanup();
    }
  }

  void _updateFadePalette() {
    final currentLines = t.terminalLines;
    if (currentLines == _lastTerminalLines && _fadeThemes.isNotEmpty) {
      return; // No change, reuse existing palette
    }

    _lastTerminalLines = currentLines;

    _fadeThemes = List.generate(currentLines, (i) {
      final fadeFactor = 0.3 + (0.7 * (i / currentLines));
      return _createFadedTheme(fadeFactor);
    });
  }

  Future<void> _mainLoop() async {
    final events = t.eventStreamer<Event>(rawKeys: true);

    await for (final event in events) {
      var keepRunning = true;

      switch (event) {
        case EngineErrorEvent():
          t.writeln('EngineErrorEvent: $event');
        case RawKeyEvent():
          keepRunning = _handleRawKeyEvent(event);
        default:
          t.writeln('Unknown event: $event - ${event.runtimeType} - ${event is NoneEvent}');
      }

      if (!keepRunning) break;
    }
  }

  bool _handleRawKeyEvent(RawKeyEvent rawEvent) {
    final parser = Parser()..advance(rawEvent.sequence);
    final events = parser.drainEvents();

    for (final event in events) {
      if (event case KeyEvent(:final code)) {
        if (code.name == KeyCodeName.escape) return false;

        final data = _parseKeyEvent(event);
        final line = _formatKeyEventLine(data, rawEvent);
        _addToHistory(line);
        _redrawHistory();
      }
      if (event case MouseEvent()) {
        final data = _parseMouseEvent(event);
        final line = _formatMouseEventLine(data, rawEvent);
        _addToHistory(line);
        _redrawHistory();
      }
    }
    return true;
  }

  KeyEventData _parseKeyEvent(KeyEvent event) {
    final modifiers = _extractModifiers(event.modifiers);
    final keyValue = event.code.kind == KeyCodeKind.char ? event.code.char : event.code.name.toString().split('.').last;

    return KeyEventData(
      modifiers: modifiers,
      keyValue: keyValue,
      eventType: event.eventType,
    );
  }

  MouseEventData _parseMouseEvent(MouseEvent event) {
    return MouseEventData(
      modifiers: _extractModifiers(event.modifiers),
      button: event.button.button.toString().split('.').last,
      action: event.button.action.toString().split('.').last,
      x: event.x,
      y: event.y,
    );
  }

  List<String> _extractModifiers(KeyModifiers km) {
    final modifiers = <String>[];
    if (km.has(KeyModifiers.shift)) modifiers.add('shift');
    if (km.has(KeyModifiers.ctrl)) modifiers.add('ctrl');
    if (km.has(KeyModifiers.alt)) modifiers.add('alt');
    if (km.has(KeyModifiers.superKey)) modifiers.add('super');
    if (km.has(KeyModifiers.hyper)) modifiers.add('hyper');
    if (km.has(KeyModifiers.meta)) modifiers.add('meta');
    if (km.has(KeyModifiers.keyPad)) modifiers.add('keyPad');
    if (km.has(KeyModifiers.capsLock)) modifiers.add('capsLock');

    return modifiers;
  }

  String _formatCapabilities(KeyboardEnhancementFlagsEvent? flags) {
    if (flags == null) return 'unable to retrieve keyboard capabilities';

    final sb = StringBuffer()
      ..writeln('Keyboard capabilities:')
      ..writeln(
        '  ${flags.has(KeyboardEnhancementFlagsEvent.disambiguateEscapeCodes).toString().padLeft(5)}: Disambiguate Escape Codes',
      )
      ..writeln(
        '  ${flags.has(KeyboardEnhancementFlagsEvent.reportEventTypes).toString().padLeft(5)}: Report Event Types',
      )
      ..writeln(
        '  ${flags.has(KeyboardEnhancementFlagsEvent.reportAlternateKeys).toString().padLeft(5)}: Report Alternate Keys',
      )
      ..writeln(
        '  ${flags.has(KeyboardEnhancementFlagsEvent.reportAllKeysAsEscapeCodes).toString().padLeft(5)}: Report All Keys As Escape Codes',
      );

    return sb.toString();
  }

  String _formatKeyEventLine(KeyEventData data, RawKeyEvent rawEvent) {
    final sb = StringBuffer();

    if (data.modifiers.isNotEmpty) {
      sb
        ..write(data.modifiers.join('+'))
        ..write('+');
    }

    sb.write(data.keyValue);

    final eventTypeStr = switch (data.eventType) {
      KeyEventType.keyPress => ' PRESS',
      KeyEventType.keyRelease => ' RELEASE',
      KeyEventType.keyRepeat => ' REPEAT',
      _ => null,
    };
    if (eventTypeStr != null) {
      sb.write(eventTypeStr);
    }

    final rawSeq = _formatRawSequence(rawEvent.sequence);
    sb.write('    → $rawSeq');

    return sb.toString();
  }

  void _addToHistory(String line) {
    // Update palette if terminal size changed
    _updateFadePalette();

    displayHistory.add(line);

    // Keep only lines that fit in terminal height
    while (displayHistory.length > t.terminalLines && displayHistory.isNotEmpty) {
      displayHistory.removeAt(0);
    }
  }

  void _redrawHistory() {
    final totalLines = displayHistory.length;
    if (totalLines == 0) return;

    // Move cursor up to start of history (but only if we have more than 1 line)
    if (totalLines > 1) {
      t.moveUp(totalLines - 1);
    }

    // Redraw each line with appropriate fade
    final startIndex = _fadeThemes.length - totalLines;
    for (var i = 0; i < totalLines; i++) {
      final line = displayHistory[i];
      final themeIndex = startIndex + i;
      final fadedTheme = _fadeThemes[themeIndex.clamp(0, _fadeThemes.length - 1)];

      t
        ..eraseLine()
        ..writeln(_colorizeKeyEventLine(line, fadedTheme));
    }

    // Cursor is now at the end of history, ready for next line
  }

  Theme _createFadedTheme(double fadeFactor) {
    final fadeTarget = Color.fromRGBComponent(0, 0, 0);

    final primaryLerp = colorLerp(fadeTarget, baseColors.primary);
    final secondaryLerp = colorLerp(fadeTarget, baseColors.secondary);
    final accentLerp = colorLerp(fadeTarget, baseColors.accent);
    final mutedLerp = colorLerp(fadeTarget, baseColors.muted);
    final errorLerp = colorLerp(fadeTarget, baseColors.error);

    return (
      primary: primaryLerp(fadeFactor),
      secondary: secondaryLerp(fadeFactor),
      accent: accentLerp(fadeFactor),
      muted: mutedLerp(fadeFactor),
      error: errorLerp(fadeFactor),
    );
  }

  String _colorizeKeyEventLine(String line, Theme colors) {
    // Parse the line and apply colors
    // Format: [modifier+modifier+]key[ PRESS/RELEASE/REPEAT]    → raw sequence

    final arrowIdx = line.indexOf('→');
    final mainPart = arrowIdx >= 0 ? line.substring(0, arrowIdx).trim() : line.trim();
    final rawPart = arrowIdx >= 0 ? line.substring(arrowIdx) : '';

    final sb = StringBuffer();

    // Parse main part (modifiers + key + event type)
    final parts = mainPart.split(RegExp(r'\s+'));
    if (parts.isNotEmpty) {
      final keyAndMods = parts[0];
      final plusIdx = keyAndMods.lastIndexOf('+');

      if (plusIdx >= 0) {
        // Has modifiers
        final mods = keyAndMods.substring(0, plusIdx + 1); // Include the '+'
        final key = keyAndMods.substring(plusIdx + 1);

        final modStyle = t.style()..fg(colors.primary);
        final keyStyle = t.style()..fg(colors.secondary);

        sb
          ..write(modStyle(mods))
          ..write(keyStyle(key));
      } else {
        // No modifiers
        final keyStyle = t.style()..fg(colors.secondary);
        sb.write(keyStyle(keyAndMods));
      }

      // Event type (PRESS, RELEASE, REPEAT)
      if (parts.length > 1) {
        final eventStyle = t.style()..fg(colors.muted);
        sb
          ..write(' ')
          ..write(eventStyle(parts.sublist(1).join(' ')));
      }
    }

    // Raw sequence part
    if (rawPart.isNotEmpty) {
      final rawStyle = t.style()..fg(colors.accent);
      sb
        ..write('    ')
        ..write(rawStyle(rawPart));
    }

    return sb.toString();
  }

  String _formatRawSequence(List<int> bytes) {
    if (bytes.isEmpty) return '';

    final parts = <String>[];
    var i = 0;

    while (i < bytes.length) {
      final byte = bytes[i];

      // ESC (0x1B)
      if (byte == 0x1B) {
        // Check if it's CSI (ESC [)
        if (i + 1 < bytes.length && bytes[i + 1] == 0x5B) {
          parts.add('CSI');
          i += 2;
          continue;
        }
        // Check if it's OSC (ESC ])
        if (i + 1 < bytes.length && bytes[i + 1] == 0x5D) {
          parts.add('OSC');
          i += 2;
          continue;
        }
        // Just ESC
        parts.add('ESC');
        i++;
        continue;
      }

      // Digits (0x30-0x39) - group consecutive digits together
      if (byte >= 0x30 && byte <= 0x39) {
        final digitBuf = StringBuffer();
        while (i < bytes.length && bytes[i] >= 0x30 && bytes[i] <= 0x39) {
          digitBuf.writeCharCode(bytes[i]);
          i++;
        }
        parts.add(digitBuf.toString());
        continue;
      }

      // Printable ASCII (0x20-0x7E, excluding digits which are handled above)
      if (byte >= 0x20 && byte <= 0x7E) {
        parts.add(String.fromCharCode(byte));
        i++;
        continue;
      }

      // Control characters - show as decimal
      parts.add(byte.toString());
      i++;
    }

    return parts.join(' ');
  }

  String _formatMouseEventLine(MouseEventData data, RawKeyEvent rawEvent) {
    final sb = StringBuffer();

    final modifiers = data.modifiers.isNotEmpty ? data.modifiers.join('+') : 'none';
    sb.write('modifiers: $modifiers, button: ${data.button} / ${data.action}, x: ${data.x}, y: ${data.y}');

    final rawSeq = _formatRawSequence(rawEvent.sequence);
    sb.write('    → $rawSeq');

    return sb.toString();
  }

  Future<void> _cleanup() async {
    t.setKeyboardFlags(KeyboardEnhancementFlagsEvent.empty());

    if (config.withMouse) {
      t.disableMouseEvents();
    }

    //t.popCapabilities();
    await t.dispose();
  }
}

// Entry point
Future<void> main(List<String> arguments) async {
  final config = KeyViewerConfig.fromArgs(arguments);
  final t = TermLib();

  if (config.withKitty) t.enableKeyboardEnhancement();

  ProcessSignal.sigterm.watch().listen((event) async {
    t
      ..disableKeyboardEnhancement()
      ..disableRawMode()
      ..writeln('SIGTERM received');

    if (config.withMouse) {
      t.disableMouseEvents();
    }

    await t.flushThenExit(0);
  });

  final viewer = KeyViewer(t, config: config);
  await t.withRawModeAsync(viewer.run);
  await t.flushThenExit(0);
}
