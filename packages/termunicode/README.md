# term_unicode

Dart library designed to provide a set of utilities for working with Unicode
characters in terminal applications. It is particularly useful for applications
that need to handle a wide range of Unicode characters and properties.

This library is part of the [termKit](https://github.com/kascote/termkit)
project.

## Main Features

### Character Width Determination

One of the main features of term_unicode is the ability to determine the width
of a character or string. This takes into account different properties or
contexts, which can be crucial for correctly displaying text in a terminal
application.

### Emoji Support

The library includes support to check if a character is an emoji, which can be
useful for handling emoji characters in user input or text processing.

### Printable Characters

`term_unicode` can also determine if a character is printable, which can be
useful for handling user input or displaying text.

### Non-Character and Private-Use Characters

The library can also determine if a character is a non-character or private-use

## Usage

To use `term_unicode`, simply import the library into your Dart application:

```dart
import 'package:term_unicode/term_unicode.dart';

void main() {
  print(widthString('a')); // 1
  print(widthString('👩')); // 2
  print(widthString('ｈｅｌｌｏ')); // 10
}
```

**_IMPORTANT_**:
This packages export two libraries, `term_unicode.dart` and
`term_ucd.dart`.

`term_unicode.dart` is the main library and contains the main features of the
package. Nothing more is needed if only want to use the utilities to inspect
Unicode characters.

`term_ucd.dart` contains the Unicode Character Database (UCD) parser and some
other parsers used to create the tables that `term_unicode` needs to work.

## Re-generate the tables

To regenerate the tables used by `term_unicode`, you can run the following
command from the root directory:

```bash
dart run generator.dart
```

this will create a `data` directory, where some UCD files will be downloaded
and will overwrite the file `lib/src/tables.dart`.

## How it works

`term_unicode` implements a 3 stage table lookup. Is more or less the same idea
that other libraries use. The difference with this, is that `term_unicode` not
only stores the character width, but also some other properties that can be
useful for terminal applications. This makes that the stage2 table is bigger,
but the lookup is super fast.

For a more detailed explanation of the process on how the 3 stage table works,
you can check this link: [Fast Lookup of Unicode Properties](https://here-be-braces.com/fast-lookup-of-unicode-properties/)

This project is based on work from other projects, like:

- <https://github.com/ridiculousfish/widecharwidth>
- <https://github.com/unicode-rs/unicode-width>
- <https://cs.opensource.google/go/x/text/+/master:internal/ucd/ucd.go>

## Contributing

Contributions to `term_unicode` are welcome. Please submit a pull request or
create an issue to discuss any changes you wish to make.

## License

`term_unicode` is licensed under the MIT License.
