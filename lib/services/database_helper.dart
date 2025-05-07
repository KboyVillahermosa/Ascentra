import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/user.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String path = join(documentsDirectory.path, 'user_database.db');
      
      return await openDatabase(
        path,
        version: 2, // Increased version for schema update
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      print('Database initialization error: $e');
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT,
        photoUrl TEXT,
        authProvider TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns for Google authentication
      await db.execute('ALTER TABLE users ADD COLUMN photoUrl TEXT');
      await db.execute('ALTER TABLE users ADD COLUMN authProvider TEXT DEFAULT "email"');
      // Make password nullable
      await db.execute('ALTER TABLE users RENAME TO temp_users');
      await db.execute('''
        CREATE TABLE users(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL,
          email TEXT UNIQUE NOT NULL,
          password TEXT,
          photoUrl TEXT,
          authProvider TEXT NOT NULL
        )
      ''');
      await db.execute('''
        INSERT INTO users (id, username, email, password, authProvider)
        SELECT id, username, email, password, "email" FROM temp_users
      ''');
      await db.execute('DROP TABLE temp_users');
    }
  }

  Future<User?> getUserByEmail(String email) async {
    try {
      Database db = await database;
      List<Map<String, dynamic>> results = await db.query(
        'users',
        where: 'email = ?',
        whereArgs: [email],
      );

      if (results.isNotEmpty) {
        return User.fromMap(results.first);
      }
      return null;
    } catch (e) {
      print('Error getting user by email: $e');
      return null;
    }
  }

  Future<int> insertOrUpdateGoogleUser(User user) async {
    try {
      Database db = await database;
      // Check if user with this email already exists
      User? existingUser = await getUserByEmail(user.email);
      
      if (existingUser != null) {
        // Update existing user
        await db.update(
          'users',
          {
            'username': user.username,
            'photoUrl': user.photoUrl,
            'authProvider': 'google',
          },
          where: 'email = ?',
          whereArgs: [user.email],
        );
        return existingUser.id!;
      } else {
        // Insert new user
        return await db.insert('users', user.toMap());
      }
    } catch (e) {
      print('Error inserting/updating Google user: $e');
      return -1;
    }
  }

  // Keep existing methods for email-based login
  Future<int> insertUser(User user) async {
    try {
      Database db = await database;
      
      // Check if email already exists
      List<Map<String, dynamic>> result = await db.query(
        'users',
        where: 'email = ?',
        whereArgs: [user.email],
      );
      
      if (result.isNotEmpty) {
        return -1; // Email already exists
      }
      
      return await db.insert('users', user.toMap());
    } catch (e) {
      print('Error inserting user: $e');
      return -2;
    }
  }

  Future<User?> getUser(String email, String password) async {
    try {
      Database db = await database;
      List<Map<String, dynamic>> results = await db.query(
        'users',
        where: 'email = ? AND password = ?',
        whereArgs: [email, password],
      );

      if (results.isNotEmpty) {
        return User.fromMap(results.first);
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }
}