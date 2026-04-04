import 'dart:io';
import 'package:test/test.dart';
import 'package:tka/store/project_store.dart';

const _yamlContent = '''
version: 1
name: test-project
description: Test
fields:
  title:
    type: string
    required: true
states:
  initial: todo
  transitions:
    todo:
      - done
''';

void main() {
  late Directory tmpDir;
  late ProjectStore store;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('project_store_test_');
    store = ProjectStore(tmpDir.path);
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  test('load reads a YAML file and returns ProjectDefinition', () {
    File('${tmpDir.path}/test-project.yaml').writeAsStringSync(_yamlContent);

    final def = store.load('test-project');

    expect(def.version, 1);
    expect(def.name, 'test-project');
    expect(def.description, 'Test');
    expect(def.fields.containsKey('title'), isTrue);
    expect(def.fields['title']!.required, isTrue);
    expect(def.stateMachine.initial, 'todo');
    expect(def.stateMachine.canTransition('todo', 'done'), isTrue);
  });

  test('list returns all project names', () {
    File('${tmpDir.path}/alpha.yaml').writeAsStringSync(_yamlContent);
    File('${tmpDir.path}/beta.yaml').writeAsStringSync(_yamlContent);
    File('${tmpDir.path}/ignore.txt').writeAsStringSync('not yaml');

    final names = store.list();

    expect(names.toSet(), {'alpha', 'beta'});
  });

  test('list returns empty list when directory does not exist', () {
    final emptyStore = ProjectStore('${tmpDir.path}/nonexistent');
    expect(emptyStore.list(), isEmpty);
  });

  test('exists returns true for existing project', () {
    File('${tmpDir.path}/my-proj.yaml').writeAsStringSync(_yamlContent);
    expect(store.exists('my-proj'), isTrue);
  });

  test('exists returns false for non-existing project', () {
    expect(store.exists('nope'), isFalse);
  });

  test('load throws for non-existing project', () {
    expect(() => store.load('nope'), throwsException);
  });
}
