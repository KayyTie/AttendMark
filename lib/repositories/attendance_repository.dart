import 'package:sqflite/sqflite.dart';
import '../models/attendance_record.dart';
import '../database/database_helper.dart';

class AttendanceRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<AttendanceRecord> create(AttendanceRecord record) async {
    final db = await _dbHelper.database;
    final id = await db.insert(
      'attendance_records',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return AttendanceRecord(
      id: id,
      sessionId: record.sessionId,
      date: record.date,
      timetableEntryId: record.timetableEntryId,
      status: record.status,
    );
  }

  Future<int> update(AttendanceRecord record) async {
    final db = await _dbHelper.database;
    return await db.update(
      'attendance_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<List<AttendanceRecord>> getRecordsForSession(int sessionId) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'attendance_records',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    return result.map((map) => AttendanceRecord.fromMap(map)).toList();
  }

  Future<List<AttendanceRecord>> getRecordsForDate(
      int sessionId, DateTime date) async {
    final db = await _dbHelper.database;
    final dateString = date.toIso8601String().split('T')[0];
    final result = await db.query(
      'attendance_records',
      where: 'session_id = ? AND date = ?',
      whereArgs: [sessionId, dateString],
    );
    return result.map((map) => AttendanceRecord.fromMap(map)).toList();
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db
        .delete('attendance_records', where: 'id = ?', whereArgs: [id]);
  }

  /// Deletes ALL records for a specific date (use only when clearing a whole day).
  Future<int> deleteRecordsForDate(int sessionId, DateTime date) async {
    final db = await _dbHelper.database;
    final dateString = date.toIso8601String().split('T')[0];
    return await db.delete(
      'attendance_records',
      where: 'session_id = ? AND date = ?',
      whereArgs: [sessionId, dateString],
    );
  }

  /// Deletes ONLY the holiday marker record(s) for a date, leaving lecture records intact.
  Future<int> deleteHolidayForDate(int sessionId, DateTime date) async {
    final db = await _dbHelper.database;
    final dateString = date.toIso8601String().split('T')[0];
    // status 3 = holiday (AttendanceStatus.holiday.index)
    return await db.delete(
      'attendance_records',
      where:
          'session_id = ? AND date = ? AND status = ? AND timetable_entry_id IS NULL',
      whereArgs: [sessionId, dateString, AttendanceStatus.holiday.index],
    );
  }
}
