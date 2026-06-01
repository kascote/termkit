import 'package:characters/characters.dart';
import 'package:meta/meta.dart';
import 'package:termparser/termparser_events.dart';
import 'package:termunicode/termunicode.dart' show widthString;

import 'key_binding.dart';
import 'probe/query_result.dart';
import 'probe/term_info.dart';
import 'style.dart';
import 'termlib_base.dart';

/// Editing actions a key can be bound to.
///
/// Public so callers can supply a custom [KeyBinding] via
/// [ReadlineOptions.keyBinding].
enum ReadlineAction {
  /// Submit the current buffer.
  enter,

  /// Cancel and return `null`.
  escape,

  /// Delete the grapheme before the cursor.
  backSpace,

  /// Delete from the cursor to the start of the buffer (Ctrl+U).
  clearBOL,

  /// Delete from the cursor to the end of the buffer (Ctrl+K).
  clearEOL,

  /// Delete the grapheme at the cursor.
  delete,

  /// Move the cursor one grapheme left.
  moveLeft,

  /// Move the cursor one grapheme right.
  moveRight,

  /// Move the cursor to the start of the buffer.
  home,

  /// Move the cursor to the end of the buffer.
  end,
}

/// Default key bindings for [Readline].
KeyBinding<ReadlineAction> _defaultKeyBinding() => KeyBinding<ReadlineAction>()
  ..map(['enter', 'ctrl+m'], ReadlineAction.enter)
  ..map(['escape'], ReadlineAction.escape)
  ..map(['backSpace', 'ctrl+h'], ReadlineAction.backSpace)
  ..map(['ctrl+u'], ReadlineAction.clearBOL)
  ..map(['ctrl+k'], ReadlineAction.clearEOL)
  ..map(['delete', 'ctrl+d'], ReadlineAction.delete)
  ..map(['left', 'ctrl+b'], ReadlineAction.moveLeft)
  ..map(['right', 'ctrl+f'], ReadlineAction.moveRight)
  ..map(['home', 'ctrl+a'], ReadlineAction.home)
  ..map(['end', 'ctrl+e'], ReadlineAction.end);

/// Options for [InteractiveTerm.readLine].
///
/// A single bag carries everything, including the initial buffer.
final class ReadlineOptions {
  /// Creates a [ReadlineOptions].
  const ReadlineOptions({
    this.initBuffer = '',
    this.maxLength,
    this.visualLength,
    this.wrap = false,
    this.tabWidth = 4,
    this.prompt,
    this.promptStyle,
    this.keyBinding,
    this.bracketedPaste,
    this.inBandResize,
  });

  /// Initial text. Cut at the first newline, then truncated to [maxLength].
  final String initBuffer;

  /// Grapheme-cluster count cap. `null` means unlimited.
  final int? maxLength;

  /// Total on-screen columns (including the prompt). `null` means the current
  /// terminal width. Clamped to the real terminal width.
  final int? visualLength;

  /// `false` = horizontal scroll on one row; `true` = vertical soft-wrap.
  final bool wrap;

  /// Number of spaces inserted by the Tab key.
  final int tabWidth;

  /// Display-only prompt label. Not part of the buffer, not returned. The
  /// width is auto-measured from the normalized text. `null` means no prompt.
  final String? prompt;

  /// Optional styling for the [prompt]. Rendered self-closing so the prompt's
  /// color does not bleed into the user's input. `null` renders the prompt
  /// plain.
  final Style? promptStyle;

  /// Override key bindings. `null` uses the defaults.
  final KeyBinding<ReadlineAction>? keyBinding;

  /// Whether to use bracketed paste.
  ///
  /// `null` (default) derives support from [InteractiveTerm.termInfo] — i.e.
  /// the result of a prior [InteractiveTerm.probe] (no support assumed if the
  /// terminal was never probed). Set explicitly to force on/off.
  final bool? bracketedPaste;

  /// Whether to enable in-band window resize reporting.
  ///
  /// When enabled, the terminal sends a [WindowResizeEvent] on resize and the
  /// widget reflows immediately (instead of only on the next keypress).
  ///
  /// `null` (default) derives support from [InteractiveTerm.termInfo] — i.e.
  /// the result of a prior [InteractiveTerm.probe] (no support assumed if the
  /// terminal was never probed). Set explicitly to force on/off.
  final bool? inBandResize;
}

/// A visual line described by a `[start, end)` range of grapheme indices.
@immutable
class _Line {
  const _Line(this.start, this.end);
  final int start;
  final int end;
}

