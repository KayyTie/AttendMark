import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('attend_marker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const boolType = 'BOOLEAN NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    const integerNullable = 'INTEGER';
    const textNullable = 'TEXT';

    await db.execute('''
CREATE TABLE sessions (
  id $idType,
  name $textType,
  start_date $textType,
  end_date $textNullable,
  is_active $boolType
)
''');

    await db.execute('''
CREATE TABLE subjects (
  id $idType,
  session_id $integerType,
  name $textType,
  color_hex $textNullable,
  professor $textNullable,
  subject_code $textNullable,
  FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
)
''');

    await db.execute('''
CREATE TABLE modifiers (
  id $idType,
  name $textType,
  color_hex $textNullable
)
''');

    // Seed default modifiers
    await db.insert('modifiers', {'name': 'Theory', 'color_hex': null});
    await db.insert('modifiers', {'name': 'Lab', 'color_hex': '#CE93D8'});

    await db.execute('''
CREATE TABLE timetable_entries (
  id $idType,
  session_id $integerType,
  day_of_week $integerType,
  start_time $textType,
  end_time $textType,
  subject_id $integerNullable,
  is_break $boolType,
  modifier_id $integerNullable,
  FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE,
  FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE SET NULL,
  FOREIGN KEY (modifier_id) REFERENCES modifiers (id) ON DELETE SET NULL
)
''');

    await db.execute('''
CREATE TABLE attendance_records (
  id $idType,
  session_id $integerType,
  date $textType,
  timetable_entry_id $integerNullable,
  status $integerType,
  FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE,
  FOREIGN KEY (timetable_entry_id) REFERENCES timetable_entries (id) ON DELETE CASCADE
)
''');

    await db.execute('''
CREATE TABLE presets (
  id $idType,
  name $textType,
  actions_json $textType
)
''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE timetable_entries ADD COLUMN is_lab BOOLEAN NOT NULL DEFAULT 0');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE subjects ADD COLUMN professor TEXT');
      await db.execute('ALTER TABLE subjects ADD COLUMN subject_code TEXT');
    }
    if (oldVersion < 4) {
      // Create modifiers table and seed defaults
      await db.execute('''
CREATE TABLE modifiers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  color_hex TEXT
)
''');
      await db.insert('modifiers', {'name': 'Theory', 'color_hex': null});
      await db.insert('modifiers', {'name': 'Lab', 'color_hex': '#CE93D8'});

      // Add modifier_id FK column
      await db.execute(
          'ALTER TABLE timetable_entries ADD COLUMN modifier_id INTEGER REFERENCES modifiers(id) ON DELETE SET NULL');

      // Backfill: isLab=1 → modifier_id=2 (Lab), isLab=0 → modifier_id=1 (Theory)
      await db.execute(
          'UPDATE timetable_entries SET modifier_id = 2 WHERE is_lab = 1 AND is_break = 0');
      await db.execute(
          'UPDATE timetable_entries SET modifier_id = 1 WHERE is_lab = 0 AND is_break = 0');
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}

