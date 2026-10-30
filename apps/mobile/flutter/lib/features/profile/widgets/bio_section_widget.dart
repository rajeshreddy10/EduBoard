import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/edu_button.dart';
import '../../../core/widgets/edu_text_field.dart';
import '../../../providers/profile_provider.dart';

class BioSectionWidget extends ConsumerStatefulWidget {
  const BioSectionWidget({super.key});

  @override
  ConsumerState<BioSectionWidget> createState() => _BioSectionWidgetState();
}

class _BioSectionWidgetState extends ConsumerState<BioSectionWidget> {
  late final TextEditingController _bioController;
  late final TextEditingController _philController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    _bioController = TextEditingController(text: profile.bio);
    _philController = TextEditingController(text: profile.teachingPhilosophy);
  }

  @override
  void dispose() {
    _bioController.dispose();
    _philController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    await ref.read(profileProvider.notifier).updateBio(_bioController.text.trim());
    await ref.read(profileProvider.notifier).updatePhilosophy(_philController.text.trim());
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bio and teaching philosophy updated.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
              Icon(Icons.psychology_outlined, size: 20, color: colorScheme.secondary),
              const SizedBox(width: 8),
              Text(
                'Bio & Teaching Philosophy',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 18),
          EduTextField(
            controller: _bioController,
            label: 'Academic Biography',
            maxLines: 3,
            hintText: 'Describe your research and teaching focus...',
          ),
          const SizedBox(height: 16),
          EduTextField(
            controller: _philController,
            label: 'Teaching Philosophy',
            maxLines: 3,
            hintText: 'Describe your pedagogical visual approach...',
          ),
          const SizedBox(height: 20),
          EduButton(
            label: 'Update Pedagogical Bio',
            isLoading: _isSaving,
            onPressed: _handleSave,
          ),
        ],
      ),
    );
  }
}
