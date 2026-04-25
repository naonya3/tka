import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import '../helpers/project_name.dart';
import '../models/field_definition.dart';
import '../models/project_definition.dart';
import '../store/project_store.dart';
import '../templates/project_templates.dart';

class ProjectCommand extends Command {
  @override
  final String name = 'project';
  @override
  final String description = 'Manage project definitions';

  ProjectCommand(String basePath, {void Function(String)? printer, Stream<List<int>>? stdinStream}) {
    final store = ProjectStore('$basePath/projects');
    final p = printer ?? print;
    addSubcommand(_ProjectListCommand(store, p));
    addSubcommand(_ProjectShowCommand(store, p));
    addSubcommand(_ProjectTemplatesCommand(p));
    addSubcommand(_ProjectAddCommand(store, '$basePath/projects', p, stdinStream: stdinStream));
    addSubcommand(_ProjectSchemaCommand(p));
    addSubcommand(_ProjectWorkflowCommand(store, p));
    addSubcommand(_ProjectArchiveCommand(store, p));
    addSubcommand(_ProjectUnarchiveCommand(store, p));
  }
}

class _ProjectListCommand extends Command {
  @override
  final String name = 'list';
  @override
  final String description = 'List projects. Use --archived to list archived projects. Output: JSON array of {"name", "description"} objects.';

  final ProjectStore _store;
  final void Function(String) _printer;

  _ProjectListCommand(this._store, this._printer) {
    argParser.addFlag('archived', help: 'List archived projects', defaultsTo: false);
  }

  @override
  void run() {
    final archived = argResults!['archived'] as bool;
    final names = archived ? _store.listArchived() : _store.list();
    final result = names.map((name) {
      String description = '';
      try {
        final def = archived ? _store.loadArchived(name) : _store.load(name);
        description = def.description;
      } catch (_) {
        // Malformed project definition — emit empty description rather than fail.
      }
      return {'name': name, 'description': description};
    }).toList();
    _printer(jsonEncode(result));
  }
}

class _ProjectShowCommand extends Command {
  @override
  final String name = 'show';
  @override
  final String description = 'Show project definition (fields, states). Usage: tka project show <name>. Output: JSON object.';

  final ProjectStore _store;
  final void Function(String) _printer;

  _ProjectShowCommand(this._store, this._printer) {
    argParser.addFlag('pretty', help: 'Pretty-print JSON output', defaultsTo: false);
  }

  @override
  void run() {
    if (argResults!.rest.isEmpty) {
      throw UsageException('Project name is required.', usage);
    }
    final name = argResults!.rest.first;
    final project = _store.load(name);

    final fieldsJson = <String, dynamic>{};
    for (final entry in project.fields.entries) {
      final fieldMap = <String, dynamic>{
        'type': entry.value.type == FieldType.enumType ? 'enum' : entry.value.type.name,
        'required': entry.value.required,
      };
      if (entry.value.description != null) {
        fieldMap['description'] = entry.value.description;
      }
      if (entry.value.values != null) {
        fieldMap['values'] = entry.value.values;
      }
      fieldsJson[entry.key] = fieldMap;
    }
    final json = {
      'name': project.name,
      'description': project.description,
      'fields': fieldsJson,
      'states': {
        'initial': project.stateMachine.initial,
        'transitions': project.stateMachine.toTransitionsJson(),
      },
    };
    final pretty = argResults!['pretty'] as bool;
    if (pretty) {
      _printer(const JsonEncoder.withIndent('  ').convert(json));
    } else {
      _printer(jsonEncode(json));
    }
  }
}

class _ProjectTemplatesCommand extends Command {
  @override
  final String name = 'templates';
  @override
  final String description = 'List available project templates. Output: JSON array of {"name", "description"}.';

  final void Function(String) _printer;

  _ProjectTemplatesCommand(this._printer);

  @override
  void run() {
    final list = templateDescriptions.entries
        .map((e) => {'name': e.key, 'description': e.value})
        .toList();
    _printer(jsonEncode(list));
  }
}

class _ProjectAddCommand extends Command {
  @override
  final String name = 'add';
  @override
  final String description = '''Add a new project from template or JSON schema.

Usage:
  tka project add <name> [--template <name>]
  tka project add <name> --schema '<json>'
  echo '<json>' | tka project add <name> --schema -

Output: {"project": "..."}
JSON schema format: {"description": "...", "fields": {...}, "states": {...}}
Use "tka project schema" to see the full specification.''';

  final ProjectStore _store;
  final String _projectsPath;
  final void Function(String) _printer;
  final Stream<List<int>>? _stdinStream;

