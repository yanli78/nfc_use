import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_use/core/constants/card_item.dart';

void main() {
  test('CardItem preserves imported card fields', () {
    final card = CardItem(
      id: 'R5',
      title: '云·原神',
      color: const Color(0xFF023896),
      imageUrl: '/local/R5.png',
      sortOrder: 1,
    );

    final restored = CardItem.fromMap(card.toMap());

    expect(restored.id, 'R5');
    expect(restored.title, '云·原神');
    expect(restored.imageUrl, '/local/R5.png');
    expect(restored.sortOrder, 1);
  });

  test('CardItem map does not include config path', () {
    final card = CardItem(
      id: 'R1',
      title: '何意味',
      color: const Color(0xFF215694),
      imageUrl: '/local/R1.png',
    );

    expect(card.toMap().containsKey('path'), isFalse);
    expect(card.toMap().containsKey('actionPath'), isFalse);
  });
}
