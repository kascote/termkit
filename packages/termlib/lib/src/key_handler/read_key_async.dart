// import 'dart:async';
// import 'dart:io';

// import '../termlib_base.dart';
// import './events.dart';
// import './events_parser.dart';

// final _broadcastStream = stdin.asBroadcastStream();

// ///
// class ReadKeyAsync {
//   ///
//   static Future<Event> readKeyAsync(TermLib term) async {
//     const timeoutDuration = Duration(milliseconds: 100);
//     final completer = Completer<Event>();
//     final sequence = <int>[];
//     StreamSubscription<List<int>>? subscription;

//     final timer = Timer(timeoutDuration, () async {
//       await subscription!.cancel();
//       completer.complete(TimeOutEvent());
//     });

//     subscription = _broadcastStream.listen(
//       (event) async {
//         sequence.addAll(event);
//         await subscription!.cancel();
//         timer.cancel();
//         completer.complete(parseEvent(term, sequence));
//       },
//       onError: completer.completeError,
//       cancelOnError: true,
//     );

//     return completer.future;
//   }
// }
