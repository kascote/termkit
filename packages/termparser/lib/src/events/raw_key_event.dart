import 'package:meta/meta.dart';

import 'event_base.dart';
import 'shared.dart';

/// Raw Key Event
@immutable
final class RawKeyEvent extends InputEvent {
  /// The raw key values received
  final List<int> sequence;

  /// Constructs a new instance of [RawKeyEvent].
  RawKeyEvent(List<int> value) : sequence = List<int>.from(value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RawKeyEvent && runtimeType == other.runtimeType && listEquals(sequence, other.sequence);

  @override
  int get hashCode => Object.hashAll(sequence);
}
