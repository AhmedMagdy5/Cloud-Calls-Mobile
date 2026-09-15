import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _idx = 0;

  final _pages = const [
    _OnbData(Icons.phone_in_talk_rounded, 'Crystal-clear HD calls',
        'Enterprise-grade VoIP powered by SIP & WebRTC'),
    _OnbData(Icons.shield_outlined, 'Secure & encrypted',
        'TLS + SRTP keep every conversation private'),
    _OnbData(Icons.cloud_done_outlined, 'Connect to your PBX',
        'Works with Asterisk, 3CX, and any SIP PBX'),
  ];

  Future<void> _finish() async {
    await StorageService.setBool(StorageKeys.onboardingDone, true);
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          Positioned(
            top: -100, right: -80,
            child: _Orb(size: 280, color: const Color(0xFF4F46E5).withOpacity(0.22)),
          ),
          Positioned(
            bottom: -120, left: -100,
            child: _Orb(size: 320, color: const Color(0xFF6366F1).withOpacity(0.15)),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: AlignmentDirectional.topEnd,
                  child: TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Skip',
                      style: GoogleFonts.dmSans(
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _ctrl,
                    onPageChanged: (i) => setState(() => _idx = i),
                    itemCount: _pages.length,
                    itemBuilder: (_, i) {
                      final p = _pages[i];
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                gradient: AppTheme.brandGradient,
                                borderRadius: BorderRadius.circular(36),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.brandPrimary.withOpacity(0.5),
                                    blurRadius: 40,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Icon(p.icon, size: 64, color: Colors.white),
                            ),
                            const SizedBox(height: 48),
                            Text(
                              p.title,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.6,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              p.subtitle,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.dmSans(
                                fontSize: 15,
                                color: AppTheme.textMuted,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 6,
                      width: i == _idx ? 28 : 6,
                      decoration: BoxDecoration(
                        gradient: i == _idx ? AppTheme.brandGradient : null,
                        color: i == _idx ? null : Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.brandPrimary.withOpacity(0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: FilledButton(
                      onPressed: () {
                        if (_idx == _pages.length - 1) {
                          _finish();
                        } else {
                          _ctrl.nextPage(
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeOut);
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.brandPrimary,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        _idx == _pages.length - 1 ? 'Get Started' : 'Continue',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnbData {
  final IconData icon;
  final String title;
  final String subtitle;
  const _OnbData(this.icon, this.title, this.subtitle);
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
        gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
      ),
    );
  }
}
