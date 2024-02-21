import 'package:termansi/termansi.dart' as ansi;

import '../termlib_base.dart';

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
  void enableMouseEvents() => write(ansi.Sup.startMouseEvents);

  /// Stop receiving mouse events
  void disableMouseEvents() => write(ansi.Sup.endMouseEvents);
}
