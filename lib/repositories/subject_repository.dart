import '../models/subject.dart';
import '../database/database_helper.dart';

class SubjectRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Subject> create(Subject subject) async {
    final db = await _dbHelper.database;
    final id = await db.insert('subjects', subject.toMap());
    return Subject(
        id: id,
        sessionId: subject.sessionId,
        name: subject.name,
        colorHex: subject.colorHex);
  }

  Future<List<Subject>> getSubjectsForSession(int sessionId) async {
    final db = await _dbHelper.database;
    final result = await db
        .query('subjects', where: 'session_id = ?', whereArgs: [sessionId]);
    return result.map((map) => Subject.fromMap(map)).toList();
  }

  Future<int> update(Subject subject) async {
    final db = await _dbHelper.database;
    return await db.update('subjects', subject.toMap(),
        where: 'id = ?', whereArgs: [subject.id]);
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('subjects', where: 'id = ?', whereArgs: [id]);
  }
}
