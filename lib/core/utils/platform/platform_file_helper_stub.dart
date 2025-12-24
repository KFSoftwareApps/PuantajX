import 'platform_file_helper.dart';

PlatformFileHelper createPlatformFileHelper() => StubFileHelper();

class StubFileHelper implements PlatformFileHelper {
  @override
  Future<String> saveReportPhoto(String sourcePath) async {
    throw UnimplementedError();
  }
}
