final _validProjectName = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_-]*$');

void validateProjectName(String name) {
  if (name.isEmpty) {
    throw FormatException('Project name cannot be empty');
  }
  if (!_validProjectName.hasMatch(name)) {
    throw FormatException(
        'Invalid project name: "$name". Use only alphanumeric characters, hyphens, and underscores.');
  }
  if (name.contains('..') || name.contains('/') || name.contains('\\')) {
    throw FormatException('Invalid project name: "$name"');
  }
}
