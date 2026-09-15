import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../data/call_history_store.dart';
import '../../../domain/entities/call_entity.dart';
import '../../providers/call_provider.dart';
import '../../../core/constants/app_config.dart';
import '../../providers/repository_providers.dart';

enum _Filter { all, incoming, outgoing, missed }

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _store = CallHistoryStore.instance;
  _Filter _filter = _Filter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _store.load();
    _store.addListener(_onChange);
    Future.microtask(() {
      if (AppConfig.hasBackendConfigured) {
        ref.read(callRepositoryProvider).fetchRemoteHistory();
      }
    });
  }

  @override
  void dispose() {
    _store.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() { if (mounted) setState(() {}); }

  Future<void> _redial(CallEntity c) async {
    try {
      await ref.read(callProvider).dial(c.number);
      if (mounted) context.push('/call/active');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())));
      }
    }
  }

  bool _matchesFilter(CallEntity c) {
    switch (_filter) {
      case _Filter.all: return true;
      case _Filter.incoming:
        return c.direction == CallDirection.incoming &&
            c.status != CallStatus.missed;
      case _Filter.outgoing:
        return c.direction == CallDirection.outgoing;
      case _Filter.missed:
        return c.status == CallStatus.missed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final items = _store.items.where((c) {
      if (!_matchesFilter(c)) return false;
      if (q.isEmpty) return true;
      return (c.displayName ?? '').toLowerCase().contains(q) ||
          c.number.toLowerCase().contains(q);
    }).toList();

    final stats = _store.todayStats();
    final followUps = _store.pendingFollowUps();

    return Column(children: [
      _TodayStatsCard(stats: stats, followUpCount: followUps.length),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'Search history',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),

      SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (final f in _Filter.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(_label(f)),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                ),
              ),
            const SizedBox(width: 8),
            if (_store.items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ActionChip(
                  avatar: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Clear'),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Clear history?'),
                            content: const Text(
                                'All call records will be deleted.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Clear')),
                            ],
                          ),
                        ) ??
                        false;
                    if (ok) await _store.clear();
                  },
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: items.isEmpty
            ? const Center(
                child: Text('No calls yet', style: TextStyle(color: Colors.grey)),
              )
            : ListView.separated(
                itemCount: items.length,
                padding: const EdgeInsets.symmetric(vertical: 4),
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 76),
                itemBuilder: (_, i) => _HistoryTile(
                  call: items[i],
                  onRedial: () => _redial(items[i]),
                  onDelete: () => _store.remove(items[i].id),
                ),
              ),
      ),
    ]);
  }

  String _label(_Filter f) => switch (f) {
        _Filter.all => 'All',
        _Filter.incoming => 'Incoming',
        _Filter.outgoing => 'Outgoing',
        _Filter.missed => 'Missed',
      };
}

