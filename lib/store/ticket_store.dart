import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/ticket.dart';

class SeqConflictException implements Exception {
  final String project;
  final int seq;
  SeqConflictException(this.project, this.seq);
  @override
  String toString() => 'Seq conflict: $project-${seq.toString().padLeft(3, '0')} already exists';
}

class TicketStore {
  final String basePath;

  TicketStore(this.basePath);

  String _projectDir(String project) => p.join(basePath, project);

  int nextSeq(String project) {
    final dir = Directory(_projectDir(project));
    if (!dir.existsSync()) return 1;
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'));
    if (files.isEmpty) return 1;
    final maxSeq = files
        .map((f) => int.tryParse(p.basenameWithoutExtension(f.path)) ?? 0)
        .reduce((a, b) => a > b ? a : b);
    return maxSeq + 1;
  }

  /// Atomically assigns a seq and saves a new ticket.
  /// Uses a project-level lock file to prevent race conditions.
  int createNew(Ticket ticket) {
    final dir = Directory(_projectDir(ticket.project));
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final lockPath = p.join(dir.path, '.create.lock');
    final lockFile = File(lockPath);

    // Spin-wait for lock (exclusive create)
    const maxAttempts = 50;
    for (var i = 0; i < maxAttempts; i++) {
      try {
        lockFile.createSync(exclusive: true);
        break;
      } on FileSystemException {
        if (i == maxAttempts - 1) {
          throw Exception('Could not acquire create lock for ${ticket.project}');
        }
        sleep(Duration(milliseconds: 10));
      }
    }

    try {
      final seq = nextSeq(ticket.project);
      final now = DateTime.now().toIso8601String();
      final newTicket = Ticket(
        project: ticket.project,
        seq: seq,
        status: ticket.status,
        fields: ticket.fields,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdAtRaw: now,
        updatedAtRaw: now,
      );
      final filePath = p.join(dir.path, newTicket.fileName);
      final tmpFile = File('$filePath.tmp');
      tmpFile.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(newTicket.toJson()));
      tmpFile.renameSync(filePath);
      return seq;
    } finally {
      try { lockFile.deleteSync(); } catch (_) {}
    }
  }

  void save(Ticket ticket, {String? expectedUpdatedAt}) {
    final dir = Directory(_projectDir(ticket.project));
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final filePath = p.join(dir.path, ticket.fileName);
    final existing = File(filePath);

    if (expectedUpdatedAt != null && existing.existsSync()) {
      final data =
          jsonDecode(existing.readAsStringSync()) as Map<String, dynamic>;
      if (data['updated_at'] != expectedUpdatedAt) {
        throw Exception(
            'Optimistic lock conflict: ticket was modified by another process');
      }
    }

    final tmpFile = File('$filePath.tmp');
    tmpFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(ticket.toJson()));
    tmpFile.renameSync(filePath);
  }

  Ticket load(String project, int seq) {
    final fileName = '${seq.toString().padLeft(3, '0')}.json';
    final file = File(p.join(_projectDir(project), fileName));
    if (!file.existsSync()) {
      throw Exception(
          'Ticket not found: $project-${seq.toString().padLeft(3, '0')}');
    }
    return Ticket.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
  }

  List<Ticket> listAll(String project) {
    final dir = Directory(_projectDir(project));
    if (!dir.existsSync()) return [];
    return dir
        .listSync()
        .whereType<File>()
        .where(
            (f) => f.path.endsWith('.json') && !f.path.endsWith('.tmp'))
        .map((f) => Ticket.fromJson(
            jsonDecode(f.readAsStringSync()) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.seq.compareTo(b.seq));
  }

  List<Ticket> listByStatus(String project, String status) {
    return listAll(project).where((t) => t.status == status).toList();
  }

  List<Ticket> listArchived(String project) {
    final dir = Directory(p.join(_projectDir(project), 'archived'));
    if (!dir.existsSync()) return [];
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json') && !f.path.endsWith('.tmp'))
        .map((f) => Ticket.fromJson(
            jsonDecode(f.readAsStringSync()) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.seq.compareTo(b.seq));
  }

  void archive(String project, int seq) {
    final fileName = '${seq.toString().padLeft(3, '0')}.json';
    final src = File(p.join(_projectDir(project), fileName));
    if (!src.existsSync()) {
      throw Exception(
          'Ticket not found: $project-${seq.toString().padLeft(3, '0')}');
    }
    final archiveDir = Directory(p.join(_projectDir(project), 'archived'));
    if (!archiveDir.existsSync()) archiveDir.createSync();
    src.renameSync(p.join(archiveDir.path, fileName));
  }
}
