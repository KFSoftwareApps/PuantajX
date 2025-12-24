import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../authz/permissions.dart';
import '../../features/auth/data/repositories/auth_repository.dart';

class PermissionGuard extends ConsumerWidget {
  final AppPermission permission;
  final Widget child;
  final Widget? fallback;

  const PermissionGuard({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permsAsync = ref.watch(currentPermissionsProvider);

    return permsAsync.when(
      data: (perms) => perms.contains(permission)
          ? child
          : (fallback ?? const SizedBox.shrink()),
      loading: () => fallback ?? const SizedBox.shrink(),
      error: (_, __) => fallback ?? const SizedBox.shrink(),
    );
  }
}
