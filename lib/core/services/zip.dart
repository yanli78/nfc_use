import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';

/// 压缩文件服务类
///
/// 提供文件选择和解压功能，支持主流压缩格式（ZIP）。
///
/// 主要功能：
/// - [pickFile] - 调用文件管理器选择文件
/// - [extractZip] - 解压ZIP文件到指定目录
/// - [extractZipToDefaultDir] - 解压ZIP文件到默认位置（内部存储/nfc_use）
/// - [getDefaultExtractDir] - 获取默认解压目录路径
///
/// 默认解压位置：
/// - Android: /storage/emulated/0/nfc_use/
/// - iOS: Documents/nfc_use/
///
/// 依赖的库：
/// - `archive` - ZIP解压核心处理
/// - `path` - 文件路径处理
/// - `path_provider` - 获取设备目录路径
/// - `file_picker` - 文件选择器（通过 [FilePickerService] 接口抽象）
///
/// 错误类型：
/// - [ZipErrorType.fileNotFound] - 文件不存在
/// - [ZipErrorType.invalidFormat] - 无效的压缩格式
/// - [ZipErrorType.fileCorrupted] - 文件损坏
/// - [ZipErrorType.permissionDenied] - 权限不足
/// - [ZipErrorType.extractFailed] - 解压失败
/// - [ZipErrorType.canceled] - 用户取消选择
class ZipService {
  ZipService._();

  static final ZipService instance = ZipService._();

  /// 文件选择服务接口
  FilePickerService? _filePickerService;

  /// 默认解压目录名称
  static const String _defaultDirName = 'nfc_use';

  /// 设置文件选择服务实现
  ///
  /// 在使用 [pickFile] 之前需要设置文件选择服务实现，
  /// 通常在应用启动时初始化。
  void setFilePickerService(FilePickerService service) {
    _filePickerService = service;
  }

  /// 获取默认解压目录路径
  ///
  /// 返回内部存储根目录下的 "nfc_use" 文件夹路径：
  /// - Android: /storage/emulated/0/nfc_use
  /// - iOS: &lt;Documents&gt;/nfc_use
  ///
  /// 如果无法获取目录路径，返回 null
  Future<String?> getDefaultExtractDir() async {
    try {
      Directory? externalDir;
      if (Platform.isAndroid) {
        externalDir = await getExternalStorageDirectory();
      } else if (Platform.isIOS) {
        externalDir = await getApplicationDocumentsDirectory();
      }

      if (externalDir == null) return null;

      // Android: /storage/emulated/0/Android/data/com.example.nfc_use/files
      // 需要向上导航到根目录
      String basePath = externalDir.path;
      if (Platform.isAndroid) {
        // 移除 Android/data/包名/files 部分
        final parts = basePath.split(Platform.pathSeparator);
        final androidIndex = parts.indexOf('Android');
        if (androidIndex > 0) {
          basePath = parts.sublist(0, androidIndex).join(Platform.pathSeparator);
        }
      }

      return path_lib.join(basePath, _defaultDirName);
    } catch (_) {
      return null;
    }
  }

