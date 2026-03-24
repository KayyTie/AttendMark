import '../models/timetable_entry.dart';
import '../database/database_helper.dart';

class TimetableRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<TimetableEntry> create(TimetableEntry entry) async {
    final db = await _dbHelper.database;
    final map = entry.toMap()..remove('id');
    final id = await db.insert('timetable_entries', map);
    return TimetableEntry(
      id: id,
      sessionId: entry.sessionId,
      dayOfWeek: entry.dayOfWeek,
      startTime: entry.startTime,
      endTime: entry.endTime,
      subjectId: entry.subjectId,
      isBreak: entry.isBreak,
      modifierId: entry.modifierId,
    );
  }

  Future<int> update(TimetableEntry entry) async {
    final db = await _dbHelper.database;
    return await db.update(
      'timetable_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<List<TimetableEntry>> getEntriesForSession(int sessionId) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'timetable_entries',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'day_of_week ASC, start_time ASC',
    );
    return result.map((map) => TimetableEntry.fromMap(map)).toList();
  }

  Future<List<TimetableEntry>> getEntriesForDay(
      int sessionId, int dayOfWeek) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'timetable_entries',
      where: 'session_id = ? AND day_of_week = ?',
      whereArgs: [sessionId, dayOfWeek],
      orderBy: 'start_time ASC',
    );
    return result.map((map) => TimetableEntry.fromMap(map)).toList();
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'timetable_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAllForSession(int sessionId) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'timetable_entries',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }
}
