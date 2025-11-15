import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

void main() {
  group('MouseEvent >', () {
    test('constructor with default modifiers', () {
      final event = MouseEvent(10, 20, MouseButton.down());
      expect(event.x, 10);
      expect(event.y, 20);
      expect(event.modifiers, const KeyModifiers(0));
    });

    test('constructor with modifiers', () {
      const modifiers = KeyModifiers(1);
      final event = MouseEvent(5, 15, MouseButton.down(), modifiers: modifiers);
      expect(event.x, 5);
      expect(event.y, 15);
      expect(event.modifiers, modifiers);
    });

    test('equality - identical events', () {
      final event1 = MouseEvent(10, 20, MouseButton.down(MouseButtonKind.left));
      final event2 = MouseEvent(10, 20, MouseButton.down(MouseButtonKind.left));

      expect(event1, equals(event2));
    });

    test('equality - different x', () {
      final event1 = MouseEvent(10, 20, MouseButton.down());
      final event2 = MouseEvent(11, 20, MouseButton.down());

      expect(event1, isNot(equals(event2)));
    });

    test('equality - different y', () {
      final event1 = MouseEvent(10, 20, MouseButton.down());
      final event2 = MouseEvent(10, 21, MouseButton.down());

      expect(event1, isNot(equals(event2)));
    });

    test('equality - different button', () {
      final event1 = MouseEvent(10, 20, MouseButton.down(MouseButtonKind.left));
      final event2 = MouseEvent(10, 20, MouseButton.down(MouseButtonKind.right));

      expect(event1, isNot(equals(event2)));
    });

    test('equality - different modifiers', () {
      final event1 = MouseEvent(10, 20, MouseButton.down(), modifiers: const KeyModifiers(3));
      final event2 = MouseEvent(10, 20, MouseButton.down(), modifiers: const KeyModifiers(2));

      expect(event1, isNot(equals(event2)));
    });

    test('hashCode - consistent', () {
      final event = MouseEvent(10, 20, MouseButton.down());
      expect(event.hashCode, equals(event.hashCode));
    });

    test('hashCode - equal objects have same hashCode', () {
      final event1 = MouseEvent(10, 20, MouseButton.down(MouseButtonKind.left));
      final event2 = MouseEvent(10, 20, MouseButton.down(MouseButtonKind.left));

      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('is InputEvent', () {
      final event = MouseEvent(0, 0, MouseButton.down());
      expect(event, isA<InputEvent>());
    });
  });

  group('MouseButton >', () {
    test('constructor', () {
      const button = MouseButton(MouseButtonKind.left, MouseButtonAction.down);
      expect(button.button, MouseButtonKind.left);
      expect(button.action, MouseButtonAction.down);
    });

    test('factory down with button', () {
      final button = MouseButton.down(MouseButtonKind.left);
      expect(button.button, MouseButtonKind.left);
      expect(button.action, MouseButtonAction.down);
    });

    test('factory down without button', () {
      final button = MouseButton.down();
      expect(button.button, MouseButtonKind.none);
      expect(button.action, MouseButtonAction.down);
    });

    test('factory up with button', () {
      final button = MouseButton.up(MouseButtonKind.right);
      expect(button.button, MouseButtonKind.right);
      expect(button.action, MouseButtonAction.up);
    });

    test('factory up without button', () {
      final button = MouseButton.up();
      expect(button.button, MouseButtonKind.none);
      expect(button.action, MouseButtonAction.up);
    });

    test('factory drag with button', () {
      final button = MouseButton.drag(MouseButtonKind.middle);
      expect(button.button, MouseButtonKind.middle);
      expect(button.action, MouseButtonAction.drag);
    });

    test('factory drag without button', () {
      final button = MouseButton.drag();
      expect(button.button, MouseButtonKind.none);
      expect(button.action, MouseButtonAction.drag);
    });

    test('factory moved with button', () {
      final button = MouseButton.moved(MouseButtonKind.left);
      expect(button.button, MouseButtonKind.left);
      expect(button.action, MouseButtonAction.moved);
    });

    test('factory moved without button', () {
      final button = MouseButton.moved();
      expect(button.button, MouseButtonKind.none);
      expect(button.action, MouseButtonAction.moved);
    });

    test('factory wheelUp', () {
      final button = MouseButton.wheelUp();
      expect(button.button, MouseButtonKind.none);
      expect(button.action, MouseButtonAction.wheelUp);
    });

    test('factory wheelDown', () {
      final button = MouseButton.wheelDown();
      expect(button.button, MouseButtonKind.none);
      expect(button.action, MouseButtonAction.wheelDown);
    });

    test('factory wheelLeft', () {
      final button = MouseButton.wheelLeft();
      expect(button.button, MouseButtonKind.none);
      expect(button.action, MouseButtonAction.wheelLeft);
    });

    test('factory wheelRight', () {
      final button = MouseButton.wheelRight();
      expect(button.button, MouseButtonKind.none);
      expect(button.action, MouseButtonAction.wheelRight);
    });

    test('factory none', () {
      final button = MouseButton.none();
      expect(button.button, MouseButtonKind.none);
      expect(button.action, MouseButtonAction.none);
    });

    test('equality - identical buttons', () {
      const button1 = MouseButton(MouseButtonKind.left, MouseButtonAction.down);
      const button2 = MouseButton(MouseButtonKind.left, MouseButtonAction.down);

      expect(button1, equals(button2));
    });

    test('equality - different button kind', () {
      const button1 = MouseButton(MouseButtonKind.left, MouseButtonAction.down);
      const button2 = MouseButton(MouseButtonKind.right, MouseButtonAction.down);

      expect(button1, isNot(equals(button2)));
    });

    test('equality - different action', () {
      const button1 = MouseButton(MouseButtonKind.left, MouseButtonAction.down);
      const button2 = MouseButton(MouseButtonKind.left, MouseButtonAction.up);

      expect(button1, isNot(equals(button2)));
    });

    test('hashCode - consistent', () {
      const button = MouseButton(MouseButtonKind.left, MouseButtonAction.down);
      expect(button.hashCode, equals(button.hashCode));
    });

    test('hashCode - equal objects have same hashCode', () {
      const button1 = MouseButton(MouseButtonKind.left, MouseButtonAction.down);
      const button2 = MouseButton(MouseButtonKind.left, MouseButtonAction.down);

      expect(button1.hashCode, equals(button2.hashCode));
    });
  });

  group('MouseButtonAction enum >', () {
    test('all values exist', () {
      expect(MouseButtonAction.values, contains(MouseButtonAction.down));
      expect(MouseButtonAction.values, contains(MouseButtonAction.drag));
      expect(MouseButtonAction.values, contains(MouseButtonAction.up));
      expect(MouseButtonAction.values, contains(MouseButtonAction.moved));
      expect(MouseButtonAction.values, contains(MouseButtonAction.wheelUp));
      expect(MouseButtonAction.values, contains(MouseButtonAction.wheelDown));
      expect(MouseButtonAction.values, contains(MouseButtonAction.wheelLeft));
      expect(MouseButtonAction.values, contains(MouseButtonAction.wheelRight));
      expect(MouseButtonAction.values, contains(MouseButtonAction.none));
    });
  });

  group('MouseButtonKind enum >', () {
    test('all values exist', () {
      expect(MouseButtonKind.values, contains(MouseButtonKind.none));
      expect(MouseButtonKind.values, contains(MouseButtonKind.left));
      expect(MouseButtonKind.values, contains(MouseButtonKind.middle));
      expect(MouseButtonKind.values, contains(MouseButtonKind.right));
    });
  });
}
