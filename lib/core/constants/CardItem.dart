import 'package:flutter/material.dart';

class CardItem {
  final String title;
  final String subtitle;
  final String description;
  final Color color;
  final String imageUrl;

  CardItem({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.color,
    required this.imageUrl,
  });
}
