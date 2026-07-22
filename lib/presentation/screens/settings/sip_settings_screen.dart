import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../../core/services/backend_settings_service.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../features/presence/mobile_presence_service.dart';
import '../../../features/sip/sip_service.dart';

/// Full advanced SIP settings — account, network, audio.
class SipSettingsScreen extends ConsumerStatefulWidget {
  const SipSettingsScreen({super.key});
  @override
  ConsumerState<SipSettingsScreen> createState() => _SipSettingsScreenState();
}

class _SipSettingsScreenState extends ConsumerState<SipSettingsScreen> {
  final _form = GlobalKey<FormState>();

  // Account
  final _apiUrl = TextEditingController();
  final _registrationSecret = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _server = TextEditingController();
  final _port = TextEditingController(text: '5060');
  final _authId = TextEditingController();
  final _displayName = TextEditingController();
  final _wsPath = TextEditingController(text: '/ws');
  final _outboundProxy = TextEditingController();
  String _transport = 'udp';

  // Network
  final _stun = TextEditingController(text: 'stun:stun.l.google.com:19302');
  final _turn = TextEditingController();
  final _turnUser = TextEditingController();
  final _turnPass = TextEditingController();
  bool _ice = true;

  // Audio
  bool _echo = true;
  bool _noise = true;
  List<String> _codecs = const ['opus', 'PCMU', 'PCMA'];

