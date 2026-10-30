import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/edu_image.dart';
import '../../../providers/profile_provider.dart';

/// Avatar component with glowing aura, network image / initials fallback, and avatar preset selector
class AvatarPickerWidget extends ConsumerWidget {
  const AvatarPickerWidget({super.key});

  void _pickAvatar(BuildContext context, WidgetRef ref) {
    final avatarPresets = [
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&h=200&fit=crop',
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&h=200&fit=crop',
      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&h=200&fit=crop',
      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&h=200&fit=crop',
    ];

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select Academic Avatar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: avatarPresets.map((url) {
                  return GestureDetector(
                    onTap: () {
                      ref.read(profileProvider.notifier).updateAvatar(url);
                      Navigator.pop(ctx);
                    },
                    child: EduAvatar(
                      imageUrl: url,
                      name: 'A',
                      radius: 28,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.clear_rounded),
                title: const Text('Reset to Name Initials'),
                onTap: () {
                  ref.read(profileProvider.notifier).updateAvatar(null);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: EduAvatar(
              imageUrl: profile.avatarUrl,
              name: profile.name,
              radius: 52,
            ),
          ),
          GestureDetector(
            onTap: () => _pickAvatar(context, ref),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.surface, width: 2.5),
              ),
              child: const Icon(Icons.edit_rounded, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