  _ProjectAddCommand(this._store, this._projectsPath, this._printer, {Stream<List<int>>? stdinStream})
      : _stdinStream = stdinStream {
    argParser
      ..addOption('template', defaultsTo: 'sample')
      ..addOption('schema', help: 'JSON schema string, or - to read from stdin');
  }

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      throw UsageException('Project name is required.', usage);
    }
    final projectName = argResults!.rest.first;
    validateProjectName(projectName);

    if (_store.exists(projectName)) {
      throw Exception('Project already exists: $projectName');
    }

    final schemaOption = argResults!['schema'] as String?;

    if (schemaOption != null) {
      await _addFromSchema(projectName, schemaOption);
    } else {
      _addFromTemplate(projectName);
    }
  }

  Future<void> _addFromSchema(String projectName, String schemaOption) async {
    String jsonStr;
    if (schemaOption == '-') {
      final input = _stdinStream ?? stdin;
      final bytes = <int>[];
      await for (final chunk in input) {
        bytes.addAll(chunk);
      }
      jsonStr = utf8.decode(bytes);
    } else {
      jsonStr = schemaOption;
    }

    final Map<String, dynamic> schema;
    try {
      schema = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Invalid JSON: $e');
    }

    final yamlData = <String, dynamic>{
      'version': 1,
      'name': projectName,
      ...schema,
    };

    // Validate by parsing
    ProjectDefinition.fromYaml(yamlData);

    final yaml = _toYaml(yamlData);
    final dir = Directory(_projectsPath);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    File('$_projectsPath/$projectName.yaml').writeAsStringSync(yaml);
    _printer(jsonEncode({'project': projectName}));
  }

  void _addFromTemplate(String projectName) {
    final templateName = argResults!['template'] as String;
    if (!projectTemplates.containsKey(templateName)) {
      throw Exception('Unknown template: $templateName');
    }

    final yaml = projectTemplates[templateName]!
        .replaceFirst(RegExp(r'name: \S+'), 'name: $projectName');
    final dir = Directory(_projectsPath);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    File('$_projectsPath/$projectName.yaml').writeAsStringSync(yaml);
    _printer(jsonEncode({'project': projectName, 'template': templateName}));
  }

  static String _toYaml(Map<String, dynamic> data) {
    final buf = StringBuffer();
    buf.writeln('version: ${data['version']}');
    buf.writeln('name: ${data['name']}');
    if (data['description'] != null) {
      buf.writeln('description: ${_yamlStr(data['description'] as String)}');
    }
    buf.writeln('fields:');
    final fields = data['fields'] as Map;
    for (final entry in fields.entries) {
      final field = entry.value as Map;
      buf.writeln('  ${entry.key}:');
      buf.writeln('    type: ${field['type']}');
      if (field['required'] == true) buf.writeln('    required: true');
      if (field['description'] != null) {
        buf.writeln('    description: ${_yamlStr(field['description'] as String)}');
      }
      if (field['values'] != null) {
        final values = (field['values'] as List).map((v) => v.toString()).toList();
        buf.writeln('    values: [${values.join(', ')}]');
      }
    }
    buf.writeln('states:');
    final states = data['states'] as Map;
    buf.writeln('  initial: ${states['initial']}');
    if (states['guide'] is Map) {
      buf.writeln('  guide:');
      final guide = states['guide'] as Map;
      for (final entry in guide.entries) {
        buf.writeln('    ${entry.key}: ${_yamlStr(entry.value as String)}');
      }
    }
    buf.writeln('  transitions:');
    final transitions = states['transitions'] as Map;
    for (final entry in transitions.entries) {
      if (entry.value is List) {
        final targets = (entry.value as List).map((v) => v.toString()).toList();
        buf.writeln('    ${entry.key}: [${targets.join(', ')}]');
      } else if (entry.value is Map) {
        final map = entry.value as Map;
        final targets = (map['targets'] as List).map((v) => v.toString()).toList();
        buf.writeln('    ${entry.key}:');
        buf.writeln('      targets: [${targets.join(', ')}]');
        if (map['verify'] != null) {
          buf.writeln('      verify:');
          final verify = map['verify'] as Map;
          for (final v in verify.entries) {
            buf.writeln('        ${v.key}: ${_yamlStr(v.value.toString())}');
          }
        }
      }
    }
    return buf.toString();
  }

  static String _yamlStr(String s) {
    if (s.contains(':') || s.contains('#') || s.contains('"') || s.contains("'") || s.contains('\n')) {
      return '"${s.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\n', '\\n')}"';
    }
    return s;
  }
}

class _ProjectSchemaCommand extends Command {
  @override
  final String name = 'schema';
  @override
  final String description = '''Show project YAML schema specification.

Usage: tka project schema
Output: JSON describing available field types, properties, and states format.
Use this to understand what JSON to pass to "tka project add --schema".
To edit an existing project, modify the YAML file at: \$(tka root)/projects/<name>.yaml''';

  final void Function(String) _printer;

  _ProjectSchemaCommand(this._printer);

