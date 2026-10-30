import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/edu_button.dart';
import '../../../providers/auth_provider.dart';
import '../widgets/onboarding_page_item.dart';

/// Multi-step onboarding carousel highlighting DrawSpace, VoiceBoard, and DocCanvas
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<OnboardingPageData> _pages = const [
    OnboardingPageData(
      title: 'Infinite Pedagogical Whiteboard',
      subtitle: 'Teach effortlessly with precision pens, geometric shapes, spotlight tools, and private teacher cues.',
      icon: Icons.gesture_rounded,
      accentColor: Color(0xFF38BDF8),
    ),
    OnboardingPageData(
      title: 'Real-time VoiceBoard',
      subtitle: 'Voice-to-text dictation transforms live audio into draggable lecture cards on your digital canvas.',
      icon: Icons.mic_rounded,
      accentColor: Color(0xFF34D399),
    ),
    OnboardingPageData(
      title: 'Interactive DocCanvas',
      subtitle: 'Overlay highlighters, step-by-step replay timelines, and interactive math solvers on academic notes.',
      icon: Icons.description_rounded,
      accentColor: Color(0xFFF43F5E),
    ),
  ];

  void _finishOnboarding() {
    ref.read(authProvider.notifier).completeOnboarding();
    final authState = ref.read(authProvider);
    if (authState.isAuthenticated) {
      context.go('/dashboard');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _finishOnboarding,
            child: Text(
              'Skip',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (idx) => setState(() => _currentIndex = idx),
                itemBuilder: (context, idx) => OnboardingPageItem(data: _pages[idx]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentIndex == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentIndex == i
                        ? _pages[_currentIndex].accentColor
                        : colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 36),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: _currentIndex == _pages.length - 1
                  ? EduButton(
                      label: 'Get Started with EduBoard',
                      icon: Icons.rocket_launch_rounded,
                      onPressed: _finishOnboarding,
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: EduButton(
                            label: 'Next',
                            icon: Icons.arrow_forward_rounded,
                            onPressed: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeInOut,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
