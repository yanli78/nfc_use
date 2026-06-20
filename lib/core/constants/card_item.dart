import 'package:flutter/material.dart';

class CardItem {
  // 业务字段
  // id作为唯一标识，使用字符串类型以支持多种ID生成方式（如UUID、时间戳等）
  final String id;
  //标题
  final String title;
  //副标题
  final String subtitle;
  //描述信息
  final String description;
  //颜色
  final Color color;
  //图片URL
  final String imageUrl;
  //创建时间
  final DateTime createdAt;
  //更新时间
  final DateTime? updatedAt;
  //排序序号
  final int sortOrder;

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

  /// 从数据库Map转换为对象
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

  /// 转换为数据库Map
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
}
