import '../database/database_helper.dart';
import '../models/modifier.dart';

class ModifierRepository {
  Future<List<Modifier>> getAllModifiers() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('modifiers', orderBy: 'id ASC');
    return maps.map(Modifier.fromMap).toList();
  }

  Future<Modifier> create(Modifier modifier) async {
    final db = await DatabaseHelper.instance.database;
    final id = await db.insert('modifiers', modifier.toMap()..remove('id'));
    return modifier.copyWith(id: id);
  }

  Future<void> update(Modifier modifier) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('modifiers', modifier.toMap(),
        where: 'id = ?', whereArgs: [modifier.id]);
  }

  Future<void> delete(int id) async {
    final db = await DatabaseHelper.instance.database;
    // modifier_id FK has ON DELETE SET NULL so related entries are unlinked
    await db.delete('modifiers', where: 'id = ?', whereArgs: [id]);
  }
}
