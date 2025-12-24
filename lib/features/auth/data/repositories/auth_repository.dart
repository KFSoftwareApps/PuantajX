import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User; // Hide generic User to avoid conflict with our User model
import 'package:google_sign_in/google_sign_in.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/web_id_cache.dart';

import '../../../../core/authz/permissions.dart';
import '../../../../core/init/providers.dart';
import '../models/security_models.dart';
import '../models/user_model.dart';
import '../models/organization_model.dart';
import '../../../../core/sync/data/models/outbox_item.dart';
import '../../../../core/subscription/subscription_model.dart';
import '../../../../core/subscription/plan_config.dart';

part 'auth_repository.g.dart';

// Abstract Interface
abstract class IAuthRepository {
  Future<User?> login(String email, String password);
  Future<User?> signInWithGoogle();
  Future<User> register(String email, String password, String fullName, String orgName);
  Future<void> logout();
  Future<User?> getCurrentUser();
  Future<void> updateProfile(int userId, {String? fullName, String? phoneNumber});
  Future<void> updateAvatar(String path);
  Future<List<User>> getOrganizationMembers(String orgId);
  Future<void> inviteMember({
    required String orgId,
    required String email,
    required String fullName,
    required AppRole role,
    required String temporaryPassword,
  });
  Future<void> removeMember(int userId);
  Future<void> deleteAccount();
  Future<Map<String, dynamic>> exportUserData();
  Future<void> changePassword(String currentPassword, String newPassword);
  Future<void> updateMemberRole(int userId, AppRole newRole);
  Future<void> updateUserProjects(int userId, List<int> projectIds);

  // Security
  Future<Set<AppPermission>> getUserPermissions(User user);
  Future<void> updateOrgPolicy(OrgPolicy policy);
  Future<OrgPolicy> getOrgPolicy(String orgId);
  
  // Billing
  Future<Organization?> getOrganization(String orgId);
  Future<void> updateOrgBilling({
    required String orgId,
    required String? email,
    required bool notifyBilling,
    required bool notifyLimits,
    required bool notifySummary,
  });
  Future<void> sendBillingVerificationEmail(String orgId);
  Future<void> refreshOrganizationFromSupabase(String orgId);
  Future<void> updateOrgPlan(String orgId, String planId);
  Future<void> updateOrgName(String orgId, String newName, String newCode);

  // Hybrid Auth
  Future<bool> hasPassword();
  Future<void> setPassword(String password);
  
  // Audit
  Future<List<AuditLog>> getAuditLogs(String orgId);
}

// Implementation
class AuthRepository implements IAuthRepository {
  final Isar? _isar;
  final SupabaseClient _supabase;

  AuthRepository(this._isar, this._supabase);

