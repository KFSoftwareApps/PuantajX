import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class FileDownloadHelperImpl {
  static Future<String?> saveToDownloads(BuildContext context, List<int> bytes, String filename, {String? mimeType}) async {
    try {
      final blob = html.Blob([bytes], mimeType ?? 'application/octet-stream');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
      return filename; // Return filename as "path"
    } catch (e) {
      debugPrint('Web Save Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      return null;
    }
  }

  static Future<void> saveAndNotify(BuildContext context, List<int> bytes, String filename) async {
    await saveToDownloads(context, bytes, filename);
    // On web, the browser handles the notification/download bar.
    // We can show a toast just to confirm action was triggered.
    if (context.mounted) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İndirme başlatıldı...')));
    }
  }
}
