class CustomerEntity {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? company;
  final List<String> tags;
  final String? lastCallSummary;
  final DateTime? lastCallAt;
  final int openTickets;
  final String? crmUrl;

  const CustomerEntity({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.company,
    this.tags = const [],
    this.lastCallSummary,
    this.lastCallAt,
    this.openTickets = 0,
    this.crmUrl,
  });

  factory CustomerEntity.fromJson(Map<String, dynamic> j) => CustomerEntity(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? j['displayName']?.toString() ?? '',
        phone: j['phone']?.toString() ?? j['number']?.toString() ?? '',
        email: j['email']?.toString(),
        company: j['company']?.toString(),
        tags: (j['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        lastCallSummary: j['lastCallSummary']?.toString(),
        lastCallAt: j['lastCallAt'] != null
            ? DateTime.tryParse(j['lastCallAt'].toString())
            : null,
        openTickets: (j['openTickets'] as num?)?.toInt() ?? 0,
        crmUrl: j['crmUrl']?.toString(),
      );
}
