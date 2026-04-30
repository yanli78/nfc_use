// --- 模型定义 (对应 models/nfc_card_model.dart) ---
import 'package:flutter/material.dart';

class NfcCardInfo {
  final String id;
  final String title;
  final String description;
  final Color cardColor;

  NfcCardInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.cardColor,
  });
}
