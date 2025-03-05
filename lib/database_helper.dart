import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  // Tables
  final String folderTable = 'folders';
  final String cardTable = 'cards';

  // Singleton constructor
  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'card_organizer.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future _onCreate(Database db, int version) async {
    // Create folders table
    await db.execute('''
      CREATE TABLE $folderTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    // Create cards table
    await db.execute('''
      CREATE TABLE $cardTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        suit TEXT NOT NULL,
        imageUrl TEXT NOT NULL,
        folderId INTEGER
      )
    ''');

    // Insert default folders
    await _insertDefaultFolders(db);
    
    // Insert default cards
    await _insertDefaultCards(db);
  }

  Future _insertDefaultFolders(Database db) async {
    String now = DateTime.now().toIso8601String();
    List<String> folders = ['Hearts', 'Spades', 'Diamonds', 'Clubs'];
    
    for (String folder in folders) {
      await db.insert(folderTable, {
        'name': folder,
        'timestamp': now
      });
    }
  }

  Future _insertDefaultCards(Database db) async {
    List<String> suits = ['Hearts', 'Spades', 'Diamonds', 'Clubs'];
    List<String> ranks = ['Ace', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'Jack', 'Queen', 'King'];

    for (String suit in suits) {
      for (String rank in ranks) {
        String cardName = '$rank of $suit';
        // Simple image URL based on card name
        String imageUrl = 'https://example.com/cards/${suit.toLowerCase()}/${rank.toLowerCase()}.png';
        
        await db.insert(cardTable, {
          'name': cardName,
          'suit': suit,
          'imageUrl': imageUrl,
          'folderId': null  // Initially not in any folder
        });
      }
    }
  }

  // Get all folders
  Future<List<Map<String, dynamic>>> getFolders() async {
    Database db = await database;
    return await db.query(folderTable);
  }

  // Get cards in a folder
  Future<List<Map<String, dynamic>>> getCardsInFolder(int folderId) async {
    Database db = await database;
    return await db.query(
      cardTable,
      where: 'folderId = ?',
      whereArgs: [folderId]
    );
  }

  // Get cards by suit not in any folder
  Future<List<Map<String, dynamic>>> getAvailableCardsBySuit(String suit) async {
    Database db = await database;
    return await db.query(
      cardTable,
      where: 'suit = ? AND folderId IS NULL',
      whereArgs: [suit]
    );
  }

  // Add card to folder
  Future<int> addCardToFolder(int cardId, int folderId) async {
    // Check card count in folder
    Database db = await database;
    int count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM $cardTable WHERE folderId = ?',
      [folderId]
    )) ?? 0;
    
    if (count >= 6) {
      return -1;  // Folder full
    }
    
    return await db.update(
      cardTable,
      {'folderId': folderId},
      where: 'id = ?',
      whereArgs: [cardId]
    );
  }

  // Remove card from folder
  Future<int> removeCardFromFolder(int cardId) async {
    Database db = await database;
    return await db.update(
      cardTable,
      {'folderId': null},
      where: 'id = ?',
      whereArgs: [cardId]
    );
  }

  // Get card count in folder
  Future<int> getCardCountInFolder(int folderId) async {
    Database db = await database;
    return Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM $cardTable WHERE folderId = ?',
      [folderId]
    )) ?? 0;
  }
} 