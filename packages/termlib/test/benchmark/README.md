# Performance Benchmarks

This directory contains performance benchmarks for termlib's event queue implementation.

## poll() Latency Benchmark

Measures `poll()` response time across different scenarios to ensure <1ms target.

### Running the Benchmark

```bash
# From termlib package directory
dart run test/benchmark/poll_latency_benchmark.dart
```

### Scenarios

1. **Hot path (event ready)** - Target: <100μs
   - Queue: [KeyEvent]
   - Operation: `poll<KeyEvent>()` → dequeues first item
   - Measures: Best case - event at front, exact type match

2. **Empty queue (miss)** - Target: <50μs
   - Queue: []
   - Operation: `poll<KeyEvent>()` → returns NoneEvent
   - Measures: Early exit when no events available

3. **Type filtering (skip 2 events)** - Target: <200μs
   - Queue: [MouseEvent, MouseEvent, KeyEvent]
   - Operation: `poll<KeyEvent>()` → skips 2 non-matching events
   - Measures: Shallow type filtering overhead

4. **Deep type filtering (skip 50 events)** - Target: <500μs
   - Queue: [MouseEvent x 50, KeyEvent]
   - Operation: `poll<KeyEvent>()` → skips 50 non-matching events
   - Measures: Type filtering with significant iteration

5. **Mid-queue search (500 events)** - Target: <1000μs (1ms)
   - Queue: [MouseEvent x 250, KeyEvent, MouseEvent x 249, FocusEvent]
   - Operations: `poll<KeyEvent>()` then `poll<FocusEvent>()`
   - Measures: Search at position 250 and position 500 (worst case for 500 items)

6. **Worst case search (1000 events)** - Target: <2000μs (2ms)
   - Queue: [MouseEvent x 999, KeyEvent]
   - Operation: `poll<KeyEvent>()` → scans entire queue
   - Measures: O(n) iteration through 999 events to find match at end

### Methodology

- **Warmup**: 100 iterations (discarded)
- **Measurement**: 1000 iterations per scenario
- **Statistics**: min, max, mean, median, p95, p99, stddev
- **Pass criteria**: P99 < target for each scenario

### Result Tracking

Results are appended to `results.csv` with timestamp:

```csv
timestamp,scenario,samples,min,max,mean,median,p95,p99,stddev
2025-01-15T10:30:00.000,Hot path (event ready),1000,12,847,45.2,38,89,156,23.1
```

Use this to track performance over time and detect regressions.

### Interpreting Results

- **Min/Max**: Best and worst case latency
- **Mean**: Average latency across all samples
- **Median**: Middle value (50th percentile)
- **P95/P99**: 95th and 99th percentile (tail latency)
- **StdDev**: Variance indicator (high = GC/scheduling issues)

### Expected Results

Typical results on modern hardware (macOS ARM64):

```
Hot path (event ready):            0-1 μs    (target: <100 μs)   ✅
Empty queue (miss):                 0 μs      (target: <50 μs)    ✅
Type filtering (skip 2 events):     5 μs      (target: <200 μs)   ✅
Deep type filtering (skip 50):      5 μs      (target: <500 μs)   ✅
Mid-queue search (500 events):      5 μs      (target: <1000 μs)  ✅
Worst case search (1000 events):    5 μs      (target: <2000 μs)  ✅
```

All scenarios easily beat targets with massive headroom (10-1000x faster).

### Implementation Details

Current `EventQueue.dequeue<T>()` implementation:
- Uses simple linear iteration through `Queue<Event>`
- Type check: `event is T` for each item
- Removal: `Queue.remove(event)` which is also O(n)
- **Total complexity**: O(n) where n = queue length

### Performance Insights

**Key finding**: Linear search is fast enough for realistic queue sizes (<1000 events).

Even worst-case scenarios (999 non-matching events) complete in ~5μs median:
- Dart's `Queue` iteration is highly optimized
- Type checks (`is T`) are very fast
- Modern CPUs can iterate thousands of objects per microsecond

**Why this matters**:
- Validates current simple implementation is production-ready
- Establishes baseline for future optimization attempts
- If implementing type-indexed lookup (e.g., `Map<Type, Queue<Event>>`), can compare against this baseline
- Shows where optimization would help: not search time, but removal time (Queue.remove is O(n))

**When to optimize**:
- Queue consistently >1000 events (unlikely in practice)
- P99 latency exceeds application requirements
- Profiling shows EventQueue as bottleneck

## Memory Benchmark

Measures EventQueue memory usage at different queue sizes using Dart VM Service Protocol.

### Running the Benchmark

```bash
# Must run with --observe to enable VM service
dart --observe test/benchmark/memory_benchmark.dart
```

### Scenarios

1. **Empty queue (baseline)** - EventQueue object overhead
2. **Small queue (100 events)** - Typical interactive usage
3. **Medium queue (500 events)** - Heavy load scenario
4. **Full queue (1000 events)** - Maximum capacity
5. **Mixed event types** - KeyEvent, MouseEvent, FocusEvent, PasteEvent (250 each)

### What It Measures

- Heap memory delta before/after queue creation
- Bytes per event (total delta / event count)
- Memory usage across different event types

### Expected Results

Typical memory usage (varies by platform):
- Empty EventQueue: ~100-500 bytes (Queue overhead)
- Per KeyEvent: ~100-200 bytes
- Per MouseEvent: ~150-250 bytes
- Full queue (1000 events): ~150-250 KB

### Implementation

Uses official `vm_service` package to:
1. Force garbage collection before measurement
2. Query heap usage via `getMemoryUsage()`
3. Calculate delta for accurate allocation tracking

### Notes

- Not part of regular test suite (`dart test` won't run these)
- Run on dedicated hardware for consistent results
- Document CPU/OS specs when sharing baseline results
- High StdDev (>50μs) may indicate GC pressure or background load
- Zone override adds ~1-2μs overhead (acceptable for baseline)
- Memory benchmark requires `--observe` flag (VM service)
