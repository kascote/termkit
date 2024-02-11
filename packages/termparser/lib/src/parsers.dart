import './sequences/key_sequence.dart';
import 'sequences.dart';
import 'sequences/key_parser.dart';

///
Sequence? parseChar(String char, {bool escO = false}) {
  if (escO) {
    switch (char) {
      case 'P':
        return const KeySequence(KeyCode(name: KeyCodeName.f1));
      case 'Q':
        return const KeySequence(KeyCode(name: KeyCodeName.f2));
      case 'R':
        return const KeySequence(KeyCode(name: KeyCodeName.f3));
      case 'S':
        return const KeySequence(KeyCode(name: KeyCodeName.f4));
      default:
        return const KeySequence(KeyCode());
    }
  }
  switch (char) {
    case '\r' || '\n':
      return const KeySequence(KeyCode(name: KeyCodeName.enter));
    case '\t':
      return const KeySequence(KeyCode(name: KeyCodeName.tab));
    case '\x7f':
      return const KeySequence(KeyCode(name: KeyCodeName.backTab));
    case '\x1b':
      return const KeySequence(KeyCode(name: KeyCodeName.escape));
    case '\x00':
      return const KeySequence(KeyCode());
    default:
      return KeySequence(KeyCode(char: char));
  }
}

///
Sequence? parseESCSequence(String char) {
  // EscO[P-S] is handled in the Performer, see parse_char & esc_o argument
  // No need to handle other cases here? It's just Alt+$char
  return KeySequence(KeyCode(char: char), modifiers: const KeyModifiers(KeyModifiers.alt));
}

///
/// https://sw.kovidgoyal.net/kitty/keyboard-protocol/#legacy-functional-keys
Sequence parseCSISequence(List<String> parameters, int ignoredParameterCount, String char, {List<int>? block}) {
  // print('parseCSISequence: $parameters, $ignoredParameterCount, $char, $block');

  return switch (char) {
    'A' => _parseKeyAndModifiers(KeyCodeName.up, parameters.length == 2 ? parameters[1] : ''),
    'B' => _parseKeyAndModifiers(KeyCodeName.down, parameters.length == 2 ? parameters[1] : ''),
    'C' => _parseKeyAndModifiers(KeyCodeName.right, parameters.length == 2 ? parameters[1] : ''),
    'D' => _parseKeyAndModifiers(KeyCodeName.left, parameters.length == 2 ? parameters[1] : ''),
    'F' => _parseKeyAndModifiers(KeyCodeName.end, parameters.length == 2 ? parameters[1] : ''),
    'H' => _parseKeyAndModifiers(KeyCodeName.home, parameters.length == 2 ? parameters[1] : ''),
    'P' => _parseKeyAndModifiers(KeyCodeName.f1, parameters.length == 2 ? parameters[1] : ''),
    'Q' => _parseKeyAndModifiers(KeyCodeName.f2, parameters.length == 2 ? parameters[1] : ''),
    'R' => _parseKeyAndModifiers(KeyCodeName.f3, parameters.length == 2 ? parameters[1] : ''),
    'S' => _parseKeyAndModifiers(KeyCodeName.f4, parameters.length == 2 ? parameters[1] : ''),
    // TODO: include shift ?
    'Z' => _parseKeyAndModifiers(KeyCodeName.backTab, parameters.length == 2 ? parameters[1] : ''),
    // will not implement ESC[M
    // 'M'
    'M' || 'm' => sgrMouseParser(parameters, char, ignoredParameterCount),
    'I' => const FocusSequence(),
    'O' => const FocusSequence(hasFocus: false),
    'u' => _parseKeyboardEnhancedMode(parameters, ignoredParameterCount, char),

    // 'R' => {} , // csiCursorPositionParser,
    // 'm' => {}, // csiXtermMouseParser,

    // '~' => {}, // csiTildeParser

    _ => const NoneSequence()
  };
}

///
Sequence parseOscSequence(List<String> parameters, int ignoredParameterCount, String char, {List<int>? block}) {
  return KeySequence(KeyCode(char: char));
}

Sequence _parseKeyAndModifiers(KeyCodeName name, String parameters) {
  final (modifier, event) = modifierAndEventParser(parameters);
  return KeySequence(KeyCode(name: name), modifiers: modifier, eventType: event);
}

// This function parses `CSI … u` sequences. These are sequences defined in either
// the `CSI u` (a.k.a. "Fix Keyboard Input on Terminals - Please", https://www.leonerd.org.uk/hacks/fixterms/)
// or Kitty Keyboard Protocol (https://sw.kovidgoyal.net/kitty/keyboard-protocol/) specifications.
// This CSI sequence is a tuple of semicolon-separated numbers.
Sequence _parseKeyboardEnhancedMode(List<String> parameters, int ignoredParameterCount, String char) {
  if (parameters.isEmpty) return const NoneSequence();

  if (parameters[0] == '?') {
    return parseKeyboardEnhancedCode(parameters[1]);
  }

  // In `CSI u`, this is parsed as:
  //
  //     CSI codePoint ; modifiers u
  //     codePoint: ASCII Dec value
  //
  // The Kitty Keyboard Protocol extends this with optional components that can be
  // enabled progressively. The full sequence is parsed as:
  //
  //     CSI unicode-key-code:alternate-key-codes ; modifiers:event-type ; text-as-codepoints u

  final codePoints = parameters.first.split(':');
  final codePoint = int.tryParse(codePoints.first);
  if (codePoint == null) return const NoneSequence(); // TODO(nelson): or error ?

  final (modifierMask, eventKind) = parameters.length == 1 ? (null, null) : modifierAndKindParse(parameters[1]);
  var modifiers = modifierMask == null ? KeyModifiers.empty() : parseModifier(modifierMask);
  final kind = _parseEventKind(eventKind);
  final stateFromModifiers = _parseModifiersToState(modifierMask);

  var (keyCode, stateFromKeyCode) = _translateFunctionalKeyCode(codePoint);

  return const NoneSequence();
}
