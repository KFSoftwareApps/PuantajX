import 'package:isar/isar.dart';
import '../models/share_token_model.dart';

class ShareTokenRepository {
  final Isar _isar;

  ShareTokenRepository(this._isar);

  Future<ShareToken> createShareToken({
    required int reportId,
    required int expiryDays,
    required bool canViewPhotos,
    required bool canViewText,
    String? createdBy,
  }) async {
    return await _isar.writeTxn(() async {
      final token = ShareToken()
        ..token = ShareToken.generateToken()
        ..reportId = reportId
        ..createdAt = DateTime.now()
        ..expiresAt = DateTime.now().add(Duration(days: expiryDays))
        ..canViewPhotos = canViewPhotos
        ..canViewText = canViewText
        ..createdBy = createdBy;
      
      await _isar.shareTokens.put(token);
      return token;
    });
  }

  Future<ShareToken?> getTokenByString(String tokenStr) async {
    return await _isar.shareTokens
        .filter()
        .tokenEqualTo(tokenStr)
        .isRevokedEqualTo(false)
        .findFirst();
  }

  Future<List<ShareToken>> getTokensForReport(int reportId) async {
    return await _isar.shareTokens
        .filter()
        .reportIdEqualTo(reportId)
        .isRevokedEqualTo(false)
        .findAll();
  }

  Future<void> revokeToken(String tokenStr) async {
    final token = await getTokenByString(tokenStr);
    if (token != null) {
      await _isar.writeTxn(() async {
        token.isRevoked = true;
        await _isar.shareTokens.put(token);
      });
    }
  }

  Future<bool> isTokenValid(String tokenStr) async {
    final token = await getTokenByString(tokenStr);
    if (token == null) return false;
    if (token.isRevoked) return false;
    if (token.expiresAt.isBefore(DateTime.now())) return false;
    return true;
  }
}
