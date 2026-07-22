import 'package:flutter/material.dart';
import '../../../core/constants/app_config.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('About')),
    body: Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.phone_in_talk_rounded, size: 80),
        const SizedBox(height: 16),
        Text(AppConfig.appName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Version ${AppConfig.appVersion}'),
        const SizedBox(height: 16),
        const Text('Enterprise VoIP Softphone', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 32),
        Text(
          'Powered by Awfar',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Designed & Developed by Eng. Ahmed Magdy',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ]),
    ),
  );
}