/// Readline widget. Line input for REPL-style prompts.
///
/// The buffer is always a single logical line (no `'\n'`). "Wrap mode" is a
/// purely visual choice — the same data rendered across more rows.
@internal
class Readline {
  /// Creates a [Readline] bound to [term] with [options].
  Readline(this.term, this.options) : _binding = options.keyBinding ?? _defaultKeyBinding() {
    final label = options.prompt;
    if (label == null || label.isEmpty) {
      _promptText = '';
      _promptRender = '';
    } else {
      _promptText = label.split(RegExp(r'[\r\n]')).first;
      final style = options.promptStyle;
      // `Style.call` is self-closing: it appends a reset only when styling was
      // emitted, and in the noColor profile returns the text unchanged.
      _promptRender = style == null ? _promptText : style(_promptText);
    }
    _promptCells = widthString(_promptText);
  }

  /// Terminal handle.
  final InteractiveTerm term;

  /// Readline options.
  final ReadlineOptions options;

  final KeyBinding<ReadlineAction> _binding;

  /// Source of truth. Single line, no `'\n'`.
  String _text = '';

  /// Grapheme index in `[0, graphemeCount]`.
  int _cursor = 0;

  /// Normalized, single-line prompt text (display only).
  late final String _promptText;

  /// Prompt as written to the terminal (styled, with a trailing reset).
  late final String _promptRender;

  /// On-screen width of the prompt.
  late final int _promptCells;

  /// Top-left of the rendered region (1-based).
  int _startRow = 1;
  int _startCol = 1;

  /// Horizontal scroll offset in cells (scroll mode).
  int _scrollCol = 0;

  /// Rows used by the previous paint (so the next paint can clear leftovers).
  int _renderedRows = 1;

  /// Whether the terminal supports bracketed paste (probed at startup).
  bool _bracketedPaste = false;

  /// Whether in-band window resize reporting is active (probed at startup).
  bool _inBandResize = false;

  /// Starts reading from the keyboard.
  Future<String?> read() => term.withModes<String?>(_read, rawMode: true);

  // --- width helpers -------------------------------------------------------

  int _gWidth(String g) => widthString(g);

  /// Sum of cell widths of [gs] in `[from, to)`.
  int _cellWidth(List<String> gs, int from, int to) {
    var w = 0;
    for (var i = from; i < to; i++) {
      w += _gWidth(gs[i]);
    }
    return w;
  }

  int get _graphemeCount => _text.characters.length;

  List<String> get _graphemes => _text.characters.toList();

  /// Effective total width (clamped to the real terminal width).
  int get _wTotal {
    final cols = term.terminalColumns;
    final requested = options.visualLength ?? cols;
    return requested < cols ? requested : cols;
  }

  /// Text-area width.
  int get _wInput {
    final w = _wTotal - _promptCells;
    return w < 1 ? 1 : w;
  }

  // --- editing -------------------------------------------------------------

  bool _isControl(String s) {
    if (s.isEmpty) return false;
    final c = s.codeUnitAt(0);
    return c < 0x20 || c == 0x7f;
  }

  /// Inserts a single codepoint/grapheme [g] at the cursor (maxLength-gated).
  ///
  /// The cursor is recomputed from a grapheme count, never `++`, so a combining
  /// mark / ZWJ joiner / VS16 that merges into the adjacent cluster lands the
  /// cursor after the augmented cluster instead of over-advancing.
  void _insert(String g) {
    final chars = _text.characters;
    final before = chars.take(_cursor);
    final after = chars.skip(_cursor);
    final next = '$before$g$after';
    final max = options.maxLength;
    if (max != null && next.characters.length > max) return;
    _text = next;
    _cursor = '$before$g'.characters.length;
  }

  void _backspace() {
    if (_cursor == 0) return;
    final chars = _text.characters;
    final before = chars.take(_cursor).skipLast(1);
    final after = chars.skip(_cursor);
    _text = '$before$after';
    _cursor = before.length;
  }

  void _delete() {
    if (_cursor >= _graphemeCount) return;
    final chars = _text.characters;
    final before = chars.take(_cursor);
    final after = chars.skip(_cursor).skip(1);
    _text = '$before$after';
  }

  void _clearBOL() {
    _text = _text.characters.skip(_cursor).toString();
    _cursor = 0;
  }

  void _clearEOL() {
    _text = _text.characters.take(_cursor).toString();
  }

