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

class CorruptTicketFileException implements Exception {
  final String path;
  final String reason;
  CorruptTicketFileException(this.path, this.reason);
  @override
  String toString() => 'Corrupt ticket file: $path ($reason)';
}

class TicketStore {
  final String basePath;

  TicketStore(this.basePath);

  String _projectDir(String project) => p.join(basePath, project);

  Ticket _parseTicketFile(File file) {
    try {
      return Ticket.fromJson(
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
    } catch (e) {
      final reason = e is FormatException ? e.message : e.toString();
      throw CorruptTicketFileException(file.path, reason);
    }
  }

  int nextSeq(String project) {
    // Scan archived tickets too: an archived seq must never be reissued,
    // or a later archive would silently overwrite the old ticket.
    final dirs = [
      Directory(_projectDir(project)),
      Directory(p.join(_projectDir(project), 'archived')),
    ];
    var maxSeq = 0;
    for (final dir in dirs) {
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync().whereType<File>()) {
        if (!f.path.endsWith('.json')) continue;
        final seq = int.tryParse(p.basenameWithoutExtension(f.path)) ?? 0;
        if (seq > maxSeq) maxSeq = seq;
      }
    }
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
        title: ticket.title,
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
      final id = '$project-${seq.toString().padLeft(3, '0')}';
      final archivedFile =
          File(p.join(_projectDir(project), 'archived', fileName));
      if (archivedFile.existsSync()) {
        throw Exception(
            'Ticket not found in active: $id. Use --archived to inspect archived tickets.');
      }
      throw Exception('Ticket not found: $id');
    }
    return _parseTicketFile(file);
  }

  Ticket loadArchived(String project, int seq) {
    final fileName = '${seq.toString().padLeft(3, '0')}.json';
    final file = File(p.join(_projectDir(project), 'archived', fileName));
    if (!file.existsSync()) {
      throw Exception(
          'Archived ticket not found: $project-${seq.toString().padLeft(3, '0')}');
    }
    return _parseTicketFile(file);
  }

  List<Ticket> _listDir(Directory dir, List<String>? corruptFiles) {
    if (!dir.existsSync()) return [];
    final tickets = <Ticket>[];
    for (final f in dir.listSync().whereType<File>()) {
      if (!f.path.endsWith('.json') || f.path.endsWith('.tmp')) continue;
      try {
        tickets.add(_parseTicketFile(f));
      } on CorruptTicketFileException {
        // A single corrupt file must not take down the whole listing.
        corruptFiles?.add(f.path);
      }
    }
    tickets.sort((a, b) => a.seq.compareTo(b.seq));
    return tickets;
  }

  List<Ticket> listAll(String project, {List<String>? corruptFiles}) {
    return _listDir(Directory(_projectDir(project)), corruptFiles);
  }

  List<Ticket> listByStatus(String project, String status) {
    return listAll(project).where((t) => t.status == status).toList();
  }

  List<Ticket> listArchived(String project, {List<String>? corruptFiles}) {
    return _listDir(
        Directory(p.join(_projectDir(project), 'archived')), corruptFiles);
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
    final dest = File(p.join(archiveDir.path, fileName));
    if (dest.existsSync()) {
      // Safety net: must never silently destroy an archived ticket.
      throw Exception(
          'Archived ticket already exists: $project-${seq.toString().padLeft(3, '0')}. Refusing to overwrite it.');
    }
    src.renameSync(dest.path);
  }
}
