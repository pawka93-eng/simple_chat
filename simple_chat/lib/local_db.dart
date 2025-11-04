import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Lokalna baza danych do:
/// - przechowywania listy czatów,
/// - przechowywania wiadomości,
/// - przechowywania "moich znajomych" (tych, których dodałem z Firestore).
class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'simple_chat.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // tabela czatów
        await db.execute('''
          CREATE TABLE chats (
            chat_id TEXT PRIMARY KEY,
            my_uid TEXT,
            peer_uid TEXT,
            peer_email TEXT,
            peer_nick TEXT,
            last_message TEXT,
            last_message_at INTEGER,
            unread_count INTEGER DEFAULT 0
          )
        ''');

        // tabela wiadomości
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            chat_id TEXT,
            from_uid TEXT,
            text TEXT,
            created_at INTEGER
          )
        ''');

        // tabela "moich" osób (lokalnie dodanych)
        await db.execute('''
          CREATE TABLE friends (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            owner_uid TEXT,      -- kto to dodał (ja)
            user_uid TEXT,       -- kogo dodałem
            email TEXT,
            nick TEXT
          )
        ''');
      },
    );
  }

  // ─────────────────────────────
  //  CZATY
  // ─────────────────────────────

  /// Zapisz lub zaktualizuj czat lokalnie.
  /// [chatId] – id dokumentu w Firestore (albo wygenerowane u Ciebie),
  /// [myUid] – mój UID,
  /// [peerUid] / [peerEmail] / [peerNick] – dane rozmówcy,
  /// [lastMessage] – ostatnia wiadomość,
  /// [lastMessageAt] – millisSinceEpoch,
  /// [unreadCount] – ile nieprzeczytanych (dla mnie).
  Future<void> insertOrUpdateChat({
    required String chatId,
    required String myUid,
    required String peerUid,
    required String peerEmail,
    required String peerNick,
    String lastMessage = '',
    int? lastMessageAt,
    int unreadCount = 0,
  }) async {
    final db = await _database;

    await db.insert(
      'chats',
      {
        'chat_id': chatId,
        'my_uid': myUid,
        'peer_uid': peerUid,
        'peer_email': peerEmail,
        'peer_nick': peerNick,
        'last_message': lastMessage,
        'last_message_at': lastMessageAt ?? DateTime.now().millisecondsSinceEpoch,
        'unread_count': unreadCount,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Pobierz wszystkie czaty, które należą do mnie.
  Future<List<Map<String, dynamic>>> getChats(String myUid) async {
    final db = await _database;
    return await db.query(
      'chats',
      where: 'my_uid = ?',
      whereArgs: [myUid],
      orderBy: 'last_message_at DESC',
    );
  }

  /// Ustaw nieprzeczytane na 0 dla danego czatu.
  Future<void> resetUnread(String chatId) async {
    final db = await _database;
    await db.update(
      'chats',
      {'unread_count': 0},
      where: 'chat_id = ?',
      whereArgs: [chatId],
    );
  }

  /// Zwiększ nieprzeczytane o 1 (użyteczne gdy przyjdzie wiadomość od kogoś).
  Future<void> incrementUnread(String chatId) async {
    final db = await _database;
    final rows = await db.query(
      'chats',
      columns: ['unread_count'],
      where: 'chat_id = ?',
      whereArgs: [chatId],
      limit: 1,
    );
    int current = 0;
    if (rows.isNotEmpty) {
      current = (rows.first['unread_count'] as int?) ?? 0;
    }
    await db.update(
      'chats',
      {'unread_count': current + 1},
      where: 'chat_id = ?',
      whereArgs: [chatId],
    );
  }

  // ─────────────────────────────
  //  WIADOMOŚCI
  // ─────────────────────────────

  Future<int> insertMessage({
    required String chatId,
    required String fromUid,
    required String text,
    int? createdAt,
  }) async {
    final db = await _database;
    return await db.insert('messages', {
      'chat_id': chatId,
      'from_uid': fromUid,
      'text': text,
      'created_at': createdAt ?? DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getMessages(String chatId) async {
    final db = await _database;
    return await db.query(
      'messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'created_at ASC',
    );
  }

  // ─────────────────────────────
  //  ZNAJOMI (lokalni)
  // ─────────────────────────────

  /// Zwraca TYLKO tych, których ja dodałem (owner_uid = myUid)
  Future<List<Map<String, dynamic>>> getFriends(String myUid) async {
    final db = await _database;
    return await db.query(
      'friends',
      where: 'owner_uid = ?',
      whereArgs: [myUid],
      orderBy: 'nick ASC',
    );
  }

  /// Dodaj lokalnie osobę, którą znalazłem w Firestore.
  Future<void> insertFriend({
    required String ownerUid,
    required String userUid,
    required String email,
    required String nick,
  }) async {
    final db = await _database;

    // unikniemy duplikatów:
    final existing = await db.query(
      'friends',
      where: 'owner_uid = ? AND user_uid = ?',
      whereArgs: [ownerUid, userUid],
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    await db.insert('friends', {
      'owner_uid': ownerUid,
      'user_uid': userUid,
      'email': email,
      'nick': nick,
    });
  }
}
