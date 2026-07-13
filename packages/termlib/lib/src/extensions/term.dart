part of '../termlib_base.dart';

/// Default timeout to wait for terminal query responses.
///
/// This value is used in various query methods in the TermUtils extension
/// to specify how long to wait for a response from the terminal before timing out.
/// If the terminal reply faster, the response will be processed immediately.
const defaultQueryTimeout = 500;

/// Support function that add some extra features to the terminal.
extension TermUtils on InteractiveTerm {
  /// Write a hyperlink to the terminal.
  void hyperlink(String link, String name) => write(ansi.Term.hyperLink(link, name));

  /// Write a notification to the terminal.
  void notify(String title, String message) => write(ansi.Term.notify(title, message));

  /// Enable Alternate Screen
  void enableAlternateScreen() {
    write(ansi.Term.enableAlternateScreen);
    _modes = _modes.copyWith(alternateScreen: true);
  }

  /// Disable Alternate Screen
  void disableAlternateScreen() {
    write(ansi.Term.disableAlternateScreen);
    _modes = _modes.copyWith(alternateScreen: false);
  }

  /// Set Terminal Title
  void setTerminalTitle(String title) => write(ansi.Term.setTerminalTitle(title));

  /// Start receiving mouse events
  void enableMouseEvents() {
    write(ansi.Term.enableMouseEvents);
    _modes = _modes.copyWith(mouseEvents: true);
  }

  /// Stop receiving mouse events
  void disableMouseEvents() {
    write(ansi.Term.disableMouseEvents);
    _modes = _modes.copyWith(mouseEvents: false);
  }

  /// Start receiving focus events
  void startFocusTracking() => write(ansi.Term.enableFocusTracking);

  /// End receiving focus events
  void endFocusTracking() => write(ansi.Term.disableFocusTracking);

  /// Enabled Line Wrapping
  void enableLineWrapping() {
    write(ansi.Term.enableLineWrapping);
    _modes = _modes.copyWith(lineWrapping: true);
  }

  /// Disabled Line Wrapping
  void disableLineWrapping() {
    write(ansi.Term.disableLineWrapping);
    _modes = _modes.copyWith(lineWrapping: false);
  }

  /// Enable bracketed paste mode.
  ///
  /// When enabled, pasted text arrives as a single [PasteEvent] (wrapped in
  /// `ESC[200~` / `ESC[201~`) instead of a stream of individual key events,
  /// so an embedded newline does not look like an Enter key press.
  void enableBracketedPaste() {
    write(ansi.Term.enableBracketedPaste);
    _modes = _modes.copyWith(bracketedPaste: true);
  }

  /// Disable bracketed paste mode.
  void disableBracketedPaste() {
    write(ansi.Term.disableBracketedPaste);
    _modes = _modes.copyWith(bracketedPaste: false);
  }

  /// Query bracketed paste reporting status.
  ///
  /// ref: <https://invisible-island.net/xterm/ctlseqs/ctlseqs.html>
  Future<QueryBracketedPasteEvent?> queryBracketedPaste({int timeout = defaultQueryTimeout}) =>
      _query<QueryBracketedPasteEvent>(ansi.Term.queryBracketedPaste, timeout);

  /// Scroll the terminal up by the specified number of rows.
  void scrollUp(int rows) => write(ansi.Term.scrollUp(rows));

  /// Scroll the terminal down by the specified number of rows.
  void scrollDown(int rows) => write(ansi.Term.scrollDown(rows));

  /// Start synchronous update mode
  void startSyncUpdate() => write(ansi.Term.enableSyncUpdate);

  /// End synchronous update mode
  void endSyncUpdate() => write(ansi.Term.disableSyncUpdate);

  /// Soft Terminal reset
  void softReset() => write(ansi.Term.softTerminalReset);

  /// Query Sync status
  Future<QuerySyncUpdateEvent?> querySyncUpdate({int timeout = defaultQueryTimeout}) =>
      _query<QuerySyncUpdateEvent>(ansi.Term.querySyncUpdate, timeout);

  /// Request terminal name and version
  Future<String> queryTerminalVersion({int timeout = defaultQueryTimeout}) async {
    final event = await _query<NameAndVersionEvent>(ansi.Term.requestTermVersion, timeout);
    return event?.value ?? '';
  }

  /// Returns the current terminal status report.
  Future<Color?> queryOSCStatus(int status, {int timeout = defaultQueryTimeout}) async {
    final event = await _query<ColorQueryEvent>(ansi.Term.queryOSCColors(status), timeout);
    return (event != null) ? Color.fromRGBComponent(event.r, event.g, event.b) : null;
  }

  /// Query Keyboard enhancement support
  Future<bool> queryKeyboardEnhancementSupport({int timeout = defaultQueryTimeout}) async {
    final event = await _query<KeyboardEnhancementFlagsEvent>(ansi.Term.queryKeyboardEnhancementSupport, timeout);
    return event != null;
  }

