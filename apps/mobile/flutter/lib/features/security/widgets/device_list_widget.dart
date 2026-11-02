import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.devices_rounded, size: 18, color: colorScheme.primary),
              ),
              const SizedBox(width: 10),
              Text(
                'Authorized Devices',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${security.authorizedDevices.length} Active',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colorScheme.onSurface.withValues(alpha: 0.7)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: security.authorizedDevices.length,
            separatorBuilder: (_, __) => const Divider(height: 18),
            itemBuilder: (context, idx) {
              final dev = security.authorizedDevices[idx];
              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      dev.platform.contains('Android') ? Icons.phone_android_rounded : Icons.laptop_mac_rounded,
                      size: 20,
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
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
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
                          style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                        Text(
                          'Last active: ${timeFormat.format(dev.lastActive)}',
                          style: TextStyle(fontSize: 10, color: colorScheme.onSurface.withValues(alpha: 0.45)),
                        ),
                      ],
                    ),
                  ),
                  if (!dev.isCurrentDevice)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        ref.read(securityProvider.notifier).revokeDevice(dev.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Revoked access for ${dev.deviceName}'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                      child: const Text('Revoke', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
