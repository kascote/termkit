import 'dart:developer' as developer;
import 'dart:io';

import 'package:termlib/src/event_queue.dart';
import 'package:termparser/termparser_events.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

void main() async {
  stdout
    ..writeln('EventQueue Memory Benchmark')
    ..writeln('=' * 80);

  final serviceInfo = await developer.Service.getInfo();

  if (serviceInfo.serverUri == null) {
    stderr
      ..writeln('ERROR: VM service not available')
      ..writeln('Run with: dart --observe test/benchmark/memory_benchmark.dart');
    exit(1);
  }

  stdout.writeln('Connecting to VM service: ${serviceInfo.serverUri}');

  final wsUri = serviceInfo.serverUri.toString().replaceFirst('http://', 'ws://');
  final service = await vmServiceConnectUri(wsUri);
  final vm = await service.getVM();
  final isolateId = vm.isolates!.first.id!;

  stdout
    ..writeln('Isolate: $isolateId')
    ..writeln();

  await _benchmarkEmptyQueue(service, isolateId);
  await _benchmarkSmallQueue(service, isolateId);
  await _benchmarkMediumQueue(service, isolateId);
  await _benchmarkFullQueue(service, isolateId);
  await _benchmarkMixedEventTypes(service, isolateId);

  await service.dispose();
  stdout
    ..writeln()
    ..writeln('=' * 80)
    ..writeln('✅ Memory benchmark complete');
}

Future<void> _benchmarkEmptyQueue(VmService service, String isolateId) async {
  stdout.writeln('Scenario: Empty queue (baseline)');

  await service.getAllocationProfile(isolateId, gc: true);
  await Future<void>.delayed(const Duration(milliseconds: 100));

  final before = await service.getMemoryUsage(isolateId);

  final queue = EventQueue();

  final after = await service.getMemoryUsage(isolateId);
  final delta = after.heapUsage! - before.heapUsage!;

  stdout
    ..writeln('  Heap before: ${_formatBytes(before.heapUsage!)}')
    ..writeln('  Heap after:  ${_formatBytes(after.heapUsage!)}')
    ..writeln('  Delta:       ${_formatBytes(delta)}')
    ..writeln('  Queue size:  ${queue.length} events')
    ..writeln();
}

Future<void> _benchmarkSmallQueue(VmService service, String isolateId) async {
  stdout.writeln('Scenario: Small queue (100 events)');

  await service.getAllocationProfile(isolateId, gc: true);
  await Future<void>.delayed(const Duration(milliseconds: 100));

  final before = await service.getMemoryUsage(isolateId);

  final queue = EventQueue();
  for (var i = 0; i < 100; i++) {
    queue.enqueue(KeyEvent.fromString('a'));
  }

  final after = await service.getMemoryUsage(isolateId);
  final delta = after.heapUsage! - before.heapUsage!;

  stdout
    ..writeln('  Heap before: ${_formatBytes(before.heapUsage!)}')
    ..writeln('  Heap after:  ${_formatBytes(after.heapUsage!)}')
    ..writeln('  Delta:       ${_formatBytes(delta)}')
    ..writeln('  Queue size:  ${queue.length} events')
    ..writeln('  Per event:   ${_formatBytes(delta ~/ queue.length)}')
    ..writeln();
}

Future<void> _benchmarkMediumQueue(VmService service, String isolateId) async {
  stdout.writeln('Scenario: Medium queue (500 events)');

  await service.getAllocationProfile(isolateId, gc: true);
  await Future<void>.delayed(const Duration(milliseconds: 100));

  final before = await service.getMemoryUsage(isolateId);

  final queue = EventQueue();
  for (var i = 0; i < 500; i++) {
    queue.enqueue(KeyEvent.fromString('a'));
  }

  final after = await service.getMemoryUsage(isolateId);
  final delta = after.heapUsage! - before.heapUsage!;

  stdout
    ..writeln('  Heap before: ${_formatBytes(before.heapUsage!)}')
    ..writeln('  Heap after:  ${_formatBytes(after.heapUsage!)}')
    ..writeln('  Delta:       ${_formatBytes(delta)}')
    ..writeln('  Queue size:  ${queue.length} events')
    ..writeln('  Per event:   ${_formatBytes(delta ~/ queue.length)}')
    ..writeln();
}

Future<void> _benchmarkFullQueue(VmService service, String isolateId) async {
  stdout.writeln('Scenario: Full queue (1000 events)');

  await service.getAllocationProfile(isolateId, gc: true);
  await Future<void>.delayed(const Duration(milliseconds: 100));

  final before = await service.getMemoryUsage(isolateId);

  final queue = EventQueue();
  for (var i = 0; i < 1000; i++) {
    queue.enqueue(KeyEvent.fromString('a'));
  }

  final after = await service.getMemoryUsage(isolateId);
  final delta = after.heapUsage! - before.heapUsage!;

  stdout
    ..writeln('  Heap before: ${_formatBytes(before.heapUsage!)}')
    ..writeln('  Heap after:  ${_formatBytes(after.heapUsage!)}')
    ..writeln('  Delta:       ${_formatBytes(delta)}')
    ..writeln('  Queue size:  ${queue.length} events')
    ..writeln('  Per event:   ${_formatBytes(delta ~/ queue.length)}')
    ..writeln();
}

Future<void> _benchmarkMixedEventTypes(
  VmService service,
  String isolateId,
) async {
  stdout.writeln('Scenario: Mixed event types (1000 events)');

  await service.getAllocationProfile(isolateId, gc: true);
  await Future<void>.delayed(const Duration(milliseconds: 100));

  final before = await service.getMemoryUsage(isolateId);

  final queue = EventQueue();
  for (var i = 0; i < 250; i++) {
    queue.enqueue(KeyEvent.fromString('a'));
  }
  for (var i = 0; i < 250; i++) {
    queue.enqueue(
      const MouseEvent(
        10,
        20,
        MouseButton(MouseButtonKind.left, MouseButtonAction.down),
      ),
    );
  }
  for (var i = 0; i < 250; i++) {
    queue.enqueue(const FocusEvent());
  }
  for (var i = 0; i < 250; i++) {
    queue.enqueue(const PasteEvent('pasted text'));
  }

  final after = await service.getMemoryUsage(isolateId);
  final delta = after.heapUsage! - before.heapUsage!;

  stdout
    ..writeln('  Heap before: ${_formatBytes(before.heapUsage!)}')
    ..writeln('  Heap after:  ${_formatBytes(after.heapUsage!)}')
    ..writeln('  Delta:       ${_formatBytes(delta)}')
    ..writeln('  Queue size:  ${queue.length} events')
    ..writeln('  Per event:   ${_formatBytes(delta ~/ queue.length)}')
    ..writeln('  Event types: KeyEvent (250), MouseEvent (250), FocusEvent (250), PasteEvent (250)')
    ..writeln();
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
}
