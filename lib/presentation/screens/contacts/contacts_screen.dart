import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../data/contacts_store.dart';
import '../../../data/call_history_store.dart';
import '../../../domain/entities/contact_entity.dart';
import '../../../domain/entities/contact_tag.dart';
import '../../../core/i18n/app_strings.dart';
import '../../widgets/contact_tag_chip.dart';
import '../../../domain/entities/call_entity.dart';
import '../../providers/call_provider.dart';

/// Contacts screen — searchable list with add / edit / delete and call action.
class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});
  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  String _query = '';
  final _contacts = ContactsStore.instance;
  final _history = CallHistoryStore.instance;

  @override
  void initState() {
    super.initState();
    _contacts.load();
    _history.load();
    _contacts.addListener(_onChange);
    _history.addListener(_onChange);
  }

  @override
  void dispose() {
    _contacts.removeListener(_onChange);
    _history.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() { if (mounted) setState(() {}); }

  Future<void> _dial(String number) async {
    if (number.trim().isEmpty) return;
    if (!mounted) return;
    context.push('/call/active');
    try {
      await ref.read(callProvider).dial(number);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())));
      }
    }
  }

  CallEntity? _lastCallFor(String number) {
    for (final c in _history.items) {
      if (c.number == number) return c;
    }
    return null;
  }

  Future<void> _openEditor({ContactEntity? existing}) async {
    final saved = await showModalBottomSheet<ContactEntity?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ContactEditor(existing: existing),
    );
    if (saved == null) return;
    if (existing == null) {
      await _contacts.add(
        name: saved.name,
        number: saved.number,
        favorite: saved.favorite,
      );
    } else {
      await _contacts.update(saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _contacts.items;
    final q = _query.toLowerCase();
    final filtered = q.isEmpty
        ? all
        : all
            .where((c) =>
                c.name.toLowerCase().contains(q) ||
                c.number.toLowerCase().contains(q))
            .toList();
    final favorites = filtered.where((c) => c.favorite).toList();
    final others = filtered.where((c) => !c.favorite).toList();

    return Scaffold(
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search contacts',
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
        Expanded(
          child: all.isEmpty
              ? _EmptyState(onAdd: () => _openEditor())
              : ListView(
                  padding: const EdgeInsets.only(bottom: 90),
                  children: [
                    if (favorites.isNotEmpty) ...[
                      const _SectionHeader('Favorites'),
                      ...favorites.map((c) => _Tile(
                            contact: c,
                            lastCall: _lastCallFor(c.number),
                            onCall: () => _dial(c.number),
                            onEdit: () => _openEditor(existing: c),
                            onDelete: () => _contacts.remove(c.id),
                            onToggleFav: () => _contacts.toggleFavorite(c.id),
                          )),
                    ],
                    if (others.isNotEmpty) ...[
                      const _SectionHeader('All contacts'),
                      ...others.map((c) => _Tile(
                            contact: c,
                            lastCall: _lastCallFor(c.number),
                            onCall: () => _dial(c.number),
                            onEdit: () => _openEditor(existing: c),
                            onDelete: () => _contacts.remove(c.id),
                            onToggleFav: () => _contacts.toggleFavorite(c.id),
                          )),
                    ],
                    if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('No contacts found')),
                      ),
                  ],
                ),
        ),
      ]),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'sync',
            tooltip: 'Import phone contacts',
            onPressed: _importPhoneContacts,
            child: const Icon(Icons.sync),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Add contact'),
          ),
        ],
      ),
    );
  }

  Future<void> _importPhoneContacts() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Import phone contacts?'),
            content: const Text(
                'We will read contacts from your phone and add new ones (duplicates are skipped).'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Import')),
            ],
          ),
        ) ??
        false;
    if (!confirm) return;
    try {
      messenger.showSnackBar(const SnackBar(content: Text('Importing…')));
      final r = await _contacts.importFromDevice();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
          content: Text('Imported ${r.added} contact${r.added == 1 ? '' : 's'} · ${r.skipped} skipped')));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }
}


