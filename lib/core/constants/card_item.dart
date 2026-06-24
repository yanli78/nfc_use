import 'package:flutter/material.dart';

/// 卡片默认颜色配置
const Map<String, Color> kCardDefaultColors = {
  'explore': Color(0xFF667eea),
  'city': Color(0xFFf093fb),
  'nature': Color(0xFF4facfe),
  'tech': Color(0xFF43e97b),
};

/// 卡片图片占位符URL
const String kCardPlaceholderImageUrl =
    'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800&q=80';

/// 卡片最大标题长度
const int kCardMaxTitleLength = 50;

/// 卡片最大副标题长度
const int kCardMaxSubtitleLength = 100;

/// 卡片最大描述长度
const int kCardMaxDescriptionLength = 1000;

/// 卡片圆角半径
const double kCardBorderRadius = 32;

/// 卡片默认高度
const double kCardDefaultHeight = 380;

/// 卡片默认边距
const EdgeInsets kCardDefaultMargin = EdgeInsets.symmetric(horizontal: 10);

/// 卡片内边距
const EdgeInsets kCardDefaultPadding = EdgeInsets.all(24);

/// 卡片列表视口比例
const double kCardListViewportFraction = 0.8;

/// 卡片滑动触发阈值（上滑写入NFC）
const double kCardSwipeTriggerThreshold = 150;

/// 卡片滑动速度阈值
const double kCardSwipeVelocityThreshold = 700;

/// 卡片最大拖动距离
const double kCardMaxDragDistance = 240;

/// 卡片悬停位置（屏幕高度比例）
const double kCardHoverPositionRatio = 0.22;

/// 卡片悬停动画时长
const Duration kCardHoverDuration = Duration(milliseconds: 360);

/// 卡片回弹动画时长
const Duration kCardSnapBackDuration = Duration(milliseconds: 320);

/// 卡片退出动画时长
const Duration kCardExitDuration = Duration(milliseconds: 360);

/// 卡片悬停缩放比例
const double kCardHoverScale = 0.96;

/// 卡片退出缩放比例
const double kCardExitScale = 0.90;

/// 卡片拖动缩放变化量
const double kCardDragScaleChange = 0.08;

/// 卡片拖动透明度变化量
const double kCardDragOpacityChange = 0.18;

/// 卡片阴影基础模糊半径
const double kCardShadowBaseBlurRadius = 18;

/// 卡片阴影扩展模糊半径
const double kCardShadowExpandedBlurRadius = 18;

/// 卡片阴影基础透明度
const double kCardShadowBaseOpacity = 0.32;

/// 卡片阴影扩展透明度
const double kCardShadowExpandedOpacity = 0.18;

/// 卡片阴影基础偏移量
const double kCardShadowBaseOffset = 10;

/// 卡片阴影扩展偏移量变化
const double kCardShadowExpandedOffsetChange = 4;

/// NFC写入超时时间
const Duration kNfcWriteTimeout = Duration(seconds: 8);

/// NFC写入成功提示
const String kNfcWriteSuccessMessage = 'NFC标签写入成功';

/// NFC写入失败提示
const String kNfcWriteErrorMessage = 'NFC标签写入失败';

/// NFC未检测到标签提示
const String kNfcTagNotFoundMessage = '未检测到NFC标签，写入超时';

/// NFC标签不支持NDEF格式提示
const String kNfcTagNotSupportedMessage = '当前标签不支持NDEF格式';

/// NFC标签不可写提示
const String kNfcTagNotWritableMessage = '当前NFC标签不可写';

/// NFC写入内容超限提示
const String kNfcPayloadTooLargeMessage = '写入内容超过标签容量';

/// NFC会话启动失败提示
const String kNfcSessionStartFailedMessage = 'NFC会话启动失败';

/// NFC卡模拟启动成功提示
const String kNfcHceStartSuccessMessage = '已启动NFC卡模拟，请使用PN532读取';

/// NFC卡模拟启动失败提示
const String kNfcHceStartFailedMessage = 'NFC卡模拟启动失败';

/// NFC卡模拟停止成功提示
const String kNfcHceStopSuccessMessage = '已停止NFC卡模拟';

/// NFC卡模拟停止失败提示
const String kNfcHceStopFailedMessage = 'NFC卡模拟停止失败';

/// NFC设备不支持提示
const String kNfcUnavailableMessage = '当前设备不支持NFC，或NFC未开启';

/// NFC未开启提示
const String kNfcNotEnabledMessage = '当前设备NFC未开启';

/// NFC卡模拟不支持提示
const String kNfcHceUnsupportedMessage =
    '当前设备不支持NFC卡模拟，无法被PN532读取';