  void _paste(String text) {
    final first = text.split(RegExp(r'[\r\n]')).first;
    first.characters.forEach(_insert);
  }

  void _normalizeInit() {
    var t = options.initBuffer.split(RegExp(r'[\r\n]')).first;
    final max = options.maxLength;
    if (max != null && t.characters.length > max) {
      t = t.characters.take(max).toString();
    }
    _text = t;
    _cursor = _text.characters.length;
  }

  // --- read loop -----------------------------------------------------------

  Future<String?> _read() async {
    final pos = await term.cursorPosition;
    _startRow = pos?.row ?? 1;
    _startCol = pos?.col ?? 1;
    _bracketedPaste = _resolveBracketedPaste();
    _inBandResize = _resolveInBandResize();

    // We place every visual line ourselves; let the terminal never insert its
    // own break (writing a full-width row would otherwise scroll a phantom
    // line in). Bracketed paste, when supported, keeps pasted newlines out of
    // the key stream; otherwise paste degrades to the raw-key path. In-band
    // resize, when supported, delivers a WindowResizeEvent so the widget
    // reflows on resize instead of only on the next keypress.
    term.disableLineWrapping();
    if (_bracketedPaste) term.enableBracketedPaste();
    if (_inBandResize) term.enableInBandResize();
    try {
      return await _loop();
    } finally {
      term.enableLineWrapping();
      if (_bracketedPaste) term.disableBracketedPaste();
      if (_inBandResize) term.disableInBandResize();
    }
  }

  /// Resolves bracketed-paste support without re-querying the terminal.
  ///
  /// Honors an explicit [ReadlineOptions.bracketedPaste]; otherwise reads the
  /// cached [InteractiveTerm.termInfo] from a prior probe. A terminal that was
  /// never probed is treated as unsupported (paste degrades to raw keys).
  bool _resolveBracketedPaste() {
    final override = options.bracketedPaste;
    if (override != null) return override;
    return switch (term.termInfo?.bracketedPaste) {
      Supported(value: BracketedPasteStatus.enabled || BracketedPasteStatus.disabled) => true,
      _ => false,
    };
  }

  /// Resolves in-band resize support without re-querying the terminal.
  ///
  /// Honors an explicit [ReadlineOptions.inBandResize]; otherwise reads the
  /// cached [InteractiveTerm.termInfo] from a prior probe. A terminal that was
  /// never probed is treated as unsupported.
  bool _resolveInBandResize() {
    final override = options.inBandResize;
    if (override != null) return override;
    return switch (term.termInfo?.inBandResize) {
      Supported(value: InBandResizeStatus.enabled || InBandResizeStatus.disabled) => true,
      _ => false,
    };
  }

  Future<String?> _loop() async {
    _normalizeInit();
    _render();

    while (true) {
      final ev = await term.awaitEvent<Event>(timeout: const Duration(seconds: 60));
      if (ev == null) continue;

      if (ev is KeyEvent) {
        if (ev.eventType != KeyEventType.keyPress) continue;
        final action = _binding.resolve(ev);
        switch (action) {
          case ReadlineAction.enter:
            _finishSubmit();
            return _text;
          case ReadlineAction.escape:
            _finishSubmit();
            return null;
          case ReadlineAction.backSpace:
            _backspace();
          case ReadlineAction.delete:
            _delete();
          case ReadlineAction.clearBOL:
            _clearBOL();
          case ReadlineAction.clearEOL:
            _clearEOL();
          case ReadlineAction.moveLeft:
            if (_cursor > 0) _cursor--;
          case ReadlineAction.moveRight:
            if (_cursor < _graphemeCount) _cursor++;
          case ReadlineAction.home:
            _cursor = 0;
          case ReadlineAction.end:
            _cursor = _graphemeCount;
          case null:
            if (ev.code.name == KeyCodeName.tab) {
              for (var i = 0; i < options.tabWidth; i++) {
                _insert(' ');
              }
            } else {
              final char = ev.code.char;
              if (char.isEmpty || _isControl(char)) continue;
              _insert(char);
            }
        }
        _render();
      } else if (ev is PasteEvent) {
        _paste(ev.text);
        _render();
      } else if (ev is WindowResizeEvent) {
        _render();
      }
    }
  }

  /// Moves the cursor past the last rendered row and emits a trailing newline.
  void _finishSubmit() {
    term
      ..moveTo(_startRow + _renderedRows - 1, _startCol)
      ..write(term.newLine);
  }

  // --- rendering -----------------------------------------------------------

