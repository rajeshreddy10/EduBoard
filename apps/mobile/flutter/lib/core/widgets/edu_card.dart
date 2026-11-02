import 'dart:ui';
import 'package:flutter/material.dart';

/// Clean themed Material 3 card with modern rounded corners, subtle gradient border and optional onTap
class EduCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final double elevation;
  final List<Color>? gradientColors;
  final bool isGlass;

  const EduCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 18.0,
    this.elevation = 0,
    this.gradientColors,
    this.isGlass = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final border = BorderSide(
      color: borderColor ?? colorScheme.onSurface.withValues(alpha: isDark ? 0.09 : 0.07),
      width: 1.0,
    );

    final resolvedBg = backgroundColor ?? (isGlass
        ? colorScheme.surface.withValues(alpha: isDark ? 0.70 : 0.85)
        : colorScheme.surface);

    final decoration = BoxDecoration(
      color: gradientColors == null ? resolvedBg : null,
      gradient: gradientColors != null
          ? LinearGradient(
              colors: gradientColors!,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.fromBorderSide(border),
      boxShadow: elevation > 0
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.28 * elevation.clamp(0.5, 2.0) : 0.05 * elevation.clamp(0.5, 2.0)),
                blurRadius: 12 * elevation,
                offset: Offset(0, 3 * elevation),
              ),
            ]
          : null,
    );

    Widget content = Container(
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (isGlass) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: content,
        ),
      );
    }

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: content,
        ),
      );
    }

    if (margin != null) {
      return Padding(padding: margin!, child: content);
    }
    return content;
  }
}
