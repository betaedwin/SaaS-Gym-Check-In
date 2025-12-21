import 'package:flutter/material.dart';

class AppSpacing {
  static const double screenPaddingH = 20;
  static const double screenPaddingV = 20;

  static const double tight = 6;
  static const double standard = 14;
  static const double loose = 28;

  static const double rowGap = 16;
}

class AppTextStyles {
  AppTextStyles(this.theme);

  final ThemeData theme;

  TextStyle? get display => theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.05,
        letterSpacing: -0.3,
        color: theme.colorScheme.onSurface,
      );

  TextStyle? get primary => theme.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w500,
        height: 1.25,
        color: theme.colorScheme.onSurface,
      );

  TextStyle? get primarySoft => theme.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w500,
        height: 1.25,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.88),
      );

  TextStyle? get secondary => theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        height: 1.2,
        letterSpacing: 0.25,
        color: theme.colorScheme.onSurfaceVariant,
      );

  TextStyle? get tertiaryLabel => theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w500,
        height: 1.2,
        letterSpacing: 0.25,
        color: theme.colorScheme.onSurfaceVariant,
      );

  TextStyle? get tertiaryValue => theme.textTheme.bodySmall?.copyWith(
        height: 1.25,
        color: theme.colorScheme.onSurfaceVariant,
      );

  TextStyle? get sectionTitle => theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.2,
        color: theme.colorScheme.onSurface,
      );

  TextStyle? get actionText => theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
      );
}

class AppHairlineDivider extends StatelessWidget {
  const AppHairlineDivider({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ??
        Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.65);
    return Divider(height: 1, thickness: 0.5, color: resolvedColor);
  }
}

