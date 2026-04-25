# termlib — Streams, Event Queue & Input Flow

Scope: `packages/termlib` after PLAN.md Phases 1–5.

All file/line references are in `packages/termlib/lib/src/...`.

---

## 1. The sealed `Term` split

`Term.open({backend})` is the single entry point. It returns one of two sealed subtypes based on `backend.hasTerminal`:

```dart
// termlib_base.dart:72-76
factory Term.open({TermBackend? backend, ProfileEnum? profile}) {
  final b = backend ?? TermBackend.io();
  if (b.hasTerminal) return InteractiveTerm._(b, profile);
  return PipedTerm._(b, profile);
}
```

| Subtype           | Input surface                                      | Raw mode | Events |
| ----------------- | -------------------------------------------------- | -------- | ------ |
| `InteractiveTerm` | `events` + `tryEvent` / `awaitEvent` / `nextEvent` | yes      | parsed |
| `PipedTerm`       | `stdinBytes`                                       | no       | no     |

The split is **compile-time**: `stdinBytes` does not exist on `InteractiveTerm` and `events`/`tryEvent`/… do not exist on `PipedTerm`. There is no runtime `hasTerminal` gate on the input APIs (Phase 2). The few remaining runtime-checked sites (e.g. `TermRunner.build()`) throw `TerminalNotInteractive`.

Dispatch pattern:

```dart
final term = Term.open();
switch (term) {
  case InteractiveTerm(): /* events / poll / raw mode */
  case PipedTerm():       /* stdinBytes only */
}
```

---

## 2. The backend seam (`TermBackend`)

Every side-effectful surface termlib touches is behind `TermBackend`:

```dart
// shared/term_backend.dart
class TermBackend {
  final Stream<List<int>> stdin;      // must be broadcast
  final TermSink stdout;              // narrow output surface
  final EnvironmentData env;
  final TermOs termOs;                // raw-mode FFI
  final bool hasTerminal;

  final EventQueue? eventQueue;       // test injection
  final Stream<Event>? eventSource;   // test injection (pre-parsed)
  final int maxQueueSize;             // default 5000
  final bool coalesceMotion;          // default true
}
```

- `TermBackend.io()` — production: wraps `dart:io` `stdin.asBroadcastStream()`, `Platform.environment`, real `TermSink.io()`, FFI raw-mode.
- `TermBackend.fake({...})` — tests: inject a stdin byte stream, a pre-parsed `eventSource`, or a pre-built `eventQueue`. Captures stdout in `BufferTermSink`.

No zones, no globals. `TerminalOverrides` was removed in Phase 1 — all plumbing is explicit injection.

`TermSink` (`shared/term_sink.dart`) is the narrow output contract — just `write(Object)`, `close()`, `hasTerminal`, `terminalColumns`, `terminalLines`. `BufferTermSink.output` exposes captured writes for assertions.

---

## 3. Input flow (interactive)

```
        stdin bytes (backend.stdin, broadcast)
                      │
                      ▼
            eventTransformer() (termparser)        ← one subscription, installed by InteractiveTerm._
                      │
                      ▼
             _onEventParsed(Event)
                      │
          ┌───────────┴─────────────────┐
          ▼                             ▼
     EventQueue.enqueue          _eventBroadcastController.add
     (pull consumers)            (push consumers: events.listen)
          │
          │  — on enqueue —
          │    1. check waiter list first → direct hand-off, bypass buffer
          │    2. try coalesce vs last (mouse motion / resize)
          │    3. if queue full, drop oldest (accumulate for QueueOverflowEvent)
          │    4. append
          │
          │  — on dequeue / awaitEvent —
          │    • flush any pending overflow as QueueOverflowEvent on broadcast
          │    • O(n) scan for first `is T`
          │
          ▼
  tryEvent<T>() / awaitEvent<T>() / nextEvent<T>()
```

One parser subscription → one queue + one broadcast. Both sinks see **the same event instance**. No double parsing.

### Parser subscription

```dart
// termlib_base.dart:226
_eventSubscription = b.stdin
    .transform(eventTransformer())
    .listen(_onEventParsed, onError: _onParserError);
```

Parser errors never cancel the subscription (Phase 1):

```dart
// termlib_base.dart:371-373
void _onParserError(Object error, StackTrace stack) {
  _onEventParsed(EngineErrorEvent(const [], message: error.toString()));
}
```

---

## 4. The event queue

`EventQueue` (`event_queue.dart`, `@internal`) is a bounded FIFO with three side-paths: waiter hand-off, coalesce-at-enqueue, and drop-oldest-with-overflow.

### Waiter hand-off (Phase 1)

