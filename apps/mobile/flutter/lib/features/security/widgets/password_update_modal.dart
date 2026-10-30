import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/edu_button.dart';
import '../../../core/widgets/edu_text_field.dart';
import '../../../providers/security_provider.dart';

class PasswordUpdateModal extends ConsumerStatefulWidget {
  const PasswordUpdateModal({super.key});

  @override
  ConsumerState<PasswordUpdateModal> createState() => _PasswordUpdateModalState();
}

class _PasswordUpdateModalState extends ConsumerState<PasswordUpdateModal> {
  final _oldPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _oldPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_newPassController.text != _confirmPassController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match')),
      );
      return;
    }

    setState(() => _isLoading = true);
    await ref.read(securityProvider.notifier).updatePassword(
          _oldPassController.text,
          _newPassController.text,
        );
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Update Password', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            EduTextField(
              controller: _oldPassController,
              label: 'Current Password',
              obscureText: true,
              prefixIcon: Icons.lock_outline_rounded,
            ),
            const SizedBox(height: 14),
            EduTextField(
              controller: _newPassController,
              label: 'New Password',
              obscureText: true,
              prefixIcon: Icons.key_rounded,
            ),
            const SizedBox(height: 14),
            EduTextField(
              controller: _confirmPassController,
              label: 'Confirm New Password',
              obscureText: true,
              prefixIcon: Icons.check_circle_outline_rounded,
            ),
            const SizedBox(height: 20),
            EduButton(
              label: 'Save New Password',
              isLoading: _isLoading,
              onPressed: _handleSubmit,
            ),
          ],
        ),
      ),
    );
  }
}