class _HistoryTile extends StatelessWidget {
  final CallEntity call;
  final VoidCallback onRedial;
  final VoidCallback onDelete;
  const _HistoryTile({
    required this.call,
    required this.onRedial,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final missed = call.status == CallStatus.missed;
    final incoming = call.direction == CallDirection.incoming;
    final IconData dirIcon = missed
        ? Icons.call_missed
        : incoming
            ? Icons.call_received
            : Icons.call_made;
    final Color dirColor = missed
        ? Colors.redAccent
        : incoming
            ? Colors.green
            : Colors.blueAccent;
    final title = call.displayName?.isNotEmpty == true
        ? call.displayName!
        : call.number;
    final duration = call.duration;
    final hasDuration = call.answeredAt != null && duration.inSeconds > 0;
    final dateLabel = _formatDate(call.startedAt);

    return Dismissible(
      key: ValueKey(call.id + call.startedAt.toIso8601String()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: Colors.red.shade600,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        onTap: onRedial,
        onLongPress: () => _showCallDetailSheet(context, call),
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          foregroundColor: cs.onPrimaryContainer,
          child: Text(title.isEmpty ? '#' : title.substring(0, 1).toUpperCase()),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: missed ? Colors.redAccent : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(dirIcon, size: 14, color: dirColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  hasDuration
                      ? '${call.number}  ·  ${_fmtDur(duration)}'
                      : call.number,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            if (call.disposition != CallDisposition.none ||
                (call.note?.isNotEmpty == true) ||
                call.followUpAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (call.disposition != CallDisposition.none)
                      _MiniChip(
                        icon: Icons.label_outline,
                        label: call.disposition.label,
                        color: cs.primary,
                      ),
                    if (call.followUpAt != null)
                      _MiniChip(
                        icon: Icons.event,
                        label: 'Follow-up ${DateFormat('MMM d HH:mm').format(call.followUpAt!)}',
                        color: Colors.orange.shade700,
                      ),
                    if (call.note?.isNotEmpty == true)
                      _MiniChip(
                        icon: Icons.sticky_note_2_outlined,
                        label: call.note!.length > 28
                            ? '${call.note!.substring(0, 28)}…'
                            : call.note!,
                        color: cs.onSurface.withOpacity(0.7),
                      ),
                  ],
                ),
              ),
          ],
        ),

        trailing: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(dateLabel,
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              InkWell(
                onTap: onRedial,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.call,
                      size: 18, color: Color(0xFF22C55E)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final isToday = now.year == d.year && now.month == d.month && now.day == d.day;
    final ydayD = now.subtract(const Duration(days: 1));
    final isYday =
        ydayD.year == d.year && ydayD.month == d.month && ydayD.day == d.day;
    if (isToday) return DateFormat('HH:mm').format(d);
    if (isYday) return 'Yesterday';
    return DateFormat('MMM d').format(d);
  }

  String _fmtDur(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniChip({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _TodayStatsCard extends StatelessWidget {
  final ({int total, int incoming, int outgoing, int missed, Duration talkTime}) stats;
  final int followUpCount;
  const _TodayStatsCard({required this.stats, required this.followUpCount});

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary.withOpacity(0.95), cs.primary.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.today, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Text("Today",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            const Spacer(),
            if (followUpCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.event, size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text('$followUpCount follow-up${followUpCount == 1 ? '' : 's'}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _Stat(label: 'Total', value: '${stats.total}'),
            _Stat(label: 'In', value: '${stats.incoming}'),
            _Stat(label: 'Out', value: '${stats.outgoing}'),
            _Stat(label: 'Missed', value: '${stats.missed}'),
            _Stat(label: 'Talk', value: _fmt(stats.talkTime)),
          ]),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()])),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ]),
    );
  }
}

void _showCallDetailSheet(BuildContext context, CallEntity call) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CallDetailSheet(call: call),
  );
}

class _CallDetailSheet extends StatefulWidget {
  final CallEntity call;
  const _CallDetailSheet({required this.call});
  @override
  State<_CallDetailSheet> createState() => _CallDetailSheetState();
}

class _CallDetailSheetState extends State<_CallDetailSheet> {
  late CallDisposition _disp = widget.call.disposition;
  late final _note = TextEditingController(text: widget.call.note ?? '');
  late DateTime? _followUp = widget.call.followUpAt;

  Future<void> _pickFollowUp() async {
    final now = DateTime.now();
    final initial = _followUp ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    setState(() => _followUp = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _save() async {
    await CallHistoryStore.instance.updateMeta(
      widget.call.id,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      disposition: _disp,
      followUpAt: _followUp,
      clearFollowUp: _followUp == null,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, inset + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.call.displayName?.isNotEmpty == true
              ? widget.call.displayName!
              : widget.call.number,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text(widget.call.number,
              style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
          const SizedBox(height: 16),
          const Text('Outcome', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final d in CallDisposition.values)
              ChoiceChip(label: Text(d.label), selected: _disp == d, onSelected: (_) => setState(() => _disp = d)),
          ]),
          const SizedBox(height: 16),
          const Text('Notes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Add details about this call…',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Follow-up', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
              IconButton(onPressed: () => setState(() => _followUp = null), icon: const Icon(Icons.close)),
            ],
          ]),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _save, child: const Text('Save')),
          ),
        ]),
      ),
    );
  }
}
