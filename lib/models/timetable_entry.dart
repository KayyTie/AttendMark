import 'package:flutter/material.dart';

class TimetableEntry {
  final int? id;
  final int sessionId;
  final int dayOfWeek; // 1 = Monday, 7 = Sunday
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int? subjectId;
  final bool isBreak;
  final int? modifierId; // FK → modifiers table (null = no modifier)

  TimetableEntry({
    this.id,
    required this.sessionId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.subjectId,
    this.isBreak = false,
    this.modifierId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'day_of_week': dayOfWeek,
      'start_time':
          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
      'end_time':
          '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
      'subject_id': subjectId,
      'is_break': isBreak ? 1 : 0,
      'modifier_id': modifierId,
    };
  }

  factory TimetableEntry.fromMap(Map<String, dynamic> map) {
    final startParts = (map['start_time'] as String).split(':');
    final endParts = (map['end_time'] as String).split(':');

    return TimetableEntry(
      id: map['id'],
      sessionId: map['session_id'],
      dayOfWeek: map['day_of_week'],
      startTime: TimeOfDay(
          hour: int.parse(startParts[0]), minute: int.parse(startParts[1])),
      endTime: TimeOfDay(
          hour: int.parse(endParts[0]), minute: int.parse(endParts[1])),
      subjectId: map['subject_id'],
      isBreak: map['is_break'] == 1,
      modifierId: map['modifier_id'] as int?,
    );
  }
}
