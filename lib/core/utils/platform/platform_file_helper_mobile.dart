import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'platform_file_helper.dart';

PlatformFileHelper createPlatformFileHelper() => MobileFileHelper();

class MobileFileHelper implements PlatformFileHelper {
  @override
  Future<String> saveReportPhoto(String sourcePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${appDir.path}/report_photos');
    if (!photosDir.existsSync()) {
      await photosDir.create(recursive: true);
    }
    
    final fileName = '${const Uuid().v4()}.jpg';
    final savedFile = await File(sourcePath).copy('${photosDir.path}/$fileName');
    return savedFile.path;
  }
}
