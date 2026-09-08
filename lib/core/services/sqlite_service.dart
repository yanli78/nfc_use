// database/card_database_helper.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:nfc_use/core/constants/card_item.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class CardDatabaseHelper {
  // 单例模式
  static final CardDatabaseHelper instance = CardDatabaseHelper._internal();
  factory CardDatabaseHelper() => instance;
  CardDatabaseHelper._internal();

  final ValueNotifier<int> cardsRevision = ValueNotifier<int>(0);

  // 数据库对象
  static Database? _database;
  // 数据库版本号（每次修改表结构时+1）
  static const int _databaseVersion = 4;
  // 数据库文件名
  static const String _databaseName = 'card_database.db';
  // 表名
  static const String _tableName = 'cards';

  // 获取数据库实例
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // 初始化数据库
  Future<Database> _initDatabase() async {
    // 获取应用文档目录
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);

    // 打开数据库（不存在则创建）
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // 创建表（首次创建数据库时调用）
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        color INTEGER NOT NULL,
        imageUrl TEXT NOT NULL,
        sortOrder INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 创建索引以提升排序和查询性能
    await db.execute('CREATE INDEX idx_sort_order ON $_tableName(sortOrder)');
  }

  // 数据库版本升级时调用
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE ${_tableName}_new (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          color INTEGER NOT NULL,
          imageUrl TEXT NOT NULL,
          sortOrder INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        INSERT INTO ${_tableName}_new (id, title, color, imageUrl, sortOrder)
        SELECT id, title, color, imageUrl, sortOrder FROM $_tableName
      ''');
      await db.execute('DROP TABLE $_tableName');
      await db.execute('ALTER TABLE ${_tableName}_new RENAME TO $_tableName');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sort_order ON $_tableName(sortOrder)',
      );
    }
    if (oldVersion >= 3 && oldVersion < 4) {
      await _rebuildCardsTableWithoutActionPath(db);
    }
  }

  Future<void> _rebuildCardsTableWithoutActionPath(Database db) async {
    await db.execute('''
      CREATE TABLE ${_tableName}_new (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        color INTEGER NOT NULL,
        imageUrl TEXT NOT NULL,
        sortOrder INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      INSERT INTO ${_tableName}_new (id, title, color, imageUrl, sortOrder)
      SELECT id, title, color, imageUrl, sortOrder FROM $_tableName
    ''');
    await db.execute('DROP TABLE $_tableName');
    await db.execute('ALTER TABLE ${_tableName}_new RENAME TO $_tableName');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sort_order ON $_tableName(sortOrder)',
    );
  }

  // -------------------------- 基础 CRUD 操作 --------------------------

  /// 插入单张卡片
  Future<int> insertCard(CardItem card) async {
    final db = await database;
    final result = await db.insert(
      _tableName,
      card.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace, // 主键冲突时替换
    );
    _notifyCardsChanged();
    return result;
  }

  /// 根据ID查询单张卡片
  Future<CardItem?> getCardById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return CardItem.fromMap(maps.first);
    }
    return null;
  }

  /// 查询所有卡片（按排序序号升序）
  Future<List<CardItem>> getAllCards() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'sortOrder ASC',
    );
    return List.generate(maps.length, (i) => CardItem.fromMap(maps[i]));
  }

  /// 更新卡片
  Future<int> updateCard(CardItem card) async {
    final db = await database;
    final result = await db.update(
      _tableName,
      card.toMap(),
      where: 'id = ?',
      whereArgs: [card.id],
    );
    _notifyCardsChanged();
    return result;
  }

  /// 根据ID删除卡片
  Future<int> deleteCard(String id) async {
    final db = await database;
    final result = await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyCardsChanged();
    return result;
  }

  /// 删除所有卡片
  Future<int> deleteAllCards() async {
    final db = await database;
    final result = await db.delete(_tableName);
    _notifyCardsChanged();
    return result;
  }

  // -------------------------- 扩展业务操作 --------------------------

  /// 批量插入卡片（事务处理，性能更高）
  Future<void> batchInsertCards(List<CardItem> cards) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var card in cards) {
        await txn.insert(
          _tableName,
          card.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    _notifyCardsChanged();
  }

  /// 分页查询卡片
  Future<List<CardItem>> getCardsPaginated({
    required int page,
    required int pageSize,
  }) async {
    final db = await database;
    final offset = (page - 1) * pageSize;
    final maps = await db.query(
      _tableName,
      orderBy: 'sortOrder ASC',
      limit: pageSize,
      offset: offset,
    );
    return List.generate(maps.length, (i) => CardItem.fromMap(maps[i]));
  }

  /// 搜索卡片（标题包含关键词）
  Future<List<CardItem>> searchCards(String keyword) async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      where: 'title LIKE ?',
      whereArgs: ['%$keyword%'],
      orderBy: 'sortOrder ASC',
    );
    return List.generate(maps.length, (i) => CardItem.fromMap(maps[i]));
  }

  /// 获取卡片总数
  Future<int> getCardCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM $_tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 批量更新卡片排序
  Future<void> updateCardOrders(List<CardItem> cards) async {
    final db = await database;
    await db.transaction((txn) async {
      for (int i = 0; i < cards.length; i++) {
        final card = cards[i].copyWith(sortOrder: i);
        await txn.update(
          _tableName,
          card.toMap(),
          where: 'id = ?',
          whereArgs: [card.id],
        );
      }
    });
    _notifyCardsChanged();
  }

  /// 获取最大排序序号（用于添加新卡片时自动排序）
  Future<int> getMaxSortOrder() async {
    final db = await database;
    final result = await db.rawQuery('SELECT MAX(sortOrder) FROM $_tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 关闭数据库（应用退出时调用）
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  void _notifyCardsChanged() {
    cardsRevision.value++;
  }
}