  /// Query Primary Device Attributes
  Future<PrimaryDeviceAttributesEvent?> queryPrimaryDeviceAttributes({int timeout = defaultQueryTimeout}) =>
      _query<PrimaryDeviceAttributesEvent>(ansi.Term.queryPrimaryDeviceAttributes, timeout);

  /// Query Secondary Device Attributes (DA2)
  ///
  /// Returns the terminal type / firmware version / cartridge, or `null` if the
  /// terminal does not answer within [timeout].
  Future<SecondaryDeviceAttributesEvent?> querySecondaryDeviceAttributes({int timeout = defaultQueryTimeout}) =>
      _query<SecondaryDeviceAttributesEvent>(ansi.Term.querySecondaryDeviceAttributes, timeout);

  /// Query Terminal window size in pixels
  Future<QueryTerminalWindowSizeEvent?> queryWindowSizeInPixels({int timeout = defaultQueryTimeout}) =>
      _query<QueryTerminalWindowSizeEvent>(ansi.Term.queryWindowSizePixels, timeout);

  /// Set Clipboard content
  void clipboardSet(Clipboard clipboard, String data) {
    write(ansi.Term.clipboard(clipboard.target, base64.encode(utf8.encode(data))));
  }

  /// Clear Clipboard contents
  void clipboardClear(Clipboard clipboard) {
    write(ansi.Term.clipboard(clipboard.target, ClipboardMode.clear.mode));
  }

  /// Query Clipboard content
  ///
  /// Note: Most terminals will have this feature disable by default because is
  /// a security risk. Check your terminal for support and how to enable it.
  ///
  /// Can use the timeout parameter to wait for longer time if the terminal
  /// use some interface to request permissions.
  Future<ClipboardCopyEvent?> queryClipboard(Clipboard clipboard, {int timeout = defaultQueryTimeout}) =>
      _query<ClipboardCopyEvent>(ansi.Term.clipboard(clipboard.target, ClipboardMode.query.mode), timeout);

  /// Request keyboard capabilities
  ///
  /// ref: <https://sw.kovidgoyal.net/kitty/keyboard-protocol/#progressive-enhancement>
  Future<KeyboardEnhancementFlagsEvent?> queryKeyboardCapabilities({int timeout = defaultQueryTimeout}) =>
      _query<KeyboardEnhancementFlagsEvent>(ansi.Term.requestKeyboardCapabilities, timeout);

  /// Set keyboard flags
  ///
  /// ref: <https://sw.kovidgoyal.net/kitty/keyboard-protocol/#progressive-enhancement>
  void setKeyboardFlags(KeyboardEnhancementFlagsEvent flags) {
    write(ansi.Term.setKeyboardCapabilities(flags.flags, flags.mode));
    _modes = _modes.copyWith(keyboardFlags: flags);
  }

  /// Push keyboard flags to the stack
  ///
  /// ref: <https://sw.kovidgoyal.net/kitty/keyboard-protocol/#progressive-enhancement>
  void pushKeyboardFlags(KeyboardEnhancementFlagsEvent flags) {
    write(ansi.Term.pushKeyboardCapabilities(flags.flags));
    _modes = _modes.copyWith(keyboardFlags: flags);
  }

  /// Enable keyboard enhancement
  void enableKeyboardEnhancement() => setKeyboardFlags(KeyboardEnhancement.basic.flags);

  /// Enable keyboard enhancement with all parameters
  void enableKeyboardEnhancementFull() => setKeyboardFlags(KeyboardEnhancement.full.flags);

  /// Disable keyboard enhancements
  void disableKeyboardEnhancement() => setKeyboardFlags(KeyboardEnhancement.off.flags);

  /// Pop keyboard flags from the stack
  ///
  /// Tracked mode state is intentionally not updated here: the prior flags
  /// value lives on the terminal's own stack, not in [TermModes], so it cannot
  /// be recovered locally. `withModes` restores from the value it captured at
  /// scope entry rather than relying on this.
  ///
  /// ref: <https://sw.kovidgoyal.net/kitty/keyboard-protocol/#progressive-enhancement>
  void popKeyboardFlags([int entries = 1]) => write(ansi.Term.popKeyboardCapabilities(entries));

  /// Enable Unicode Core
  ///
  /// ref:  https://github.com/contour-terminal/terminal-unicode-core
  void enableUnicodeCore() {
    write(ansi.Term.enableUnicodeCore);
    _modes = _modes.copyWith(unicodeCore: true);
  }

  /// Disable Unicode Core
  ///
  /// ref:  https://github.com/contour-terminal/terminal-unicode-core
  void disableUnicodeCore() {
    write(ansi.Term.disableUnicodeCore);
    _modes = _modes.copyWith(unicodeCore: false);
  }

  /// Query Unicode Core status
  ///
  /// ref:  https://github.com/contour-terminal/terminal-unicode-core
  Future<UnicodeCoreEvent?> queryUnicodeCore({int timeout = defaultQueryTimeout}) =>
      _query<UnicodeCoreEvent>(ansi.Term.queryUnicodeCore, timeout);

