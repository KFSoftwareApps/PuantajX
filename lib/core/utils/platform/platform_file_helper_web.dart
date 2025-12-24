import 'platform_file_helper.dart';

PlatformFileHelper createPlatformFileHelper() => WebFileHelper();

class WebFileHelper implements PlatformFileHelper {
  @override
  Future<String> saveReportPhoto(String sourcePath) async {
    // On Web, sourcePath is a Blob URL. We cannot "save" it to permanent file system easily.
    // We just return it as is, and SyncService handles upload via Blob URL fetch.
    return sourcePath;
  }
}
