import '../models/session.dart';
import '../database/database_helper.dart';

class SessionRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Session> create(Session session) async {
    final db = await _dbHelper.database;
    final id = await db.insert('sessions', session.toMap());
    return Session(
      id: id,
      name: session.name,
      startDate: session.startDate,
      endDate: session.endDate,
      isActive: session.isActive,
    );
  }

  Future<Session?> getActiveSession() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'sessions',
      where: 'is_active = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Session.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Session>> getAllSessions() async {
    final db = await _dbHelper.database;
    final result = await db.query('sessions', orderBy: 'start_date DESC');
    return result.map((map) => Session.fromMap(map)).toList();
  }

  Future<int> update(Session session) async {
    final db = await _dbHelper.database;
    return await db.update(
      'sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
