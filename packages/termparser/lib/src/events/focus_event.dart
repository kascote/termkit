import 'package:meta/meta.dart';

import 'event_base.dart';

/// Represent a Focus event.
@immutable
final class FocusEvent extends ResponseEvent {
  /// The focus state.
  final bool hasFocus;

  /// Constructs a new instance of [FocusEvent].
  const FocusEvent({this.hasFocus = true});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FocusEvent && runtimeType == other.runtimeType && hasFocus == other.hasFocus;

  @override
  int get hashCode => hasFocus.hashCode;
}