An `awaitEvent<T>()` caller registers a `_Waiter<T>`. Before the queue buffers anything, `enqueue` scans the waiter list and delivers directly to the first match — the event never hits the queue:

```dart
// event_queue.dart:101-110
void enqueue(Event event) {
  if (_disposed) return;
  for (var i = 0; i < _waiters.length; i++) {
    final w = _waiters[i];
    if (w.matches(event)) {
      _waiters.removeAt(i);
      w.deliver(event);
      return;
    }
  }
  /* coalesce / drop-oldest / append ... */
}
```

This kills the old `pollTimeout` signal race: a waiter registered before enqueue cannot miss its wake-up. Fast-path at registration: if a matching event is already buffered, `awaitEvent` returns it synchronously via a resolved future.

```dart
// event_queue.dart:167-187
Future<T?> awaitEvent<T extends Event>({Duration? timeout}) {
  if (_disposed) return Future<T?>.error(const TermDisposed());
  final buffered = dequeue<T>();
  if (buffered != null) return Future<T?>.value(buffered);

  final waiter = _Waiter<T>();
  _waiters.add(waiter);

  if (timeout != null) {
    return waiter.future.timeout(timeout, onTimeout: () {
      _waiters.remove(waiter);
      return null;
    });
  }
  return waiter.future;
}
```

Cleanup: timed-out waiters remove themselves; `dispose()` completes pending waiters with `TermDisposed`; `_completer.isCompleted` guards every completion.

### Coalesce-at-enqueue (Phase 3)

When `coalesceMotion` is true (default), consecutive high-frequency events collapse instead of appending:

- `MouseEvent` with action `moved`/`drag` AND same button+modifiers as the tail → replace tail.
- `WindowResizeEvent` → always replace tail when tail is also a resize.

Transitions (mousedown → drag → mouseup → move) are preserved — only **intra-state** samples collapse. Opt-out via `TermBackend.coalesceMotion = false`.

### Drop-oldest + `QueueOverflowEvent` (Phase 3)

On overflow the oldest event is removed and `_pendingDrops` increments. Drops are rate-limited into a single `QueueOverflowEvent` emitted on the **next** `dequeue` call:

```dart
// event_queue.dart:208-215
void _flushPendingOverflow() {
  if (_pendingDrops == 0 || onOverflow == null) return;
  final type = _lastDroppedType ?? Event;
  final count = _pendingDrops;
  _pendingDrops = 0;
  _lastDroppedType = null;
  onOverflow!(type, count);  // wired to _eventBroadcastController.add
}
```

`QueueOverflowEvent { type, dropped }` reaches `events.listen` subscribers directly; pull consumers observe it if they subscribe to `events` alongside their polling.

### O(n) scan — accepted

`dequeue<T>` iterates the buffer for the first `is T`. Justified by:

- Waiter hand-off keeps the queue **empty** whenever any consumer is actively awaiting.
- Coalesce collapses the two hottest event types, so single-type buildup is unrealistic.
- Typical interactive depth is tens. Worst-case 5000-element scan is ~50–200µs in Dart — cheaper than a hash-of-queues allocation on small queues.

See `TODO(perf)` at `event_queue.dart:146` — revisit if a real reproducer shows scan time.

---

## 5. Pull API vs push API

All four live on `InteractiveTerm` and share the single parser → queue + broadcast pipeline. `T?` return types carry real information; `NoneEvent` is gone.

| API                                  | Signature                   | Blocks?              | Returns when empty | Use                              |
| ------------------------------------ | --------------------------- | -------------------- | ------------------ | -------------------------------- |
| `tryEvent<T>()`                      | `T?`                        | no                   | `null`             | render loops, non-blocking check |
| `awaitEvent<T>({Duration? timeout})` | `Future<T?>`                | yes, up to `timeout` | `null` on timeout  | probe queries, input w/ deadline |
| `nextEvent<T>()`                     | `Future<T>`                 | yes, forever         | never returns null | blocking CLI prompts             |
| `events.listen((e) { ... })`         | `Stream<Event>` (broadcast) | push                 | n/a                | reactive style, diagnostics      |

Contract notes:

- `tryEvent<T>()` is pure dequeue — it never registers a waiter, so it always reflects the current buffer.
- `awaitEvent` with no timeout waits forever. Prefer `nextEvent` in that case; its return type isn't nullable.
- `nextEvent<T>()` only ever terminates with `TermDisposed` at shutdown; the `!` on `awaitEvent`'s result is safe.
- `events` is a broadcast — every subscriber sees every event, **including** `QueueOverflowEvent`.

---

## 6. Piped input

`PipedTerm.stdinBytes` is the single exposed surface:

