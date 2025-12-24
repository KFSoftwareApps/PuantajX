// Stub for share_plus on web platform
// This is a minimal stub to allow compilation on web
// Actual sharing on web is handled by FileDownloadHelper or Clipboard

// Use XFile from cross_file package (used by image_picker)
import 'package:cross_file/cross_file.dart';
import 'package:flutter/services.dart';
export 'package:cross_file/cross_file.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

class Share {
  static Future<void> shareXFiles(
    List<XFile> files, {
    String? subject,
    String? text,
    List<String>? emails,
    String? sharePositionOrigin,
  }) async {
    // Web: No-op for file sharing via system dialog.
    // Usually downloads are triggered separately.
  }
  
  static Future<void> share(
    String text, {
    String? subject,
  }) async {
    // Web: Copy to Clipboard or open MailTo
    await Clipboard.setData(ClipboardData(text: text));
    // Optional: Alert user
    js.context.callMethod('alert', ['Metin kopyalandı!']);
  }
  
  static Future<void> shareFiles(
    List<String> paths, {
    List<String>? mimeTypes,
    String? subject,
    String? text,
  }) async {
    // Web: No-op
  }
}
