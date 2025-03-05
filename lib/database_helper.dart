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

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'card_organizer.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

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

    await _insertDefaultData(db);
  }

  Future _insertDefaultData(Database db) async {
    String now = DateTime.now().toIso8601String();
    List<String> folders = ['Hearts', 'Spades', 'Diamonds', 'Clubs'];
    List<String> suits = ['Hearts', 'Spades', 'Diamonds', 'Clubs'];
    List<String> ranks = ['Ace', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'Jack', 'Queen', 'King'];

    await Future.wait(folders.map((folder) => db.insert(folderTable, {
      'name': folder,
      'timestamp': now
    })));

    for (String suit in suits) {
      for (String rank in ranks) {
        String cardName = '$rank of $suit';
        String imageUrl = 'https://www.tekeye.uk/playing_cards/images/svg_playing_cards/fronts/${suit.toLowerCase()}_${rank.toLowerCase()}.svg';
        await db.insert(cardTable, {
          'name': cardName,
          'suit': suit,
          'imageUrl': imageUrl,
          'folderId': null,
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _query(String table, {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    return await db.query(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> getFolders() => _query(folderTable);

  Future<List<Map<String, dynamic>>> getCardsInFolder(int folderId) =>
      _query(cardTable, where: 'folderId = ?', whereArgs: [folderId]);

  Future<List<Map<String, dynamic>>> getAvailableCardsBySuit(String suit) =>
      _query(cardTable, where: 'suit = ? AND folderId IS NULL', whereArgs: [suit]);

  Future<int> addCardToFolder(int cardId, int folderId) async {
    int count = await getCardCountInFolder(folderId);
    if (count >= 6) return -1;

    final db = await database;
    return await db.update(
      cardTable,
      {'folderId': folderId},
      where: 'id = ?',
      whereArgs: [cardId],
    );
  }

  Future<int> removeCardFromFolder(int cardId) async {
    final db = await database;
    return await db.update(
      cardTable,
      {'folderId': null},
      where: 'id = ?',
      whereArgs: [cardId],
    );
  }

  Future<int> getCardCountInFolder(int folderId) async {
    final db = await database;
    return Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM $cardTable WHERE folderId = ?',
      [folderId],
    )) ?? 0;
  }

  Future<String> getFirstCardImage(int folderId) async {
    final db = await database;
    final result = await db.query('cards', where: 'folderId = ?', whereArgs: [folderId], limit: 1);
    if (result.isNotEmpty) {
      return result.first['imageUrl'] as String;
    }
    return ''; 
  }
}