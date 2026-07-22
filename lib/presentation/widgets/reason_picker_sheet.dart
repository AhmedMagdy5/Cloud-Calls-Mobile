import 'package:flutter/material.dart';
import '../../core/i18n/app_strings.dart';
import '../../domain/entities/break_reason.dart';

/// Bottom sheet that prompts the agent to pick a reason before going
/// Offline / DND. Returns null when dismissed.
Future<BreakReasonResult?> showReasonPickerSheet(
  BuildContext context, {
  required String title,
}) {
  return showModalBottomSheet<BreakReasonResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReasonPickerSheet(title: title),
  );
}

class _ReasonPickerSheet extends StatefulWidget {
  final String title;
  const _ReasonPickerSheet({required this.title});
  @override
  State<_ReasonPickerSheet> createState() => _ReasonPickerSheetState();
}

class _ReasonPickerSheetState extends State<_ReasonPickerSheet> {
  BreakReason? _selected;
  final _customCtrl = TextEditingController();

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final insets = MediaQuery.of(context).viewInsets;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: insets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(widget.title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(s.selectReason,
                  style: TextStyle(color: Theme.of(context).hintColor)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: BreakReason.values.map((r) {
                  final isSel = _selected == r;
                  return ChoiceChip(
                    label: Text(r.label(context)),
                    avatar: Icon(r.icon, size: 18,
                        color: isSel
                            ? Theme.of(context).colorScheme.onPrimary
                            : null),
                    selected: isSel,
                    onSelected: (_) => setState(() => _selected = r),
                  );
                }).toList(),
              ),
            ),
            if (_selected == BreakReason.other)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: TextField(
                  controller: _customCtrl,
                  autofocus: true,
                  maxLength: 120,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: s.customReason,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(s.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _canConfirm()
                          ? () => Navigator.pop(
                              context,
                              BreakReasonResult(
                                _selected!,
                                _selected == BreakReason.other
                                    ? _customCtrl.text.trim()
                                    : null,
                              ))
                          : null,
                      child: Text(s.confirm),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canConfirm() {
    if (_selected == null) return false;
    if (_selected == BreakReason.other && _customCtrl.text.trim().isEmpty) {
      return false;
    }
    return true;
  }
}
