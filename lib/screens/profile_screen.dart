import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../core/profile/user_profile.dart';
import '../core/providers.dart' as prov;
import '../theme/app_colors.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/glass/glass_text_field.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  UserProfile? _profile;
  bool _isLoading = true;
  bool _isEditing = false;
  String? _profilePhoto;

  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _occupationController = TextEditingController();
  final _companyController = TextEditingController();
  final _locationController = TextEditingController();
  final _bioController = TextEditingController();
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final service = ref.read(prov.userProfileServiceProvider);
    final profile = await service.load();
    if (mounted) {
      setState(() {
        _profile = profile;
        _isLoading = false;
        _syncControllers();
      });
    }
  }

  void _syncControllers() {
    _nameController.text = _profile?.name ?? '';
    _nicknameController.text = _profile?.nickname ?? '';
    _occupationController.text = _profile?.occupation ?? '';
    _companyController.text = _profile?.company ?? '';
    _locationController.text = _profile?.location ?? '';
    _bioController.text = _profile?.bio ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _occupationController.dispose();
    _companyController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final photosDir = Directory(p.join(appDir.path, 'profile_photos'));
        if (!await photosDir.exists()) await photosDir.create(recursive: true);
        final saved = await File(picked.path).copy(
          p.join(photosDir.path, 'user_profile.jpg'),
        );
        setState(() => _profilePhoto = saved.path);
      }
    } catch (e) {
      debugPrint('Photo picker error: $e');
    }
  }

  Future<void> _save() async {
    final service = ref.read(prov.userProfileServiceProvider);
    if (_profile == null) return;

    await service.updateField('name', _nameController.text);
    await service.updateField('nickname', _nicknameController.text);
    await service.updateField('occupation', _occupationController.text);
    await service.updateField('company', _companyController.text);
    await service.updateField('location', _locationController.text);
    await service.updateField('bio', _bioController.text);

    await _loadProfile();
    setState(() => _isEditing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _addProject() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundElevated,
        title: const Text('Add Project', style: TextStyle(color: AppColors.textPrimary)),
        content: GlassTextField(
          hintText: 'Project name',
          controller: controller,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final service = ref.read(prov.userProfileServiceProvider);
                await service.addProject(controller.text);
                await _loadProfile();
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  void _addGoal() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundElevated,
        title: const Text('Add Goal', style: TextStyle(color: AppColors.textPrimary)),
        content: GlassTextField(
          hintText: 'Goal description',
          controller: controller,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final service = ref.read(prov.userProfileServiceProvider);
                await service.addGoal(controller.text);
                await _loadProfile();
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    final profile = _profile ?? UserProfile.create(userId: '');
    final completenessPercent = (profile.completenessScore * 100).round();
    final confidencePercent = (profile.confidenceScore * 100).round();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _buildAvatar(profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'U'),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name.isNotEmpty ? profile.name : 'Your Profile',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.occupation.isNotEmpty
                          ? profile.occupation
                          : profile.company.isNotEmpty
                              ? profile.company
                              : 'Tell me about yourself',
                      style: const TextStyle(fontSize: 14, color: AppColors.textTertiary),
                    ),
                  ],
                ),
                const Spacer(),
                GlassButton(
                  onPressed: () => setState(() => _isEditing = !_isEditing),
                  label: _isEditing ? 'Cancel' : 'Edit Profile',
                  icon: _isEditing ? Icons.close : Icons.edit,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Stats row
            Row(
              children: [
                _buildStatCard('Completeness', '$completenessPercent%', Icons.pie_chart, completenessPercent >= 70 ? AppColors.success : AppColors.warning),
                const SizedBox(width: 12),
                _buildStatCard('Confidence', '$confidencePercent%', Icons.verified, confidencePercent >= 70 ? AppColors.success : AppColors.warning),
                const SizedBox(width: 12),
                _buildStatCard('Projects', '${profile.projects.length}', Icons.folder_outlined, AppColors.accent),
                const SizedBox(width: 12),
                _buildStatCard('Goals', '${profile.goals.length}', Icons.flag_outlined, AppColors.accent),
              ],
            ),
            const SizedBox(height: 24),

            // Editable fields
            GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 18, color: AppColors.accent),
                      const SizedBox(width: 8),
                      const Text('Identity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      if (!profile.name.isNotEmpty)
                        const SizedBox(width: 8),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isEditing) ...[
                    _buildEditField('Name', _nameController, hint: 'Your full name'),
                    const SizedBox(height: 12),
                    _buildEditField('Nickname', _nicknameController, hint: 'What should I call you?'),
                    const SizedBox(height: 12),
                    _buildEditField('Occupation', _occupationController, hint: 'e.g. Software Engineer'),
                    const SizedBox(height: 12),
                    _buildEditField('Company', _companyController, hint: 'e.g. Acme Corp'),
                    const SizedBox(height: 12),
                    _buildEditField('Location', _locationController, hint: 'e.g. San Francisco, CA'),
                    const SizedBox(height: 12),
                    _buildEditField('Bio', _bioController, hint: 'A short description about yourself', maxLines: 3),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: GlassButton(
                        onPressed: _save,
                        label: 'Save Changes',
                        icon: Icons.save,
                      ),
                    ),
                  ] else ...[
                    _buildField('Name', profile.name.isEmpty ? 'Not set' : profile.name, !profile.name.isNotEmpty),
                    _buildField('Nickname', profile.nickname.isEmpty ? 'Not set' : profile.nickname, !profile.nickname.isNotEmpty),
                    _buildField('Occupation', profile.occupation.isEmpty ? 'Not set' : profile.occupation, !profile.occupation.isNotEmpty),
                    _buildField('Company', profile.company.isEmpty ? 'Not set' : profile.company, !profile.company.isNotEmpty),
                    _buildField('Location', profile.location.isEmpty ? 'Not set' : profile.location, !profile.location.isNotEmpty),
                    _buildField('Bio', profile.bio.isEmpty ? 'Not set' : profile.bio, !profile.bio.isNotEmpty),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Projects & Goals
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildListCard('Projects', profile.projects, Icons.folder_outlined, _addProject)),
                const SizedBox(width: 12),
                Expanded(child: _buildListCard('Goals', profile.goals, Icons.flag_outlined, _addGoal)),
              ],
            ),
            const SizedBox(height: 16),

            // Skills & Interests
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildTagCard('Skills', profile.skills)),
                const SizedBox(width: 12),
                Expanded(child: _buildTagCard('Interests', profile.interests)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String initial) {
    return GestureDetector(
      onTap: _pickPhoto,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: AppColors.accent.withAlpha(30),
            backgroundImage: _profilePhoto != null
                ? FileImage(File(_profilePhoto!))
                : null,
            child: _profilePhoto == null
                ? Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  )
                : null,
          ),
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 2),
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, String value, bool isMissing) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textTertiary)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: isMissing ? AppColors.textDisabled : AppColors.textPrimary,
                fontStyle: isMissing ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
          if (isMissing)
            const Icon(Icons.info_outline, size: 14, color: AppColors.warning),
        ],
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller, {String? hint, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
        const SizedBox(height: 6),
        GlassTextField(
          hintText: hint,
          controller: controller,
          maxLines: maxLines,
        ),
      ],
    );
  }

  Widget _buildListCard(String title, List<String> items, IconData icon, VoidCallback onAdd) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const Spacer(),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.accentGhost,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.add, size: 16, color: AppColors.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No $title yet',
                style: const TextStyle(fontSize: 13, color: AppColors.textDisabled, fontStyle: FontStyle.italic),
              ),
            )
          else
            ...items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 6, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildTagCard(String title, List<String> items) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(title == 'Skills' ? Icons.auto_awesome : Icons.favorite_outline, size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              'Discovered from conversations',
              style: const TextStyle(fontSize: 13, color: AppColors.textDisabled, fontStyle: FontStyle.italic),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: items.map((item) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentGhost,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withAlpha(40)),
                ),
                child: Text(
                  item,
                  style: const TextStyle(fontSize: 12, color: AppColors.accent),
                ),
              )).toList(),
            ),
        ],
      ),
    );
  }
}
