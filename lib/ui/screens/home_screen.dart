import 'package:flutter/material.dart';
import 'package:nfc_use/ui/widgets/nfc_card_widget.dart';

class NfcControllerApp extends StatelessWidget {
  const NfcControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NFC Controller',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
