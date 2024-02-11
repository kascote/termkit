import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// Represents a Mouse Event
@immutable
final class MouseButtonEvent extends Equatable {
  /// Mouse Button that was pressed or released
  final MouseButton button;

  /// The kind of action that was performed
  final MouseButtonAction action;

  /// Constructs a new instance of [MouseButtonEvent].
  const MouseButtonEvent(this.button, this.action);

  /// Constructs a new instance of [MouseButtonEvent] with the given button and [MouseButtonAction.down]
  factory MouseButtonEvent.down(MouseButton? button) =>
      MouseButtonEvent(button ?? MouseButton.none, MouseButtonAction.down);

  /// Constructs a new instance of [MouseButtonEvent] with the given button and [MouseButtonAction.up]
  factory MouseButtonEvent.up(MouseButton? button) =>
      MouseButtonEvent(button ?? MouseButton.none, MouseButtonAction.up);

  /// Constructs a new instance of [MouseButtonEvent] with the given button and [MouseButtonAction.drag]
  factory MouseButtonEvent.drag(MouseButton? button) =>
      MouseButtonEvent(button ?? MouseButton.none, MouseButtonAction.drag);

  /// Constructs a new instance of [MouseButtonEvent] with [MouseButtonAction.moved]
  factory MouseButtonEvent.moved(MouseButton? button) =>
      MouseButtonEvent(button ?? MouseButton.none, MouseButtonAction.moved);

  /// Constructs a new instance of [MouseButtonEvent] with [MouseButtonAction.wheelUp]
  factory MouseButtonEvent.wheelUp() => const MouseButtonEvent(MouseButton.none, MouseButtonAction.wheelUp);

  /// Constructs a new instance of [MouseButtonEvent] with [MouseButtonAction.wheelDown]
  factory MouseButtonEvent.wheelDown() => const MouseButtonEvent(MouseButton.none, MouseButtonAction.wheelDown);

  /// Constructs a new instance of [MouseButtonEvent] with [MouseButtonAction.wheelLeft]
  factory MouseButtonEvent.wheelLeft() => const MouseButtonEvent(MouseButton.none, MouseButtonAction.wheelLeft);

  /// Constructs a new instance of [MouseButtonEvent] with [MouseButtonAction.wheelRight]
  factory MouseButtonEvent.wheelRight() => const MouseButtonEvent(MouseButton.none, MouseButtonAction.wheelRight);

  /// Constructs a new instance of [MouseButtonEvent] with [MouseButtonAction.none]
  factory MouseButtonEvent.none() => const MouseButtonEvent(MouseButton.none, MouseButtonAction.none);

  @override
  List<Object?> get props => [button, action];
}

/// Represent a Mouse action
enum MouseButtonAction {
  /// Mouse button was pressed
  down,

  /// Mouse is in drag mode
  drag,

  /// Mouse button was released
  up,

  /// Mouse was moved
  moved,

  /// Mouse wheel was moved up
  wheelUp,

  /// Mouse wheel was moved down
  wheelDown,

  /// Mouse wheel was moved left
  wheelLeft,

  /// Mouse wheel was moved right
  wheelRight,

  /// No mouse action
  none,
}

/// Represent a Mouse button
enum MouseButton {
  /// No button
  none,

  /// Left mouse button
  left,

  /// Middle mouse button
  middle,

  /// Right mouse button
  right,
}