  @override
  void run() {
    final schema = {
      'description': 'Project definition schema for tka project add --schema',
      'reserved_fields_note':
          '"title" is a reserved top-level ticket property and must not be defined in fields. '
          'Every ticket has a built-in required title set via "tka create --set title=...".',
      'format': {
        'description': 'string (optional)',
        'fields': {
          '<field_name>': {
            'type': '<field_type>',
            'required': 'bool (optional, default: false)',
            'description': 'string (optional)',
            'values': 'list of strings (required for enum type)',
          }
        },
        'states': {
          'initial': '<initial_status>',
          'guide': {
            '<status>': 'string (optional) — instruction for the agent in this state',
          },
          'transitions': {
            '<status>': ['<target_status>', '...'],
            '<status_with_verify>': {
              'targets': ['<target_status>', '...'],
              'verify': {
                '<target_status>':
                    'shell command (exit 0 = pass, non-zero = block)',
              },
            },
          },
        },
      },
      'field_types': {
        'string': {'description': 'Text value'},
        'number': {'description': 'Numeric value'},
        'date': {'description': 'Date in YYYY-MM-DD format'},
        'list': {'description': 'List of strings (append-only)'},
        'enum': {
          'description': 'One of predefined values',
          'required_properties': ['values'],
        },
      },
      'states_note':
          'States that appear only as transition targets (not as keys) are terminal states.',
      'why_field_description_matters':
          'Field "description" is the agent\'s only hint about what value belongs in a field. '
          'Without it, the agent guesses from the field name. '
          'Templates that omit descriptions become bad role models for AI-generated schemas.',
      'why_state_guide_matters':
          'The "guide" string for a state is embedded in the JSON returned by "tka transition" and "tka show", '
          'giving the agent inline instructions for what to do in that state without re-reading the YAML. '
          'Each guide should answer: what to do here, and how to decide which transition to take next. '
          'A workflow without guides forces the agent to infer behavior from state names alone.',
      'verify_note':
          'Transitions with "verify" run the command before transitioning. '
          'If the command exits non-zero, the transition is blocked. '
          'To use verify as a hook (run without blocking), append "|| true" to the command.',
      'verify_cwd': 'Repository root (parent of .tka directory)',
      'verify_env': {
        'TKA_TICKET_ID': 'Ticket ID (e.g. "myproj-003")',
        'TKA_TICKET_PROJECT': 'Project name',
        'TKA_TICKET_SEQ': 'Ticket sequence number',
        'TKA_TICKET_STATUS': 'Current status (transition source)',
        'TKA_TRANSITION_TO': 'Target status',
        'TKA_BASE_PATH': 'Resolved .tka directory path',
      },
    };
    _printer(jsonEncode(schema));
  }
}

class _ProjectWorkflowCommand extends Command {
  @override
  final String name = 'workflow';
  @override
  final String description = '''Show project workflow (state machine with guides).

Usage: tka project workflow <name>
Output: JSON object with initial state, all states with guides and transitions.
Use this to understand the project workflow before starting work.''';

  final ProjectStore _store;
  final void Function(String) _printer;

  _ProjectWorkflowCommand(this._store, this._printer);

  @override
  void run() {
    if (argResults!.rest.isEmpty) {
      throw UsageException('Project name is required.', usage);
    }
    final name = argResults!.rest.first;
    final project = _store.load(name);
    final sm = project.stateMachine;

    // Collect all states (both source and target)
    final allStates = <String>{};
    allStates.add(sm.initial);
    for (final entry in sm.transitions.entries) {
      allStates.add(entry.key);
      allStates.addAll(entry.value);
    }

    final statesJson = <String, dynamic>{};
    for (final state in allStates) {
      final stateMap = <String, dynamic>{};
      final guide = sm.getGuide(state);
      if (guide != null) stateMap['guide'] = guide;

      final targets = sm.getAvailableTransitions(state);
      if (targets.isNotEmpty) {
        stateMap['next'] = targets;
      }

      statesJson[state] = stateMap;
    }

    final json = {
      'project': project.name,
      'initial': sm.initial,
      'states': statesJson,
    };
    _printer(jsonEncode(json));
  }
}

class _ProjectArchiveCommand extends Command {
  @override
  final String name = 'archive';
  @override
  final String description = '''Archive a project.

Usage: tka project archive <name>
Moves the project definition to archived/. Tickets in data/ are not affected.
Output: {"project": "...", "archived": true}''';

  final ProjectStore _store;
  final void Function(String) _printer;

  _ProjectArchiveCommand(this._store, this._printer) {
    argParser.addFlag('force',
        abbr: 'f',
        help: 'Overwrite existing archived project.',
        negatable: false);
  }

  @override
  void run() {
    if (argResults!.rest.isEmpty) {
      throw UsageException('Project name is required.', usage);
    }
    final name = argResults!.rest.first;
    final force = argResults!['force'] as bool;
    _store.archive(name, force: force);
    _printer(jsonEncode({'project': name, 'archived': true}));
  }
}

class _ProjectUnarchiveCommand extends Command {
  @override
  final String name = 'unarchive';
  @override
  final String description = '''Restore an archived project.

Usage: tka project unarchive <name>
Moves the project definition back from archived/.
Output: {"project": "...", "archived": false}''';

  final ProjectStore _store;
  final void Function(String) _printer;

  _ProjectUnarchiveCommand(this._store, this._printer);

  @override
  void run() {
    if (argResults!.rest.isEmpty) {
      throw UsageException('Project name is required.', usage);
    }
    final name = argResults!.rest.first;
    _store.unarchive(name);
    _printer(jsonEncode({'project': name, 'archived': false}));
  }
}
