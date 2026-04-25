import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

class MigrateCommand extends Command<void> {
  @override
  final String name = 'migrate';
  @override
  final String description = '''Migrate legacy .tka data to the current schema.

Usage: tka migrate [--dry-run]
Output: {"projects_migrated":N,"projects_skipped":N,"tickets_migrated":N,"tickets_skipped":N,"errors":[...]}

Current migrations:
- "title" moves from "fields.title" to top-level on every ticket.
- "title" is removed from project schema "fields" (now reserved top-level).
- Project schema version bumped to 2.

The command is idempotent — re-running on already-migrated data is a no-op.''';

  final String basePath;
  final IOSink _out;

  MigrateCommand({required this.basePath, IOSink? out})
      : _out = out ?? stdout {
    argParser.addFlag('dry-run',
        help: 'Show what would change without writing files',
        defaultsTo: false);
  }

  @override
  void run() {
    final dryRun = argResults!['dry-run'] as bool;
    final report = _MigrationReport();

    _migrateProjects(p.join(basePath, 'projects'), dryRun, report);
    _migrateProjects(
        p.join(basePath, 'projects', 'archived'), dryRun, report);
    _migrateData(p.join(basePath, 'data'), dryRun, report);

    _out.writeln(jsonEncode(report.toJson(dryRun: dryRun)));
  }

  void _migrateProjects(String dir, bool dryRun, _MigrationReport report) {
    final d = Directory(dir);
    if (!d.existsSync()) return;
    for (final entity in d.listSync()) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.yaml')) continue;
      try {
        final content = entity.readAsStringSync();
        final result = _migrateProjectYaml(content);
        if (result == null) {
          report.projectsSkipped++;
          continue;
        }
        if (!dryRun) entity.writeAsStringSync(result);
        report.projectsMigrated++;
      } catch (e) {
        report.errors.add({'file': entity.path, 'error': e.toString()});
      }
    }
  }

  void _migrateData(String dataPath, bool dryRun, _MigrationReport report) {
    final d = Directory(dataPath);
    if (!d.existsSync()) return;
    for (final projectDir in d.listSync()) {
      if (projectDir is! Directory) continue;
      _migrateTicketsIn(projectDir.path, dryRun, report);
      final archivedDir = Directory(p.join(projectDir.path, 'archived'));
      if (archivedDir.existsSync()) {
        _migrateTicketsIn(archivedDir.path, dryRun, report);
      }
    }
  }

  void _migrateTicketsIn(String dir, bool dryRun, _MigrationReport report) {
    final d = Directory(dir);
    for (final entity in d.listSync()) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.json')) continue;
      if (entity.path.endsWith('.tmp')) continue;
      try {
        final raw = entity.readAsStringSync();
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final migrated = _migrateTicketJson(data);
        if (migrated == null) {
          report.ticketsSkipped++;
          continue;
        }
        if (!dryRun) {
          final tmp = File('${entity.path}.tmp');
          tmp.writeAsStringSync(
              const JsonEncoder.withIndent('  ').convert(migrated));
          tmp.renameSync(entity.path);
        }
        report.ticketsMigrated++;
      } catch (e) {
        report.errors.add({'file': entity.path, 'error': e.toString()});
      }
    }
  }
}

/// Migrates a project YAML string. Returns the new content if changed,
/// or null if no changes were needed.
String? _migrateProjectYaml(String content) {
  final lines = content.split('\n');
  final result = <String>[];
  var changed = false;
  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    final trimmed = line.trimRight();

    // Bump version: 1 → 2
    if (trimmed.startsWith('version:')) {
      final value = trimmed.substring('version:'.length).trim();
      if (value == '1') {
        result.add('version: 2');
        changed = true;
        i++;
        continue;
      }
    }

    // Inline form:  title: { type: string, required: true }
    if (RegExp(r'^\s*title\s*:\s*\{').hasMatch(line)) {
      changed = true;
      i++;
      continue;
    }

    // Block form:
    //   title:
    //     type: string
    //     required: true
    final blockMatch = RegExp(r'^(\s*)title\s*:\s*$').firstMatch(line);
    if (blockMatch != null) {
      final indent = blockMatch.group(1)!.length;
      changed = true;
      i++;
      while (i < lines.length) {
        final next = lines[i];
        if (next.trim().isEmpty) {
          i++;
          continue;
        }
        final nextIndent = next.length - next.trimLeft().length;
        if (nextIndent <= indent) break;
        i++;
      }
      continue;
    }

    result.add(line);
    i++;
  }
  if (!changed) return null;
  return result.join('\n');
}

/// Migrates a ticket JSON map. Returns the new map if changed,
/// or null if no changes were needed.
Map<String, dynamic>? _migrateTicketJson(Map<String, dynamic> data) {
  final fields = data['fields'];
  final hasTopTitle = data['title'] is String &&
      (data['title'] as String).trim().isNotEmpty;

  if (hasTopTitle) {
    if (fields is Map && fields.containsKey('title')) {
      final next = Map<String, dynamic>.from(data);
      final newFields = Map<String, dynamic>.from(fields);
      newFields.remove('title');
      next['fields'] = newFields;
      return next;
    }
    return null;
  }

  if (fields is Map && fields['title'] is String &&
      (fields['title'] as String).trim().isNotEmpty) {
    final next = <String, dynamic>{};
    final newFields = Map<String, dynamic>.from(fields);
    final title = newFields.remove('title') as String;
    for (final entry in data.entries) {
      if (entry.key == 'fields') {
        next['title'] = title;
        next['fields'] = newFields;
      } else {
        next[entry.key] = entry.value;
      }
    }
    if (!next.containsKey('title')) {
      next['title'] = title;
      next['fields'] = newFields;
    }
    return next;
  }

  throw FormatException(
      'No "title" found at top level or in fields for ticket ${data['id'] ?? '<unknown>'}');
}

class _MigrationReport {
  int projectsMigrated = 0;
  int projectsSkipped = 0;
  int ticketsMigrated = 0;
  int ticketsSkipped = 0;
  final List<Map<String, String>> errors = [];

  Map<String, dynamic> toJson({required bool dryRun}) => {
        'dry_run': dryRun,
        'projects_migrated': projectsMigrated,
        'projects_skipped': projectsSkipped,
        'tickets_migrated': ticketsMigrated,
        'tickets_skipped': ticketsSkipped,
        'errors': errors,
      };
}
