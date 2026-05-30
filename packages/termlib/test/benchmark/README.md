# termlib benchmarks

On-demand performance benchmarks. Not part of `dart test`. Each benchmark appends a row per scenario to its own CSV with timestamp, git SHA, platform, scenario, and stats columns.

## Running

```bash
# From packages/termlib
dart run test/benchmark/poll_latency_benchmark.dart
dart run test/benchmark/throughput_benchmark.dart
dart run test/benchmark/key_to_event_latency_benchmark.dart
dart run test/benchmark/coalesce_benchmark.dart

# Memory benchmark requires the VM service.
dart --observe test/benchmark/memory_benchmark.dart
```

## CSV schema

`timestamp,sha,platform,scenario,samples,min,max,mean,median,p95,p99,stddev`

Units per benchmark:

| benchmark                  | samples unit     |
| -------------------------- | ---------------- |
| `poll_latency.csv`         | μs               |
| `throughput.csv`           | ns (per event)   |
| `key_to_event_latency.csv` | μs               |
| `coalesce.csv`             | ns (per enqueue) |

## Benchmarks

### poll_latency_benchmark

`InteractiveTerm.tryEvent<T>()` end-to-end latency. Scenarios:

| scenario                             | target   |
| ------------------------------------ | -------- |
| Hot path (event ready)               | <100 μs  |
| Empty queue (miss)                   | <50 μs   |
| Type filtering (skip 2 events)       | <200 μs  |
| Deep type filtering (skip 50 events) | <500 μs  |
| Mid-queue search (500 events)        | <1000 μs |
| Worst case search (1000 events)      | <2000 μs |

### throughput_benchmark

Raw `EventQueue` enqueue + dequeue throughput, per-event nanoseconds.

| scenario                         | what it measures            |
| -------------------------------- | --------------------------- |
| Pairwise enqueue+dequeue         | minimum cycle cost          |
| Burst drain (100)                | small-batch amortized       |
| Burst drain (1000)               | large-batch amortized       |
| Type-filtered drain (skip mouse) | O(n) scan cost during drain |

### key_to_event_latency_benchmark

Bytes on a stream → parsed `Event` via `eventTransformer`. Includes one microtask of scheduling.

| scenario               | bytes            |
| ---------------------- | ---------------- |
| Single ASCII key (a)   | `0x61`           |
| Ctrl modifier (ctrl+c) | `0x03`           |
| Arrow up (ESC [ A)     | `0x1b 0x5b 0x41` |
| Cursor position reply  | `ESC [ 5 ; 10 R` |

### coalesce_benchmark

`EventQueue` with `coalesceMotion` on vs off. Floods the queue with 5000 mouse-motion (same button-state) or window-resize events and reports per-enqueue nanoseconds plus the resulting queue length.

Expected: coalesce on → final length 1; coalesce off → final length 5000.

### memory_benchmark

Uses the Dart VM service (`--observe`) to measure `EventQueue` heap usage at different sizes (empty, 100, 500, 1000, 5000, and mixed event types). No CSV output; prints per-scenario bytes-per-event.

## Methodology

- Warmup iterations discarded.
- Percentiles from sorted samples (p95, p99).
- Run on idle hardware; document CPU/OS when sharing.
