import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:nfc_use/core/constants/card_item.dart';
import 'package:nfc_use/core/services/sqlite_service.dart';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';

class CardImportService {
  CardImportService._();

  static final CardImportService instance = CardImportService._();

  static const Set<String> _imageExtensions = {
    '.png',
    '.jpg',
    '.jpeg',
    '.webp',
  };

  Future<CardImportResult> importFromZip(String zipFilePath) async {
    final zipFile = File(zipFilePath);
    if (!await zipFile.exists()) {
      return const CardImportResult(success: false, message: 'ZIP 文件不存在');
    }

    late Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());
    } catch (error) {
      return CardImportResult(
        success: false,
        message: 'ZIP 解析失败，请确认文件未损坏',
        error: error,
      );
    }

    final configEntry = _findConfigEntry(archive);
    if (configEntry == null) {
      return const CardImportResult(success: false, message: '未找到 config.json');
    }

    late Map<String, dynamic> config;
    try {
      config =
          jsonDecode(utf8.decode(configEntry.content as List<int>))
              as Map<String, dynamic>;
    } catch (error) {
      return CardImportResult(
        success: false,
        message: 'config.json 格式不正确',
        error: error,
      );
    }

    final modules = config['modules'];
    if (modules is! List || modules.isEmpty) {
      return const CardImportResult(
        success: false,
        message: 'config.json 中没有可导入的 modules',
      );
    }

    final importDir = await _createImportDir(zipFilePath);
    final maxSortOrder = await CardDatabaseHelper.instance.getMaxSortOrder();
    final cards = <CardItem>[];
    final warnings = <String>[];

    for (final item in modules) {
      if (item is! Map<String, dynamic>) {
        warnings.add('跳过一条无效模块配置');
        continue;
      }

      final character = (item['character'] as String? ?? '').trim();
      final name = (item['name'] as String? ?? '').trim();
      final colorText = (item['color'] as String? ?? '').trim();

      if (character.isEmpty || name.isEmpty) {
        warnings.add('跳过一条缺少 character/name 的模块配置');
        continue;
      }

      final imageEntry = _findImageEntry(archive, character);
      var imagePath = kCardPlaceholderImageUrl;
      if (imageEntry != null) {
        final extension = path_lib.extension(imageEntry.name).toLowerCase();
        final fileName = '${_safeFileName(character)}$extension';
        final imageFile = File(path_lib.join(importDir.path, fileName));
        await imageFile.writeAsBytes(imageEntry.content as List<int>);
        imagePath = imageFile.path;
      } else {
        warnings.add('$character 未找到对应图片，已使用占位图');
      }

      cards.add(
        CardItem(
          id: character,
          title: name,
          color: _parseColor(colorText),
          imageUrl: imagePath,
          sortOrder: maxSortOrder + cards.length + 1,
        ),
      );
    }

    if (cards.isEmpty) {
      return CardImportResult(
        success: false,
        message: '没有导入任何卡片',
        warnings: warnings,
      );
    }

    await CardDatabaseHelper.instance.batchInsertCards(cards);

    return CardImportResult(
      success: true,
      message: '导入完成，共导入 ${cards.length} 张卡片',
      importedCount: cards.length,
      version: config['version'] as String?,
      warnings: warnings,
    );
  }

  Future<void> clearImportedAssets() async {
    final documents = await getApplicationDocumentsDirectory();
    final dir = Directory(path_lib.join(documents.path, 'imported_cards'));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  ArchiveFile? _findConfigEntry(Archive archive) {
    final files =
        archive.files.where((file) {
          return file.isFile &&
              _normalizeArchivePath(file.name).split('/').last.toLowerCase() ==
                  'config.json';
        }).toList()..sort(
          (a, b) => _pathDepth(a.name).compareTo(_pathDepth(b.name)),
        );
    return files.isEmpty ? null : files.first;
  }

  ArchiveFile? _findImageEntry(Archive archive, String character) {
    final expectedName = character.toLowerCase();
    final files =
        archive.files.where((file) {
            if (!file.isFile) return false;
            final normalized = _normalizeArchivePath(file.name).toLowerCase();
            final extension = path_lib.extension(normalized);
            if (!_imageExtensions.contains(extension)) return false;
            final baseName = path_lib.basenameWithoutExtension(normalized);
            return baseName == expectedName &&
                normalized.split('/').contains('resources');
          }).toList()
          ..sort((a, b) => _pathDepth(a.name).compareTo(_pathDepth(b.name)));

    if (files.isNotEmpty) return files.first;

    final fallbackFiles =
        archive.files.where((file) {
            if (!file.isFile) return false;
            final normalized = _normalizeArchivePath(file.name).toLowerCase();
            return _imageExtensions.contains(path_lib.extension(normalized)) &&
                path_lib.basenameWithoutExtension(normalized) == expectedName;
          }).toList()
          ..sort((a, b) => _pathDepth(a.name).compareTo(_pathDepth(b.name)));

    return fallbackFiles.isEmpty ? null : fallbackFiles.first;
  }

  Future<Directory> _createImportDir(String zipFilePath) async {
    final documents = await getApplicationDocumentsDirectory();
    final zipName = path_lib.basenameWithoutExtension(zipFilePath);
    final dir = Directory(
      path_lib.join(
        documents.path,
        'imported_cards',
        '${_safeFileName(zipName)}-${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    return dir.create(recursive: true);
  }

  Color _parseColor(String value) {
    final clean = value.replaceFirst('#', '').trim();
    try {
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
      if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
    } catch (_) {}
    return kCardDefaultColors['tech']!;
  }

  int _pathDepth(String path) => _normalizeArchivePath(path).split('/').length;

  String _normalizeArchivePath(String path) => path.replaceAll('\\', '/');

  String _safeFileName(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  }
}

class CardImportResult {
  final bool success;
  final String message;
  final int importedCount;
  final String? version;
  final List<String> warnings;
  final Object? error;

  const CardImportResult({
    required this.success,
    required this.message,
    this.importedCount = 0,
    this.version,
    this.warnings = const [],
    this.error,
  });
}
