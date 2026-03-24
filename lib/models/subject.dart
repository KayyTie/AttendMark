class Subject {
  final int? id;
  final int sessionId;
  final String name;
  final String? colorHex;
  final String? professor;
  final String? subjectCode;

  Subject({
    this.id,
    required this.sessionId,
    required this.name,
    this.colorHex,
    this.professor,
    this.subjectCode,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'name': name,
      'color_hex': colorHex,
      'professor': professor,
      'subject_code': subjectCode,
    };
  }

  factory Subject.fromMap(Map<String, dynamic> map) {
    return Subject(
      id: map['id'],
      sessionId: map['session_id'],
      name: map['name'],
      colorHex: map['color_hex'],
      professor: map['professor'],
      subjectCode: map['subject_code'],
    );
  }
}
