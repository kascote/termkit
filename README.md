```
___________                   ____  __.__  __
\__    ___/__________  _____ |    |/ _|__|/  |_
  |    |_/ __ \_  __ \/     \|      < |  \   __\
  |    |\  ___/|  | \/  Y Y  \    |  \|  ||  |
  |____| \___  >__|  |__|_|  /____|__ \__||__|
             \/            \/        \/
```

TermKit is a collection of Dart packages for working with terminal applications.

[termansi](packages/termansi): This package provides a collection of ANSI escape
sequences. It essentially serves as a reference for ANSI codes, without offering
any additional functionality beyond their definitions.

[termlib](packages/termlib): This is the core library for interacting with
terminals.

[termparser](packages/termparser): This package acts as a parser, interpreting
the ANSI sequences returned by the terminal emulator and converting them into a
collection of events.
