import 'package:termansi/termansi.dart' as ansi;
import 'package:termlib/termlib.dart';

///
extension AssortedExt on TermLib {
  /// Write a hyperlink to the terminal.
  void hyperlink(String link, String name) => write(ansi.Sup.hyperLink(link, name));

  /// Write a notification to the terminal.
  void notify(String title, String message) => write(ansi.Sup.notify(title, message));

  /// Enable Alternate Screen
  void enableAlternateScreen() => write(ansi.Sup.enableAlternateScreen);

  /// Disable Alternate Screen
  void disableAlternateScreen() => write(ansi.Sup.disableAlternateScreen);

  /// Set Terminal Title
  void setTerminalTitle(String title) => write(ansi.Sup.setTerminalTitle(title));

  /// Start receiving mouse events
  void enableMouseEvents() => write(ansi.Sup.enableMouseEvents);

  /// Stop receiving mouse events
  void disableMouseEvents() => write(ansi.Sup.disableMouseEvents);

  /// Start receiving focus events
  void startFocusTracking() => write(ansi.Sup.enableFocusTracking);

  /// End receiving focus events
  void endFocusTracking() => write(ansi.Sup.disableFocusTracking);

  /// Enabled Line Wrapping
  void enableLineWrapping() => write(ansi.Sup.enableLineWrapping);

  /// Disabled Line Wrapping
  void disableLineWrapping() => write(ansi.Sup.disableLineWrapping);

  /// Scroll the terminal up by the specified number of rows.
  void scrollUp(int rows) => write(ansi.Sup.scrollUp(rows));

  /// Scroll the terminal down by the specified number of rows.
  void scrollDown(int rows) => write(ansi.Sup.scrollDown(rows));

  /// Start synchronous update mode
  void startSyncUpdate() => write(ansi.Sup.enableSyncUpdate);

  /// End synchronous update mode
  void endSyncUpdate() => write(ansi.Sup.disableSyncUpdate);

  /// Query Sync status
  Future<SyncUpdateStatus> querySyncUpdate() async {
    write(ansi.Sup.querySyncUpdate);
    final event = await readEvent();
    if (event is QuerySyncUpdateEvent) return event.value;
    throw Exception('Unexpected event: $event');
  }

  /// Request terminal name and version
  Future<String> requestTerminalVersion() async {
    write(ansi.Sup.requestTermVersion);
    final event = await readEvent();
    if (event is NameAndVersionEvent) return event.value;
    throw Exception('Unexpected event: $event');
  }
}