/// NFC状态检测失败提示
const String kNfcStateCheckFailedMessage = 'NFC状态检测失败';

/// NFC无效内容提示
const String kNfcInvalidPayloadMessage = '写入内容不能为空';

/// 详情页关闭阈值
const double kDetailPageCloseThreshold = 150;

/// 详情页关闭速度阈值
const double kDetailPageCloseVelocityThreshold = 700;

/// 详情页最大拖动距离
const double kDetailPageMaxDragDistance = 280;

/// 详情页关闭动画时长
const Duration kDetailPageCloseDuration = Duration(milliseconds: 360);

/// 详情页拖动缩放变化量
const double kDetailPageDragScaleChange = 0.08;

/// 详情页拖动透明度变化量
const double kDetailPageDragOpacityChange = 0.3;

/// 卡片数据模型类
///
/// 用于存储卡片的基本信息，包括业务字段、视觉属性和时间戳。
/// 支持从Map转换、转换为Map、复制并修改属性等操作。
class CardItem {
  /// 卡片唯一标识，使用字符串类型以支持多种ID生成方式（如UUID、时间戳等）
  final String id;

  /// 卡片标题
  final String title;

  /// 卡片副标题
  final String subtitle;

  /// 卡片描述信息
  final String description;

  /// 卡片颜色（用于加载失败时的背景色和进度指示器）
  final Color color;

  /// 卡片图片URL
  final String imageUrl;

  /// 卡片创建时间
  final DateTime createdAt;

  /// 卡片更新时间
  final DateTime? updatedAt;

  /// 卡片排序序号
  final int sortOrder;

  /// 创建卡片实例
  ///
  /// [id] 卡片唯一标识
  /// [title] 卡片标题
  /// [subtitle] 卡片副标题
  /// [description] 卡片描述信息
  /// [color] 卡片颜色
  /// [imageUrl] 卡片图片URL
  /// [createdAt] 创建时间
  /// [updatedAt] 更新时间（可选）
  /// [sortOrder] 排序序号（默认0）
  CardItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.color,
    required this.imageUrl,
    required this.createdAt,
    this.updatedAt,
    this.sortOrder = 0,
  });

  /// 创建新卡片（自动生成ID和时间）
  ///
  /// [title] 卡片标题
  /// [subtitle] 卡片副标题
  /// [description] 卡片描述信息
  /// [color] 卡片颜色
  /// [imageUrl] 卡片图片URL
  /// [sortOrder] 排序序号（默认0）
  factory CardItem.create({
    required String title,
    required String subtitle,
    required String description,
    required Color color,
    required String imageUrl,
    int sortOrder = 0,
  }) {
    return CardItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      subtitle: subtitle,
      description: description,
      color: color,
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
      sortOrder: sortOrder,
    );
  }

  /// 从数据库Map转换为CardItem对象
  ///
  /// [map] 数据库存储的Map对象，包含卡片的所有字段
  factory CardItem.fromMap(Map<String, dynamic> map) {
    return CardItem(
      id: map['id'] as String,
      title: map['title'] as String,
      subtitle: map['subtitle'] as String,
      description: map['description'] as String,
      color: Color(map['color'] as int),
      imageUrl: map['imageUrl'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
      sortOrder: map['sortOrder'] as int? ?? 0,
    );
  }

  /// 将CardItem对象转换为数据库Map
  ///
  /// 返回包含所有卡片字段的Map，可用于数据库存储
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'color': color.toARGB32(),
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'sortOrder': sortOrder,
    };
  }

  /// 复制对象并修改部分属性
  ///
  /// 创建一个新的CardItem实例，保留原对象的所有属性，
  /// 并根据传入的参数更新指定属性。
  ///
  /// [title] 新的卡片标题（可选）
  /// [subtitle] 新的卡片副标题（可选）
  /// [description] 新的卡片描述（可选）
  /// [color] 新的卡片颜色（可选）
  /// [imageUrl] 新的卡片图片URL（可选）
  /// [updatedAt] 新的更新时间（可选，默认为当前时间）
  /// [sortOrder] 新的排序序号（可选）
  CardItem copyWith({
    String? title,
    String? subtitle,
    String? description,
    Color? color,
    String? imageUrl,
    DateTime? updatedAt,
    int? sortOrder,
  }) {
    return CardItem(
      id: id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      color: color ?? this.color,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  String toString() {
    return 'CardItem{id: $id, title: $title}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          subtitle == other.subtitle &&
          description == other.description &&
          color == other.color &&
          imageUrl == other.imageUrl &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          sortOrder == other.sortOrder;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      subtitle.hashCode ^
      description.hashCode ^
      color.hashCode ^
      imageUrl.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      sortOrder.hashCode;
}
