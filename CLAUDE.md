# Overview

TermKit is a Dart monorepo workspace for building terminal applications. Four packages work together to provide comprehensive terminal functionality:

- **termansi**: ANSI escape sequence definitions (reference library)
- **termparser**: VT500-series parser converting ANSI sequences to events
- **termlib**: Core terminal interaction library (depends on termansi + termparser)
- **termunicode**: Unicode character properties and width calculations

## Workspace Commands

Root workspace uses Dart workspace resolution (`pubspec.yaml` defines workspace packages).

```bash
# Get dependencies for all packages
dart pub get

# Run from workspace root.
# Always pass `-r failures-only`: prints nothing on success, only failures.
# Keeps output clean — prefer it over a bare `dart test`.
dart test -r failures-only packages/termlib/test/colors_test.dart
dart analyze packages/termparser/lib/src/parser.dart
dart format .
```

## Package Commands

All packages have Makefiles with consistent targets:

All `make test`/`make testf` targets run `dart test -r failures-only` — silent on
success, only failures shown. Prefer these over invoking `dart test` directly.

```bash
# From package directory
make               # shows available commands
make test          # All tests (-r failures-only)
make testf FILE=test/unicode_lib_test.dart  # Specific test (-r failures-only)
make cover         # Coverage + HTML report
make lint          # Static analysis
make lintf FILE=lib/src/table.dart  # Lint specific file
make format        # Format all
make formatf FILE=lib/src/table.dart  # Format specific file
```

Run from package directory (e.g., cd packages/termlib && make test).

## Architecture

### Package Dependencies

```
termansi (no deps)   ←┐
                      ├─ termlib (main)
termparser (no deps) ←┘

termunicode (standalone)
```

## Code Style

Workspace-wide (`analysis_options.yaml`):

- `very_good_analysis` linter
- Strict mode: strict-casts, strict-inference, strict-raw-types

Dart 3 patterns used in this codebase:

- Pattern matching with switch expressions for parsing/dispatch
- Sealed classes for event hierarchies (exhaustive matching)
- Records for multiple return values
- `final class` for classes not meant to be extended
- `const` constructors where possible
- Extension types for type-safe wrappers (zero-cost abstraction)
