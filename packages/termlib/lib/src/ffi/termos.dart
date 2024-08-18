import 'dart:io';

import 'unix/termos_unix.dart';
import 'win/termos_win.dart';

/// This class provides a common interface for interacting with the underlying
/// operating system system calls that are not available through ANSI mode
/// control sequences, and is not designed to be called directly.
abstract class TermOs {
  /// Enables raw mode for the terminal.
  /// Raw mode allows the terminal to receive input character by character,
  /// without any processing or buffering by the operating system.
  void enableRawMode();

  /// Disables raw mode for the terminal.
  void disableRawMode();

  /// Creates a new instance of TermOs.
  factory TermOs() {
    if (Platform.isWindows) {
      return TermOsWindows();
    } else {
      return TermOsUnix();
    }
  }
}
