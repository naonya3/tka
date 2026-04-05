const _reset = '\x1B[0m';
const _bold = '\x1B[1m';
const _dim = '\x1B[2m';
const _invert = '\x1B[7m';

class WatchTicketData {
  final String id;
  final String status;
  final String title;
  WatchTicketData(
      {required this.id, required this.status, required this.title});
}

int displayWidth(String s) {
  var w = 0;
  for (final rune in s.runes) {
    w += _isWide(rune) ? 2 : 1;
  }
  return w;
}

bool _isWide(int rune) {
  if (rune >= 0x4E00 && rune <= 0x9FFF) return true;
  if (rune >= 0x3400 && rune <= 0x4DBF) return true;
  if (rune >= 0x20000 && rune <= 0x2FFFF) return true;
  if (rune >= 0xF900 && rune <= 0xFAFF) return true;
  if (rune >= 0x3040 && rune <= 0x309F) return true;
  if (rune >= 0x30A0 && rune <= 0x30FF) return true;
  if (rune >= 0xAC00 && rune <= 0xD7AF) return true;
  if (rune >= 0x1100 && rune <= 0x115F) return true;
  if (rune >= 0xFF01 && rune <= 0xFF60) return true;
  if (rune >= 0xFFE0 && rune <= 0xFFE6) return true;
  if (rune >= 0x2E80 && rune <= 0x303E) return true;
  if (rune >= 0xFE30 && rune <= 0xFE4F) return true;
  if (rune >= 0x1F000 && rune <= 0x1FAFF) return true;
  if (rune >= 0x1F300 && rune <= 0x1F9FF) return true;
  return false;
}

String _sanitize(String s) {
  return s.replaceAll('\n', ' ').replaceAll('\r', '').replaceAll('\t', ' ');
}

String _truncate(String s, int maxWidth) {
  if (maxWidth < 4) maxWidth = 4;
  if (displayWidth(s) <= maxWidth) return s;
  final buf = StringBuffer();
  var w = 0;
  for (final rune in s.runes) {
    final cw = _isWide(rune) ? 2 : 1;
    if (w + cw > maxWidth - 3) break;
    buf.writeCharCode(rune);
    w += cw;
  }
  buf.write('...');
  return buf.toString();
}

String _pad(String s, int targetWidth) {
  final w = displayWidth(s);
  if (w >= targetWidth) return s;
  return '$s${' ' * (targetWidth - w)}';
}

String renderDashboard({
  required String projectName,
  required List<WatchTicketData> tickets,
  required List<String> projectNames,
  required int projectIndex,
  required Set<String> activeFilters,
  required List<String> statuses,
  int width = 60,
}) {
  final buf = StringBuffer();

  // Header: all projects in fixed order, selected one inverted
  final nav = StringBuffer(' ');
  for (var i = 0; i < projectNames.length; i++) {
    if (i == projectIndex) {
      nav.write(' $_bold$_invert ${projectNames[i]} $_reset');
    } else {
      nav.write(' $_dim${projectNames[i]}$_reset');
    }
  }
  buf.writeln(nav);

  // Status filter bar with numbers
  final filterBar = StringBuffer('  ');
  for (var i = 0; i < statuses.length; i++) {
    final s = statuses[i];
    final num = i + 1;
    if (activeFilters.contains(s)) {
      filterBar.write('$_invert $num:$s $_reset ');
    } else {
      filterBar.write('$_dim$num:$s$_reset ');
    }
  }
  buf.writeln(filterBar);
  buf.writeln();

  if (tickets.isEmpty) {
    buf.writeln('  ${_dim}No tickets$_reset');
    buf.writeln();
    buf.writeln('  ${_dim}TAB:project  1-${statuses.length}:filter  0:reset  q:quit$_reset');
    return buf.toString();
  }

  // Table
  final idW = tickets.fold<int>(
      2, (m, t) => displayWidth(t.id) > m ? displayWidth(t.id) : m);
  final statusW = tickets.fold<int>(
      6, (m, t) => displayWidth(t.status) > m ? displayWidth(t.status) : m);
  final fixedW = idW + statusW + 4 + 6;
  var titleW = (width - 2) - fixedW;
  if (titleW < 5) titleW = 5;

  buf.writeln(
      '  ┌${'─' * (idW + 2)}┬${'─' * (statusW + 2)}┬${'─' * (titleW + 2)}┐');
  buf.writeln(
      '  │ $_bold${_pad('ID', idW)}$_reset │ $_bold${_pad('STATUS', statusW)}$_reset │ $_bold${_pad('TITLE', titleW)}$_reset │');
  buf.writeln(
      '  ├${'─' * (idW + 2)}┼${'─' * (statusW + 2)}┼${'─' * (titleW + 2)}┤');

  for (final ticket in tickets) {
    var title = _sanitize(ticket.title);
    title = _truncate(title, titleW);
    buf.writeln(
        '  │ ${_pad(ticket.id, idW)} │ ${_pad(ticket.status, statusW)} │ ${_pad(title, titleW)} │');
  }

  buf.writeln(
      '  └${'─' * (idW + 2)}┴${'─' * (statusW + 2)}┴${'─' * (titleW + 2)}┘');

  // Footer: keybindings
  buf.writeln();
  buf.writeln('  ${_dim}TAB:project  1-${statuses.length}:filter  0:reset  q:quit$_reset');

  return buf.toString();
}
