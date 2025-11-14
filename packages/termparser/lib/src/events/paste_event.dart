import 'package:meta/meta.dart';

import 'event_base.dart';

/// Paste Action Event
@immutable
final class PasteEvent extends InputEvent {
  /// The pasted text
  final String text;

  /// Constructs a new instance of [PasteEvent].
  const PasteEvent(this.text);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PasteEvent && runtimeType == other.runtimeType && text == other.text;

  @override
  int get hashCode => text.hashCode;
}
