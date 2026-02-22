// lib/services/database_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../core/constants/app_constants.dart';
import '../data/models/minutiae_record_model.dart';
import '../data/models/palm_session_model.dart';
import '../domain/entities/minutiae_record.dart';
import '../domain/entities/palm_session.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);
    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Palm sessions table
    await db.execute('''
      CREATE TABLE ${AppConstants.tableSessions} (
        id TEXT PRIMARY KEY,
        device_id TEXT NOT NULL,
        hand_side TEXT NOT NULL,
        palm_image_path TEXT NOT NULL,
        palm_minutiae_points TEXT NOT NULL,
        palm_perceptual_hash TEXT NOT NULL,
        palm_histogram_signature TEXT NOT NULL,
        blur_score REAL NOT NULL,
        brightness_score REAL NOT NULL,
        focus_distance REAL NOT NULL,
        captured_at INTEGER NOT NULL,
        is_dorsal_side INTEGER DEFAULT 0
      )
    ''');

    // Minutiae records table
    await db.execute('''
      CREATE TABLE ${AppConstants.tableMinutiae} (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        hand_side TEXT NOT NULL,
        finger_name TEXT NOT NULL,
        image_path TEXT NOT NULL,
        minutiae_points TEXT NOT NULL,
        perceptual_hash TEXT NOT NULL,
        histogram_signature TEXT NOT NULL,
        blur_score REAL NOT NULL,
        brightness_score REAL NOT NULL,
        focus_distance REAL NOT NULL,
        captured_at INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES ${AppConstants.tableSessions}(id)
      )
    ''');

    // Luminosity records table
    await db.execute('''
      CREATE TABLE ${AppConstants.tableLuminosity} (
        id TEXT PRIMARY KEY,
        device_id TEXT NOT NULL,
        brightness_score REAL NOT NULL,
        light_condition TEXT NOT NULL,
        camera_type TEXT NOT NULL,
        focal_length REAL NOT NULL,
        aperture_score REAL NOT NULL,
        focus_distance REAL NOT NULL,
        blur_score REAL NOT NULL,
        recorded_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future migrations
  }

  // ─── SESSIONS ──────────────────────────────────────────────────────────────

  Future<void> insertSession(PalmSession session) async {
    final db = await database;
    final model = PalmSessionModel.fromEntity(session);
    await db.insert(
      AppConstants.tableSessions,
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<PalmSession?> getSessionById(String id) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.tableSessions,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return PalmSessionModel.fromMap(maps.first);
  }

  Future<List<PalmSession>> getSessionsByDeviceId(String deviceId) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.tableSessions,
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'captured_at DESC',
    );
    return maps.map((m) => PalmSessionModel.fromMap(m)).toList();
  }

  // ─── MINUTIAE ──────────────────────────────────────────────────────────────

  Future<void> insertMinutiae(MinutiaeRecord record) async {
    final db = await database;
    final model = MinutiaeRecordModel.fromEntity(record);
    await db.insert(
      AppConstants.tableMinutiae,
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MinutiaeRecord>> getMinutiaeBySession(String sessionId) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.tableMinutiae,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'captured_at ASC',
    );
    return maps.map((m) => MinutiaeRecordModel.fromMap(m)).toList();
  }

  // ─── LUMINOSITY ────────────────────────────────────────────────────────────

  Future<void> insertLuminosity(Map<String, dynamic> record) async {
    final db = await database;
    await db.insert(
      AppConstants.tableLuminosity,
      record,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getLuminosityByDevice(String deviceId) async {
    final db = await database;
    return db.query(
      AppConstants.tableLuminosity,
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'recorded_at DESC',
    );
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
