import '../models/ticket.dart';

/// Expands {{id}}, {{project}} and {{seq}} placeholders in a state guide
/// against a concrete ticket, so guides can contain copy-pasteable commands
/// like "tka transition {{id}} --to running". Expansion happens at read time
/// (show/transition output); the YAML keeps the template form.
String expandGuide(String guide, Ticket ticket) => guide
    .replaceAll('{{id}}', ticket.id)
    .replaceAll('{{project}}', ticket.project)
    .replaceAll('{{seq}}', ticket.seq.toString());