  void _render() {
    term.startSyncUpdate();
    if (options.wrap) {
      _renderWrap();
    } else {
      _renderScroll();
    }
    term.endSyncUpdate();
  }

  void _renderScroll() {
    final gs = _graphemes;
    final wInput = _wInput;
    final cursorCell = _cellWidth(gs, 0, _cursor);

    // scroll-by-one edge tracking: keep cursorCell in [_scrollCol, +wInput).
    if (cursorCell < _scrollCol) {
      _scrollCol = cursorCell;
    } else if (cursorCell >= _scrollCol + wInput) {
      _scrollCol = cursorCell - wInput + 1;
    }
    if (_scrollCol < 0) _scrollCol = 0;

    final slice = StringBuffer();
    var cell = 0;
    for (final g in gs) {
      final w = _gWidth(g);
      final gStart = cell;
      final gEnd = cell + w;
      cell = gEnd;
      if (gEnd <= _scrollCol) continue; // entirely left of window
      if (gStart >= _scrollCol + wInput) break; // entirely right of window
      if (gStart < _scrollCol) {
        // width-2 grapheme straddling the left edge: blank the visible cell.
        slice.write(' ');
        continue;
      }
      if (gEnd > _scrollCol + wInput) {
        // width-2 grapheme straddling the right edge: drop it (leave blank).
        break;
      }
      slice.write(g);
    }

    term.moveTo(_startRow, _startCol);
    if (_promptText.isNotEmpty) term.write(_promptRender);
    term
      ..write(slice.toString())
      ..eraseLineFromCursor()
      ..moveTo(_startRow, _startCol + _promptCells + (cursorCell - _scrollCol));
    _renderedRows = 1;
  }

  void _renderWrap() {
    final gs = _graphemes;
    final wInput = _wInput;
    final lines = _wrapLines(gs, wInput);
    final inputLeft = _startCol + _promptCells;
    final (cLine, cCol) = _cursorVisual(gs, lines, wInput);

    // The cursor may sit on a phantom row past the last text line (cursor at
    // the end of a full line); count it so leftover rows are cleared correctly.
    final usedRows = (cLine + 1) > lines.length ? cLine + 1 : lines.length;

    // Vertical overflow: if the region grows past the bottom, the terminal
    // scrolls; pull startRow up by the number of rows that fell off.
    final overflow = (_startRow + usedRows - 1) - term.terminalLines;
    if (overflow > 0) {
      _startRow -= overflow;
      if (_startRow < 1) _startRow = 1;
    }

    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (i == 0) {
        term.moveTo(_startRow, _startCol);
        if (_promptText.isNotEmpty) term.write(_promptRender);
      } else {
        term.moveTo(_startRow + i, inputLeft);
      }
      term
        ..write(gs.sublist(l.start, l.end).join())
        ..eraseLineFromCursor();
    }

    // Clear rows the region shrank past since the previous paint.
    for (var i = usedRows; i < _renderedRows; i++) {
      term
        ..moveTo(_startRow + i, _startCol)
        ..eraseLine();
    }
    _renderedRows = usedRows;

    term.moveTo(_startRow + cLine, inputLeft + cCol);
  }

  /// Greedy character-boundary wrap, shared model for cursor math.
  ///
  /// A width-2 grapheme that does not fit the last column wraps whole to the
  /// next row, leaving the previous row's trailing cell blank.
  List<_Line> _wrapLines(List<String> gs, int wInput) {
    final lines = <_Line>[];
    var start = 0;
    var width = 0;
    for (var i = 0; i < gs.length; i++) {
      final w = _gWidth(gs[i]);
      if (width + w > wInput && i > start) {
        lines.add(_Line(start, i));
        start = i;
        width = w;
      } else {
        width += w;
      }
    }
    lines.add(_Line(start, gs.length));
    return lines;
  }

  (int, int) _cursorVisual(List<String> gs, List<_Line> lines, int wInput) {
    for (var li = 0; li < lines.length; li++) {
      final l = lines[li];
      if (_cursor >= l.start && _cursor < l.end) {
        return (li, _cellWidth(gs, l.start, _cursor));
      }
    }
    // Cursor at the end of the buffer.
    final last = lines.length - 1;
    final col = _cellWidth(gs, lines[last].start, _cursor);
    // End of a completely full line: show the cursor at the start of the next
    // (virtual) row instead of one past the last column.
    if (col >= wInput && gs.isNotEmpty) return (last + 1, 0);
    return (last, col);
  }
}
