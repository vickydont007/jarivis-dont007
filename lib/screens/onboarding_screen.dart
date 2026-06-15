import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/glass/glass_text_field.dart';
import '../widgets/common/gradient_icon.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  final _apiKeyController = TextEditingController();
  final _nameController = TextEditingController();
  String? _avatarPath;
  bool _micGranted = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _avatarPath = picked.path);
    }
  }

  Future<void> _requestMicPermission() async {
    try {
      const channel = MethodChannel('com.nextron.ai/mic_permission');
      final result = await channel.invokeMethod('requestPermission');
      setState(() => _micGranted = result == 'authorized');
    } catch (_) {
      setState(() => _micGranted = false);
    }
  }

  Future<void> _complete() async {
    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('openrouter_api_key', _apiKeyController.text.trim());
    await prefs.setString('user_name', _nameController.text.trim());
    if (_avatarPath != null) {
      await prefs.setString('user_profile_photo', _avatarPath!);
    }
    await prefs.setBool('onboarding_complete', true);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildStep(),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildWelcomeStep();
      case 1:
        return _buildApiKeyStep();
      case 2:
        return _buildProfileStep();
      case 3:
        return _buildPermissionsStep();
      case 4:
        return _buildCompleteStep();
      default:
        return _buildWelcomeStep();
    }
  }

  Widget _buildWelcomeStep() {
    return GlassCard(
      key: const ValueKey('welcome'),
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GradientIcon(
            icon: Icons.psychology,
            size: 72,
            colors: const [AppColors.accent, Color(0xFF8B5CF6)],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('JARVIS OS', style: AppTypography.display),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your Personal AI Operating System',
            style: AppTypography.subhead.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxl),
          GlassButton(
            label: 'Get Started',
            icon: Icons.arrow_forward,
            onPressed: () => setState(() => _step = 1),
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeyStep() {
    return GlassCard(
      key: const ValueKey('apikey'),
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Connect AI', style: AppTypography.title),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Enter your OpenRouter API key to enable AI features.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          GlassTextField(
            controller: _apiKeyController,
            hintText: 'sk-or-v1-...',
            obscureText: true,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Get a free key at openrouter.ai — \$10 credit = 1000+ requests/day',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Row(
            children: [
              GlassButton(
                label: 'Back',
                variant: GlassButtonVariant.secondary,
                onPressed: () => setState(() => _step = 0),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: GlassButton(
                  label: 'Continue',
                  icon: Icons.arrow_forward,
                  onPressed: _apiKeyController.text.isEmpty
                      ? null
                      : () => setState(() => _step = 2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStep() {
    return GlassCard(
      key: const ValueKey('profile'),
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About You', style: AppTypography.title),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tell us your name so your AI can personalize responses.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.backgroundElevated,
                    backgroundImage: _avatarPath != null ? FileImage(File(_avatarPath!)) : null,
                    child: _avatarPath == null
                        ? const Icon(Icons.person, size: 40, color: AppColors.textTertiary)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          GlassTextField(
            controller: _nameController,
            hintText: 'Your name',
          ),
          const SizedBox(height: AppSpacing.xxl),
          Row(
            children: [
              GlassButton(
                label: 'Back',
                variant: GlassButtonVariant.secondary,
                onPressed: () => setState(() => _step = 1),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: GlassButton(
                  label: 'Continue',
                  icon: Icons.arrow_forward,
                  onPressed: () => setState(() => _step = 3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsStep() {
    return GlassCard(
      key: const ValueKey('permissions'),
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Permissions', style: AppTypography.title),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Allow microphone access for voice commands.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          _PermissionTile(
            icon: Icons.mic,
            title: 'Microphone',
            subtitle: 'Voice commands and hands-free interaction',
            granted: _micGranted,
            onTap: _micGranted ? null : _requestMicPermission,
          ),
          const SizedBox(height: AppSpacing.xxl),
          Row(
            children: [
              GlassButton(
                label: 'Back',
                variant: GlassButtonVariant.secondary,
                onPressed: () => setState(() => _step = 2),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: GlassButton(
                  label: 'Continue',
                  icon: Icons.arrow_forward,
                  onPressed: () => setState(() => _step = 4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteStep() {
    return GlassCard(
      key: const ValueKey('complete'),
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GradientIcon(
            icon: Icons.check_circle,
            size: 72,
            colors: const [AppColors.success, Color(0xFF10B981)],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('All Set!', style: AppTypography.display),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your AI is ready. Click below to start.',
            style: AppTypography.subhead.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxl),
          GlassButton(
            label: _isSaving ? 'Starting...' : 'Launch JARVIS OS',
            icon: Icons.rocket_launch,
            onPressed: _isSaving ? null : _complete,
          ),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final VoidCallback? onTap;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, color: granted ? AppColors.success : AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.body),
                Text(subtitle, style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
              ],
            ),
          ),
          if (granted)
            const Icon(Icons.check_circle, color: AppColors.success, size: 20)
          else
            GlassButton(
              label: 'Allow',
              isCompact: true,
              variant: GlassButtonVariant.secondary,
              onPressed: onTap,
            ),
        ],
      ),
    );
  }
}
