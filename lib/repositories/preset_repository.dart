import '../models/preset.dart';
import '../database/database_helper.dart';

class PresetRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Preset> create(Preset preset) async {
    final db = await _dbHelper.database;
    final id = await db.insert('presets', preset.toMap());
    return Preset(
      id: id,
      name: preset.name,
      actionsJson: preset.actionsJson,
    );
  }

  Future<List<Preset>> getAllPresets() async {
    final db = await _dbHelper.database;
    final result = await db.query('presets');
    return result.map((map) => Preset.fromMap(map)).toList();
  }

  Future<int> update(Preset preset) async {
    final db = await _dbHelper.database;
    return await db.update(
      'presets',
      preset.toMap(),
      where: 'id = ?',
      whereArgs: [preset.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'presets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
