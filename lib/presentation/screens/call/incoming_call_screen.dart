import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/call_provider.dart';
import '../../providers/agent_providers.dart';
import '../../widgets/customer_card.dart';
import '../../widgets/caller_info_card.dart';
import '../../../domain/entities/call_entity.dart';
import '../../../features/caller_id/caller_lookup_service.dart';
import '../../../core/i18n/app_strings.dart';

class IncomingCallScreen extends ConsumerStatefulWidget {
  const IncomingCallScreen({super.key});

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen> {
  String? _cachedName;
  String? _cachedNumber;

  void _cacheCaller(CallEntity? call) {
    if (call == null) return;
    if (call.displayName?.isNotEmpty == true) _cachedName = call.displayName;
    if (call.number.isNotEmpty) _cachedNumber = call.number;
  }

  bool _shouldDismiss(CallEntity? call) {
    if (call == null) return true;
    if (call.direction != CallDirection.incoming) return true;
    if (call.answeredAt != null) return false;
    return call.status.isTerminal;
  }

  void _leaveIncomingScreen() {
    if (!mounted) return;
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CallController>(callProvider, (prev, next) {
      final call = next.current;
      _cacheCaller(call);
      if (_shouldDismiss(call)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _leaveIncomingScreen());
      }
    });

    final c = ref.watch(callProvider);
    final call = c.current;
    _cacheCaller(call);

    if (_shouldDismiss(call)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _leaveIncomingScreen());
    }

    final number = call?.number.isNotEmpty == true ? call!.number : (_cachedNumber ?? '');
    final label = call?.displayName?.isNotEmpty == true
        ? call!.displayName!
        : (number.isNotEmpty ? number : (_cachedName ?? 'Unknown'));

    final customer = number.isNotEmpty
        ? ref.watch(customerLookupProvider(number))
        : const AsyncValue.data(null);

    final callerInfo = number.isNotEmpty
        ? ref.watch(callerLookupProvider(number))
        : const AsyncValue.data(CallerInfo(number: ''));

    final s = context.s;
    final isVip = callerInfo.maybeWhen(
      data: (info) => info.isVip,
      orElse: () => false,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: DecoratedBox(
        decoration: isVip
            ? BoxDecoration(
                color: const Color(0xFF0F172A),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withOpacity(0.85),
                  width: 3,
                ),
              )
            : const BoxDecoration(color: Color(0xFF0F172A)),
        child: SafeArea(
        child: Column(children: [
          const SizedBox(height: 40),
          Text(s.incomingCall,
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
          const SizedBox(height: 24),
          CircleAvatar(
            radius: 70,
            backgroundColor: Colors.white.withOpacity(0.12),
            child: const Icon(Icons.person, size: 80, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w600),
          ),
          if (number.isNotEmpty && label != number)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                number,
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
              ),
            ),
          callerInfo.when(
            data: (info) => Padding(
              padding: const EdgeInsets.only(top: 16),
              child: CallerInfoCard(info: info),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
              ),
            ),
            error: (_, __) => const SizedBox(height: 8),
          ),
          customer.when(
            data: (cust) => cust == null
                ? const SizedBox(height: 16)
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: CustomerCard(customer: cust),
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: Colors.white54),
            ),
            error: (_, __) => const SizedBox(height: 16),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _Btn(
                color: Colors.red,
                icon: Icons.call_end,
                label: s.decline,
                onTap: () {
                  c.hangup();
                  _leaveIncomingScreen();
                },
              ),
              _Btn(
                color: Colors.green,
                icon: Icons.call,
                label: s.accept,
                onTap: () {
                  c.answer();
                  context.go('/call/active');
                },
              ),
            ]),
          ),
        ]),
      ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Btn({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Column(children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 34),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ]);
}
