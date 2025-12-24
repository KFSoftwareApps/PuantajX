import 'package:flutter/material.dart';

class FileDownloadHelperImpl {
  static Future<String?> saveToDownloads(BuildContext context, List<int> bytes, String filename, {String? mimeType}) async {
    throw UnimplementedError('Platform not supported');
  }

  static Future<void> saveAndNotify(BuildContext context, List<int> bytes, String filename) async {
    throw UnimplementedError('Platform not supported');
  }
}
