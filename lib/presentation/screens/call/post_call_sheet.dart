import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/services/follow_up_notification_service.dart';
import '../../../data/call_history_store.dart';
import '../../../data/repositories/task_repository_impl.dart';
import '../../../domain/entities/agent_assist_entity.dart';
import '../../../domain/entities/call_entity.dart';
import '../../providers/repository_providers.dart';
import '../../widgets/agent_assist_panel.dart';

/// Bottom sheet shown after a call ends so the agent can tag the outcome,
/// write a quick note, and (optionally) schedule a follow-up.
class PostCallSheet extends ConsumerStatefulWidget {
  final CallEntity call;
  const PostCallSheet({super.key, required this.call});

  @override
  ConsumerState<PostCallSheet> createState() => _PostCallSheetState();
}

class _PostCallSheetState extends ConsumerState<PostCallSheet> {
  late CallDisposition _disposition = widget.call.disposition;
  late final TextEditingController _note =
      TextEditingController(text: widget.call.note ?? '');
  DateTime? _followUp;
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String _fmtDur(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  void _applyAssistSummary(AgentAssistSummary summary) {
    setState(() {
      if (summary.summary.isNotEmpty) _note.text = summary.summary;
      if (summary.suggestedDisposition != null) {
        _disposition = summary.suggestedDisposition!;
      }
    });
  }

  Future<void> _pickFollowUp() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null) return;
    setState(() {
      _followUp = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    await CallHistoryStore.instance.updateMeta(
      widget.call.id,
      note: note,
      disposition: _disposition,
      followUpAt: _followUp,
    );

    await ref.read(callRepositoryProvider).syncWrapUp(
          callId: widget.call.id,
          disposition: _disposition,
          note: note,
          followUpAt: _followUp,
        );

    if (_followUp != null) {
      await FollowUpNotificationService.instance.scheduleForCall(
        widget.call.id,
        _followUp!,
      );
      if (AppConfig.hasBackendConfigured) {
        try {
          await TaskRepositoryImpl().createTask(
            title: 'Follow-up: ${widget.call.displayName ?? widget.call.number}',
            number: widget.call.number,
            dueAt: _followUp,
            callId: widget.call.id,
          );
        } catch (_) {}
      }
    } else if (widget.call.followUpAt != null) {
      await CallHistoryStore.instance.updateMeta(
        widget.call.id,
        clearFollowUp: true,
      );
      await FollowUpNotificationService.instance.cancelForCall(widget.call.id);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final cs = Theme.of(context).colorScheme;
    final call = widget.call;
    final name = call.displayName?.isNotEmpty == true
        ? call.displayName!
        : call.number;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, inset + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AgentAssistSummaryBanner(
              callId: call.id,
              onApply: _applyAssistSummary,
            ),
            Row(children: [
              CircleAvatar(
                backgroundColor: cs.primaryContainer,
                child: Text(name.isEmpty ? '#' : name.substring(0, 1).toUpperCase()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                    Text(
                      call.duration.inSeconds > 0
                          ? '${_label(call.status)}  ·  ${_fmtDur(call.duration)}'
                          : _label(call.status),
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurface.withOpacity(0.6)),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Skip'),
              ),
            ]),
            const SizedBox(height: 16),
            const Text('Outcome',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in CallDisposition.values)
                  ChoiceChip(
                    label: Text(d.label),
                    selected: _disposition == d,
                    onSelected: (_) => setState(() => _disposition = d),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Notes',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Add a quick note about this call…',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Follow-up',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFollowUp,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(_followUp == null
                      ? 'Schedule…'
                      : DateFormat('MMM d, HH:mm').format(_followUp!)),
                ),
              ),
              if (_followUp != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Clear',
                  onPressed: () => setState(() => _followUp = null),
                  icon: const Icon(Icons.close),
                ),
              ],
            ]),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _label(CallStatus s) => switch (s) {
        CallStatus.ended => 'Completed',
        CallStatus.missed => 'Missed',
        CallStatus.failed => 'Failed',
        CallStatus.busy => 'User busy',
        CallStatus.declined => 'Declined',
        CallStatus.noAnswer => 'No answer',
        CallStatus.unavailable => 'Unavailable',
        CallStatus.canceled => 'Cancelled',
        _ => s.name,
      };
}
