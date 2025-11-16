import 'package:termparser/src/events/internal_events.dart';
import 'package:test/test.dart';

void main() {
  group('NoneEvent >', () {
    test('equality - different instances', () {
      // Use non-const to create different instances
      // ignore: prefer_const_constructors
      final event1 = NoneEvent();
      // Use non-const to create different instances
      // ignore: prefer_const_constructors
      final event2 = NoneEvent();

      expect(event1, equals(event2));
      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('equality - same instance', () {
      const event = NoneEvent();

      expect(event, equals(event));
    });

    test('hashCode - consistent', () {
      const event = NoneEvent();

      expect(event.hashCode, equals(event.hashCode));
    });
  });
}