  /// Enable color palette update notifications.
  ///
  /// When enabled, terminal sends `ColorSchemeEvent` when OS theme or
  /// terminal profile changes.
  ///
  /// ref: https://github.com/contour-terminal/contour/blob/master/docs/vt-extensions/color-palette-update-notifications.md
  void enableColorPaletteUpdates() => write(ansi.Term.enableColorPaletteUpdates);

  /// Disable color palette update notifications.
  ///
  /// ref: https://github.com/contour-terminal/contour/blob/master/docs/vt-extensions/color-palette-update-notifications.md
  void disableColorPaletteUpdates() => write(ansi.Term.disableColorPaletteUpdates);

  /// Query terminal color scheme preference (light/dark mode).
  ///
  /// ref: https://github.com/contour-terminal/contour/blob/master/docs/vt-extensions/color-palette-update-notifications.md
  Future<ColorSchemeEvent?> queryColorScheme({int timeout = defaultQueryTimeout}) =>
      _query<ColorSchemeEvent>(ansi.Term.queryColorScheme, timeout);

  /// Enable in-band window resize reporting.
  ///
  /// When enabled, terminal sends [WindowResizeEvent] on window resize.
  /// An immediate report is sent when first enabled.
  ///
  /// ref: https://gist.github.com/rockorager/e695fb2924d36b2bcf1fff4a3704bd83
  void enableInBandResize() {
    write(ansi.Term.enableInBandResize);
    _modes = _modes.copyWith(inBandResize: true);
  }

  /// Disable in-band window resize reporting.
  ///
  /// ref: https://gist.github.com/rockorager/e695fb2924d36b2bcf1fff4a3704bd83
  void disableInBandResize() {
    write(ansi.Term.disableInBandResize);
    _modes = _modes.copyWith(inBandResize: false);
  }

  /// Enables resize event delivery, using in-band reporting where possible
  /// and a signal-based fallback everywhere else.
  ///
  /// Always turns on in-band resize reporting (mode 2048) via
  /// [enableInBandResize]. Additionally, when the terminal is not already
  /// known — from a prior [InteractiveTerm.probe] — to support that mode,
  /// this also watches `SIGWINCH` and synthesizes a [WindowResizeEvent] on
  /// each signal, so resize events still arrive on terminals that ignore mode
  /// 2048. Call [InteractiveTerm.probe] first if you want to skip installing
  /// a redundant watcher on a terminal that has already answered the in-band
  /// resize query one way or the other.
  ///
  /// The synthesized event carries the current [InteractiveTerm.terminalLines]
  /// and [InteractiveTerm.terminalColumns] with pixel dimensions left at 0
  /// (unsupported, matching [WindowResizeEvent]'s own convention). It is fed
  /// through the same pipeline as every other parsed event, so on terminals
  /// where both the in-band report and the signal fire for the same resize,
  /// the resulting consecutive [WindowResizeEvent]s coalesce to one in the
  /// event queue.
  ///
  /// No `SIGWINCH` watcher is installed on Windows, which has no such signal.
  /// Calling this more than once installs at most one watcher.
  void enableResizeEvents() {
    enableInBandResize();

    final inBandDefinite = switch (termInfo?.inBandResize) {
      Supported(value: InBandResizeStatus.enabled) => true,
      Supported(value: InBandResizeStatus.disabled) => true,
      _ => false,
    };
    if (inBandDefinite) return;
    if (Platform.isWindows) return;

    _resizeSignalSubscription ??= ProcessSignal.sigwinch.watch().listen((_) {
      _onEventParsed(WindowResizeEvent(terminalLines, terminalColumns));
    });
  }

  /// Disables resize event delivery.
  ///
  /// Cancels the `SIGWINCH` watcher installed by [enableResizeEvents], if
  /// any, then disables in-band resize reporting via [disableInBandResize].
  void disableResizeEvents() {
    unawaited(_resizeSignalSubscription?.cancel());
    _resizeSignalSubscription = null;
    disableInBandResize();
  }

  /// Query in-band window resize reporting status.
  ///
  /// ref: https://gist.github.com/rockorager/e695fb2924d36b2bcf1fff4a3704bd83
  Future<QueryWindowResizeEvent?> queryInBandResize({int timeout = defaultQueryTimeout}) =>
      _query<QueryWindowResizeEvent>(ansi.Term.queryInBandResize, timeout);

  /// Sends [escape] and waits up to [timeout] ms for a reply of type [T] with
  /// raw mode applied for the duration; returns null on timeout.
  ///
  /// Shared mechanism behind every single-shot `queryX` method here and in
  /// [CursorUtils]. Not exposed — public queries wrap it (and map its result
  /// where needed). For batched capability probing see `probeTerminal`.
  Future<T?> _query<T extends Event>(Object escape, int timeout) {
    return withModes<T?>(() async {
      write(escape);
      return awaitEvent<T>(timeout: Duration(milliseconds: timeout));
    }, rawMode: true);
  }
}
