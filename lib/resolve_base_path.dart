import 'dart:io';
import 'package:path/path.dart' as p;

class ResolveException implements Exception {
  final String message;
  ResolveException(this.message);
  @override
  String toString() => message;
}

class ResolveNotFound extends ResolveException {
  ResolveNotFound() : super('.tka directory not found.');
}

String resolveBasePath({String? baseOption, String? cwd}) {
  if (baseOption != null) {
    if (!Directory(baseOption).existsSync()) {
      throw ResolveNotFound();
    }
    return baseOption;
  }

  var dir = cwd ?? Directory.current.path;
  while (true) {
    final candidate = p.join(dir, '.tka');
    if (Directory(candidate).existsSync()) return candidate;
    final parent = p.dirname(dir);
    if (parent == dir) break;
    dir = parent;
  }

  throw ResolveNotFound();
}
