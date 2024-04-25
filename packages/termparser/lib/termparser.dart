/// ANSI terminal escape sequences parser.
///
/// This library provides a parser for ANSI terminal escape sequences. It
/// allows to parse data coming from the terminal (stdin) and dispatching
/// events based on the input.
///
/// This parser is a 2-steps parser. The first step will parse the input data
/// and generate a consistent state. The second step will take the state and
/// generate events based on the state. This separation allows to have a
/// consistent state even if the input data is not complete.
library;

export 'src/parser.dart' show Parser, ctrlQuestionMarkQuirk, rawModeReturnQuirk;
