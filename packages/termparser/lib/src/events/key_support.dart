/// An extension type representing key modifiers (Shift, Ctrl, Alt, etc.)
extension type const KeyModifiers._(int value) {
  /// Represents no modifier keys pressed.
  static const KeyModifiers none = KeyModifiers._(0x00);

  /// Represents the Shift key modifier.
  static const KeyModifiers shift = KeyModifiers._(0x01);

  /// Represents the Alt key modifier.
  static const KeyModifiers alt = KeyModifiers._(0x02);

  /// Represents the Ctrl key modifier.
  static const KeyModifiers ctrl = KeyModifiers._(0x04);

  /// Represents the Super (Windows/Command) key modifier.
  static const KeyModifiers superKey = KeyModifiers._(0x08);

  /// Represents the Hyper key modifier.
  static const KeyModifiers hyper = KeyModifiers._(0x10);

  /// Represents the Meta key modifier.
  static const KeyModifiers meta = KeyModifiers._(0x20);

  /// Represents the that the key event originated from the keypad.
  static const KeyModifiers keyPad = KeyModifiers._(0x40);

  /// Represents the Caps Lock key modifier.
  static const KeyModifiers capsLock = KeyModifiers._(0x80);

  /// Optional factory if you really want to accept raw masks (e.g. parsing).
  factory KeyModifiers.fromMask(int mask) => KeyModifiers._(mask & _allKeyModifiersMask);

  /// Checks if the specified modifier is present.
  bool has(KeyModifiers modifier) => (value & modifier.value) == modifier.value;

  /// Combines two KeyModifier instances using a bitwise OR operation.
  KeyModifiers operator |(KeyModifiers other) => KeyModifiers._(value | other.value);

  /// Combines two KeyModifier instances using a bitwise AND operation.
  KeyModifiers operator &(KeyModifiers other) => KeyModifiers._(value & other.value);

  /// Returns a debug string representation of the active modifiers.
  String debugInfo() {
    final mods = <String>[];
    if (has(KeyModifiers.shift)) mods.add('shift');
    if (has(KeyModifiers.alt)) mods.add('alt');
    if (has(KeyModifiers.ctrl)) mods.add('ctrl');
    if (has(KeyModifiers.superKey)) mods.add('super');
    if (has(KeyModifiers.hyper)) mods.add('hyper');
    if (has(KeyModifiers.meta)) mods.add('meta');
    if (has(KeyModifiers.keyPad)) mods.add('keyPad');
    if (has(KeyModifiers.capsLock)) mods.add('capsLock');
    return "KeyModifiers{${mods.isEmpty ? 'none' : mods.join('+')}}";
  }
}

final int _allKeyModifiersMask =
    KeyModifiers.shift.value |
    KeyModifiers.alt.value |
    KeyModifiers.ctrl.value |
    KeyModifiers.superKey.value |
    KeyModifiers.hyper.value |
    KeyModifiers.meta.value |
    KeyModifiers.keyPad.value |
    KeyModifiers.capsLock.value;
