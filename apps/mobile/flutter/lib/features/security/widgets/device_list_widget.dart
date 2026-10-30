import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../providers/security_provider.dart';

class DeviceListWidget extends ConsumerWidget {
  const DeviceListWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final security = ref.watch(securityProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timeFormat = DateFormat('MMM d, h:mm a');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.devices_rounded, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Authorized Devices',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${security.authorizedDevices.length} Active',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.55)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: security.authorizedDevices.length,
            separatorBuilder: (_, __) => const Divider(height: 18),
            itemBuilder: (context, idx) {
              final dev = security.authorizedDevices[idx];
              return Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    child: Icon(
                      dev.platform.contains('Android') ? Icons.phone_android_rounded : Icons.laptop_mac_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              dev.deviceName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            if (dev.isCurrentDevice) ...[
                              const SizedBox(width: 6),
                              const AppStatusBadge(label: 'THIS DEVICE', isFilled: true),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${dev.platform} • ${dev.ipAddress}',
                          style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.55)),
                        ),
                        Text(
                          'Last active: ${timeFormat.format(dev.lastActive)}',
                          style: TextStyle(fontSize: 10, color: colorScheme.onSurface.withValues(alpha: 0.4)),
                        ),
                      ],
                    ),
                  ),
                  if (!dev.isCurrentDevice)
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                      onPressed: () {
                        ref.read(securityProvider.notifier).revokeDevice(dev.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Revoked access for ${dev.deviceName}')),
                        );
                      },
                      child: const Text('Revoke', style: TextStyle(fontSize: 12)),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
