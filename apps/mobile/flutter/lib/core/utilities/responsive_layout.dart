import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Helper utilities and widgets for Mobile & Tablet responsive adaptation
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
  });

  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= AppConstants.mobileMaxWidth;
  }

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < AppConstants.mobileMaxWidth;
  }

  static double contentWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 800) {
      return 760;
    }
    return width;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppConstants.mobileMaxWidth && tablet != null) {
          return tablet!;
        }
        return mobile;
      },
    );
  }
}
