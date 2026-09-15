import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/rbac_provider.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/services/storage_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late bool _autoDialFromShare =
      StorageService.getBool(StorageKeys.autoDialFromShare);

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final rbac = ref.watch(rbacProvider);
    final s = context.s;

    String currentLanguageLabel() {
      if (locale == null) return s.languageSystem;
      return locale.languageCode == 'ar' ? s.languageArabic : s.languageEnglish;
    }

    Future<void> pickLanguage() async {
      await showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (ctx) {
          Widget tile(String title, Locale? value) {
            final selected = (value?.languageCode) == (locale?.languageCode);
            return ListTile(
              leading: const Icon(Icons.language),
              title: Text(title),
              trailing: selected ? const Icon(Icons.check, color: Colors.green) : null,
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(localeProvider.notifier).set(value);
              },
            );
          }
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(s.language,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                ),
                tile(s.languageSystem, null),
                tile(s.languageEnglish, const Locale('en')),
                tile(s.languageArabic, const Locale('ar')),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(child: Column(children: [
          ListTile(leading: const Icon(Icons.person_outline), title: Text(s.profile), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/profile')),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.dns_outlined), title: Text(s.sipAccount), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/settings/sip')),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.notifications_outlined), title: Text(s.notifications), trailing: const Icon(Icons.chevron_right), onTap: () {}),
        ])),
        const SizedBox(height: 12),
        Card(child: Column(children: [
          ListTile(leading: const Icon(Icons.task_alt), title: const Text('Tasks & follow-ups'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/tasks')),
          if (AppConfig.hasBackendConfigured) ...[
            const Divider(height: 1),
            ListTile(leading: const Icon(Icons.chat_bubble_outline), title: const Text('Team chat'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/chat')),
            if (rbac.canUseSupervisorTools) ...[
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.supervisor_account), title: const Text('Supervisor board'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/supervisor')),
            ],
          ],
        ])),
        const SizedBox(height: 12),
        Card(child: Column(children: [
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(s.theme),
            trailing: DropdownButton<ThemeMode>(
              value: mode, underline: const SizedBox(),
              items: [
                DropdownMenuItem(value: ThemeMode.system, child: Text(s.themeSystem)),
                DropdownMenuItem(value: ThemeMode.light, child: Text(s.themeLight)),
                DropdownMenuItem(value: ThemeMode.dark, child: Text(s.themeDark)),
              ],
              onChanged: (v) => v == null ? null : ref.read(themeModeProvider.notifier).set(v),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(s.language),
            trailing: Text(currentLanguageLabel()),
            onTap: pickLanguage,
          ),
        ])),
        const SizedBox(height: 12),
        Card(child: Column(children: [
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.share_outlined),
            title: Text(s.autoDialFromShare),
            subtitle: Text(s.autoDialFromShareSub),
            value: _autoDialFromShare,
            onChanged: (v) async {
              setState(() => _autoDialFromShare = v);
              await StorageService.setBool(StorageKeys.autoDialFromShare, v);
            },
          ),
        ])),
        const SizedBox(height: 12),
        Card(child: Column(children: [
          ListTile(leading: const Icon(Icons.info_outline), title: Text(s.about), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/about')),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(s.signOut, style: const TextStyle(color: Colors.red)),
            onTap: () async { await ref.read(authProvider.notifier).logout(); if (context.mounted) context.go('/login'); },
          ),
        ])),
      ],
    );
  }
}
