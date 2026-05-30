# Overview

termlib is a Dart library providing utilities for terminal applications. It handles terminal interactions, styling, colors, keyboard input, mouse events, and terminal capabilities.

## Architecture

### Core Components

**`Term.open({TermBackend? backend})`** (`lib/src/termlib_base.dart`): Factory returning a sealed `Term` — either `InteractiveTerm` (stdin is a tty) or `PipedTerm` (stdin piped). Dispatch via pattern matching.

**InteractiveTerm**: tty mode. Owns a background parser subscription feeding both an `EventQueue` (pull API: `tryEvent`, `awaitEvent`, `nextEvent`) and a broadcast `events` stream (push API). Holds raw-mode state.

**PipedTerm**: non-tty mode. Exposes `stdinBytes` (`Stream<List<int>>`) — compose with `utf8.decoder` and `LineSplitter` for line processing. No parsed events.

**`TermBackend`** (`lib/src/shared/term_backend.dart`): transport seam. `TermBackend.io()` wraps real stdin/stdout; `TermBackend.fake({stdin, stdout, eventQueue, eventSource, env, termOs, hasTerminal, maxQueueSize, coalesceMotion})` for tests. No zones, no globals — explicit injection only.

**`TermSink`** (`lib/src/shared/term_sink.dart`): narrow output surface. `TermSink.io()` wraps real stdout; `BufferTermSink` records writes for tests.

**`EventQueue`** (`lib/src/event_queue.dart`, `@internal`): FIFO with bounded capacity (default 5000, configurable via `TermBackend.maxQueueSize`). Drop-oldest on overflow, coalesced into a single `QueueOverflowEvent` on the next `dequeue`. Coalesce-at-enqueue for `MouseEvent` motion (same button-state) and `WindowResizeEvent`. Per-waiter direct hand-off bypasses the buffer for active `awaitEvent<T>` callers.

**`KeyBinding<A>`** (`lib/src/key_binding.dart`): declarative key-to-action mapping. Supports spec strings (`"ctrl+c"`, `"alt+shift+f1"`), multiple keys per action, aliases. Used by `readline.dart`.

**ProfileEnum**: color capability level (noColor, ansi16, ansi256, trueColor). Auto-detected via `envColorProfile()`.

**Style / Color**: fluent styling, ANSI/256/RGB color.

**TermOs** (`lib/src/ffi/termos.dart`): FFI raw-mode. Implementations: `TermOsUnix`, `TermOsWindows`.

### Event API

Interactive-only. Three surfaces over the same background parser subscription:

```dart
final term = Term.open();
if (term is! InteractiveTerm) return;

// Pull, non-blocking
final KeyEvent? k = term.tryEvent<KeyEvent>();

// Pull, bounded wait
final k = await term.awaitEvent<KeyEvent>(timeout: Duration(seconds: 1));

// Pull, blocking forever
final k = await term.nextEvent<KeyEvent>();

// Push
term.events.listen((event) { ... });
```

All four share one parser, one queue, one broadcast. `tryEvent` and `awaitEvent` return `T?` (null = no match / timeout). `nextEvent` returns `T` and only ever terminates with `TermDisposed` on shutdown.

### Exceptions

- `TermDisposed` — thrown from pending `awaitEvent`/`nextEvent` futures on dispose.
- `TerminalNotInteractive` — thrown from runtime-gated call sites (e.g. `TermRunner.build()`) when invoked on a non-tty. Most interactive-only APIs are compile-time prevented by the `InteractiveTerm` / `PipedTerm` split.
- `QueueOverflowEvent` — not an exception; pushed onto the `events` broadcast when drop-oldest fires.

### Lifecycle

- `Term.open()` — constructs an `InteractiveTerm` or `PipedTerm` based on `backend.hasTerminal`.
- `InteractiveTerm.dispose()` — cancels the parser subscription, disposes the queue (completing pending waiters with `TermDisposed`), closes the broadcast.
- `TermRunner.build(...)` — sets up alt-screen/raw-mode/cursor/mouse/keyboard-enhancement, installs SIGINT/SIGTERM restore, disposes on return.

### Key Patterns

- `termparser` parses stdin bytes into typed events; `eventTransformer()` is the `StreamTransformer<List<int>, Event>` used by `InteractiveTerm`.
- Raw-bytes-only recipes (diagnostic tools) use `term.backend.stdin` or `PipedTerm.stdinBytes`.
- Color downsampling when the profile doesn't support full RGB.

### Testing

Tests inject `TermBackend.fake(...)` with a controlled `stdin` byte stream, `eventSource` stream of pre-parsed events, or pre-built `eventQueue`. Capture stdout via `TermSink.buffer()`. Helpers in `test/shared.dart`.

Benchmarks under `test/benchmark/` run on demand (not part of `dart test`):

```bash
dart run test/benchmark/poll_latency_benchmark.dart
dart run test/benchmark/throughput_benchmark.dart
dart run test/benchmark/key_to_event_latency_benchmark.dart
dart run test/benchmark/coalesce_benchmark.dart
dart --observe test/benchmark/memory_benchmark.dart
```

Each benchmark appends a row per scenario to its own CSV (`test/benchmark/<name>.csv`) with timestamp, git SHA, platform, scenario, and stats columns.