```dart
// termlib_base.dart:412
Stream<List<int>> get stdinBytes => _b.stdin;
```

Typical line processing:

```dart
await for (final line in term.stdinBytes
    .transform(utf8.decoder)
    .transform(const LineSplitter())) {
  processLine(line);
}
```

No parser, no queue, no `events`. For diagnostic tools that want a raw-byte view _in interactive mode_, the documented recipe uses `term.backend.stdin` directly and wraps each chunk:

```dart
// example/key_viewer.dart:179-180
final rawKeys = t.backend.stdin.map(RawKeyEvent.new);
await for (final event in rawKeys) { ... }
```

This is intentionally outside the public API — running a second parser against shared stdin is unsupported. Use it for byte-level debugging only; the tool is on its own for escape-sequence boundaries and bracketed paste framing.

---

## 7. Probing

`probeTerminal()` (`probe/probe.dart`) writes a CSI/OSC query and waits for the matching response via `awaitEvent<T>`. Each helper in `raw_queries.dart` follows the same shape:

```dart
// probe/raw_queries.dart:17-20
Future<PrimaryDeviceAttributesEvent?> rawQueryDeviceAttrs(int timeout) async {
  write(ansi.Term.queryPrimaryDeviceAttributes);
  return awaitEvent<PrimaryDeviceAttributesEvent>(
    timeout: Duration(milliseconds: timeout),
  );
}
```

Flow:

```
write(CSI query) ──► terminal echoes response bytes on stdin
                                    │
                                    ▼
                          background parser subscription
                                    │
                                    ▼
                         _onEventParsed
                                    │
                                    ▼
                     waiter hand-off to awaitEvent<PrimaryDeviceAttributesEvent>
                     (user KeyEvents interleaved during probe go to the queue
                      for later consumption — they don't match the type)
```

Invariants:

- Background subscription is **never paused** during a probe. User key presses in flight are still parsed and queued.
- The response wakes its waiter directly — it never enters the queue, so probe latency isn't sensitive to queue depth.
- If the queue fills during a slow probe, older user events are dropped (with `QueueOverflowEvent`); the probe response is unaffected because it went through the waiter path.

---

## 8. Lifecycle

```
Term.open(backend: ...)
          │
          ├── hasTerminal == true ──► InteractiveTerm._
          │        │
          │        ▼
          │    constructor wires:
          │      new EventQueue(maxSize, coalesceMotion, onOverflow=_emitOverflow)
          │      new StreamController<Event>.broadcast()  → events
          │      backend.stdin.transform(eventTransformer()).listen(_onEventParsed,
          │                                                          onError: _onParserError)
          │   (or: if backend.eventQueue != null → use injected queue
          │        if backend.eventSource != null → subscribe to it instead of parser)
          │
          └── hasTerminal == false ──► PipedTerm._
                 └── no queue, no broadcast, no subscription
                     stdinBytes passes through _b.stdin
```

`dispose()` on `InteractiveTerm`:

```dart
// termlib_base.dart:357-364
Future<void> dispose() async {
  await _eventSubscription?.cancel();
  await _eventQueue?.dispose();           // pending waiters → TermDisposed
  await _eventBroadcastController?.close();
  _eventQueue = null;
  _eventSubscription = null;
  _eventBroadcastController = null;
}
```

`TermRunner` (`term_runner.dart`) is the DX helper — not an Elm/Bubbletea loop. It:

- builds the `InteractiveTerm` (throws `TerminalNotInteractive` if stdin is piped),
- enables alt-screen / raw mode / hide-cursor / mouse / keyboard enhancement,
- installs SIGINT/SIGTERM handlers that restore the terminal synchronously then dispose + exit asynchronously,
- runs the user callback with guaranteed cleanup on normal/error/signal paths.

There is no `Cmd`/`Msg` dispatcher; events flow only through the queue + broadcast described above.

---

## 9. Exceptions

| Type                      | Where                                          |
| ------------------------- | ---------------------------------------------- |
| `TermDisposed`            | pending `awaitEvent`/`nextEvent` on dispose    |
| `TerminalNotInteractive`  | `TermRunner.build()` on a piped tty            |
| `InvalidKeySpecException` | `KeyBinding.map` / `validateKey` on a bad spec |

`QueueOverflowEvent` is **not** an exception — it's an `Event` pushed on the broadcast.

Most interactive-only APIs are compile-time prevented by the `InteractiveTerm`/`PipedTerm` split, so `TerminalNotInteractive` is only needed at the handful of runtime-checked call sites.

---

## 10. Choosing which API

