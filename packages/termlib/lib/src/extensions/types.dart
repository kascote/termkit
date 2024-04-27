/// Clipboard to use
enum Clipboard implements Comparable<Clipboard> {
  /// Operate over the system clipboard
  system('c'),

  /// Operate over the primary clipboard
  primary('p');

  const Clipboard(this.target);

  /// Operation
  final String target;

  @override
  int compareTo(Clipboard other) => target.compareTo(other.target);
}

/// Clipboard Operation Modes
enum ClipboardMode implements Comparable<ClipboardMode> {
  /// Set clipboard contents
  set('+'),

  /// Query clipboard contents
  query('?'),

  /// Clear clipboard contents
  clear('!');

  const ClipboardMode(this.mode);

  /// Operation mode
  final String mode;

  @override
  int compareTo(ClipboardMode other) => mode.compareTo(other.mode);
}
