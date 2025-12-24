import 'dart:typed_data';

// Stub for web compatibility
class File implements FileSystemEntity {
  @override
  final String path;
  
  File(this.path);
  
  Future<bool> exists() async => false;
  bool existsSync() => false;
  
  Future<Uint8List> readAsBytes() async => Uint8List(0);
  Future<void> writeAsBytes(List<int> bytes) async {}
  Future<void> writeAsString(String content) async {}
  
  Future<int> length() async => 0;
  
  Future<File> copy(String newPath) async => File(newPath);
  
  void createSync({bool recursive = false}) {}
  Future<File> create({bool recursive = false}) async => this;
  
  @override
  void deleteSync({bool recursive = false}) {}
  Future<void> delete({bool recursive = false}) async {}
}

class Platform {
  static bool get isAndroid => false;
  static bool get isIOS => false;
}

class Directory implements FileSystemEntity {
  @override
  final String path;
  
  Directory(this.path);
  
  Future<bool> exists() async => false;
  bool existsSync() => false;
  
  List<FileSystemEntity> listSync({bool recursive = false, bool followLinks = true}) => [];
  
  void createSync({bool recursive = false}) {}
  Future<Directory> create({bool recursive = false}) async => this;
  
  @override
  void deleteSync({bool recursive = false}) {}
  Future<void> delete({bool recursive = false}) async {}
}

abstract class FileSystemEntity {
  String get path;
  void deleteSync({bool recursive = false});
}

class HttpClient {
  Future<HttpClientRequest> postUrl(Uri url) async => throw UnimplementedError();
  void close({bool force = false}) {}
}

class HttpClientRequest {
  final HttpHeaders headers = HttpHeaders();
  void write(Object? obj) {}
  Future<HttpClientResponse> close() async => throw UnimplementedError();
}

class HttpHeaders {
  set contentType(ContentType? contentType) {}
  void set(String name, Object value) {}
}

class HttpClientResponse {
  int get statusCode => 200;
  Stream<List<int>> transform(dynamic transformer) => const Stream.empty();
}

class ContentType {
  static final json = ContentType('application', 'json');
  ContentType(String primaryType, String subType);
}

class SocketException implements Exception {}
