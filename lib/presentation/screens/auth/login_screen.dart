import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../../features/sip/sip_service.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/services/backend_settings_service.dart';
import '../../../core/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _domain = TextEditingController();
  bool _obscure = true;
  bool _prefilled = false;
  bool _rememberLogin = true;
  bool _useBackendAuth = false;

  bool get _backendAvailable => BackendSettingsService.instance.isConfigured;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final saved = await ref.read(sipRepoProvider).load();
      final remember = ref.read(sipRepoProvider).shouldSaveLogin;
      if (!mounted) return;
      setState(() {
        _rememberLogin = remember;
        if (saved != null) {
          _user.text = saved.username;
          _domain.text = saved.server.isNotEmpty
              ? saved.server
              : AppConfig.sipServer;
          if (saved.password.isNotEmpty) _pass.text = saved.password;
          _prefilled = true;
        } else {
          _domain.text = AppConfig.sipServer;
        }
      });
    });
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _domain.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final ok = _useBackendAuth && _backendAvailable
        ? await ref.read(authProvider.notifier).loginWithBackend(
              username: _user.text.trim(),
              password: _pass.text,
              rememberLogin: _rememberLogin,
            )
        : await ref.read(authProvider.notifier).loginWithSip(
              username: _user.text.trim(),
              password: _pass.text,
              domain: _domain.text.trim(),
              rememberLogin: _rememberLogin,
            );
    if (!mounted) return;
    if (ok) {
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(authProvider).error ?? 'Login failed'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final sip = ref.watch(sipStatusProvider);
    final registering = sip.status == SipStatus.registering ||
        sip.status == SipStatus.reconnecting;
    final sipMode = !_useBackendAuth || !_backendAvailable;

    return Theme(
      data: AppTheme.dark,
      child: Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          Positioned(
            top: -120, left: -80,
            child: _Orb(size: 280, color: const Color(0xFF4F46E5).withOpacity(0.20)),
          ),
          Positioned(
            bottom: -140, right: -100,
            child: _Orb(size: 320, color: const Color(0xFF6366F1).withOpacity(0.15)),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.brandPrimary.withOpacity(0.45),
                              blurRadius: 40,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/icons/app_logo.png',
                          width: 84,
                          height: 84,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.8,
                          ),
                          children: const [
                            TextSpan(text: 'Awfar '),
                            TextSpan(
                              text: 'CC',
                              style: TextStyle(color: Color(0xFF818CF8)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Welcome back',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sipMode
                          ? 'Connect to your PBX with extension and server address'
                          : 'Sign in with your agent account (API)',
                      style: GoogleFonts.dmSans(
                        color: AppTheme.textMuted,
                        fontSize: 14,
                      ),
                    ),
                    if (_backendAvailable) ...[
                      const SizedBox(height: 12),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('PBX / SIP'),
                            icon: Icon(Icons.dialpad),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('Backend API'),
                            icon: Icon(Icons.cloud),
                          ),
                        ],
                        selected: {_useBackendAuth},
                        onSelectionChanged: (s) =>
                            setState(() => _useBackendAuth = s.first),
                      ),
                    ],
                    if (_prefilled) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Loaded saved configuration',
                        style: GoogleFonts.dmSans(
                          color: const Color(0xFF818CF8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.borderDark, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _user,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: sipMode ? 'Extension' : 'Username',
                              hintText: sipMode ? 'e.g. 200' : null,
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _pass,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Required' : null,
                          ),
                          if (sipMode) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _domain,
                              decoration: const InputDecoration(
                                labelText: 'PBX Server (IP or domain)',
                                hintText: AppConfig.sipServer,
                                prefixIcon: Icon(Icons.dns_outlined),
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 4),
                          ],
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _rememberLogin,
                            onChanged: (v) =>
                                setState(() => _rememberLogin = v ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: AppTheme.brandPrimary,
                            title: Text(
                              'Save login on this device',
                              style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              'Keep it off on shared phones.',
                              style: GoogleFonts.dmSans(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (registering)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(children: [
                          const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.brandPrimary)),
                          const SizedBox(width: 10),
                          Text(sip.statusLabel,
                              style: const TextStyle(color: AppTheme.brandPrimary)),
                        ]),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.brandPrimary.withOpacity(0.4),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: FilledButton(
                        onPressed: (auth.loading || registering) ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.brandPrimary,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: (auth.loading || registering)
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(
                                'Sign in',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await context.push('/settings/sip');
                        if (mounted) setState(() {});
                      },
                      icon: const Icon(Icons.tune, color: AppTheme.textMuted),
                      label: Text(
                        'SIP Account & API settings',
                        style: GoogleFonts.dmSans(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        side: const BorderSide(color: AppTheme.borderDark),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
        gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
      ),
    );
  }
}
