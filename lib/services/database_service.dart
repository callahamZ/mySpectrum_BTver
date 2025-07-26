import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' as io;
import 'dart:convert';

class DatabaseHelper {
  static const _databaseName = "SpectrumData.db";
  static const _databaseVersion = 1;
  static const table = 'measurements';
  static const columnId = 'id';
  static const columnTimestamp = 'timestamp';
  static const columnSpectrumData = 'spectrumData';
  static const columnTemperature = 'temperature';
  static const columnLux = 'lux';
  // static const columnFirebaseData = 'firebaseData'; // REMOVED

  Future<List<Map<String, dynamic>>> getAllMeasurements() async {
    Database db = await instance.database;
    return await db.query(table);
  }

  Future<int> deleteMeasurement(int id) async {
    Database db = await instance.database;
    return await db.delete(table, where: '$columnId = ?', whereArgs: [id]);
  }

  // Add this function to delete all measurements
  Future<int> deleteAllMeasurements() async {
    Database db = await instance.database;
    return await db.delete(table);
  }

  // Make this a singleton class.
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // Only have a single app-wide reference to the database.
  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    // Lazily instantiate the database the first time it is accessed.
    _database = await _initDatabase();
    return _database!;
  }

  // This opens the database (and creates it if it doesn't exist).
  Future<Database> _initDatabase() async {
    io.Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  // SQL code to create the database table.
  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnTimestamp TEXT NOT NULL,
        $columnSpectrumData TEXT,
        $columnTemperature REAL,
        $columnLux REAL
      )
    ''');
  }

  // Helper method to insert a measurement.
  Future<int> insertMeasurement({
    required DateTime timestamp,
    List<double>? spectrumData,
    double? temperature,
    double? lux,
    // Map<String, dynamic>? firebaseData, // REMOVED
  }) async {
    Database db = await instance.database;
    return await db.insert(table, {
      columnTimestamp: timestamp.toIso8601String(),
      columnSpectrumData: spectrumData?.join(','),
      columnTemperature: temperature,
      columnLux: lux,
      // columnFirebaseData: firebaseData != null ? jsonEncode(firebaseData) : null, // REMOVED
    });
  }

  // New method to get the latest measurement
  Future<Map<String, dynamic>?> getLatestMeasurement() async {
    Database db = await instance.database;
    List<Map<String, dynamic>> result = await db.query(
      table,
      orderBy:
          '$columnTimestamp DESC', // Order by timestamp in descending order
      limit: 1, // Get only the latest one
    );
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }
}
