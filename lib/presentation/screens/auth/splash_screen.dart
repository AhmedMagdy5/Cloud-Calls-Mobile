import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    unawaited(_boot());
  }

  Future<void> _boot() async {
    final onboarded = StorageService.getBool(StorageKeys.onboardingDone);
    if (!onboarded) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      context.go('/onboarding');
      return;
    }

    // Parallel: minimum splash feel + restore saved SIP session.
    final restored = await Future.wait([
      Future<void>.delayed(const Duration(milliseconds: 700)),
      ref.read(authProvider.notifier).tryRestoreSession(),
    ]).then((r) => r[1] as bool);

    if (!mounted) return;
    context.go(restored ? '/home' : '/login');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          // Radial glow
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.8,
                  colors: [
                    const Color(0xFF4F46E5).withOpacity(0.25),
                    AppTheme.bgDark,
                  ],
                ),
              ),
            ),
          ),
          // Floating orb top
          Positioned(
            top: -120,
            left: -80,
            child: _Orb(size: 280, color: const Color(0xFF4F46E5).withOpacity(0.18)),
          ),
          Positioned(
            bottom: -100,
            right: -90,
            child: _Orb(size: 240, color: const Color(0xFF6366F1).withOpacity(0.14)),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: Tween<double>(begin: 0.75, end: 1.0).animate(_ctrl),
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.brandPrimary.withOpacity(0.45),
                          blurRadius: 60,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/icons/app_logo.png',
                      width: 150,
                      height: 150,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.2,
                      color: Colors.white,
                    ),
                    children: [
                      const TextSpan(text: 'Awfar '),
                      TextSpan(
                        text: 'CC',
                        style: TextStyle(
                          foreground: Paint()
                            ..shader = const LinearGradient(
                              colors: [Color(0xFF818CF8), Color(0xFF4F46E5)],
                            ).createShader(const Rect.fromLTWH(0, 0, 80, 40)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enterprise VoIP Softphone',
                  style: GoogleFonts.dmSans(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          // Slim progress line at bottom
          Positioned(
            left: 0, right: 0, bottom: 40,
            child: Center(
              child: SizedBox(
                width: 140,
                height: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: const AlwaysStoppedAnimation(AppTheme.brandPrimary),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
        ),
      ),
    );
  }
}
