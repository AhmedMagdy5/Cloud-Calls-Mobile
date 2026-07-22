import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/splash_screen.dart';
import '../../presentation/screens/auth/onboarding_screen.dart';
import '../../presentation/screens/home/home_shell.dart';
import '../../presentation/screens/dialer/dialer_screen.dart';
import '../../presentation/screens/call/active_call_screen.dart';
import '../../presentation/screens/call/incoming_call_screen.dart';
import '../../presentation/screens/history/history_screen.dart';
import '../../presentation/screens/contacts/contacts_screen.dart';

import '../../presentation/screens/chat/chat_screen.dart';
import '../../presentation/screens/tasks/tasks_screen.dart';
import '../../presentation/screens/supervisor/supervisor_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/settings/sip_settings_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/about/about_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeShell()),
      GoRoute(path: '/dialer', builder: (_, __) => const DialerScreen()),
      GoRoute(path: '/call/active', builder: (_, __) => const ActiveCallScreen()),
      GoRoute(path: '/call/incoming', builder: (_, __) => const IncomingCallScreen()),
      GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
      GoRoute(path: '/contacts', builder: (_, __) => const ContactsScreen()),
      
      GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
      GoRoute(path: '/tasks', builder: (_, __) => const TasksScreen()),
      GoRoute(path: '/supervisor', builder: (_, __) => const SupervisorScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/settings/sip', builder: (_, __) => const SipSettingsScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/about', builder: (_, __) => const AboutScreen()),
    ],
  );
});
