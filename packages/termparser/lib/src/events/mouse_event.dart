import 'package:meta/meta.dart';

import 'event_base.dart';
import 'key_event.dart';

/// Represent a Mouse event.
@immutable
final class MouseEvent extends InputEvent {
  /// The x coordinate of the mouse event.
  final int x;

  /// The y coordinate of the mouse event.
  final int y;

  /// The button that was pressed.
  final MouseButton button;

  /// The key modifiers that could have been pressed.
  final KeyModifiers modifiers;

  /// Constructs a new instance of [MouseEvent].
  const MouseEvent(this.x, this.y, this.button, {this.modifiers = const KeyModifiers(0)});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MouseEvent &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          button == other.button &&
          modifiers == other.modifiers;

  @override
  int get hashCode => Object.hash(x, y, button, modifiers);
}

/// Represents a Mouse Event
@immutable
final class MouseButton {
  /// Mouse Button that was pressed or released
  final MouseButtonKind button;

  /// The kind of action that was performed
  final MouseButtonAction action;

  /// Constructs a new instance of [MouseButton].
  const MouseButton(this.button, this.action);

  /// Constructs a new instance of [MouseButton] with the given button and [MouseButtonAction.down]
  factory MouseButton.down([MouseButtonKind? button]) =>
      MouseButton(button ?? MouseButtonKind.none, MouseButtonAction.down);

  /// Constructs a new instance of [MouseButton] with the given button and [MouseButtonAction.up]
  factory MouseButton.up([MouseButtonKind? button]) =>
      MouseButton(button ?? MouseButtonKind.none, MouseButtonAction.up);

  /// Constructs a new instance of [MouseButton] with the given button and [MouseButtonAction.drag]
  factory MouseButton.drag([MouseButtonKind? button]) =>
      MouseButton(button ?? MouseButtonKind.none, MouseButtonAction.drag);

  /// Constructs a new instance of [MouseButton] with [MouseButtonAction.moved]
  factory MouseButton.moved([MouseButtonKind? button]) =>
      MouseButton(button ?? MouseButtonKind.none, MouseButtonAction.moved);

  /// Constructs a new instance of [MouseButton] with [MouseButtonAction.wheelUp]
  factory MouseButton.wheelUp() => const MouseButton(MouseButtonKind.none, MouseButtonAction.wheelUp);

  /// Constructs a new instance of [MouseButton] with [MouseButtonAction.wheelDown]
  factory MouseButton.wheelDown() => const MouseButton(MouseButtonKind.none, MouseButtonAction.wheelDown);

  /// Constructs a new instance of [MouseButton] with [MouseButtonAction.wheelLeft]
  factory MouseButton.wheelLeft() => const MouseButton(MouseButtonKind.none, MouseButtonAction.wheelLeft);

  /// Constructs a new instance of [MouseButton] with [MouseButtonAction.wheelRight]
  factory MouseButton.wheelRight() => const MouseButton(MouseButtonKind.none, MouseButtonAction.wheelRight);

  /// Constructs a new instance of [MouseButton] with [MouseButtonAction.none]
  factory MouseButton.none() => const MouseButton(MouseButtonKind.none, MouseButtonAction.none);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MouseButton && runtimeType == other.runtimeType && button == other.button && action == other.action;

  @override
  int get hashCode => Object.hash(button, action);
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
enum MouseButtonKind {
  /// No button
  none,

  /// Left mouse button
  left,

  /// Middle mouse button
  middle,

  /// Right mouse button
  right,
}
