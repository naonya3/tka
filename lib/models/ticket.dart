class Ticket {
  final String project;
  final int seq;
  final String status;
  final Map<String, dynamic> fields;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String _createdAtRaw;
  final String _updatedAtRaw;

  Ticket({
    required this.project,
    required this.seq,
    required this.status,
    required this.fields,
    required this.createdAt,
    required this.updatedAt,
    required String createdAtRaw,
    required String updatedAtRaw,
  })  : _createdAtRaw = createdAtRaw,
        _updatedAtRaw = updatedAtRaw;

  String get id => '$project-${seq.toString().padLeft(3, '0')}';

  String get fileName => '${seq.toString().padLeft(3, '0')}.json';

  factory Ticket.fromJson(Map<String, dynamic> json) {
    final createdAtStr = json['created_at'] as String;
    final updatedAtStr = json['updated_at'] as String;
    return Ticket(
      project: json['project'] as String,
      seq: json['seq'] as int,
      status: json['status'] as String,
      fields: Map<String, dynamic>.from(json['fields'] as Map),
      createdAt: DateTime.parse(createdAtStr),
      updatedAt: DateTime.parse(updatedAtStr),
      createdAtRaw: createdAtStr,
      updatedAtRaw: updatedAtStr,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project': project,
      'seq': seq,
      'status': status,
      'fields': fields,
      'created_at': _createdAtRaw,
      'updated_at': _updatedAtRaw,
    };
  }
}
