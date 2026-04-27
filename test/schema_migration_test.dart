import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:recurly/utils/schema.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> settingsBox;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('recurly_schema_test_');
    Hive.init(tempDir.path);
    settingsBox = await Hive.openBox<dynamic>('schema_test_settings');
  });

  tearDown(() async {
    await settingsBox.close();
    await tempDir.delete(recursive: true);
  });

  group('migrateSchema', () {
    test('writes current version when no schemaVersion is stored', () async {
      expect(settingsBox.get('schemaVersion'), isNull);

      await migrateSchema(settingsBox);

      expect(settingsBox.get('schemaVersion'), equals(kCurrentSchemaVersion));
    });

    test('no-op when stored version equals current version', () async {
      await settingsBox.put('schemaVersion', kCurrentSchemaVersion);

      await migrateSchema(settingsBox);

      expect(settingsBox.get('schemaVersion'), equals(kCurrentSchemaVersion));
    });

    test('throws StateError when stored version is greater than current', () async {
      await settingsBox.put('schemaVersion', kCurrentSchemaVersion + 1);

      expect(
        () => migrateSchema(settingsBox),
        throwsA(isA<StateError>()),
      );
    });
  });
}
