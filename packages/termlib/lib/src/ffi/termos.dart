import 'dart:io';

import 'unix/termos_unix.dart';
import 'win/termos_win.dart';

/// This class provides a common interface for interacting with the underlying
/// operating system system calls that are not available through ANSI mode
/// control sequences, and is not designed to be called directly.
abstract class TermOs {
  /// Sets the height of the window.
  ///
  /// The [height] parameter specifies the desired height of the window.
  /// Returns an integer representing the status of the operation.
  /// A non-zero value indicates an error occurred.
  /// A value of zero indicates success.
  int setWindowHeight(int height);

  /// Sets the width of the terminal window.
  ///
  /// The [width] parameter specifies the desired width of the terminal window.
  /// Returns an integer representing the success or failure of the operation.
  /// A non-zero value indicates failure, while a zero value indicates success.
  int setWindowWidth(int width);

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
