import 'dart:io';

Future<void> main() async {
  final version = '3.1.0+1';
  final urls = [
      'https://github.com/isar/isar/releases/download/3.1.0+1/isar.wasm',
      'https://github.com/isar/isar/releases/download/v3.1.0+1/isar.wasm',
      'https://unpkg.com/isar@3.1.0+1/dist/isar.wasm',
      'https://cdn.jsdelivr.net/npm/isar@3.1.0+1/dist/isar.wasm',
      'https://fastly.jsdelivr.net/npm/isar@3.1.0+1/dist/isar.wasm',
  ];
  final filename = 'web/isar.wasm';
  final buildFilename = 'build/web/isar.wasm';

  final httpClient = HttpClient();
  httpClient.badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

  for (final url in urls) {
      print('Trying $url ...');
      try {
        final request = await httpClient.getUrl(Uri.parse(url));
        final response = await request.close();
        if (response.statusCode == HttpStatus.ok) {
            final file = File(filename);
            if (!file.parent.existsSync()) file.parent.createSync(recursive: true);
            await response.pipe(file.openWrite());
            print('Success! Downloaded to $filename from $url');
            
             // Copy to build
            final buildFile = File(buildFilename);
            if (buildFile.parent.existsSync()) {
                await file.copy(buildFilename);
                print('Copied to $buildFilename');
            }
            return;
        } else {
            print('Failed $url: ${response.statusCode}');
        }
      } catch(e) { print('Error $url: $e'); }
  }
  print('All failed.');
}
// placeholder to match structure
void dummy() {}
