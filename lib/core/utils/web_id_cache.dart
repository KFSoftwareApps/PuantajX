class WebIdCache {
  static final WebIdCache _instance = WebIdCache._internal();
  factory WebIdCache() => _instance;
  WebIdCache._internal();

  final Map<int, String> _idMap = {};

  void register(String uuid) {
    _idMap[uuid.hashCode] = uuid;
  }

  String? lookup(int id) {
    return _idMap[id];
  }

  // Helper to ensure consistency (and strict int type)
  int store(String uuid) {
    final id = uuid.hashCode;
    _idMap[id] = uuid;
    return id;
  }
}
