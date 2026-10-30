import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/edu_button.dart';
import '../../../core/widgets/edu_text_field.dart';
import '../../../providers/profile_provider.dart';

class AcademicInfoForm extends ConsumerStatefulWidget {
  const AcademicInfoForm({super.key});

  @override
  ConsumerState<AcademicInfoForm> createState() => _AcademicInfoFormState();
}

class _AcademicInfoFormState extends ConsumerState<AcademicInfoForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _institutionController;
  late final TextEditingController _deptController;
  late final TextEditingController _roleController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    _nameController = TextEditingController(text: profile.name);
    _institutionController = TextEditingController(text: profile.institution);
    _deptController = TextEditingController(text: profile.department);
    _roleController = TextEditingController(text: profile.role);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _institutionController.dispose();
    _deptController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    await ref.read(profileProvider.notifier).updateAcademicInfo(
          name: _nameController.text.trim(),
          institution: _institutionController.text.trim(),
          department: _deptController.text.trim(),
          role: _roleController.text.trim(),
        );
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Academic information updated successfully.')),
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
              Icon(Icons.school_outlined, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Academic Credentials',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 18),
          EduTextField(
            controller: _nameController,
            label: 'Full Name & Honorific',
            prefixIcon: Icons.badge_outlined,
          ),
          const SizedBox(height: 14),
          EduTextField(
            controller: _institutionController,
            label: 'University / Research Institute',
            prefixIcon: Icons.account_balance_outlined,
          ),
          const SizedBox(height: 14),
          EduTextField(
            controller: _deptController,
            label: 'Department',
            prefixIcon: Icons.biotech_outlined,
          ),
          const SizedBox(height: 14),
          EduTextField(
            controller: _roleController,
            label: 'Academic Role',
            prefixIcon: Icons.work_outline_rounded,
          ),
          const SizedBox(height: 20),
          EduButton(
            label: 'Save Academic Info',
            isLoading: _isSaving,
            onPressed: _handleSave,
          ),
        ],
      ),
    );
  }
}
