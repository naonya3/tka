import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:tka/commands/project_command.dart';
import 'package:tka/commands/create_command.dart';
import 'package:tka/commands/list_command.dart';
import 'package:tka/commands/show_command.dart';
import 'package:tka/commands/update_command.dart';
import 'package:tka/commands/transition_command.dart';
import 'package:tka/commands/append_command.dart';
import 'package:tka/commands/watch_command.dart';
import 'package:tka/commands/archive_command.dart';
import 'package:tka/commands/root_command.dart';
import 'package:tka/commands/init_command.dart';
import 'package:tka/resolve_base_path.dart';
import 'package:tka/store/project_store.dart';
import 'package:tka/store/ticket_store.dart';

Future<void> main(List<String> args) async {
  final globalParser = ArgParser()
    ..addOption('base', help: 'Path to .tka directory');

  String? baseOption;
  List<String> rest;
  try {
    final globalResults = globalParser.parse(args);
    baseOption = globalResults['base'] as String?;
    rest = globalResults.rest;
  } on FormatException {
    rest = args;
  }

  if (rest.isNotEmpty && rest.first == 'init') {
    if (rest.contains('--help') || rest.contains('-h')) {
      stderr.writeln(InitCommand.usage);
      return;
    }
    try {
      InitCommand().run();
    } on InitException catch (e) {
      stderr.writeln(e);
      exit(1);
    }
    return;
  }

  late final String basePath;
  try {
    basePath = resolveBasePath(baseOption: baseOption);
  } on ResolveNotFound {
    if (baseOption == null) {
      stderr.writeln('.tka directory not found.');
      exit(1);
    }
    stderr.write(
        '$baseOption not found. Initialize? [y/N] ');
    final answer = stdin.readLineSync() ?? '';
    if (answer.toLowerCase() != 'y') {
      stderr.writeln('Aborted.');
      exit(1);
    }
    Directory('$baseOption/projects').createSync(recursive: true);
    Directory('$baseOption/data').createSync(recursive: true);
    stderr.writeln('Initialized $baseOption');
    basePath = baseOption;
  } on ResolveException catch (e) {
    stderr.writeln(e);
    exit(1);
  }

  final projectStore = ProjectStore('$basePath/projects');
  final ticketStore = TicketStore('$basePath/data');

  final runner = CommandRunner('tka', '''Ticket for Agents — schema-driven ticket management CLI.

All output is machine-readable JSON on stdout. Errors go to stderr as JSON.
No human-friendly formatting — designed to be consumed by AI agents directly.

.tka resolution: --base <path> > ./.tka > search parent directories.

Examples:
  tka init
  tka project list
  tka project show <name>
  tka create <project> --set title="Buy milk" --set quantity=3
  tka list -p shopping --status pending
  tka list -p shopping --where priority=p0 --sort -created_at --limit 5
  tka list -p shopping --fields id,status
  tka list -p shopping --archived
  tka show <id>
  tka show <id> --pretty
  tka update <id> --set title="New title"
  tka transition <id> --to done
  tka append <id> --field history --value "Done"
  tka archive <id>
  tka root
  tka watch
  tka project add <name> --template tdd
  tka project add <name> --schema '{"fields":{...},"states":{...}}'
  tka project schema
  tka project templates
  tka project archive <name>
  tka project unarchive <name>
  tka project list --archived

Long text: use pipe (--set field=-) or file (--set field=@path):
  echo "multiline\\ntext" | tka create proj --set title=T --set detail=-
  tka update <id> --set detail=@design.md''')
    ..addCommand(ProjectCommand(basePath))
    ..addCommand(CreateCommand(projectStore: projectStore, ticketStore: ticketStore))
    ..addCommand(ListCommand(
        projectStore: projectStore, ticketStore: ticketStore))
    ..addCommand(ShowCommand(projectStore: projectStore, ticketStore: ticketStore))
    ..addCommand(UpdateCommand(
        projectStore: projectStore, ticketStore: ticketStore))
    ..addCommand(TransitionCommand(
        projectStore: projectStore, ticketStore: ticketStore))
    ..addCommand(AppendCommand(
        projectStore: projectStore, ticketStore: ticketStore))
    ..addCommand(ArchiveCommand(ticketStore: ticketStore))
    ..addCommand(RootCommand(basePath: basePath))
    ..addCommand(WatchCommand(
        projectStore: projectStore,
        ticketStore: ticketStore,
        dataPath: '$basePath/data'));

  try {
    final parsed = runner.parse(rest);
    await runner.runCommand(parsed);
  } on UsageException catch (e) {
    stderr.writeln(jsonEncode({'error': e.message}));
    exit(64);
  } on FormatException catch (e) {
    stderr.writeln(jsonEncode({'error': e.message}));
    exit(1);
  } on ArgumentError catch (e) {
    stderr.writeln(jsonEncode({'error': e.message}));
    exit(1);
  } on Exception catch (e) {
    var msg = e.toString().replaceFirst('Exception: ', '');
    msg = msg.replaceAll(basePath, '<store>');
    stderr.writeln(jsonEncode({'error': msg}));
    exit(1);
  } catch (e) {
    var msg = e.toString();
    msg = msg.replaceAll(basePath, '<store>');
    stderr.writeln(jsonEncode({'error': msg}));
    exit(1);
  }
}
