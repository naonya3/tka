import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import '../models/project_definition.dart';

class ProjectStore {
  final String basePath;

  ProjectStore(this.basePath);

  ProjectDefinition load(String name) {
    final file = File(p.join(basePath, '$name.yaml'));
    if (!file.existsSync()) {
      throw Exception(
          'Project not found: $name. '
          'Create one with: tka project add $name --template <name> '
          'or: tka project add $name --schema \'<json>\'. '
          'Run "tka project schema" to see the schema specification.');
    }
    final content = file.readAsStringSync();
    final yaml = loadYaml(content);
    return ProjectDefinition.fromYaml(Map.from(yaml as Map));
  }

  List<String> list() {
    final dir = Directory(basePath);
    if (!dir.existsSync()) return [];
    return dir.listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.yaml'))
        .map((f) => p.basenameWithoutExtension(f.path))
        .toList();
  }

  bool exists(String name) {
    return File(p.join(basePath, '$name.yaml')).existsSync();
  }

  void archive(String name) {
    final file = File(p.join(basePath, '$name.yaml'));
    if (!file.existsSync()) {
      throw Exception('Project not found: $name');
    }
    final archiveDir = Directory(p.join(basePath, 'archived'));
    if (!archiveDir.existsSync()) archiveDir.createSync();
    final dest = File(p.join(archiveDir.path, '$name.yaml'));
    if (dest.existsSync()) dest.deleteSync();
    file.renameSync(dest.path);
  }

  void unarchive(String name) {
    final file = File(p.join(basePath, 'archived', '$name.yaml'));
    if (!file.existsSync()) {
      throw Exception('Archived project not found: $name');
    }
    final dest = File(p.join(basePath, '$name.yaml'));
    if (dest.existsSync()) {
      throw Exception('Active project already exists: $name');
    }
    file.renameSync(dest.path);
  }

  List<String> listArchived() {
    final dir = Directory(p.join(basePath, 'archived'));
    if (!dir.existsSync()) return [];
    return dir.listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.yaml'))
        .map((f) => p.basenameWithoutExtension(f.path))
        .toList();
  }
}
