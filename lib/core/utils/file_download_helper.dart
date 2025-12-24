import 'file_download_helper_stub.dart'
    if (dart.library.io) 'file_download_helper_mobile.dart'
    if (dart.library.html) 'file_download_helper_web.dart';

class FileDownloadHelper {
  static Future<String?> saveToDownloads(dynamic context, List<int> bytes, String filename, {String? mimeType}) =>
      FileDownloadHelperImpl.saveToDownloads(context, bytes, filename, mimeType: mimeType);

  static Future<void> saveAndNotify(dynamic context, List<int> bytes, String filename) =>
      FileDownloadHelperImpl.saveAndNotify(context, bytes, filename);
}
