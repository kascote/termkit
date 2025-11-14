import 'package:meta/meta.dart';

import 'event_base.dart';

/// Represent an empty event
@immutable
final class NoneEvent extends InternalEvent {
  /// Constructs a new instance of [NoneEvent].
  const NoneEvent();

  @override
  bool operator ==(Object other) => identical(this, other) || other is NoneEvent && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}
