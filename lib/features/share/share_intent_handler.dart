import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../core/services/storage_service.dart';
import '../../features/caller_id/caller_lookup_service.dart';

/// Pending number to pre-fill the dialer after a share intent.
final dialerPrefillProvider = StateProvider<String?>((ref) => null);

/// Handles tel: / text share intents and routes to dialer or auto-call.
class ShareIntentHandler {
  ShareIntentHandler._();
  static final instance = ShareIntentHandler._();

  static const _channel = MethodChannel('com.awfar.cloudcalls/share');

  void Function(String number, bool autoDial)? onShareDial;
  StreamSubscription<List<SharedMediaFile>>? _mediaSub;

  static final _phoneRe = RegExp(
    r'(\+?\d[\d\s\-\(\)]{5,}\d|\d{4,})',
  );

  static String? extractPhone(String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith('tel:')) {
      return CallerLookupService.normalize(trimmed.substring(4));
    }
    final match = _phoneRe.firstMatch(trimmed);
    if (match == null) return null;
    final raw = match.group(0)!;
    final normalized = CallerLookupService.normalize(raw);
    return normalized.isEmpty ? null : normalized;
  }

  Future<void> init() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShare') {
        _handleShare(call.arguments?.toString() ?? '');
      }
    });

    try {
      final initial = await ReceiveSharingIntent.instance.getInitialMedia();
      for (final file in initial) {
        _handleShare(_textFromMedia(file));
      }
      if (initial.isNotEmpty) {
        await ReceiveSharingIntent.instance.reset();
      }
    } catch (e) {
      debugPrint('[ShareIntent] initial media error: $e');
    }

    _mediaSub = ReceiveSharingIntent.instance.getMediaStream().listen((files) {
      for (final file in files) {
        _handleShare(_textFromMedia(file));
      }
    }, onError: (e) => debugPrint('[ShareIntent] stream error: $e'));
  }

  String _textFromMedia(SharedMediaFile file) {
    if (file.type == SharedMediaType.text || file.type == SharedMediaType.url) {
      return file.path;
    }
    return file.path;
  }

  void _handleShare(String text) {
    if (text.trim().isEmpty) return;
    final phone = extractPhone(text);
    if (phone == null || phone.isEmpty) return;
    final autoDial = StorageService.getBool(StorageKeys.autoDialFromShare);
    onShareDial?.call(phone, autoDial);
  }

  void dispose() {
    _mediaSub?.cancel();
    _mediaSub = null;
  }
}
