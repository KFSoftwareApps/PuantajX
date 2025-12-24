import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

part 'share_token_model.g.dart';

@collection
class ShareToken {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String token;

  @Index()
  late int reportId;

  late DateTime createdAt;
  late DateTime expiresAt;

  bool canViewPhotos = true;
  bool canViewText = true;

  String? createdBy; // User ID who created the share

  bool isRevoked = false;

  static String generateToken() {
    return const Uuid().v4();
  }
}