  /// 确保默认解压目录存在
  ///
  /// 如果目录不存在则自动创建，返回目录路径。
  /// 如果创建失败（权限不足等），返回 null。
  Future<String?> ensureDefaultDirExists() async {
    final dirPath = await getDefaultExtractDir();
    if (dirPath == null) return null;

    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dirPath;
    } catch (_) {
      return null;
    }
  }

  /// 选择文件
  ///
  /// 调用设备文件管理器，允许用户选择文件。
  /// 支持指定允许的文件扩展名列表进行过滤。
  ///
  /// [allowedExtensions] 允许选择的文件扩展名列表，如 ['zip', 'rar']
  /// 返回选中文件的完整路径，如果用户取消选择则返回 null
  ///
  /// 抛出 [ZipException]：
  /// - [ZipErrorType.canceled] - 用户取消选择
  /// - [ZipErrorType.permissionDenied] - 权限不足
  /// - [ZipErrorType.extractFailed] - 文件选择器未初始化或其他错误
  Future<String?> pickFile({List<String>? allowedExtensions}) async {
    if (_filePickerService == null) {
      throw const ZipException(
        type: ZipErrorType.extractFailed,
        message: '文件选择器服务未初始化，请先调用 setFilePickerService',
      );
    }

    try {
      final result = await _filePickerService!.pickFile(
        allowedExtensions: allowedExtensions,
      );

      if (result == null) {
        throw const ZipException(
          type: ZipErrorType.canceled,
          message: '用户取消选择文件',
        );
      }

      return result;
    } on PermissionDeniedException {
      throw const ZipException(
        type: ZipErrorType.permissionDenied,
        message: '文件访问权限不足',
      );
    } catch (error) {
      throw ZipException(
        type: ZipErrorType.extractFailed,
        message: '文件选择失败：$error',
        error: error,
      );
    }
  }

  /// 选择压缩文件
  ///
  /// 调用文件管理器，仅允许选择ZIP格式的文件。
  ///
  /// 返回选中的ZIP文件完整路径，如果用户取消选择则返回 null
  Future<String?> pickZipFile() {
    return pickFile(allowedExtensions: ['zip']);
  }

  /// 解压ZIP文件到指定目录
  ///
  /// 将指定的ZIP文件解压到目标目录。
  /// 支持进度反馈和完成状态回调。
  ///
  /// [zipFilePath] ZIP文件的完整路径
  /// [destDirPath] 解压目标目录路径
  /// [onProgress] 解压进度回调，参数为进度百分比（0-100）
  /// [onComplete] 解压完成回调，参数为解压结果
  ///
  /// 返回 [ExtractResult] 对象，包含解压状态和详细信息
  Future<ExtractResult> extractZip(
    String zipFilePath,
    String destDirPath, {
    void Function(int progress)? onProgress,
    void Function(ExtractResult result)? onComplete,
  }) async {
    try {
      // 1. 验证文件存在
      final zipFile = File(zipFilePath);
      if (!await zipFile.exists()) {
        final result = ExtractResult(
          success: false,
          errorType: ZipErrorType.fileNotFound,
          message: 'ZIP文件不存在: $zipFilePath',
        );
        onComplete?.call(result);
        return result;
      }

      // 2. 创建目标目录
      final destDir = Directory(destDirPath);
      if (!await destDir.exists()) {
        try {
          await destDir.create(recursive: true);
        } catch (error) {
          final result = ExtractResult(
            success: false,
            errorType: ZipErrorType.permissionDenied,
            message: '无法创建目标目录：$error',
          );
          onComplete?.call(result);
          return result;
        }
      }

      // 3. 读取并解析ZIP文件
      late Archive archive;
      try {
        final bytes = await zipFile.readAsBytes();
        archive = ZipDecoder().decodeBytes(bytes);
      } catch (error) {
        final result = ExtractResult(
          success: false,
          errorType: ZipErrorType.fileCorrupted,
          message: 'ZIP文件解析失败，文件可能已损坏：$error',
        );
        onComplete?.call(result);
        return result;
      }

      if (archive.isEmpty) {
        final result = ExtractResult(
          success: false,
          errorType: ZipErrorType.invalidFormat,
          message: 'ZIP文件为空或格式无效',
        );
        onComplete?.call(result);
        return result;
      }

      // 4. 解压文件
      final totalFiles = archive.length;
      int extractedCount = 0;

      for (final file in archive) {
        final filePath = path_lib.join(destDirPath, file.name);

        // 跳过目录（通过文件名末尾是否有斜杠判断）
        if (file.name.endsWith('/')) {
          await Directory(filePath).create(recursive: true);
          extractedCount++;
          onProgress?.call((extractedCount * 100) ~/ totalFiles);
          continue;
        }

        // 确保父目录存在
        final parentDir = Directory(path_lib.dirname(filePath));
        if (!await parentDir.exists()) {
          await parentDir.create(recursive: true);
        }

        // 写入文件
        try {
          await File(filePath).writeAsBytes(file.content as List<int>);
        } catch (error) {
          final result = ExtractResult(
            success: false,
            errorType: ZipErrorType.extractFailed,
            message: '解压文件失败: ${file.name} - $error',
            extractedFiles: extractedCount,
            totalFiles: totalFiles,
          );
          onComplete?.call(result);
          return result;
        }

        extractedCount++;
        onProgress?.call((extractedCount * 100) ~/ totalFiles);
      }

      // 5. 验证解压结果
      final verifyResult = await _verifyExtraction(destDirPath, totalFiles);

      if (verifyResult.success) {
        final result = ExtractResult(
          success: true,
          message: '解压完成，共解压 $extractedCount 个文件',
          extractedFiles: extractedCount,
          totalFiles: totalFiles,
          destDirPath: destDirPath,
        );
        onComplete?.call(result);
        return result;
      } else {
        final result = ExtractResult(
          success: false,
          errorType: ZipErrorType.extractFailed,
          message: verifyResult.message,
          extractedFiles: extractedCount,
          totalFiles: totalFiles,
          destDirPath: destDirPath,
        );
        onComplete?.call(result);
        return result;
      }

    } catch (error) {
      final result = ExtractResult(
        success: false,
        errorType: ZipErrorType.extractFailed,
        message: '解压过程发生错误：$error',
        error: error,
      );
      onComplete?.call(result);
      return result;
    }
  }

  /// 解压ZIP文件到默认目录
  ///
  /// 将指定的ZIP文件解压到内部存储根目录下的 "nfc_use" 文件夹。
  /// 自动检测并创建目录（若不存在）。
  ///
  /// 默认路径：
  /// - Android: /storage/emulated/0/nfc_use/
  /// - iOS: &lt;Documents&gt;/nfc_use/
  ///
  /// [zipFilePath] ZIP文件的完整路径
  /// [onProgress] 解压进度回调，参数为进度百分比（0-100）
  /// [onComplete] 解压完成回调，参数为解压结果
  ///
  /// 返回 [ExtractResult] 对象，包含解压状态和详细信息
  Future<ExtractResult> extractZipToDefaultDir(
    String zipFilePath, {
    void Function(int progress)? onProgress,
    void Function(ExtractResult result)? onComplete,
  }) async {
    // 1. 获取并确保默认目录存在
    final destDirPath = await ensureDefaultDirExists();
    if (destDirPath == null) {
      final result = ExtractResult(
        success: false,
        errorType: ZipErrorType.permissionDenied,
        message: '无法获取或创建默认解压目录',
      );
      onComplete?.call(result);
      return result;
    }

    // 2. 使用文件名创建子目录，避免文件冲突
    final zipFileName = path_lib.basenameWithoutExtension(zipFilePath);
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final finalDestPath = path_lib.join(destDirPath, '$zipFileName-$timestamp');

    // 3. 执行解压
    return extractZip(
      zipFilePath,
      finalDestPath,
      onProgress: onProgress,
      onComplete: onComplete,
    );
  }

  /// 验证解压结果的完整性
  ///
  /// 检查解压目录中文件数量是否与预期一致。
  Future<ExtractResult> _verifyExtraction(String destDirPath, int expectedCount) async {
    try {
      final dir = Directory(destDirPath);
      if (!await dir.exists()) {
        return ExtractResult(
          success: false,
          errorType: ZipErrorType.extractFailed,
          message: '解压目录不存在',
        );
      }

      final files = await dir.list(recursive: true).toList();
      final fileCount = files.whereType<File>().length;

      if (fileCount == 0 && expectedCount > 0) {
        return ExtractResult(
          success: false,
          errorType: ZipErrorType.extractFailed,
          message: '解压目录为空',
        );
      }

      return ExtractResult(
        success: true,
        message: '验证通过，解压目录中共有 $fileCount 个文件',
        extractedFiles: fileCount,
        totalFiles: expectedCount,
        destDirPath: destDirPath,
      );
    } catch (error) {
      return ExtractResult(
        success: false,
        errorType: ZipErrorType.extractFailed,
        message: '验证解压结果失败：$error',
      );
    }
  }

  /// 列出默认解压目录下的所有文件
  ///
  /// 返回文件列表，如果目录不存在或无权限则返回空列表。
  Future<List<FileInfo>> listDefaultDirFiles() async {
    final dirPath = await getDefaultExtractDir();
    if (dirPath == null) return [];

    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return [];

      final files = await dir.list(recursive: true).toList();
      return files.whereType<File>().map((file) {
        return FileInfo(
          path: file.path,
          name: path_lib.basename(file.path),
          size: file.lengthSync(),
          lastModified: file.lastModifiedSync(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// 获取默认解压目录的空间使用情况
  ///
  /// 返回目录的总大小（字节），如果目录不存在则返回 0。
  Future<int> getDefaultDirSize() async {
    final dirPath = await getDefaultExtractDir();
    if (dirPath == null) return 0;

    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return 0;

      int totalSize = 0;
      await for (final file in dir.list(recursive: true)) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      return totalSize;
    } catch (_) {
      return 0;
    }
  }

  /// 删除默认解压目录下的指定文件
  ///
  /// [filePath] 要删除的文件完整路径
  /// 返回 true 如果删除成功
  Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 清空默认解压目录
  ///
  /// 删除 "nfc_use" 目录下的所有内容（保留目录本身）。
  /// 返回 true 如果清空成功。
  Future<bool> clearDefaultDir() async {
    final dirPath = await getDefaultExtractDir();
    if (dirPath == null) return false;

    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return true;

      await for (final entity in dir.list()) {
        if (entity is File) {
          await entity.delete();
        } else if (entity is Directory) {
          await entity.delete(recursive: true);
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 验证路径是否为有效的ZIP文件
  ///
  /// [filePath] 文件路径
  /// 返回 true 如果文件存在且扩展名是 zip
  Future<bool> isValidZipFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return false;

    final extension = path_lib.extension(filePath).toLowerCase();
    return extension == '.zip';
  }

  /// 获取ZIP文件中的文件列表
  ///
  /// [zipFilePath] ZIP文件路径
  /// 返回文件列表，如果解析失败则返回空列表
  Future<List<ArchiveFileInfo>> getZipFileList(String zipFilePath) async {
    try {
      final zipFile = File(zipFilePath);
      if (!await zipFile.exists()) return [];

      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      return archive.map((file) {
        return ArchiveFileInfo(
          name: file.name,
          size: file.size,
          isDirectory: file.name.endsWith('/'),
          lastModified: null,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}

/// 文件选择服务接口
///
/// 抽象文件选择功能，便于替换不同的实现（如 file_picker、系统文件选择等）。
///
/// 使用示例：
/// ```dart
/// // 在应用启动时注册实现
/// ZipService.instance.setFilePickerService(YourFilePickerImpl());
/// ```
abstract class FilePickerService {
  /// 选择文件
  ///
  /// [allowedExtensions] 允许选择的文件扩展名列表
  /// 返回选中文件的完整路径，如果用户取消选择则返回 null
  Future<String?> pickFile({List<String>? allowedExtensions});
}

/// 权限拒绝异常
class PermissionDeniedException implements Exception {
  final String message;

  const PermissionDeniedException([this.message = '权限被拒绝']);

  @override
  String toString() => 'PermissionDeniedException: $message';
}

/// ZIP错误类型枚举
enum ZipErrorType {
  /// 文件不存在
  fileNotFound,

  /// 无效的压缩格式
  invalidFormat,

  /// 文件损坏
  fileCorrupted,

  /// 权限不足
  permissionDenied,

  /// 解压失败
  extractFailed,

  /// 用户取消选择
  canceled,
}

/// ZIP操作异常
class ZipException implements Exception {
  /// 错误类型
  final ZipErrorType type;

  /// 错误消息
  final String message;

  /// 原始错误对象
  final Object? error;

  /// 创建ZIP异常
  const ZipException({
    required this.type,
    required this.message,
    this.error,
  });

  @override
  String toString() => 'ZipException($type): $message${error != null ? '\n$error' : ''}';
}

/// 解压结果类
///
/// 封装解压操作的结果信息，包括成功状态、错误类型、文件统计等。
class ExtractResult {
  /// 是否解压成功
  final bool success;

  /// 错误类型（仅在失败时有值）
  final ZipErrorType? errorType;

  /// 结果消息
  final String message;

  /// 已解压文件数量
  final int? extractedFiles;

  /// 总文件数量
  final int? totalFiles;

  /// 解压目标目录路径
  final String? destDirPath;

  /// 原始错误对象
  final Object? error;

  /// 创建解压结果
  ///
  /// [success] 是否成功
  /// [errorType] 错误类型
  /// [message] 结果消息
  /// [extractedFiles] 已解压文件数
  /// [totalFiles] 总文件数
  /// [destDirPath] 目标目录
  /// [error] 原始错误
  const ExtractResult({
    required this.success,
    this.errorType,
    required this.message,
    this.extractedFiles,
    this.totalFiles,
    this.destDirPath,
    this.error,
  });

  /// 创建成功结果
  factory ExtractResult.success({
    required String message,
    required int extractedFiles,
    required int totalFiles,
    required String destDirPath,
  }) {
    return ExtractResult(
      success: true,
      message: message,
      extractedFiles: extractedFiles,
      totalFiles: totalFiles,
      destDirPath: destDirPath,
    );
  }

  /// 创建失败结果
  factory ExtractResult.failure({
    required ZipErrorType errorType,
    required String message,
    int? extractedFiles,
    int? totalFiles,
    Object? error,
  }) {
    return ExtractResult(
      success: false,
      errorType: errorType,
      message: message,
      extractedFiles: extractedFiles,
      totalFiles: totalFiles,
      error: error,
    );
  }

  @override
  String toString() {
    return 'ExtractResult{success: $success, errorType: $errorType, '
        'message: $message, extractedFiles: $extractedFiles, '
        'totalFiles: $totalFiles, destDirPath: $destDirPath}';
  }
}

/// ZIP文件信息类
///
/// 封装ZIP归档中单个文件的信息。
class ArchiveFileInfo {
  /// 文件名（包含相对路径）
  final String name;

  /// 文件大小（字节）
  final int size;

  /// 是否为目录
  final bool isDirectory;

  /// 最后修改时间
  final DateTime? lastModified;

  /// 创建ZIP文件信息
  const ArchiveFileInfo({
    required this.name,
    required this.size,
    required this.isDirectory,
    this.lastModified,
  });

  @override
  String toString() {
    return 'ArchiveFileInfo{name: $name, size: $size, '
        'isDirectory: $isDirectory, lastModified: $lastModified}';
  }
}

/// 文件信息类
///
/// 封装文件系统中单个文件的信息。
class FileInfo {
  /// 文件完整路径
  final String path;

  /// 文件名
  final String name;

  /// 文件大小（字节）
  final int size;

  /// 最后修改时间
  final DateTime lastModified;

  /// 创建文件信息
  const FileInfo({
    required this.path,
    required this.name,
    required this.size,
    required this.lastModified,
  });

  /// 获取文件大小的可读字符串
  String get readableSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  String toString() {
    return 'FileInfo{name: $name, size: $readableSize, path: $path}';
  }
}
