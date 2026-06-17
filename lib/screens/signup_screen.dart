import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/glass/glass_text_field.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _nameError = null;
      _emailError = null;
      _passwordError = null;
      _confirmError = null;
    });

    bool valid = true;

    if (_nameController.text.trim().isEmpty) {
      _nameError = 'Name is required';
      valid = false;
    }

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _emailError = 'Email is required';
      valid = false;
    } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      _emailError = 'Invalid email address';
      valid = false;
    }

    if (_passwordController.text.isEmpty) {
      _passwordError = 'Password is required';
      valid = false;
    } else if (_passwordController.text.length < 6) {
      _passwordError = 'Password must be at least 6 characters';
      valid = false;
    }

    if (_confirmController.text != _passwordController.text) {
      _confirmError = 'Passwords do not match';
      valid = false;
    }

    return valid;
  }

  Future<void> _signup() async {
    if (!_validate()) return;

    setState(() => _isLoading = true);

    final error = await ref.read(authStateProvider.notifier).register(
          _emailController.text.trim(),
          _passwordController.text,
          _nameController.text.trim(),
        );

    setState(() => _isLoading = false);

    if (error != null && mounted) {
      _emailError = error;
      setState(() {});
      return;
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Ambient glow
          Positioned(
            top: -size.height * 0.2,
            right: -size.width * 0.1,
            child: Container(
              width: size.width * 0.6,
              height: size.width * 0.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accentGlow,
                    AppColors.accentGlow.withOpacity(0.02),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          // Signup card
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xxxl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: Container(
                    width: 400,
                    padding: const EdgeInsets.all(AppSpacing.xxxl),
                    decoration: BoxDecoration(
                      color: AppColors.glassFill,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusXxl),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.accent, AppColors.accentMuted],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                          child: const Center(
                            child: Text('◉',
                                style: TextStyle(
                                    fontSize: 22, color: Colors.white)),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'Set up your JARVIS OS account',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxxl),
                        // Name
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GlassTextField(
                              controller: _nameController,
                              hintText: 'Display Name',
                              prefixIcon: Icons.person_outlined,
                            ),
                            if (_nameError != null)
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: AppSpacing.xs),
                                child: Text(
                                  _nameError!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // Email
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GlassTextField(
                              controller: _emailController,
                              hintText: 'Email',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            if (_emailError != null)
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: AppSpacing.xs),
                                child: Text(
                                  _emailError!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // Password
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GlassTextField(
                              controller: _passwordController,
                              hintText: 'Password',
                              prefixIcon: Icons.lock_outlined,
                              obscureText: true,
                            ),
                            if (_passwordError != null)
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: AppSpacing.xs),
                                child: Text(
                                  _passwordError!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // Confirm Password
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GlassTextField(
                              controller: _confirmController,
                              hintText: 'Confirm Password',
                              prefixIcon: Icons.lock_outlined,
                              obscureText: true,
                            ),
                            if (_confirmError != null)
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: AppSpacing.xs),
                                child: Text(
                                  _confirmError!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        // Signup button
                        SizedBox(
                          width: double.infinity,
                          child: GlassButton(
                            label: 'Create Account',
                            onPressed: _isLoading ? null : _signup,
                            isLoading: _isLoading,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // Back to login
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Already have an account?',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
