class Cycle<E> implements Iterator<E?> {
  List<E> items;
  int _pos = -1;
  int? times;

  Cycle(this.items, {this.times});

  E? get cycle {
    return moveNext() ? current : null;
  }

  @override
  E? get current {
    if (_pos >= 0) return items[_pos % items.length];
    return null;
  }

  @override
  bool moveNext() {
    _pos++;
    if (times == null) return true;
    times = times! - 1;
    return times! > 0;
  }
}

String printable(int code) => isPrintable(code) ? String.fromCharCode(code) : '.';

/// quick check for printable characters. for more advanced check
/// https://github.com/xxgreg/dart_printable_char
bool isPrintable(int code) {
  if (code <= 0xFF) {
    if (0x20 <= code && code <= 0x7E) {
      return true;
    }
    if (0xA1 <= code && code <= 0xFF) {
      return code != 0xAD;
    }
  }
  return false;
}
