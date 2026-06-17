import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/glass/glass_text_field.dart';
import 'signup_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) return;

    setState(() => _isLoading = true);

    final error = await ref.read(authStateProvider.notifier).login(
          email,
          password,
          rememberMe: _rememberMe,
        );

    setState(() => _isLoading = false);

    if (error != null && mounted) {
      _showError(error);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
          Positioned(
            bottom: -size.height * 0.15,
            left: -size.width * 0.1,
            child: Container(
              width: size.width * 0.4,
              height: size.width * 0.4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accentMuted.withOpacity(0.3),
                    Colors.transparent,
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Login card
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
                          'Welcome to JARVIS OS',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'Sign in to continue',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxxl),
                        // Email
                        GlassTextField(
                          controller: _emailController,
                          hintText: 'Email',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // Password
                        GlassTextField(
                          controller: _passwordController,
                          hintText: 'Password',
                          prefixIcon: Icons.lock_outlined,
                          obscureText: true,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // Remember Me
                        Row(
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: _rememberMe,
                                onChanged: (v) =>
                                    setState(() => _rememberMe = v ?? true),
                                fillColor: WidgetStateProperty.resolveWith(
                                  (states) => states.contains(WidgetState.selected)
                                      ? AppColors.accent
                                      : Colors.transparent,
                                ),
                                checkColor: Colors.white,
                                side: const BorderSide(
                                    color: AppColors.glassBorder),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _rememberMe = !_rememberMe),
                              child: const Text(
                                'Remember me',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        // Login button
                        SizedBox(
                          width: double.infinity,
                          child: GlassButton(
                            label: 'Sign In',
                            onPressed: _isLoading ? null : _login,
                            isLoading: _isLoading,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // Create account
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account?",
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SignupScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Create Account',
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