  @override
  Future<User?> login(String email, String password) async {
    try {
      final res = await _supabase.auth.signInWithPassword(email: email, password: password);
      
      if (res.user != null) {
        return await _syncUserAfterLogin(res.user!);
      }
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login credentials')) {
        throw Exception('Hatalı e-posta/şifre veya hesabınız henüz onaylanmamış (Mailinizi kontrol edin).');
      }
      if (e.message.contains('Email not confirmed')) {
        throw Exception('E-posta adresi doğrulanmamış. Lütfen mailinizi kontrol edin.');
      }
      throw Exception('Giriş başarısız: ${e.message}');
    } catch (e) {
       debugPrint('Supabase Login Error: $e');
       rethrow;
    }
    return null;
  }

  @override
  Future<User?> signInWithGoogle() async {
     try {
       if (kIsWeb) {
          await _supabase.auth.signInWithOAuth(
             OAuthProvider.google,
             redirectTo: 'https://puantajx.kfsoftware.app',
          );
          return null;
       } else {
          const webClientId = '421792290498-a8ii1len9tenl0pqepucgl51robhdlug.apps.googleusercontent.com'; 
          
          final GoogleSignIn googleSignIn = GoogleSignIn(
            serverClientId: webClientId,
            scopes: [
              'email',
              'profile',
              'openid',
            ],
          );
          
          final googleUser = await googleSignIn.signIn();
          if (googleUser == null) return null;
   
          final googleAuth = await googleUser.authentication;
          final accessToken = googleAuth.accessToken;
          final idToken = googleAuth.idToken;
   
          if (idToken == null) throw Exception('Google ID Token alınamadı.');
   
          final res = await _supabase.auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
            accessToken: accessToken,
          );
   
          if (res.user != null) {
             return await _syncUserAfterLogin(res.user!);
          }
       }
     } catch (e) {
       debugPrint('Google Sign In Error: $e');
       rethrow;
     }
     return null;
  }

  Future<User> _syncUserAfterLogin(dynamic remoteUser) async { 
        final email = remoteUser.email ?? '';
        final id = remoteUser.id;
        final metadata = remoteUser.userMetadata ?? {};

        if (_isar == null) {
           var user = User()
               ..email = email
               ..serverId = id
               ..fullName = metadata['full_name'] ?? email.split('@')[0]
               ..currentOrgId = 'DEFAULT'
               ..role = AppRole.owner 
               ..passwordHash = ''
               ..isSynced = true;

             // Web: Master Sync via RPC (Bypasses all API cache/schema issues)
             try {
               final syncData = await _supabase.rpc('get_or_create_user_org', params: {
                 'p_user_id': id,
                 'p_email': email,
                 'p_full_name': user.fullName,
               });

               if (syncData != null) {
                  // Ensure we store the CODE, not UUID in currentOrgId for consistency with Mobile
                  user.currentOrgId = (syncData['org_code'] as String?) ?? (syncData['org_name'] as String?) ?? 'DEFAULT';
                   
                  final remoteRoleStr = syncData['role'] as String;
                  user.role = AppRole.values.firstWhere(
                      (e) => e.name.toLowerCase() == remoteRoleStr.toLowerCase(),
                      orElse: () => AppRole.owner
                  );
               }
             } catch (e) {
               debugPrint('Master RPC Sync Error: $e');
             }
             return user;
        }

        User? localUser = await (_isar as dynamic).users.filter().emailEqualTo(email).findFirst();
        
        await (_isar as dynamic).writeTxn(() async {
          if (localUser == null) {
             localUser = User()
               ..email = email
               ..serverId = id
               ..fullName = metadata['full_name'] ?? email.split('@')[0]
               ..currentOrgId = metadata['org_name'] ?? 'DEFAULT'
               ..role = AppRole.owner
               ..passwordHash = ''
               ..createdAt = DateTime.now()
               ..termsAcceptedAt = DateTime.now()
               ..termsVersion = '1.0'
               ..privacyAcceptedAt = DateTime.now()
               ..privacyVersion = '1.0'
               ..isSynced = true;

             try {
                final memberData = await _supabase
                    .from('organization_members')
                    .select('role, org_id')
                    .eq('user_id', id)
                    .maybeSingle();
                
                if (memberData != null) {
                   final remoteRoleStr = memberData['role'] as String;
                   final remoteOrgId = memberData['org_id'] as String;
                   
                   localUser!.currentOrgId = remoteOrgId;
                   localUser!.role = AppRole.values.firstWhere(
                      (e) => e.name.toLowerCase() == remoteRoleStr.toLowerCase(),
                      orElse: () => AppRole.viewer
                   );
                   
                   if (remoteRoleStr == 'owner') localUser!.role = AppRole.owner;
                }
             } catch (e) {
                debugPrint('Role Sync Error: $e');
             }
             
             final userToSync = localUser;
             if (userToSync != null) {
               final orgCode = userToSync.currentOrgId;
               final existingOrg = await (_isar as dynamic).organizations.filter().codeEqualTo(orgCode).findFirst();
               if (existingOrg == null) {
                  await (_isar as dynamic).organizations.put(Organization()..name = orgCode..code = orgCode..createdAt = DateTime.now());
                  await (_isar as dynamic).orgPolicys.put(OrgPolicy()..orgId = orgCode);
               }
             }
          } else {
             localUser?.serverId = id;
             localUser?.isSynced = true;
          }
          if (localUser != null) {
            await (_isar as dynamic).users.put(localUser!);
          }
        });

        final finalUser = localUser;
        if (finalUser != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('userId', finalUser.id);
          return finalUser;
        }
        
        throw Exception('Kullanıcı senkronizasyonu başarısız oldu.');
  }

  @override
  Future<User> register(String email, String password, String fullName, String orgName) async {
    try {
       final checkRes = await _supabase.functions.invoke(
          'check-google-user',
          body: {'email': email},
       );
       
       if (checkRes.status == 200) {
          final data = checkRes.data;
          if (data['hasGoogle'] == true) {
             throw Exception('Bu e-posta adresi Google ile bağlı. Lütfen "Google ile Giriş Yap" butonunu kullanın.');
          }
       }
    } catch (e) {
       if (e.toString().contains('Google ile bağlı')) rethrow;
       debugPrint('Google Check Failed: $e');
    }

    final res = await _supabase.auth.signUp(
      email: email, 
      password: password,
      data: {'full_name': fullName, 'org_name': orgName, 'org_code': orgName.toUpperCase().replaceAll(' ', '')},
    );
    
    final remoteUser = res.user;
    if (remoteUser == null) throw Exception('Kayıt başlatılamadı');

    if (res.session == null) {
       throw Exception('Lütfen e-posta adresinize gelen doğrulama linkine tıklayarak hesabınızı onaylayın.');
    }

    if (_isar != null) {
      return await (_isar as dynamic).writeTxn(() async {
        final org = Organization()
          ..name = orgName
          ..code = orgName.toUpperCase().replaceAll(' ', '')
          ..createdAt = DateTime.now();
        await (_isar as dynamic).organizations.put(org);

        final policy = OrgPolicy()..orgId = org.code;
        await (_isar as dynamic).orgPolicys.put(policy);

        final user = User()
          ..email = email
          ..passwordHash = ''
          ..serverId = remoteUser.id
          ..fullName = fullName
          ..currentOrgId = org.code
          ..role = AppRole.owner
          ..termsAcceptedAt = DateTime.now()
          ..termsVersion = '1.0'
          ..privacyAcceptedAt = DateTime.now()
          ..privacyVersion = '1.0'
          ..createdAt = DateTime.now()
          ..isSynced = true;

        await (_isar as dynamic).users.put(user);

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('userId', user.id);
        } catch (_) {}

        return user;
      });
    } else {
      return await _syncUserAfterLogin(remoteUser);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userId');
    } catch (_) {}
  }

  @override
  Future<User?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId != null && _isar != null) {
        return await (_isar as dynamic).users.get(userId);
      } else if (_supabase.auth.currentUser != null) {
         return _syncUserAfterLogin(_supabase.auth.currentUser!);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  @override
  Future<void> updateProfile(int userId, {String? fullName, String? phoneNumber}) async {
    if (_isar != null) {
      await (_isar as dynamic).writeTxn(() async {
        final user = await (_isar as dynamic).users.get(userId);
        if (user != null) {
          if (fullName != null) user.fullName = fullName;
          if (phoneNumber != null) user.phoneNumber = phoneNumber;
          await (_isar as dynamic).users.put(user);
        }
      });
    } else {
        final updates = <String, dynamic>{};
        if (fullName != null) updates['full_name'] = fullName;
        if (updates.isNotEmpty) {
           await _supabase.auth.updateUser(UserAttributes(data: updates));
        }
    }
  }

  @override
  Future<void> updateAvatar(String path) async {
    final currentUser = await getCurrentUser();
    if (currentUser != null) {
      if (_isar != null) {
        await (_isar as dynamic).writeTxn(() async {
           final user = await (_isar as dynamic).users.get(currentUser.id);
           if (user != null) {
               user.avatarPath = path;
               await (_isar as dynamic).users.put(user);
               
               final outbox = OutboxItem()
                ..entityId = user.id.toString()
                ..entityType = 'ATTACHMENT_AVATAR'
                ..operation = 'UPLOAD'
                ..localFilePath = path
                ..createdAt = DateTime.now();
               await (_isar as dynamic).outboxItems.put(outbox);
           }
        });
      }
    }
  }

  @override
  Future<List<User>> getOrganizationMembers(String orgId) async {
    if (_isar != null) {
        return await (_isar as dynamic).users.filter().currentOrgIdEqualTo(orgId).findAll();
        // Web: Fetch from organization_members JOIN auth.users via RPC
        try {
           debugPrint('DEBUG: Fetching members for Org: $orgId');
           final List<dynamic> data = await _supabase.rpc('get_organization_members_v2', params: {
             'p_org_id': orgId,
           });

           debugPrint('DEBUG: RPC Result count: ${data.length}');
           if (data.isEmpty) {
              debugPrint('WARNING: RPC returned empty. Attempting direct query fallback...');
              final fallbackData = await _supabase
                  .from('organization_members')
                  .select('user_id, role, organization_id:org_id')
                  .eq('org_id', orgId);
              debugPrint('DEBUG: Fallback Result count: ${fallbackData.length}');
              // If fallback has data, we might need a different mapping or just log it
           }

           return data.map((e) {
             final uuid = e['id']?.toString() ?? '';
             final roleStr = (e['role'] ?? 'viewer').toString();
             
             return User()
               ..id = WebIdCache().store(uuid)
               ..serverId = uuid
               ..email = (e['email'] ?? '---').toString()
               ..fullName = (e['full_name'] ?? 'İsimsiz').toString()
               ..currentOrgId = orgId
               ..role = AppRole.values.firstWhere(
                  (r) => r.name.toLowerCase() == roleStr.toLowerCase(),
                  orElse: () => AppRole.viewer,
               )
               ..passwordHash = ''
               ..isSynced = true;
           }).toList();
        } catch (e, stack) {
          debugPrint('CRITICAL: Web Fetch Members Error: $e');
          debugPrint('Stack: $stack');
          rethrow; // Rethrow to show in the UI error state
        }
    }
  }

  @override
  Future<void> inviteMember({
    required String orgId,
    required String email,
    required String fullName,
    required AppRole role,
    required String temporaryPassword,
  }) async {
    if (_isar != null) {
       await (_isar as dynamic).writeTxn(() async {
         final existingUser = await (_isar as dynamic).users.filter().emailEqualTo(email.trim()).findFirst();
         final user = existingUser ?? User();
         user.fullName = fullName;
         user.email = email;
         user.role = role;
         user.currentOrgId = orgId;
         await (_isar as dynamic).users.put(user);
       });
    } else {
        // Web: Invitation Flow
        try {
          // 1. Try to link if user already exists in Auth
          final linkedUserId = await _supabase.rpc('link_member_by_email', params: {
            'p_email': email.trim(),
            'p_org_id': orgId,
            'p_role': role.name,
          });

          if (linkedUserId == null) {
             // 2. User doesn't exist, create via Edge Function
             try {
                await _supabase.functions.invoke('invite-member', body: {
                  'email': email.trim(),
                  'password': temporaryPassword,
                  'data': {
                    'full_name': fullName,
                    'org_name': 'Invitation', // Metadata
                  }
                });
                
                // 3. Link them now that they exist
                await _supabase.rpc('link_member_by_email', params: {
                  'p_email': email.trim(),
                  'p_org_id': orgId,
                  'p_role': role.name,
                });
             } catch (e) {
                if (e.toString().contains('zaten kayıtlı')) {
                   // Race condition? Re-try link
                   await _supabase.rpc('link_member_by_email', params: {
                      'p_email': email.trim(),
                      'p_org_id': orgId,
                      'p_role': role.name,
                   });
                } else {
                   rethrow;
                }
             }
          }
        } catch (e, stack) {
          debugPrint('CRITICAL: Web Invitation Error: $e');
          debugPrint('Stack: $stack');
          throw Exception('Üye davet edilemedi: $e');
        }
    }
  }

  @override
  Future<void> removeMember(int userId) async {
     if (_isar != null) {
       await (_isar as dynamic).writeTxn(() async {
         await (_isar as dynamic).users.delete(userId);
       });
     } else {
        // Web: Remove from organization membership
        final uuid = WebIdCache().lookup(userId);
        if (uuid != null) {
           // We only remove them from this organization, not delete the auth user
           await _supabase.from('organization_members').delete().eq('user_id', uuid);
        }
     }
  }

  @override
  Future<void> deleteAccount() async {
      if (_isar != null) {
        await (_isar as dynamic).writeTxn(() async {
           await (_isar as dynamic).clear(); 
        });
      } else {
        // Web / Supabase Delete
        try {
           final user = _supabase.auth.currentUser;
           if (user != null) {
              // 1. Try to invoke Edge Function if exists (best practice)
              try {
                await _supabase.functions.invoke('delete-account');
              } catch (_) {
                 // 2. Fallback: Manual Cleanup (Best Effort)
                 // Delete from public.users / profiles if exists?
                 // Delete org membership
                 await _supabase.from('organization_members').delete().eq('user_id', user.id);
                 
                 // If owner, maybe delete org? (Dangerous if shared, but MVP assumption: separate orgs)
                 // Checking if owner of any org
                 // ... omitted to prevent accidental data loss for shared orgs
              }
           }
        } catch (e) {
           debugPrint('Delete Account Error: $e');
        } finally {
            // 3. Always Sign Out & Clear Local
            await _supabase.auth.signOut();
            final prefs = await SharedPreferences.getInstance();
            await prefs.clear();
            // UI should reaction to auth state change (user becomes null)
        }
      }
  }

  @override
  Future<Map<String, dynamic>> exportUserData() async {
    final user = await getCurrentUser();
    if (user == null) throw Exception('Kullanıcı bulunamadı');

    Map<String, dynamic>? orgData;
    if (_isar != null) {
       final org = await (_isar as dynamic).organizations.filter().codeEqualTo(user.currentOrgId).findFirst();
       if (org != null) {
          orgData = { 'name': org.name, 'code': org.code };
       }
    }
    
    return {
      'user': {
        'id': user.id,
      },
      'organization': orgData,
    };
  }

  @override
  Future<void> changePassword(String currentPassword, String newPassword) async {
     if (_isar != null) {
        final user = await getCurrentUser();
        if (user != null) {
           await (_isar as dynamic).writeTxn(() async {
              user.passwordHash = newPassword;
              await (_isar as dynamic).users.put(user);
           });
        }
     }
     await _supabase.auth.updateUser(UserAttributes(password: newPassword));
  }

  @override
  Future<void> updateMemberRole(int userId, AppRole newRole) async {
    if (_isar != null) {
      await (_isar as dynamic).writeTxn(() async {
        final user = await (_isar as dynamic).users.get(userId);
        if (user != null) {
          user.role = newRole;
          await (_isar as dynamic).users.put(user);
        }
      });
    } else {
        // Web: Update role in organization_members
        final uuid = WebIdCache().lookup(userId);
        if (uuid != null) {
           await _supabase.from('organization_members').update({
             'role': newRole.name,
           }).eq('user_id', uuid);
        }
    }
  }

  @override
  Future<void> updateUserProjects(int userId, List<int> projectIds) async {
    if (_isar != null) {
      await (_isar as dynamic).writeTxn(() async {
        final user = await (_isar as dynamic).users.get(userId);
        if (user != null) {
          user.assignedProjectIds = projectIds;
          await (_isar as dynamic).users.put(user);
        }
      });
    }
  }

  @override
  Future<Set<AppPermission>> getUserPermissions(User user) async {
    if (_isar == null) return getEffectivePermissions(role: user.role);

    final policy =
        await (_isar as dynamic).orgPolicys.filter().orgIdEqualTo(user.currentOrgId).findFirst();

    final template = await (_isar as dynamic).orgRoleTemplates
        .filter()
        .orgIdEqualTo(user.currentOrgId)
        .roleEqualTo(user.role)
        .findFirst();

    final override = await (_isar as dynamic).membershipOverrides
        .filter()
        .memberIdEqualTo(user.id.toString())
        .findFirst();

    return getEffectivePermissions(
      role: user.role,
      policy: policy,
      roleTemplate: template,
      override: override,
    );
  }

  @override
  Future<void> updateOrgPolicy(OrgPolicy policy) async {
    if (_isar != null) {
      await (_isar as dynamic).writeTxn(() async {
        await (_isar as dynamic).orgPolicys.put(policy);
      });
    }
  }

  @override
  Future<OrgPolicy> getOrgPolicy(String orgId) async {
    if (_isar != null) {
      final policy = await (_isar as dynamic).orgPolicys.filter().orgIdEqualTo(orgId).findFirst();
      if (policy == null) {
        final newPolicy = OrgPolicy()..orgId = orgId;
        await (_isar as dynamic).writeTxn(() async {
          await (_isar as dynamic).orgPolicys.put(newPolicy);
        });
        return newPolicy;
      }
      return policy;
    }
    return OrgPolicy()..orgId = orgId;
  }

  @override
  Future<Organization?> getOrganization(String orgId) async {
    if (_isar != null) {
      return await (_isar as dynamic).organizations.filter().codeEqualTo(orgId).findFirst();
    }
    return null;
  }

  @override
  Future<void> refreshOrganizationFromSupabase(String orgId) async {
       if (_isar == null) return;
       try {
         final remoteOrg = await _supabase.from('organizations').select().eq('code', orgId).maybeSingle();
         
         if (remoteOrg != null) {
            final localOrg = await (_isar as dynamic).organizations.filter().codeEqualTo(orgId).findFirst();
            if (localOrg != null) {
               await (_isar as dynamic).writeTxn(() async {
                  localOrg.billingEmailVerified = remoteOrg['billing_email_verified'] == true;
                  localOrg.billingEmail = remoteOrg['billing_email'];
                  localOrg.plan = remoteOrg['plan'] ?? 'free'; 
                  await (_isar as dynamic).organizations.put(localOrg);

                  final planStr = remoteOrg['plan'] as String? ?? 'free';
                  final subPlan = SubscriptionPlan.values.firstWhere(
                     (e) => e.name.toLowerCase() == planStr.toLowerCase(),
                     orElse: () => SubscriptionPlan.free
                  );

                  var sub = await (_isar as dynamic).subscriptions.filter().orgIdEqualTo(orgId).findFirst();
                  if (sub == null) {
                     sub = Subscription()
                       ..orgId = orgId
                       ..createdAt = DateTime.now()
                       ..store = 'sync';
                  }
                  sub.plan = subPlan;
                  sub.status = SubscriptionStatus.active;
                  sub.lastVerifiedAt = DateTime.now();
                  
                  await (_isar as dynamic).subscriptions.put(sub);
               });
            }
         }
       } catch (e) {
         debugPrint('Refresh Org Error: $e');
       }
  }

  @override
  Future<void> updateOrgBilling({
    required String orgId,
    required String? email,
    required bool notifyBilling,
    required bool notifyLimits,
    required bool notifySummary,
  }) async {
    if (_isar != null) {
      await (_isar as dynamic).writeTxn(() async {
        final org = await (_isar as dynamic).organizations.filter().codeEqualTo(orgId).findFirst();
        if (org != null) {
          if (org.billingEmail != email) {
            org.billingEmailVerified = false;
          }
          org.billingEmail = email;
          org.notifyBillingUpdates = notifyBilling;
          org.notifyLimitWarnings = notifyLimits;
          org.notifyMonthlySummary = notifySummary;
          await (_isar as dynamic).organizations.put(org);
        }
      });
    }
  }

  @override
  Future<void> updateOrgPlan(String orgId, String planId) async {
     try {
        await _supabase.from('organizations').update({'plan': planId}).eq('code', orgId);
     } catch (e) {
        debugPrint('Remote Sync Error (updateOrgPlan): $e');
     }

     if (_isar != null) {
       await (_isar as dynamic).writeTxn(() async {
          final org = await (_isar as dynamic).organizations.filter().codeEqualTo(orgId).findFirst();
          if (org != null) {
             org.plan = planId;
             await (_isar as dynamic).organizations.put(org);
          }
       });
     }
  }

  @override
  Future<void> updateOrgName(String orgId, String newName, String newCode) async {
     try {
        await _supabase.from('organizations').update({'name': newName, 'code': newCode}).eq('code', orgId);
     } catch (e) {
        debugPrint('Remote Update ERROR: $e');
     }

     try {
       await _supabase.auth.updateUser(
         UserAttributes(data: {'org_name': newName, 'org_code': newCode}),
       );
     } catch (e) {
       debugPrint('Metadata Update Failed: $e');
     }

     if (_isar != null) {
       await (_isar as dynamic).writeTxn(() async {
          final org = await (_isar as dynamic).organizations.filter().codeEqualTo(orgId).findFirst();
          if (org != null) {
             org.name = newName;
             org.code = newCode;
             await (_isar as dynamic).organizations.put(org);

             final users = await (_isar as dynamic).users.filter().currentOrgIdEqualTo(orgId).findAll();
             for (var u in users) {
                u.currentOrgId = newCode;
                await (_isar as dynamic).users.put(u);
             }

             final policies = await (_isar as dynamic).orgPolicys.filter().orgIdEqualTo(orgId).findAll();
             for (var p in policies) {
                p.orgId = newCode;
                await (_isar as dynamic).orgPolicys.put(p);
             }
          }
       });
     }
  }

  @override
  Future<void> sendBillingVerificationEmail(String orgId) async {
    try {
      final res = await _supabase.functions.invoke('send-verification', body: {
        'org_id': orgId,
      });
      if (res.status != 200) throw Exception('Email gönderilemedi: ${res.data}');
    } catch (e) {
      debugPrint('Verification Email Error: $e');
      throw Exception('Email gönderimi başarısız');
    }
  }
  
  @override
  Future<bool> hasPassword() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;
    final identities = user.identities;
    if (identities == null) return false;
    return identities.any((i) => i.provider == 'email');
  }

  @override
  Future<void> setPassword(String password) async {
    await _supabase.auth.updateUser(UserAttributes(password: password));
  }

  @override
  Future<List<AuditLog>> getAuditLogs(String orgId) async {
    if (_isar != null) {
       return await (_isar as dynamic).auditLogs.filter().orgIdEqualTo(orgId).sortByTimestampDesc().findAll();
    }
    return []; 
  }
}

