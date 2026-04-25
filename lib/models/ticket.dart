class Ticket {
  final String project;
  final int seq;
  final String title;
  final String status;
  final Map<String, dynamic> fields;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String _createdAtRaw;
  final String _updatedAtRaw;

  Ticket({
    required this.project,
    required this.seq,
    required this.title,
    required this.status,
    required this.fields,
    required this.createdAt,
    required this.updatedAt,
    required String createdAtRaw,
    required String updatedAtRaw,
  })  : _createdAtRaw = createdAtRaw,
        _updatedAtRaw = updatedAtRaw {
    if (title.trim().isEmpty) {
      throw ArgumentError('title is required and cannot be empty');
    }
  }

  String get id => '$project-${seq.toString().padLeft(3, '0')}';

  String get fileName => '${seq.toString().padLeft(3, '0')}.json';

  factory Ticket.fromJson(Map<String, dynamic> json) {
    final createdAtStr = json['created_at'] as String;
    final updatedAtStr = json['updated_at'] as String;
    final title = json['title'];
    if (title is! String || title.trim().isEmpty) {
      final project = json['project'];
      final seq = json['seq'];
      final id = (project is String && seq is int)
          ? '$project-${seq.toString().padLeft(3, '0')}'
          : '<unknown>';
      throw FormatException(
          'Ticket $id is missing top-level "title". '
          'Run "tka migrate" to upgrade legacy tickets that store title inside fields.');
    }
    return Ticket(
      project: json['project'] as String,
      seq: json['seq'] as int,
      title: title,
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
      'title': title,
      'status': status,
      'fields': fields,
      'created_at': _createdAtRaw,
      'updated_at': _updatedAtRaw,
    };
  }
}
