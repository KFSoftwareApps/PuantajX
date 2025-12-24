import 'platform_file_helper_stub.dart'
    if (dart.library.io) 'platform_file_helper_mobile.dart'
    if (dart.library.html) 'platform_file_helper_web.dart';

abstract class PlatformFileHelper {
  Future<String> saveReportPhoto(String sourcePath);
}

PlatformFileHelper getPlatformFileHelper() => createPlatformFileHelper();