  bool _obscurePwd = true;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final saved = await ref.read(sipRepoProvider).load();
    final c = saved ?? ref.read(sipServiceProvider).credentials ?? SipCredentials.empty;
    setState(() {
      _apiUrl.text = BackendSettingsService.instance.savedApiBaseUrl ?? '';
      _registrationSecret.text = BackendSettingsService.instance.registrationSecret;
      _username.text = c.username;
      _password.text = c.password;
      _server.text = c.server;
      _port.text = c.port.toString();
      _transport = c.transport;
      _authId.text = c.authId ?? '';
      _displayName.text = c.displayName ?? '';
      _wsPath.text = c.wsPath;
      _outboundProxy.text = c.outboundProxy ?? '';
      _stun.text = c.stunServer;
      _turn.text = c.turnServer ?? '';
      _turnUser.text = c.turnUsername ?? '';
      _turnPass.text = c.turnPassword ?? '';
      _ice = c.iceEnabled;
      _echo = c.echoCancellation;
      _noise = c.noiseSuppression;
      _codecs = List.of(c.codecPriority);
      _loaded = true;
    });
  }

  SipCredentials _build() => SipCredentials(
        server: _server.text.trim(),
        port: int.tryParse(_port.text.trim()) ?? 5060,
        transport: _transport,
        username: _username.text.trim(),
        password: _password.text,
        authId: _authId.text.trim().isEmpty ? null : _authId.text.trim(),
        displayName: _displayName.text.trim().isEmpty ? null : _displayName.text.trim(),
        wsPath: _wsPath.text.trim().isEmpty ? '/ws' : _wsPath.text.trim(),
        outboundProxy: _outboundProxy.text.trim().isEmpty ? null : _outboundProxy.text.trim(),
        stunServer: _stun.text.trim(),
        turnServer: _turn.text.trim().isEmpty ? null : _turn.text.trim(),
        turnUsername: _turnUser.text.trim().isEmpty ? null : _turnUser.text.trim(),
        turnPassword: _turnPass.text.isEmpty ? null : _turnPass.text,
        iceEnabled: _ice,
        echoCancellation: _echo,
        noiseSuppression: _noise,
        codecPriority: _codecs,
      );

  Future<void> _apply() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final creds = _build();
      final previous = await ref.read(sipRepoProvider).load();
      final sipChanged = previous == null ||
          !SipService.credentialsEqual(previous, creds);

      final api = _apiUrl.text.trim();
      final secret = _registrationSecret.text.trim();
      if (api.isNotEmpty) {
        await BackendSettingsService.instance.save(
          apiBaseUrl: api,
          registrationSecret: secret.isEmpty ? null : secret,
        );
      } else {
        await BackendSettingsService.instance.clear();
      }

      if (sipChanged) {
        await ref.read(authProvider.notifier).applySipSettings(creds);
      } else {
        await ref.read(authProvider.notifier).applySipSettings(
              creds,
              reconnect: false,
            );
        await MobilePresenceService.instance.refreshAfterBackendSettingsChange();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sipChanged
                ? 'Settings saved — registering…'
                : 'Settings saved',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    if (!_form.currentState!.validate()) return;
    final svc = ref.read(sipServiceProvider);
    await svc.disconnect();
    await svc.connect(_build());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Test registration started — watch status')),
    );
  }

  void _resetDefaults() {
    setState(() {
      _port.text = '5060';
      _transport = 'udp';
      _wsPath.text = '/ws';
      _outboundProxy.clear();
      _stun.text = 'stun:stun.l.google.com:19302';
      _turn.clear(); _turnUser.clear(); _turnPass.clear();
      _ice = true; _echo = true; _noise = true;
      _codecs = const ['opus', 'PCMU', 'PCMA'];
    });
  }

  @override
  void dispose() {
    _apiUrl.dispose();
    _registrationSecret.dispose();
    _username.dispose();
    _password.dispose();
    _server.dispose();
    _port.dispose();
    _authId.dispose();
    _displayName.dispose();
    _wsPath.dispose();
    _outboundProxy.dispose();
    _stun.dispose();
    _turn.dispose();
    _turnUser.dispose();
    _turnPass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final sip = ref.watch(sipStatusProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced SIP Settings'),
        actions: [
          IconButton(
            tooltip: 'Reset to defaults',
            icon: const Icon(Icons.restart_alt),
            onPressed: _resetDefaults,
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusChip(status: sip.status, label: sip.statusLabel),
            const SizedBox(height: 16),

            // ---- Account ----
            _Section(
              icon: Icons.account_circle_outlined,
              title: 'SIP Account',
              children: [
                _field(
                  _apiUrl,
                  'Backend / Webphone API URL',
                  icon: Icons.hub_outlined,
                  hint: 'https://phone-test.awfarcc.com/api-files',
                ),
                _field(
                  _registrationSecret,
                  'Registration Secret',
                  icon: Icons.key_outlined,
                  hint: 'AWF-SIP-REG-2026-X9K4M7',
                ),
                Text(
                  'Supervisor presence: saves Online / DND / In Call to webphone reports. API URL must end with /api-files.',
                  style: TextStyle(color: cs.onSurface.withOpacity(0.65), fontSize: 12),
                ),
                const SizedBox(height: 8),
                _field(_username, 'Username (Extension)', icon: Icons.person_outline, required: true),
                _field(_password, 'Password',
                    icon: Icons.lock_outline,
                    required: true,
                    obscure: _obscurePwd,
                    suffix: IconButton(
                      icon: Icon(_obscurePwd ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePwd = !_obscurePwd),
                    )),
                _field(_server, 'SIP Domain / Server',
                    icon: Icons.dns_outlined, required: true, hint: 'pbx.example.com'),
                Row(children: [
                  Expanded(child: _field(_port, 'Port', icon: Icons.numbers, keyboard: TextInputType.number, required: true)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _transport,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Transport',
                        prefixIcon: Icon(Icons.swap_horiz),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'udp', child: Text('UDP', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'tcp', child: Text('TCP', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'tls', child: Text('TLS', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'wss', child: Text('WSS', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'ws', child: Text('WS', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setState(() => _transport = v ?? 'udp'),
                    ),
                  ),
                ]),
                _field(_authId, 'Auth ID (optional)', icon: Icons.badge_outlined),
                _field(_displayName, 'Display Name (optional)', icon: Icons.label_outline),
                _field(_wsPath, 'WebSocket Path', icon: Icons.alt_route, hint: '/ws'),
                _field(_outboundProxy, 'Outbound Proxy (optional)',
                    icon: Icons.router_outlined, hint: 'sip:proxy.example.com:5060'),
              ],
            ),

            // ---- Network ----
            _Section(
              icon: Icons.lan_outlined,
              title: 'Network',
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable ICE'),
                  subtitle: const Text('Required for most NAT scenarios'),
                  value: _ice,
                  onChanged: (v) => setState(() => _ice = v),
                ),
                _field(_stun, 'STUN Server', icon: Icons.cloud_outlined),
                _field(_turn, 'TURN Server (optional)', icon: Icons.cloud_queue),
                Row(children: [
                  Expanded(child: _field(_turnUser, 'TURN Username', icon: Icons.person)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_turnPass, 'TURN Password', icon: Icons.password, obscure: true)),
                ]),
              ],
            ),

            // ---- Audio ----
            _Section(
              icon: Icons.graphic_eq,
              title: 'Audio',
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Echo Cancellation'),
                  value: _echo,
                  onChanged: (v) => setState(() => _echo = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Noise Suppression'),
                  value: _noise,
                  onChanged: (v) => setState(() => _noise = v),
                ),
                const SizedBox(height: 8),
                const Text('Codec Priority', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, children: [
                  for (int i = 0; i < _codecs.length; i++)
                    InputChip(
                      label: Text('${i + 1}. ${_codecs[i]}'),
                      onPressed: () {
                        if (i == 0) return;
                        setState(() {
                          final c = _codecs.removeAt(i);
                          _codecs.insert(i - 1, c);
                        });
                      },
                    ),
                ]),
                Text('Tap a codec to promote its priority.',
                    style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 12)),
              ],
            ),

            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _apply,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: const Text('Save & Apply'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _saving ? null : _test,
              icon: const Icon(Icons.wifi_tethering),
              label: const Text('Test Connection'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _resetDefaults,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset to Defaults'),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    IconData? icon,
    bool required = false,
    bool obscure = false,
    String? hint,
    TextInputType? keyboard,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: c,
        obscureText: obscure,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon) : null,
          suffixIcon: suffix,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null
            : null,
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  const _Section({required this.icon, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icon, color: cs.primary),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          ...children,
        ]),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final SipStatus status;
  final String label;
  const _StatusChip({required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    Color bg; IconData icon;
    switch (status) {
      case SipStatus.registered: bg = Colors.green; icon = Icons.check_circle; break;
      case SipStatus.registering:
      case SipStatus.reconnecting: bg = Colors.orange; icon = Icons.sync; break;
      case SipStatus.failed: bg = Colors.red; icon = Icons.error_outline; break;
      case SipStatus.unregistered: bg = Colors.grey; icon = Icons.power_settings_new; break;
      case SipStatus.idle: bg = Colors.blueGrey; icon = Icons.circle_outlined; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bg.withOpacity(0.4)),
      ),
      child: Row(children: [
        Icon(icon, color: bg, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(color: bg, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}
