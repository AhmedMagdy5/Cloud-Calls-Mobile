class UserEntity {
  final String id;
  final String name;
  final String email;
  final String extension;
  final String? avatarUrl;
  final String? department;
  final String? role;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.extension,
    this.avatarUrl,
    this.department,
    this.role,
  });

  bool get isSupervisor =>
      role?.toLowerCase() == 'supervisor' || role?.toLowerCase() == 'admin';

  factory UserEntity.fromJson(Map<String, dynamic> j) => UserEntity(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        email: j['email']?.toString() ?? '',
        extension: j['extension']?.toString() ?? '',
        avatarUrl: j['avatar']?.toString() ?? j['avatarUrl']?.toString(),
        department: j['department']?.toString(),
        role: j['role']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'extension': extension,
        'avatarUrl': avatarUrl,
        'department': department,
        'role': role,
      };

  String toJsonString() {
    final m = toJson();
    return m.entries.map((e) => '${e.key}:${e.value ?? ''}').join('|');
  }

  static UserEntity? fromStoredString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final map = <String, dynamic>{};
    for (final part in raw.split('|')) {
      final idx = part.indexOf(':');
      if (idx <= 0) continue;
      map[part.substring(0, idx)] = part.substring(idx + 1);
    }
    return UserEntity.fromJson(map);
  }
}

/// Full SIP configuration — account + network + audio.
/// Persisted via SipSettingsRepository.
class SipCredentials {
  // Account
  final String server;          // e.g. pbx.company.com or IP
  final int port;               // 5060 / 5061 / 8089
  final String transport;       // wss / ws / udp / tcp / tls
  final String username;        // extension
  final String password;
  final String? authId;
  final String? displayName;
  final String wsPath;          // for ws/wss
  final String? outboundProxy;  // optional

  // Network
  final String stunServer;
  final String? turnServer;
  final String? turnUsername;
  final String? turnPassword;
  final bool iceEnabled;

  // Audio
  final bool echoCancellation;
  final bool noiseSuppression;
  final List<String> codecPriority; // ['opus','PCMU','PCMA']

  const SipCredentials({
    required this.server,
    this.port = 5060,
    this.transport = 'udp',
    required this.username,
    required this.password,
    this.authId,
    this.displayName,
    this.wsPath = '/ws',
    this.outboundProxy,
    this.stunServer = 'stun:stun.l.google.com:19302',
    this.turnServer,
    this.turnUsername,
    this.turnPassword,
    this.iceEnabled = true,
    this.echoCancellation = true,
    this.noiseSuppression = true,
    this.codecPriority = const ['opus', 'PCMU', 'PCMA'],
  });

  bool get isWebSocket => transport == 'ws' || transport == 'wss';
  String get wsUri => '$transport://$server:$port$wsPath';
  String get sipUri => 'sip:$username@$server';

  SipCredentials copyWith({
    String? server,
    int? port,
    String? transport,
    String? username,
    String? password,
    String? authId,
    String? displayName,
    String? wsPath,
    String? outboundProxy,
    String? stunServer,
    String? turnServer,
    String? turnUsername,
    String? turnPassword,
    bool? iceEnabled,
    bool? echoCancellation,
    bool? noiseSuppression,
    List<String>? codecPriority,
  }) => SipCredentials(
    server: server ?? this.server,
    port: port ?? this.port,
    transport: transport ?? this.transport,
    username: username ?? this.username,
    password: password ?? this.password,
    authId: authId ?? this.authId,
    displayName: displayName ?? this.displayName,
    wsPath: wsPath ?? this.wsPath,
    outboundProxy: outboundProxy ?? this.outboundProxy,
    stunServer: stunServer ?? this.stunServer,
    turnServer: turnServer ?? this.turnServer,
    turnUsername: turnUsername ?? this.turnUsername,
    turnPassword: turnPassword ?? this.turnPassword,
    iceEnabled: iceEnabled ?? this.iceEnabled,
    echoCancellation: echoCancellation ?? this.echoCancellation,
    noiseSuppression: noiseSuppression ?? this.noiseSuppression,
    codecPriority: codecPriority ?? this.codecPriority,
  );

  Map<String, dynamic> toJson() => {
    'server': server, 'port': port, 'transport': transport,
    'username': username, 'authId': authId, 'displayName': displayName,
    'wsPath': wsPath, 'outboundProxy': outboundProxy,
    'stunServer': stunServer, 'turnServer': turnServer,
    'turnUsername': turnUsername,
    'iceEnabled': iceEnabled,
    'echoCancellation': echoCancellation,
    'noiseSuppression': noiseSuppression,
    'codecPriority': codecPriority,
    // NOTE: password & turnPassword stored separately in secure storage
  };

  factory SipCredentials.fromJson(Map<String, dynamic> j, {String password = '', String? turnPassword}) =>
      SipCredentials(
        server: j['server'] ?? '',
        port: (j['port'] as num?)?.toInt() ?? 5060,
        transport: j['transport'] ?? 'udp',
        username: j['username'] ?? '',
        password: password,
        authId: j['authId'],
        displayName: j['displayName'],
        wsPath: j['wsPath'] ?? '/ws',
        outboundProxy: j['outboundProxy'],
        stunServer: j['stunServer'] ?? 'stun:stun.l.google.com:19302',
        turnServer: j['turnServer'],
        turnUsername: j['turnUsername'],
        turnPassword: turnPassword,
        iceEnabled: j['iceEnabled'] ?? true,
        echoCancellation: j['echoCancellation'] ?? true,
        noiseSuppression: j['noiseSuppression'] ?? true,
        codecPriority: (j['codecPriority'] as List?)
                ?.map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList() ??
            const ['opus', 'PCMU', 'PCMA'],
      );

  static const empty = SipCredentials(
    server: '', username: '', password: '',
  );
}