class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.contacts_outlined,
              size: 64, color: Theme.of(context).hintColor),
          const SizedBox(height: 12),
          const Text('No contacts yet'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add your first contact'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final ContactEntity contact;
  final CallEntity? lastCall;
  final VoidCallback onCall;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleFav;
  const _Tile({
    required this.contact,
    required this.onCall,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFav,
    this.lastCall,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String? sub;
    IconData? dirIcon;
    Color? dirColor;
    if (lastCall != null) {
      sub = DateFormat('MMM d, HH:mm').format(lastCall!.startedAt);
      dirIcon = lastCall!.direction == CallDirection.incoming
          ? Icons.call_received
          : Icons.call_made;
      dirColor = lastCall!.status == CallStatus.missed
          ? Colors.redAccent
          : cs.onSurface.withOpacity(0.6);
    }

    return Dismissible(
      key: ValueKey(contact.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red.shade400,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Delete contact?'),
                content: Text('Remove ${contact.name}?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete')),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => onDelete(),
      child: ListTile(
        onTap: onCall,
        onLongPress: onEdit,
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          foregroundColor: cs.onPrimaryContainer,
          child: Text(contact.name.isEmpty
              ? '#'
              : contact.name.substring(0, 1).toUpperCase()),
        ),
        title: Row(children: [
          Flexible(
            child: Text(contact.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: contact.blocked ? Colors.redAccent : null,
                )),
          ),
          if (contact.blocked) ...[
            const SizedBox(width: 6),
            const Icon(Icons.block, size: 14, color: Colors.redAccent),
          ],
          if (contact.fromDevice) ...[
            const SizedBox(width: 6),
            Icon(Icons.phone_android, size: 13, color: cs.onSurface.withOpacity(0.45)),
          ],
        ]),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (dirIcon != null) ...[
                Icon(dirIcon, size: 13, color: dirColor),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  sub ?? contact.number,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            if ((contact.company ?? '').isNotEmpty)
              Text(contact.company!,
                  style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.55)),
                  overflow: TextOverflow.ellipsis),
          ],
        ),

        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: contact.favorite ? 'Unfavorite' : 'Favorite',
            icon: Icon(
              contact.favorite ? Icons.star : Icons.star_border,
              color: contact.favorite ? Colors.amber : null,
            ),
            onPressed: onToggleFav,
          ),
          IconButton(
            tooltip: 'Call',
            icon: const Icon(Icons.call, color: Color(0xFF22C55E)),
            onPressed: onCall,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: Icon(Icons.delete_outline, color: cs.error),
            onPressed: () async {
              final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete contact?'),
                      content: Text('Remove ${contact.name}?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ) ??
                  false;
              if (ok) onDelete();
            },
          ),
        ]),
      ),
    );
  }
}

class _ContactEditor extends StatefulWidget {
  final ContactEntity? existing;
  const _ContactEditor({this.existing});
  @override
  State<_ContactEditor> createState() => _ContactEditorState();
}

class _ContactEditorState extends State<_ContactEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _number =
      TextEditingController(text: widget.existing?.number ?? '');
  late final TextEditingController _company =
      TextEditingController(text: widget.existing?.company ?? '');
  late final TextEditingController _email =
      TextEditingController(text: widget.existing?.email ?? '');
  late final TextEditingController _notes =
      TextEditingController(text: widget.existing?.notes ?? '');
  late bool _favorite = widget.existing?.favorite ?? false;
  late bool _blocked = widget.existing?.blocked ?? false;
  late Set<ContactTag> _selectedTags = {
    ...?widget.existing?.tags.where((t) => t != ContactTag.blocked),
  };
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    _company.dispose();
    _email.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final base = widget.existing;
    final entity = ContactEntity(
      id: base?.id ?? '',
      name: _name.text.trim(),
      number: _number.text.trim(),
      avatarUrl: base?.avatarUrl,
      favorite: _favorite,
      online: base?.online ?? false,
      company: _company.text.trim().isEmpty ? null : _company.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      blocked: _blocked,
      tags: [
        ..._selectedTags,
        if (_blocked && !_selectedTags.contains(ContactTag.blocked))
          ContactTag.blocked,
      ],
      fromDevice: base?.fromDevice ?? false,
    );
    Navigator.of(context).pop(entity);
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final editing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, inset + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(editing ? 'Edit contact' : 'New contact',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _number,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+*#]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Phone / SIP number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Number is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _company,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Company (optional)',
                prefixIcon: Icon(Icons.business_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: Icon(Icons.sticky_note_2_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                context.s.contactTags,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in ContactTag.values)
                  if (tag != ContactTag.blocked)
                    FilterChip(
                      selected: _selectedTags.contains(tag),
                      label: Text('${tag.emoji} ${tag.label(context.s)}'),
                      selectedColor: tag.color.withOpacity(0.25),
                      checkmarkColor: tag.color,
                      onSelected: (on) => setState(() {
                        if (on) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      }),
                    ),
              ],
            ),
            const SizedBox(height: 4),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _favorite,
              onChanged: (v) => setState(() => _favorite = v),
              title: const Text('Favorite'),
              secondary: const Icon(Icons.star_border),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _blocked,
              onChanged: (v) => setState(() => _blocked = v),
              title: const Text('Block this number'),
              subtitle: const Text('Incoming calls from this number will be auto-rejected'),
              secondary: const Icon(Icons.block, color: Colors.redAccent),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: Text(editing ? 'Save' : 'Add'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

}
