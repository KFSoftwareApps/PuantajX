import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/presentation/setup_organization_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/app_shell.dart';
import '../../features/project/presentation/projects_screen.dart';
import '../../features/project/presentation/workers_screen.dart';
import '../../features/attendance/presentation/attendance_screen.dart';
import '../../features/report/presentation/reports_screen.dart';
import '../../features/report/presentation/daily_report_wizard_screen.dart';
import '../../features/home/presentation/settings_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/report/presentation/report_detail_screen.dart';
import '../../features/auth/presentation/manage_members_screen.dart';
import '../../features/project/presentation/project_detail_screen.dart';
import '../../features/project/presentation/project_settings_screen.dart';
import '../../features/project/presentation/project_members_screen.dart';
import '../../features/project/presentation/project_team_screen.dart';
import '../../features/finance/presentation/payment_summary_screen.dart';
import '../../features/finance/presentation/worker_payment_detail_screen.dart';
import '../../features/settings/presentation/policy_settings_screen.dart';
import '../../features/settings/presentation/user_overrides_screen.dart';
import '../../features/settings/presentation/user_override_editor_screen.dart';
import '../../features/settings/presentation/role_templates_screen.dart';
import '../../features/settings/presentation/role_template_editor_screen.dart';
import '../../features/settings/presentation/audit_log_viewer_screen.dart';
import '../../features/auth/presentation/owner_panel_screen.dart';
import '../../features/settings/presentation/subscription_screen.dart';
import '../../features/settings/presentation/legal_screens.dart';
import '../../features/auth/presentation/organization_info_screen.dart';
import '../../features/settings/presentation/data_settings_screen.dart';
import '../../features/settings/presentation/support_screen.dart';
import '../../features/report/data/models/daily_report_model.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isOnLogin = state.matchedLocation == '/login' || state.matchedLocation == '/register';
    final isOnSetup = state.matchedLocation == '/setup-org';
    
    // 1. Not logged in -> Go to Login
    if (session == null) {
      return isOnLogin ? null : '/login';
    }

    // 2. Logged in, check Org Name
    final metadata = session.user.userMetadata;
    final orgName = metadata?['org_name'];
    
    // Condition: Org Name is missing OR it is 'DEFAULT' (which means auto-repaired placeholder)
    final needsSetup = orgName == null || orgName.toString().trim().isEmpty || orgName == 'DEFAULT';

    if (needsSetup) {
      // If setup is needed but we are not there, go there.
      if (!isOnSetup) return '/setup-org';
      return null; // Already on setup
    }

    // 3. Setup done, but trying to go to Setup or Login -> Go Dashboard
    if (isOnLogin || isOnSetup) {
      return '/dashboard';
    }

    return null; // Allow navigation
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/setup-org',
      builder: (context, state) => const SetupOrganizationScreen(),
    ),
    GoRoute(
      path: '/privacy-policy',
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
    // ... rest of routes remain unchanged from here on ...
    GoRoute(
      path: '/terms-of-service',
      builder: (context, state) => const TermsOfServiceScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: [
        // Dashboard Branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        // Projects Branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/projects',
              builder: (context, state) => const ProjectsScreen(),
              routes: [
                GoRoute(
                  path: 'workers',
                  builder: (context, state) => const WorkersScreen(),
                ),
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootNavigatorKey,
                   builder: (context, state) {
                    final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                    return ProjectDetailScreen(projectId: id);
                  },
                  routes: [
                    GoRoute(
                      path: 'team',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) {
                        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                        return ProjectTeamScreen(projectId: id); 
                      },
                    ),
                    GoRoute(
                      path: 'settings',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) {
                        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                        return ProjectSettingsScreen(projectId: id);
                      },
                    ),
                    GoRoute(
                      path: 'members',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) {
                        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                        return ProjectMembersScreen(projectId: id);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        // Reports Branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/reports',
              builder: (context, state) => const ReportsScreen(),
              routes: [
                GoRoute(
                  path: 'new',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const DailyReportWizardScreen(),
                ),
                GoRoute(
                  path: 'edit',
                  parentNavigatorKey: _rootNavigatorKey,
                    redirect: (_, state) {
                         if (state.extra == null) return '/reports'; // Fallback
                         return null;
                    },
                  builder: (context, state) {
                    final report = state.extra as DailyReport;
                    return DailyReportWizardScreen(initialReport: report);
                  },
                ),
                GoRoute(
                  path: 'payment-summary',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const PaymentSummaryScreen(),
                  routes: [
                    GoRoute(
                      path: ':workerId',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) {
                         final workerId = int.tryParse(state.pathParameters['workerId'] ?? '') ?? 0;
                         final projectId = int.tryParse(state.uri.queryParameters['projectId'] ?? '') ?? 0;
                         return WorkerPaymentDetailScreen(
                           projectId: projectId,
                           workerId: workerId,
                         );
                      },
                    ),
                  ],
                ),
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                    return ReportDetailScreen(reportId: id);
                  },
                ),

              ],
            ),
          ],
        ),
        // Attendance Branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/attendance',
              builder: (context, state) => const AttendanceScreen(),
            ),
          ],
        ),
        // Settings Branch
        StatefulShellBranch(
          routes: [
             GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
              routes: [
                GoRoute(
                  path: 'profile',
                  builder: (context, state) => const ProfileScreen(),
                ),
                GoRoute(
                  path: 'members',
                  builder: (context, state) => const ManageMembersScreen(),
                ),
                GoRoute(
                  path: 'subscription',
                  builder: (context, state) => const SubscriptionScreen(),
                ),
                GoRoute(
                  path: 'data-sync',
                  builder: (context, state) => const DataSettingsScreen(),
                ),
                GoRoute(
                  path: 'organization-info',
                  builder: (context, state) => const OrganizationInfoScreen(),
                ),
                GoRoute(
                  path: 'about', // This matches /settings/about
                  builder: (context, state) => const SupportScreen(),
                ),
                 GoRoute(
                  path: 'privacy-policy',
                  builder: (context, state) => const PrivacyPolicyScreen(),
                ),
                GoRoute(
                  path: 'terms-of-service', 
                  builder: (context, state) => const TermsOfServiceScreen(),
                ),
                GoRoute(
                  path: 'privacy', // Alias for older links if any
                  builder: (context, state) => const PrivacyPolicyScreen(),
                ),
                GoRoute(
                  path: 'owner-panel',
                  builder: (context, state) => const OwnerPanelScreen(),
                  routes: [
                    GoRoute(
                      path: 'policies',
                      builder: (context, state) => const PolicySettingsScreen(),
                    ),
                    GoRoute(
                      path: 'user-overrides',
                      builder: (context, state) => const UserOverridesScreen(),
                      routes: [
                        GoRoute(
                          path: ':userId',
                          builder: (context, state) {
                            final userId = int.tryParse(state.pathParameters['userId'] ?? '') ?? 0;
                            return UserOverrideEditorScreen(userId: userId);
                          },
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'role-templates',
                      builder: (context, state) => const RoleTemplatesScreen(),
                      routes: [
                        GoRoute(
                          path: ':role',
                          builder: (context, state) {
                            final roleStr = state.pathParameters['role'] ?? '';
                            return RoleTemplateEditorScreen(roleStr: roleStr);
                          },
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'audit-logs',
                      builder: (context, state) => const AuditLogViewerScreen(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
