// Win32-dependent library for interrogating and manipulating the console.
//
// This class provides raw wrappers for the underlying terminal system calls
// that are not available through ANSI mode control sequences, and is not
// designed to be called directly. Package consumers should normally use the
// `Console` class to call these methods.
//
// code borrow from https://github.com/timsneath/dart_console/blob/main/lib/src/ffi/win/termlib_win.dart

// ignore_for_file: prefer_const_declarations

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../termos.dart';

/// Implementation of the TermOs interface for Windows operating system.
class TermOsWindows implements TermOs {
  /// input device handle
  late final int inputHandle;

  /// output device handle
  late final int outputHandle;

  @override
  void enableRawMode() {
    final dwMode = (~CONSOLE_MODE.ENABLE_ECHO_INPUT) &
        (~CONSOLE_MODE.ENABLE_PROCESSED_INPUT) &
        (~CONSOLE_MODE.ENABLE_LINE_INPUT) &
        (~CONSOLE_MODE.ENABLE_WINDOW_INPUT);
    SetConsoleMode(inputHandle, dwMode);
  }

  @override
  void disableRawMode() {
    final dwMode = CONSOLE_MODE.ENABLE_ECHO_INPUT &
        CONSOLE_MODE.ENABLE_EXTENDED_FLAGS &
        CONSOLE_MODE.ENABLE_INSERT_MODE &
        CONSOLE_MODE.ENABLE_LINE_INPUT &
        CONSOLE_MODE.ENABLE_MOUSE_INPUT &
        CONSOLE_MODE.ENABLE_PROCESSED_INPUT &
        CONSOLE_MODE.ENABLE_QUICK_EDIT_MODE &
        CONSOLE_MODE.ENABLE_VIRTUAL_TERMINAL_INPUT;
    SetConsoleMode(inputHandle, dwMode);
  }

  /// Hides the cursor.
  void hideCursor() {
    final lpConsoleCursorInfo = calloc<CONSOLE_CURSOR_INFO>()..ref.bVisible = 0;
    try {
      SetConsoleCursorInfo(outputHandle, lpConsoleCursorInfo);
    } finally {
      calloc.free(lpConsoleCursorInfo);
    }
  }

  /// Shows the cursor on the terminal screen.
  void showCursor() {
    final lpConsoleCursorInfo = calloc<CONSOLE_CURSOR_INFO>()..ref.bVisible = 1;
    try {
      SetConsoleCursorInfo(outputHandle, lpConsoleCursorInfo);
    } finally {
      calloc.free(lpConsoleCursorInfo);
    }
  }

  /// Clears the screen
  void clearScreen() {
    final pBufferInfo = calloc<CONSOLE_SCREEN_BUFFER_INFO>();
    final pCharsWritten = calloc<Uint32>();
    final origin = calloc<COORD>();
    try {
      final bufferInfo = pBufferInfo.ref;
      GetConsoleScreenBufferInfo(outputHandle, pBufferInfo);

      final consoleSize = bufferInfo.dwSize.X * bufferInfo.dwSize.Y;

      FillConsoleOutputCharacter(outputHandle, ' '.codeUnitAt(0), consoleSize, origin.ref, pCharsWritten);

      GetConsoleScreenBufferInfo(outputHandle, pBufferInfo);

      FillConsoleOutputAttribute(outputHandle, bufferInfo.wAttributes, consoleSize, origin.ref, pCharsWritten);

      SetConsoleCursorPosition(outputHandle, origin.ref);
    } finally {
      calloc
        ..free(origin)
        ..free(pCharsWritten)
        ..free(pBufferInfo);
    }
  }

  /// Sets the cursor position to the specified coordinates.
  ///
  /// The [x] parameter represents the horizontal position of the cursor,
  /// while the [y] parameter represents the vertical position of the cursor.
  void setCursorPosition(int x, int y) {
    final coord = calloc<COORD>()
      ..ref.X = x
      ..ref.Y = y;
    try {
      SetConsoleCursorPosition(outputHandle, coord.ref);
    } finally {
      calloc.free(coord);
    }
  }

  /// Constructs a new instance of the [TermOsWindows] class.
  /// This class represents the Windows implementation of the [TermOs] interface.
  TermOsWindows() {
    outputHandle = GetStdHandle(STD_HANDLE.STD_OUTPUT_HANDLE);
    inputHandle = GetStdHandle(STD_HANDLE.STD_INPUT_HANDLE);
  }
}
