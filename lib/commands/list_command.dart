import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import '../store/project_store.dart';
import '../store/ticket_store.dart';
import '../models/ticket.dart';
import '../helpers/field_input.dart';

class ListCommand extends Command<void> {
  @override
  final String name = 'list';
  @override
  final String description = '''List tickets in a project.

Usage: tka list --project <name> [--status X] [--where field=value] [--sort key] [--limit N] [--offset N] [--fields f1,f2]
Output: JSON array with selected fields (default: id, status).
Built-in fields: id, seq, project, status, created_at, updated_at.
Custom fields: as defined in the project YAML.

Examples:
  tka list -p myproj
  tka list -p myproj --status todo
  tka list -p myproj --where priority=p0
  tka list -p myproj --sort -created_at --limit 5
  tka list -p myproj --fields id,status,due,priority
  tka list -p myproj --archived''';

  final ProjectStore projectStore;
  final TicketStore ticketStore;
  final IOSink _out;

  ListCommand({
    required this.projectStore,
    required this.ticketStore,
    IOSink? out,
  }) : _out = out ?? stdout {
    argParser
      ..addOption('project', abbr: 'p', help: 'Project name (required)', mandatory: true)
      ..addOption('status', abbr: 's', help: 'Filter by status')
      ..addMultiOption('where', abbr: 'w', splitCommas: false, help: 'Filter by field=value (AND)')
      ..addOption('sort', help: 'Sort key. Prefix with - for descending')
      ..addOption('limit', help: 'Max number of tickets to return')
      ..addOption('offset', help: 'Number of tickets to skip')
      ..addOption('fields', abbr: 'f', help: 'Comma-separated output fields (default: id,status)')
      ..addFlag('archived', help: 'List archived tickets instead of active ones', defaultsTo: false);
  }

  @override
  void run() {
    final projectName = argResults!['project'] as String;
    final statusFilter = argResults!['status'] as String?;
    final whereFilters = argResults!['where'] as List<String>;
    final wherePairs = whereFilters.map((w) => parseSetOption(w)).toList();

    const _metaHints = {
      'status': 'Use --status <value> to filter by status.',
      'id': '"id" is a computed meta field, not a filterable field.',
      'project': '"project" is a meta field. Use --project to specify the project.',
      'seq': '"seq" is a meta field, not a filterable field.',
      'created_at': '"created_at" is a meta field. Use --sort created_at instead.',
      'updated_at': '"updated_at" is a meta field. Use --sort updated_at instead.',
    };
    for (final (field, _) in wherePairs) {
      if (_metaHints.containsKey(field)) {
        throw Exception('"$field" is not a field. ${_metaHints[field]}');
      }
    }

    final sortKey = argResults!['sort'] as String?;
    final limitStr = argResults!['limit'] as String?;
    final offsetStr = argResults!['offset'] as String?;

    int? limit;
    int? offset;
    if (limitStr != null) {
      limit = int.tryParse(limitStr);
      if (limit == null || limit < 1) {
        throw Exception('--limit must be a positive integer');
      }
    }
    if (offsetStr != null) {
      offset = int.tryParse(offsetStr);
      if (offset == null || offset < 0) {
        throw Exception('--offset must be a non-negative integer');
      }
    }

    final projectDef = projectStore.load(projectName);
    final sm = projectDef.stateMachine;

    if (statusFilter != null) {
      final allStatuses = <String>{sm.initial};
      for (final e in sm.transitions.entries) {
        allStatuses.add(e.key);
        allStatuses.addAll(e.value);
      }
      if (!allStatuses.contains(statusFilter)) {
        throw Exception(
            'Unknown status: $statusFilter. Available: ${allStatuses.join(', ')}');
      }
    }

    final archived = argResults!['archived'] as bool;
    var allTickets = archived
        ? ticketStore.listArchived(projectName)
        : ticketStore.listAll(projectName);
    if (statusFilter != null) {
      allTickets = allTickets.where((t) => t.status == statusFilter).toList();
    }
    if (wherePairs.isNotEmpty) {
      allTickets = allTickets.where((t) {
        for (final (field, value) in wherePairs) {
          final fv = t.fields[field];
          if (fv == null) return false;
          final fvStr = fv.toString();
          final nFv = num.tryParse(fvStr);
          final nVal = num.tryParse(value);
          if (nFv != null && nVal != null) {
            if (nFv != nVal) return false;
          } else {
            if (fvStr != value) return false;
          }
        }
        return true;
      }).toList();
    }

    if (sortKey != null) {
      var key = sortKey;
      var descending = false;
      if (key.startsWith('-')) {
        descending = true;
        key = key.substring(1);
      }
      allTickets.sort((a, b) {
        final va = _sortValue(a, key);
        final vb = _sortValue(b, key);
        if (va == null && vb == null) return 0;
        if (va == null) return 1;
        if (vb == null) return -1;
        int cmp;
        if (va is Comparable && vb is Comparable) {
          cmp = (va as Comparable).compareTo(vb);
        } else {
          cmp = va.toString().compareTo(vb.toString());
        }
        return descending ? -cmp : cmp;
      });
    }

    if (offset != null && offset > 0) {
      allTickets = allTickets.skip(offset).toList();
    }
    if (limit != null) {
      allTickets = allTickets.take(limit).toList();
    }

    final fieldsOption = argResults!['fields'] as String?;
    final outputFields = fieldsOption != null
        ? fieldsOption.split(',').map((f) => f.trim()).where((f) => f.isNotEmpty).toList()
        : ['id', 'status'];
    if (outputFields.isEmpty) {
      throw Exception('--fields must specify at least one field name');
    }

    const builtInFields = {'id', 'seq', 'project', 'status', 'created_at', 'updated_at'};
    final customFields = projectDef.fields.keys.toSet();
    final unknown = outputFields
        .where((f) => !builtInFields.contains(f) && !customFields.contains(f))
        .toList();
    if (unknown.isNotEmpty) {
      final available = [...builtInFields, ...customFields]..sort();
      throw Exception(
          'Unknown fields: ${unknown.join(', ')}. Available: ${available.join(', ')}');
    }

    final result = allTickets.map((t) {
      final entry = <String, dynamic>{};
      for (final f in outputFields) {
        switch (f) {
          case 'id':
            entry['id'] = t.id;
          case 'seq':
            entry['seq'] = t.seq;
          case 'project':
            entry['project'] = t.project;
          case 'status':
            entry['status'] = t.status;
          case 'created_at':
            entry['created_at'] = t.toJson()['created_at'];
          case 'updated_at':
            entry['updated_at'] = t.toJson()['updated_at'];
          default:
            entry[f] = t.fields[f];
        }
      }
      return entry;
    }).toList();

    _out.writeln(jsonEncode(result));
  }

  dynamic _sortValue(Ticket t, String key) {
    switch (key) {
      case 'seq':
        return t.seq;
      case 'id':
        return t.id;
      case 'status':
        return t.status;
      case 'created_at':
        return t.createdAt;
      case 'updated_at':
        return t.updatedAt;
      default:
        return t.fields[key];
    }
  }
}
