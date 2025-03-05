import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  // Tables
  final String folderTable = 'folders';
  final String cardTable = 'cards';

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get _db async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'card_organizer.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  // Create tables
  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $folderTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $cardTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        suit TEXT NOT NULL,
        imageUrl TEXT NOT NULL,
        folderId INTEGER
      )
    ''');
  }

  // Get all folders
  Future<List<Map<String, dynamic>>> getFolders() async {
    final db = await _db;
    return await db.query(folderTable);
  }

  // Get cards in a folder
  Future<List<Map<String, dynamic>>> getCardsInFolder(int folderId) async {
    final db = await _db;
    return await db.query(cardTable, where: 'folderId = ?', whereArgs: [folderId]);
  }

  // Get available cards by suit (not in any folder)
  Future<List<Map<String, dynamic>>> getAvailableCardsBySuit(String suit) async {
    final db = await _db;
    return await db.query(cardTable, where: 'suit = ? AND folderId IS NULL', whereArgs: [suit]);
  }

  // Add card to folder (with a limit of 6 cards per folder)
  Future<int> addCardToFolder(int cardId, int folderId) async {
    if (await getCardCountInFolder(folderId) >= 6) return -1;  // Folder full
    final db = await _db;
    return await db.update(cardTable, {'folderId': folderId}, where: 'id = ?', whereArgs: [cardId]);
  }

  // Remove card from folder
  Future<int> removeCardFromFolder(int cardId) async {
    final db = await _db;
    return await db.update(cardTable, {'folderId': null}, where: 'id = ?', whereArgs: [cardId]);
  }

  // Get card count in folder
  Future<int> getCardCountInFolder(int folderId) async {
    final db = await _db;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $cardTable WHERE folderId = ?', [folderId])) ?? 0;
  }

  // Get the first card image in the folder
  Future<String> getFirstCardImage(int folderId) async {
    final db = await _db;
    final result = await db.query(cardTable, where: 'folderId = ?', whereArgs: [folderId], limit: 1);
    return result.isNotEmpty ? result.first['imageUrl'] as String : '';  // Return empty string if no card found
  }
}
