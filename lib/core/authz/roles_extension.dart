import 'roles.dart';

extension AppRoleExtension on AppRole {
  String get trName {
    switch (this) {
      case AppRole.owner: return 'Sahip';
      case AppRole.admin: return 'Yönetici';
      case AppRole.supervisor: return 'Şantiye Şefi';
      case AppRole.finance: return 'Finans';
      case AppRole.timesheetEditor: return 'Puantaj Sorumlusu';
      case AppRole.viewer: return 'Görüntüleyici';
      case AppRole.guest: return 'Misafir';
    }
  }
}
