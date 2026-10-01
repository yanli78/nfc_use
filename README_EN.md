# NFC Use

[中文](README.md) | [English](README_EN.md)

An Android-focused Flutter NFC wallet application. It maintains cards locally, uses **Host Card Emulation (HCE)** to let a PN532 or another reader retrieve the selected card ID, and imports card definitions and images from ZIP bundles exported by a desktop application.

## Features

- Card-based home screen: swipe horizontally between cards and swipe up on the current card to enable HCE and open its detail view.
- Android HCE: answers a SELECT APDU for the configured AID with the current card ID followed by status word `9000`.
- NFC diagnostics for NFC hardware, HCE support, default payment-app status, emulation status, and the latest APDU/response.
- Opens system NFC settings and can request that this app become the default payment app.
- SQLite-backed card wallet storing card IDs, names, colors, image paths, and ordering; supports sorting, counting, and clearing cards.
- Imports card configuration and PNG/JPG/JPEG/WEBP images from a ZIP file, with a placeholder for missing images.
- Provides MQTT broker, port, client ID, topic, and authentication settings, plus connection, disconnection, and JSON QoS 1 publishing services.

## Platform and prerequisites

- Flutter SDK (the project declares Dart SDK `^3.11.5`)
- An Android device or emulator; real NFC/HCE features require a physical device that supports both NFC and HCE
- System NFC enabled; some devices also require this app to be selected as the default payment app
- A PN532/reader that sends a compatible SELECT AID command when HCE reading is needed
- A reachable MQTT broker when MQTT is needed

The Android manifest declares NFC, vibration, and HCE as non-required features. The app can therefore be installed on a device without NFC, but its NFC functions will not work.

## Quick start

```bash
git clone <repository-url>
cd nfc_use
flutter pub get
flutter run
```

Build a release APK:

```bash
flutter build apk --release
```

The current Android application ID is `com.example.nfc_use`. Change it to your own unique ID and configure a production signing key before distribution; release builds currently use the debug signing configuration.

## Use HCE card emulation

1. In **Settings**, select **NFC card emulation**.
2. Ensure that NFC is enabled and HCE is supported. If necessary, choose **Set as default payment app** and confirm in the Android system UI.
3. Return to the home screen, select a card, and swipe it upward.
4. The app enables HCE and stores that card's `id` as the response token.
5. Hold the phone near a PN532/reader. After the reader sends SELECT for AID `F0010203040506`, it receives the UTF-8 token followed by status word `9000`.
6. Inspect the latest APDU, response, and count in Settings to troubleshoot reader compatibility.

The HCE service is routed through a payment-category AID. NFC settings and default-payment-app behavior vary by Android vendor, so actual availability depends on the device.

## Card data and import

Cards are stored in `card_database.db` within the application's documents directory, not in the project folder. When no local cards exist, the home screen shows a `NONE` sample card.

Use **Import cards** in Settings to select a ZIP file. The importer locates `config.json` and images named after each module's `character`. Files may be in subdirectories; this layout is typical:

```text
config.json
resources/
  K1.png
  K2.png
```

A minimal `config.json` is:

```json
{
  "version": "1.1",
  "modules": [
    {
      "name": "Example card",
      "character": "K1",
      "color": "#3B82F6"
    }
  ]
}
```

During import, `character` becomes the card ID, `name` becomes the title, and `color` should be a hexadecimal color. If `resources/K1.png` exists (JPG/JPEG/WEBP also work), it is copied into app-private storage; otherwise a placeholder is used. An existing card with the same ID is replaced.

## MQTT status and configuration

Choose **MQTT message bus** in Settings, enter the Broker host, port (default `1883`), client ID, topic (default `nfc_use/send`), username, and password, then connect. The service publishes this JSON at QoS 1:

```json
{
  "value": "<value-to-send>"
}
```

Important: the current home-screen card swipe directly invokes HCE `writeCardId`; it does not automatically publish MQTT based on the selected send mode. MQTT connection and `sendValue` publishing are implemented, but are not wired into this gesture yet. To publish on a card swipe, the UI flow must call `NfcService.instance.sendValue(...)`.

## Security and privacy

- The current MQTT implementation uses plain TCP and exposes no TLS setting. Use it only on a trusted network, or extend it with encrypted MQTT.
- Broker credentials live only in the current settings-page controller and are not automatically persisted after an app restart; nevertheless, never place real credentials in source code or public bundles.
- HCE returns the selected card ID to compatible readers. Do not use this as a secure payment or authentication mechanism, and do not place sensitive credentials in the ID.
- ZIP-imported pictures and card identifiers are written to private app storage. Clearing cards also removes imported images.

## Stack

- Flutter / Material
- `nfc_manager` for NDEF tag sessions and writing services
- Native Android `HostApduService` for HCE APDU responses and debug data
- `sqflite` for local card data
- `archive`, `file_picker`, and `path_provider` for ZIP import and file handling
- `mqtt_client` for MQTT connectivity and QoS 1 publishing

## Project layout

```text
lib/
  core/
    constants/card_item.dart          Card model and interaction constants
    services/nfc_service.dart         HCE, NDEF, and MQTT services
    services/sqlite_service.dart      SQLite card data
    services/card_import_service.dart ZIP wallet import
    services/zip.dart                 ZIP selection, extraction, and file tools
  pages/
    Home/                             Card browsing, detail, and sorting
    Setting/                          HCE, MQTT, and import settings
android/app/src/main/
  kotlin/.../NfcHceService.kt         Custom HCE service
  kotlin/.../MainActivity.kt          Flutter MethodChannel bridge
  res/xml/apduservice.xml             HCE AID declaration
```