// Repository Provider
final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  final isar = ref.watch(isarProvider).valueOrNull;
  final supabase = ref.watch(supabaseClientProvider);
  return AuthRepository(isar, supabase);
});

// Permissions Providers
final currentPermissionsProvider = FutureProvider.autoDispose<Set<AppPermission>>((ref) async {
  final user = ref.watch(authControllerProvider).valueOrNull;
  if (user == null) return <AppPermission>{};

  final repo = ref.watch(authRepositoryProvider);
  return await repo.getUserPermissions(user);
});

final permissionsProvider = Provider<Set<AppPermission>>((ref) {
  return ref.watch(currentPermissionsProvider).valueOrNull ?? <AppPermission>{};
});

// Organization members (current org)
final organizationMembersProvider = FutureProvider.autoDispose<List<User>>((ref) async {
  final user = ref.watch(authControllerProvider).valueOrNull;
  if (user == null) return <User>[];

  final repo = ref.watch(authRepositoryProvider);
  return await repo.getOrganizationMembers(user.currentOrgId);
});

// Controller
@riverpod
class AuthController extends _$AuthController {
  @override
  FutureOr<User?> build() async {
    final repo = ref.read(authRepositoryProvider);
    return await repo.getCurrentUser();
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      return await repo.login(email, password);
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      return await repo.signInWithGoogle();
    });
  }

  Future<void> register(String email, String password, String fullName, String orgName) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      return await repo.register(email, password, fullName, orgName);
    });
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logout();
    state = const AsyncValue.data(null);
  }

  Future<void> updateProfile({String? fullName, String? phoneNumber}) async {
    final currentUser = state.valueOrNull;
    if (currentUser == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      await repo.updateProfile(currentUser.id, fullName: fullName, phoneNumber: phoneNumber);
      return await repo.getCurrentUser();
    });
  }

  Future<void> updateAvatar(String path) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.updateAvatar(path);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async => await repo.getCurrentUser());
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.changePassword(currentPassword, newPassword);
  }

  Future<Map<String, dynamic>> exportUserData() async {
    final repo = ref.read(authRepositoryProvider);
    return await repo.exportUserData();
  }

  Future<void> deleteAccount() async {
    state = const AsyncValue.loading();
    await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      await repo.deleteAccount();
    });
    state = const AsyncValue.data(null);
  }
}
