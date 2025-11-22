import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class LocalQueueService {
  static Database? _database;
  static const String tableName = 'local_clients'; // ✅ Utiliser partout
  final bool _inMemory;

  LocalQueueService({bool inMemory = false}) : _inMemory = inMemory;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    if (_inMemory) {
      return await openDatabase(
        ':memory:',
        version: 3,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } else {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final dbPath = join(documentsDirectory.path, 'waiting_room.db');
      return openDatabase(dbPath, version: 3, onCreate: _onCreate, onUpgrade: _onUpgrade);
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS $tableName (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  lat REAL,
  lng REAL,
  created_at TEXT NOT NULL,
  is_synced INTEGER NOT NULL DEFAULT 0,
  waiting_room_id TEXT,
  priority TEXT NOT NULL DEFAULT 'normal'
);
''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add waiting_room_id column if it doesn't exist
      try {
        await db.execute('ALTER TABLE $tableName ADD COLUMN waiting_room_id TEXT');
      } catch (e) {
        // Column might already exist, ignore error
      }
    }
    if (oldVersion < 3) {
      // Add priority column if it doesn't exist
      try {
        await db.execute('ALTER TABLE $tableName ADD COLUMN priority TEXT NOT NULL DEFAULT \'normal\'');
      } catch (e) {
        // Column might already exist, ignore error
      }
    }
  }

  Future<void> insertClientLocally(Map<String, dynamic> client) async {
    final db = await database;
    await db.insert(
      tableName, // ✅ Utiliser tableName
      client,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getClients() async {
    final db = await database;
    return db.query(tableName, orderBy: 'created_at ASC');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedClients() async {
    final db = await database;
    return db.query(tableName, where: 'is_synced = ?', whereArgs: [0]);
  }

  Future<void> markClientAsSynced(String id) async {
    final db = await database;
    await db.update(
      tableName,
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ✅ CORRIGÉ : Utiliser tableName et supprimer int.tryParse
  Future<void> deleteClientLocally(String id) async {
    final db = await database;
    await db.delete(
      tableName, // ✅ Utiliser tableName
      where: 'id = ?',
      whereArgs: [id], // ✅ id est déjà TEXT, pas besoin de int.tryParse
    );
  }

  Future<void> clearSyncedClients() async {
    final db = await database;
    await db.delete(tableName, where: 'is_synced = ?', whereArgs: [1]);
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}