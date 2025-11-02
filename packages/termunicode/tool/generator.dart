import './generator/emitter.dart';
import './generator/table_builder.dart';

Future<void> main() async {
  final tables = Tables();
  await tables.generate();
  await emitTables(tables.tables);
}
