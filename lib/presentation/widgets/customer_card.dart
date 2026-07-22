import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../domain/entities/customer_entity.dart';

/// Screen-pop card shown during inbound/outbound calls.
class CustomerCard extends StatelessWidget {
  final CustomerEntity customer;
  const CustomerCard({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withOpacity(0.55),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Icon(Icons.account_circle_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  customer.name.isNotEmpty ? customer.name : customer.phone,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (customer.openTickets > 0)
                Chip(
                  label: Text('${customer.openTickets} open'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: cs.errorContainer,
                ),
            ]),
            if (customer.company != null && customer.company!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(customer.company!, style: TextStyle(color: cs.onSurface.withOpacity(0.7))),
            ],
            if (customer.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final t in customer.tags)
                    Chip(label: Text(t), visualDensity: VisualDensity.compact),
                ],
              ),
            ],
            if (customer.lastCallSummary != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last call: ${customer.lastCallSummary}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.65)),
              ),
            ],
            if (customer.crmUrl != null && customer.crmUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => launchUrl(Uri.parse(customer.crmUrl!)),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open in CRM'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
