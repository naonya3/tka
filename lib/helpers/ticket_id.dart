(String project, int seq) parseTicketId(String id) {
  final match = RegExp(r'^(.+)-(\d+)$').firstMatch(id);
  if (match == null) throw FormatException('Invalid ticket id: $id');
  return (match.group(1)!, int.parse(match.group(2)!));
}
