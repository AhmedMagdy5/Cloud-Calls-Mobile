import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_config.dart';
import '../../domain/entities/agent_assist_entity.dart';
import '../providers/agent_providers.dart';

/// Real-time agent assist panel (transcript + knowledge search).
class AgentAssistPanel extends ConsumerStatefulWidget {
  final String callId;
  final ValueChanged<String>? onApplyNote;
  final ValueChanged<String>? onSuggestedDisposition;
  const AgentAssistPanel({
    super.key,
    required this.callId,
    this.onApplyNote,
    this.onSuggestedDisposition,
  });

  @override
  ConsumerState<AgentAssistPanel> createState() => _AgentAssistPanelState();
}

class _AgentAssistPanelState extends ConsumerState<AgentAssistPanel> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.enableAgentAssist || !AppConfig.hasBackendConfigured) {
      return const SizedBox.shrink();
    }

    final transcript = ref.watch(callTranscriptProvider(widget.callId));
    final knowledge = ref.watch(knowledgeSearchProvider(_query));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(children: [
            Icon(Icons.auto_awesome, color: Colors.amber, size: 18),
            SizedBox(width: 8),
            Text('Agent Assist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          transcript.when(
            data: (chunks) {
              if (chunks.isEmpty) {
                return Text('Listening…',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12));
              }
              return SizedBox(
                height: 72,
                child: ListView.builder(
                  itemCount: chunks.length,
                  itemBuilder: (_, i) {
                    final c = chunks[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${c.speaker}: ${c.text}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
            ),
            error: (_, __) => const Text('Transcript unavailable',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _search,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search knowledge base…',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
              prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onSubmitted: (v) => setState(() => _query = v.trim()),
          ),
          knowledge.when(
            data: (results) {
              if (results.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final r in results.take(3))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(r, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.note_add_outlined, size: 18, color: Colors.white54),
                          onPressed: () => widget.onApplyNote?.call(r),
                        ),
                      ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Post-call AI summary chip row.
class AgentAssistSummaryBanner extends ConsumerWidget {
  final String callId;
  final void Function(AgentAssistSummary summary) onApply;
  const AgentAssistSummaryBanner({
    super.key,
    required this.callId,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!AppConfig.enableAgentAssist || !AppConfig.hasBackendConfigured) {
      return const SizedBox.shrink();
    }
    final summary = ref.watch(callAssistSummaryProvider(callId));
    return summary.when(
      data: (s) {
        if (s == null || s.summary.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.35),
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              leading: const Icon(Icons.summarize_outlined),
              title: const Text('AI suggested wrap-up'),
              subtitle: Text(s.summary, maxLines: 3, overflow: TextOverflow.ellipsis),
              trailing: TextButton(
                onPressed: () => onApply(s),
                child: const Text('Apply'),
              ),
            ),
          ),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
