import 'dart:io';

import 'constants.dart';

// How many elements fit in a line when write the tables
const int _stage1ChunkSize = 11;
const int _stage2ChunkSize = 19;
const int _stage3ChunkSize = 19;

/// Emit the final file with the tables.
Future<void> emitTables(Map<String, List<int>> tables) async {
  final out = File(destinationFile).openWrite()
    ..writeln('// generated code, internal functions no need to document')
    ..writeln('// ignore_for_file: public_member_api_docs')
    ..writeln("import 'dart:typed_data';\n")
    ..writeln('// AUTO GENERATED FILE - DO NOT EDIT\n')
    ..writeln("const unicodeUCD = '$version';\n")
    ..writeln('// dart format off');

  _emitStage('stage1', 'Uint16List', out, _stage1ChunkSize, tables);
  _emitStage('stage2', 'Uint8List', out, _stage2ChunkSize, tables);
  _emitStage('stage3', 'Uint8List', out, _stage3ChunkSize, tables);
  out.writeln('// dart format on');

  await out.close();
}

void _emitStage(String stage, String container, IOSink file, int chunkSize, Map<String, List<int>> tables) {
  file.writeln('final $stage = $container.fromList([');

  final stageLength = tables[stage]!.length;
  for (var i = 0; i < stageLength; i++) {
    if (i == 0) file.write(tabChars);
    if (i > 0 && i % chunkSize == 0) file.write('\n$tabChars');
    file.write('0x${tables[stage]![i].toRadixString(16)},');
  }

  file.writeln('\n]);');
}
