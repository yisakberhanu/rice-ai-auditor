import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const _databaseName = "AfricaRice_Prod.db"; 
  static const _databaseVersion = 4; // 🚀 Bumped to v4 for the new Mismatch Flag
  static const table = 'scans';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL, 
        rice_type TEXT NOT NULL, 
        
        -- Commercial Verdict
        grade TEXT NOT NULL,
        consistency TEXT NOT NULL,
        shape TEXT NOT NULL,
        chalky_status TEXT NOT NULL,
        
        -- Grain Counts & Defect Percentages
        total_count INTEGER NOT NULL,
        broken_count INTEGER NOT NULL DEFAULT 0,
        broken_pct REAL NOT NULL,
        long_pct REAL NOT NULL,
        med_pct REAL NOT NULL,
        short_pct REAL NOT NULL,
        black_pct REAL NOT NULL,
        yellow_pct REAL NOT NULL,
        red_pct REAL NOT NULL,
        green_pct REAL NOT NULL,
        chalky_pct REAL NOT NULL,
        
        -- Physical & Optical Calibrations
        avg_length REAL NOT NULL,
        avg_width REAL NOT NULL,
        lwr REAL NOT NULL,
        L REAL NOT NULL,
        a REAL NOT NULL,
        b REAL NOT NULL,
        
        -- Audit Traceability Signals
        model_version TEXT NOT NULL,
        confidence REAL DEFAULT 0.0,
        inference_time_ms INTEGER DEFAULT 0,
        gps_location TEXT,
        variety_mismatch INTEGER DEFAULT 0, -- 🚨 NEW: AI vs Human Verification (0=False, 1=True)
        image_path TEXT NOT NULL
      )
    ''');

    // Indexes for fast querying on the Dashboard and History screens
    await db.execute('CREATE INDEX idx_timestamp ON $table(timestamp)');
    await db.execute('CREATE INDEX idx_grade ON $table(grade)');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 🚨 Safe Migration Protocol
    debugPrint("🚀 Migrating Database from v$oldVersion to v$newVersion...");
    var columns = await db.rawQuery('PRAGMA table_info($table)');
    var columnNames = columns.map((e) => e['name']).toList();

    // Helper to add column safely without crashing
    Future<void> addCol(String name, String type) async {
      if (!columnNames.contains(name)) {
        await db.execute('ALTER TABLE $table ADD COLUMN $name $type');
      }
    }

    if (oldVersion < 3) {
      await addCol('model_version', "TEXT NOT NULL DEFAULT 'ConvNeXt-v1.0.3-FP16'");
      await addCol('confidence', "REAL DEFAULT 0.0");
      await addCol('inference_time_ms', "INTEGER DEFAULT 0");
      await addCol('broken_count', "INTEGER DEFAULT 0");
      await addCol('image_path', "TEXT DEFAULT ''");
    }
    
    if (oldVersion < 4) {
      // 🚨 Injecting the new feature safely for existing users
      await addCol('variety_mismatch', "INTEGER DEFAULT 0"); 
    }
  }

  /// 💾 ATOMIC INSERT: Guarantees the 100-limit cap without data corruption
  Future<int> insertScan(Map<String, dynamic> row) async {
    try {
      Database db = await instance.database;
      int insertedId = -1;
      
      // 🚨 NEW: PRE-SAVE TRACEABILITY CHECKER
      // This prints out to your terminal right before writing to the physical storage
      debugPrint("=====================================");
      debugPrint("🌍 DB PRE-SAVE -> GPS Coordinates: ${row['gps_location']}");
      debugPrint("🧠 DB PRE-SAVE -> Engine Version: ${row['model_version']}");
      debugPrint("=====================================");
      
      // 🛡️ Wrapping in a Transaction. If the app crashes halfway, it reverts safely.
      await db.transaction((txn) async {
        // 1. Insert the new scan
        insertedId = await txn.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);

        // 2. Self-Clean to maintain max 100 scans for Field Storage Health
        await txn.execute('''
          DELETE FROM $table 
          WHERE id NOT IN (
            SELECT id FROM $table ORDER BY timestamp DESC LIMIT 100
          )
        ''');
      });
      
      debugPrint("✅ Database: Saved Scan ID $insertedId (Transaction Complete)");
      return insertedId;
    } catch (e) {
      debugPrint("❌ Database Insert Failure: $e");
      return -1; 
    }
  }

  /// 📥 Retrieve all scans sorted by newest first
  Future<List<Map<String, dynamic>>> getScans() async {
    try {
      Database db = await instance.database;
      final List<Map<String, dynamic>> results = await db.query(table, orderBy: "timestamp DESC");
      debugPrint("📊 Database: Fetched ${results.length} records.");
      return results;
    } catch (e) {
      debugPrint("❌ Database Query Failure: $e");
      return [];
    }
  }

  /// 🗑️ Delete a single scan (Useful for the History Screen)
  Future<int> deleteScan(int id) async {
    try {
      Database db = await instance.database;
      return await db.delete(table, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint("❌ Database Delete Failure: $e");
      return 0;
    }
  }

  /// 🗑️ Clear all data (Useful for Admin testing)
  Future<void> clearDatabase() async {
    Database db = await instance.database;
    await db.delete(table);
  }
}