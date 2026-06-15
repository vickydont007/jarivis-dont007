import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../glass/glass_button.dart';
import '../glass/glass_card.dart';

class ErrorState extends StatelessWidget {
  final String message;
  final String? details;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final IconData icon;

  const ErrorState({
    super.key,
    required this.message,
    this.details,
    this.onRetry,
    this.retryLabel,
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: GlassCard(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.lg),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              if (details != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  details!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.xl),
                GlassButton(
                  onPressed: onRetry,
                  label: retryLabel ?? 'Try Again',
                  icon: Icons.refresh,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class InlineErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;
  final VoidCallback? onAction;
  final String? actionLabel;

  const InlineErrorBanner({
    super.key,
    required this.message,
    this.onDismiss,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      variant: GlassCardVariant.status,
      statusColor: AppColors.error,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            ),
          ),
          if (onAction != null && actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!, style: const TextStyle(color: AppColors.accent, fontSize: 12)),
            ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 16, color: AppColors.textTertiary),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

class LoadingState extends StatelessWidget {
  final String? message;
  final double size;
  final bool compact;

  const LoadingState({
    super.key,
    this.message,
    this.size = 32,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: AppColors.accent,
                  strokeWidth: 2,
                ),
              ),
              if (message != null) ...[
                const SizedBox(width: 12),
                Text(
                  message!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              color: AppColors.accent,
              strokeWidth: 3,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.glassFill.withOpacity(_animation.value),
            borderRadius: widget.borderRadius ?? BorderRadius.circular(AppSpacing.radiusMd),
          ),
        );
      },
    );
  }
}

class SkeletonListTile extends StatelessWidget {
  final bool hasLeading;
  final int lines;

  const SkeletonListTile({
    super.key,
    this.hasLeading = true,
    this.lines = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GlassCard(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm,
          ),
          leading: hasLeading
              ? const SkeletonLoader(width: 40, height: 40)
              : null,
          title: SkeletonLoader(
            width: 150,
            height: 16,
            borderRadius: BorderRadius.circular(8),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(lines, (i) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SkeletonLoader(
                width: i == lines - 1 ? 100 : 200,
                height: 12,
                borderRadius: BorderRadius.circular(6),
              ),
            )),
          ),
        ),
      ),
    );
  }
}

class SkeletonCard extends StatelessWidget {
  final double? width;
  final double height;

  const SkeletonCard({
    super.key,
    this.width,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      width: width ?? double.infinity,
      height: height,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    );
  }
}
