/// attended=0, missed=1, cancelled=2, holiday=3, empty=4
/// empty means no decision has been made; it is excluded from all counts.
enum AttendanceStatus { attended, missed, cancelled, holiday, empty }

class AttendanceRecord {
  final int? id;
  final int sessionId;
  final DateTime date;
  final int? timetableEntryId; // nullable if it's a full day holiday
  final AttendanceStatus status;

  AttendanceRecord({
    this.id,
    required this.sessionId,
    required this.date,
    this.timetableEntryId,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'date': date
          .toIso8601String()
          .split('T')[0], // store just the YYYY-MM-DD part
      'timetable_entry_id': timetableEntryId,
      'status': status.index,
    };
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'],
      sessionId: map['session_id'],
      date: DateTime.parse(map['date']),
      timetableEntryId: map['timetable_entry_id'],
      status: AttendanceStatus.values[map['status'] as int],
    );
  }
}
