import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  // Factory constructor to return the same instance
  factory DatabaseHelper() {
    return _instance;
  }

  // Private constructor
  DatabaseHelper._internal();

  // Getter for the database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize database
  Future<Database> _initDatabase() async {
    String path = await getDatabasePath();
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<String> getDatabasePath() async {
    return join(await getDatabasesPath(), 'ascentra.db');
  }

  // Create database tables
  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        date TEXT NOT NULL,
        duration_seconds INTEGER NOT NULL,
        distance REAL NOT NULL,
        elevation_gain REAL NOT NULL,
        avg_pace TEXT NOT NULL,
        route_points TEXT NOT NULL,
        description TEXT,
        activity_type TEXT,
        feeling TEXT,
        private_notes TEXT,
        liked_by TEXT
      )
    ''');
    
    // Add any other tables you need here
  }
}