```
┌────────────────────────────────────────────────────────────────────┐
│  Piped input                       → PipedTerm.stdinBytes          │
│  Interactive, reactive             → InteractiveTerm.events        │
│  Interactive, render loop          → tryEvent / awaitEvent         │
│  Interactive, blocking CLI prompt  → nextEvent                     │
│  Interactive, capability probe     → probe() / awaitEvent          │
│  Interactive, byte-level debug     → backend.stdin.map(...)         │
└────────────────────────────────────────────────────────────────────┘
```

All five interactive surfaces share the same parser subscription — consistent, no duplication, no lost events aside from drop-oldest under sustained backlog (which is reported).

---

## 11. KeyBinding (DX)

`KeyBinding<A>` (`key_binding.dart`, Phase 4) replaces ad-hoc `Map<KeyEvent, String>` lookups. Key specs are canonicalized via `KeyEvent.fromString(...).toSpec()`, so multiple specs can alias the same action and casing/order don't matter:

```dart
final binding = KeyBinding<AppAction>()
  ..map(['ctrl+q', 'escape'], AppAction.quit)
  ..map(['ctrl+s'], AppAction.save);

final action = binding.resolve(keyEvent);  // null if unmapped or non-keyPress
```

`readline.dart` is the reference consumer:

```dart
// readline.dart:18-28
final _keyBinding = KeyBinding<_Action>()
  ..map(['enter', 'ctrl+m'], _Action.enter)
  ..map(['escape'], _Action.escape)
  ..map(['backSpace', 'ctrl+h'], _Action.backSpace)
  ..map(['ctrl+u'], _Action.clearBOL)
  ..map(['ctrl+k'], _Action.clearEOL)
  ..map(['delete', 'ctrl+d'], _Action.delete)
  ..map(['left', 'ctrl+b'], _Action.moveLeft)
  ..map(['right', 'ctrl+f'], _Action.moveRight)
  ..map(['home', 'ctrl+a'], _Action.home)
  ..map(['end', 'ctrl+e'], _Action.end);
```

Non-keyPress events (repeat, release) return `null` from `resolve`. Bracketed paste is **not** tokenized against key bindings — one `PasteEvent` per paste, opaque payload.

---

## 12. Concurrency & invariants

- Single-threaded Dart event loop → `EventQueue` is a plain `Queue<Event>`, no locks.
- Exactly **one** parser subscription per `InteractiveTerm` instance. Do not attach a second parser to the same stdin.
- Waiter hand-off uses FIFO order within the registered list; ties between waiters for overlapping types resolve to whoever registered first.
- Overflow signalling is rate-limited: between two `dequeue` calls, N drops emit **one** `QueueOverflowEvent` carrying `dropped: N` and the last evicted type.
- No pause/resume on the stdin subscription — the queue is the shock absorber.
- Backpressure: the broadcast controller does not pause the parser if a listener lags. Slow `events.listen` consumers buffer inside the Dart `StreamController`; heavy downstream work should `unawaited(handler(event))` or schedule.
- No cross-isolate support. One `InteractiveTerm` per isolate; raw mode is OS-global and two instances will drift.

---

## 13. Testing model

Tests construct `Term.open(backend: TermBackend.fake(...))` with:

- `stdin:` byte stream to exercise the parser end-to-end,
- `eventSource:` pre-parsed `Stream<Event>` to bypass the parser,
- `eventQueue:` pre-seeded queue for starting state.

Output is captured with `BufferTermSink` (`stdout: TermSink.buffer()`) and asserted via `BufferTermSink.output`.

Benchmarks under `packages/termlib/test/benchmark/` (Phase 5) are on-demand, not part of `dart test`. Each appends a timestamped row to `<name>.csv`:

```bash
dart run test/benchmark/poll_latency_benchmark.dart
dart run test/benchmark/throughput_benchmark.dart
dart run test/benchmark/key_to_event_latency_benchmark.dart
dart run test/benchmark/coalesce_benchmark.dart
dart --observe test/benchmark/memory_benchmark.dart
```

---

## 14. What's internal

`@internal` (package `meta`):

- `EventQueue` — use `InteractiveTerm.tryEvent`/`awaitEvent`/`nextEvent`.
- `RawQueries` extension — use the public `probe()` / `cursorPosition` / color getters.
- `Readline` — use `InteractiveTerm.readLine()`.

Exported from `package:termlib/termlib.dart`: `Term`, `InteractiveTerm`, `PipedTerm`, `TermBackend`, `TermSink`, `BufferTermSink`, `KeyBinding`, `QueueOverflowEvent`, `TermDisposed`, `TerminalNotInteractive`, `TermRunner`, styling/color primitives, probe types.
