import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/biometric_provider.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/biometric_login_screen.dart';
import '../features/common/loading_screen.dart';
import '../features/auth/chauffeur_home.dart';
import '../features/declaration/declarations_list.dart';
import '../features/declaration/create_declaration.dart';
import '../features/declaration/declaration_detail.dart';
import '../features/declaration/voice_agent.dart';
import '../features/checklist/checklist_view.dart';
import '../features/tournee/tournee_view.dart';
import '../features/tracking/tracking_view.dart';
import '../features/documents/documents_view.dart';
import '../features/anomalies/anomalies_view.dart';
import '../features/checkup/checkup_view.dart';
import '../features/maintenance/tickets_view.dart';
import '../features/alerts/alerts_view.dart';
import '../features/admin/audit_log_view.dart';
import '../features/auth/prestataire_dashboard.dart';
import '../features/auth/rs_dashboard.dart';
import '../features/auth/rs_declarations.dart';
import '../features/budget/budget_view.dart';
import '../features/analytics/powerbi_view.dart';
import '../features/admin/admin_home.dart';
import '../features/admin/admin_biometric_screen.dart';
import '../features/admin/users_crud.dart';
import '../features/admin/vehicles_crud.dart';
import '../features/admin/admin_affectations.dart';
import '../features/auth/sl_dashboard.dart';
import '../features/auth/settings_screen.dart';
import '../features/auth/chauffeur_profile_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/complaints/complaint_view.dart';
import '../features/photo/photo_capture_screen.dart';

GoRouter createRouter(AuthProvider auth, BiometricProvider biometric) {
  final isLoggedIn = auth.status == AuthStatus.authenticated;
  final role = auth.user?['role'] as String?;
  final biometricEnabled = biometric.status == BiometricStatus.enrolled;

  return GoRouter(
    initialLocation: isLoggedIn
        ? _homeRoute(role)
        : biometricEnabled
            ? '/biometric-login'
            : '/login',
    redirect: (context, state) {
      final authProv = context.read<AuthProvider>();
      final bioProv = context.read<BiometricProvider>();
      final loggedIn = authProv.status == AuthStatus.authenticated;
      final loggingIn = state.matchedLocation == '/login';
      final biometricLogin = state.matchedLocation == '/biometric-login';
      if (!loggedIn && !loggingIn && !biometricLogin) {
        if (bioProv.status == BiometricStatus.enrolled) return '/biometric-login';
        return '/login';
      }
      if (loggedIn && loggingIn) {
        return _homeRoute(authProv.user?['role'] as String?);
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/biometric-login', builder: (_, __) => const BiometricLoginScreen()),
      GoRoute(path: '/loading', builder: (_, __) => const LoadingScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/chauffeur',
        builder: (_, __) => const ChauffeurHome(),
        routes: [
          GoRoute(
              path: 'declarations',
              builder: (_, __) => const DeclarationsList(),),
          GoRoute(
              path: 'declarations/create',
              builder: (_, __) => const CreateDeclaration(),),
          GoRoute(
              path: 'declarations/:id',
              builder: (_, state) => DeclarationDetail(id: int.parse(state.pathParameters['id']!)),),
          GoRoute(path: 'voice', builder: (_, __) => const VoiceAgent()),
          GoRoute(path: 'checklist', builder: (_, __) => const ChecklistView()),
          GoRoute(path: 'tournees', builder: (_, __) => const TourneeView()),
          GoRoute(path: 'documents', builder: (_, __) => const DocumentsView()),
          GoRoute(path: 'settings', builder: (_, __) => const SettingsScreen()),
          GoRoute(path: 'photo', builder: (_, __) => const PhotoCaptureScreen()),
          GoRoute(path: 'profile', builder: (_, __) => const ChauffeurProfileScreen()),
          GoRoute(path: 'complaints', builder: (_, __) => const ComplaintView()),
        ],
      ),
      GoRoute(
        path: '/prestataire',
        builder: (_, __) => const PrestataireDashboard(),
        routes: [
          GoRoute(path: 'tickets', builder: (_, __) => const TicketsView()),
          GoRoute(path: 'anomalies', builder: (_, __) => const AnomaliesView()),
          GoRoute(path: 'settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
      GoRoute(
        path: '/rs',
        builder: (_, __) => const RsDashboard(),
        routes: [
          GoRoute(path: 'budget', builder: (_, __) => const BudgetView()),
          GoRoute(path: 'powerbi', builder: (_, __) => const PowerBiView()),
          GoRoute(path: 'anomalies', builder: (_, __) => const AnomaliesView()),
          GoRoute(path: 'checkups', builder: (_, __) => const CheckupView()),
          GoRoute(path: 'tickets', builder: (_, __) => const TicketsView()),
          GoRoute(path: 'documents', builder: (_, __) => const DocumentsView()),
          GoRoute(path: 'alerts', builder: (_, __) => const AlertsView()),
          GoRoute(path: 'tracking', builder: (_, __) => const TrackingView()),
          GoRoute(path: 'declarations', builder: (_, __) => const RsDeclarations()),
          GoRoute(path: 'audit', builder: (_, __) => const AuditLogView()),
          GoRoute(path: 'settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
      GoRoute(
        path: '/sl',
        builder: (_, __) => const SlDashboard(),
        routes: [
          GoRoute(path: 'alerts', builder: (_, __) => const AlertsView()),
          GoRoute(path: 'tracking', builder: (_, __) => const TrackingView()),
          GoRoute(path: 'tournees', builder: (_, __) => const TourneeView()),
          GoRoute(path: 'settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
      GoRoute(
        path: '/admin',
        builder: (_, __) => const AdminHome(),
        routes: [
          GoRoute(path: 'users', builder: (_, __) => const UsersCrud()),
          GoRoute(path: 'vehicles', builder: (_, __) => const VehiclesCrud()),
          GoRoute(path: 'audit', builder: (_, __) => const AuditLogView()),
          GoRoute(path: 'biometric', builder: (_, __) => const AdminBiometricScreen()),
          GoRoute(path: 'documents', builder: (_, __) => const DocumentsView()),
          GoRoute(path: 'alerts', builder: (_, __) => const AlertsView()),
          GoRoute(path: 'checkups', builder: (_, __) => const CheckupView()),
          GoRoute(path: 'affectations', builder: (_, __) => const AdminAffectations()),
          GoRoute(path: 'settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
    ],
  );
}

String _homeRoute(String? role) {
  switch (role) {
    case 'CHAUFFEUR':
      return '/chauffeur';
    case 'PRESTATAIRE':
      return '/prestataire';
    case 'RS':
      return '/rs';
    case 'SL':
      return '/sl';
    case 'ADMIN':
      return '/admin';
    case 'MAINTENANCE':
      return '/prestataire';
    case 'RPF':
      return '/rs';
    case 'DRL':
      return '/rs';
    default:
      return '/login';
  }
}
