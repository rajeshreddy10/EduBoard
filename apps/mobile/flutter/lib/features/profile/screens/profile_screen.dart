import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utilities/responsive_layout.dart';
import '../../../core/widgets/edu_button.dart';
import '../../../core/widgets/edu_text_field.dart';
import '../../../models/user_profile_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/profile_provider.dart';
import '../widgets/avatar_picker_widget.dart';

/// User profile screen containing only:
/// Name, Address, Organization, Phone Number, Location, Bio, and Profile Pic
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _organizationController;
  late final TextEditingController _phoneController;
  late final TextEditingController _locationController;
  late final TextEditingController _bioController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    _nameController = TextEditingController(text: profile.name);
    _addressController = TextEditingController(text: profile.address);
    _organizationController = TextEditingController(text: profile.organization);
    _phoneController = TextEditingController(text: profile.phone);
    _locationController = TextEditingController(text: profile.location);
    _bioController = TextEditingController(text: profile.bio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _organizationController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(profileProvider.notifier).saveProfile(
            name: _nameController.text.trim(),
            address: _addressController.text.trim(),
            organization: _organizationController.text.trim(),
            phone: _phoneController.text.trim(),
            location: _locationController.text.trim(),
            bio: _bioController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved to Firebase successfully.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sync text fields whenever account data arrives, switches, or updates from Web in real-time
    ref.listen<UserProfileModel>(profileProvider, (previous, next) {
      if (_isSaving) return;
      final isNewUserOrColdStart = previous == null || previous.id != next.id || previous.id.isEmpty;
      if (isNewUserOrColdStart && next.id.isNotEmpty) {
        _nameController.text = next.name;
        _addressController.text = next.address;
        _organizationController.text = next.organization;
        _phoneController.text = next.phone;
        _locationController.text = next.location;
        _bioController.text = next.bio;
      } else {
        if (previous?.name != next.name || _nameController.text.isEmpty) {
          _nameController.text = next.name;
        }
        if (previous?.address != next.address || _addressController.text.isEmpty) {
          _addressController.text = next.address;
        }
        if (previous?.organization != next.organization || _organizationController.text.isEmpty) {
          _organizationController.text = next.organization;
        }
        if (previous?.phone != next.phone || _phoneController.text.isEmpty) {
          _phoneController.text = next.phone;
        }
        if (previous?.location != next.location || _locationController.text.isEmpty) {
          _locationController.text = next.location;
        }
        if (previous?.bio != next.bio || _bioController.text.isEmpty) {
          _bioController.text = next.bio;
        }
      }
    });

    final profile = ref.watch(profileProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ResponsiveLayout.contentWidth(context)),
              child: Column(
                children: [
                  // 1. Profile Picture
                  const AvatarPickerWidget(),
                  const SizedBox(height: 14),

                  // Display Name & Email Subtitle
                  Text(
                    profile.name.isNotEmpty ? profile.name : 'User Profile',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  if (profile.email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      profile.email,
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // 2. Profile Details Form (name, address, organization, phone, location, bio)
                  Container(
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
                            Icon(Icons.person_pin_rounded, size: 20, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Profile Details',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Name
                        EduTextField(
                          controller: _nameController,
                          label: 'Name',
                          hintText: 'Enter your full name',
                          prefixIcon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 16),

                        // Address
                        EduTextField(
                          controller: _addressController,
                          label: 'Address',
                          hintText: 'Enter your street address',
                          prefixIcon: Icons.home_outlined,
                        ),
                        const SizedBox(height: 16),

                        // Organization
                        EduTextField(
                          controller: _organizationController,
                          label: 'Organization',
                          hintText: 'Company, School, or Institute',
                          prefixIcon: Icons.business_outlined,
                        ),
                        const SizedBox(height: 16),

                        // Phone Number
                        EduTextField(
                          controller: _phoneController,
                          label: 'Phone Number',
                          hintText: '+1 234 567 8900',
                          keyboardType: TextInputType.phone,
                          prefixIcon: Icons.phone_outlined,
                        ),
                        const SizedBox(height: 16),

                        // Location
                        EduTextField(
                          controller: _locationController,
                          label: 'Location',
                          hintText: 'City, Country',
                          prefixIcon: Icons.location_on_outlined,
                        ),
                        const SizedBox(height: 16),

                        // Bio
                        EduTextField(
                          controller: _bioController,
                          label: 'Bio',
                          hintText: 'Write a brief description about yourself...',
                          maxLines: 4,
                          prefixIcon: Icons.notes_rounded,
                        ),
                        const SizedBox(height: 24),

                        // Save Button
                        EduButton(
                          label: 'Save Profile',
                          icon: Icons.save_rounded,
                          isLoading: _isSaving,
                          onPressed: _handleSave,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Sign Out Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(color: colorScheme.error.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text('Sign Out of Workspace'),
                    onPressed: () {
                      ref.read(authProvider.notifier).logout();
                      context.go('/login');
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
