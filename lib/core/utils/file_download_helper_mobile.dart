import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class FileDownloadHelperImpl {
  static Future<String?> saveToDownloads(BuildContext context, List<int> bytes, String filename, {String? mimeType}) async {
    try {
      if (Platform.isAndroid) {
        // Android strict storage logic or scoped storage could go here.
        // For now using the existing logic from the original file.
        Directory? directory = await getExternalStorageDirectory(); 
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          directory = downloadDir;
        }

        if (directory == null) {
           throw Exception('Depolama alanı bulunamadı');
        }

        final file = File('${directory.path}/$filename');
        await file.writeAsBytes(bytes);
        return file.path;
      } else {
        // iOS etc
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$filename');
        await file.writeAsBytes(bytes);
        return file.path;
      }
    } catch (e) {
      debugPrint('Save Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      return null;
    }
  }

  static Future<void> saveAndNotify(BuildContext context, List<int> bytes, String filename) async {
    final path = await saveToDownloads(context, bytes, filename);
    if (path != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dosya kaydedildi: Downloads/$filename'),
          action: SnackBarAction(label: 'Tamam', onPressed: () {}),
        )
      );
    }
  }
}
