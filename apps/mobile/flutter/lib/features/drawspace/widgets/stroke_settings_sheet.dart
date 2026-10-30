import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/whiteboard_stroke_model.dart';
import '../../../providers/whiteboard_provider.dart';

/// Comprehensive modal sheet for drawing tool options:
/// - Stroke thickness slider
/// - Predefined color palette: Ink, Ruby, Amber, Emerald, Azure, Violet
/// - Custom color selector & Recent colors
/// - Geometric shapes (Rectangle, Circle, Triangle, Line, Arrow, Double Arrow, Star, Diamond)
/// - Vanishing Laser Pointer controls (Red, Green, Blue + 1-5s fade duration)
/// - Focus Spotlight radius slider
/// - Presentation Pointer style selector
class StrokeSettingsSheet extends ConsumerWidget {
  const StrokeSettingsSheet({super.key});

  static const List<Map<String, dynamic>> presetPalette = [
    {'name': 'Ink', 'color': Color(0xFF0F172A)},
    {'name': 'Ruby', 'color': Color(0xFFDC2626)},
    {'name': 'Amber', 'color': Color(0xFFEA580C)},
    {'name': 'Emerald', 'color': Color(0xFF16A34A)},
    {'name': 'Azure', 'color': Color(0xFF2563EB)},
    {'name': 'Violet', 'color': Color(0xFF9333EA)},
  ];

  static const List<Color> customSwatches = [
    Color(0xFF000000), Color(0xFF475569), Color(0xFFE11D48),
    Color(0xFFF97316), Color(0xFFFACC15), Color(0xFF10B981),
    Color(0xFF06B6D4), Color(0xFF3B82F6), Color(0xFF8B5CF6),
    Color(0xFFEC4899), Color(0xFF78350F), Color(0xFFFFFFFF),
  ];

  void _openCustomColorPicker(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom Color Picker'),
        content: SizedBox(
          width: 280,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: customSwatches.map((c) {
              return GestureDetector(
                onTap: () {
                  ref.read(whiteboardProvider.notifier).setColor(c);
                  Navigator.pop(ctx);
                  HapticFeedback.selectionClick();
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black26, width: 2),
                    boxShadow: [
                      BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 6),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(whiteboardProvider);
    final notifier = ref.read(whiteboardProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Drawing Tools Settings',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.palette_outlined, size: 18),
                    label: const Text('Custom Color'),
                    onPressed: () => _openCustomColorPicker(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Stroke Width
              Row(
                children: [
                  Text('Stroke Width', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('${state.activeStrokeWidth.toStringAsFixed(0)} px', style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                ),
                child: Slider(
                  value: state.activeStrokeWidth,
                  min: 1.0,
                  max: 24.0,
                  divisions: 23,
                  onChanged: (v) {
                    notifier.setStrokeWidth(v);
                    HapticFeedback.selectionClick();
                  },
                ),
              ),
              const SizedBox(height: 14),

              // Color Palette - 6 preset colors
              Text('Preset Palette', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: presetPalette.map((item) {
                  final color = item['color'] as Color;
                  final label = item['name'] as String;
                  final isSelected = state.activeColor.toARGB32() == color.toARGB32();

                  return GestureDetector(
                    onTap: () {
                      notifier.setColor(color);
                      HapticFeedback.selectionClick();
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? colorScheme.primary : Colors.grey.withValues(alpha: 0.3),
                              width: isSelected ? 3.5 : 2.0,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 10, spreadRadius: 2)]
                                : [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                          ),
                          child: isSelected ? const Icon(Icons.check, size: 22, color: Colors.white) : null,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

              // Recent Colors
              if (state.recentColors.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('Recent Colors', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: state.recentColors.map((c) {
                      final isSelected = state.activeColor.toARGB32() == c.toARGB32();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            notifier.setColor(c);
                            HapticFeedback.selectionClick();
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? colorScheme.primary : Colors.grey.withValues(alpha: 0.3),
                                width: isSelected ? 2.5 : 1.0,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 18),

              // Geometric Shapes
              Text('Geometric Shapes', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: WhiteboardShapeType.values.map((s) {
                    final isSelected = state.activeShape == s && state.activeTool == WhiteboardTool.shape;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            notifier.setTool(WhiteboardTool.shape);
                            notifier.setShape(s);
                            HapticFeedback.selectionClick();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? colorScheme.primary.withValues(alpha: 0.16) : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(s.icon, size: 18, color: isSelected ? colorScheme.primary : colorScheme.onSurface),
                                const SizedBox(width: 6),
                                Text(
                                  s.label,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),

              // Vanishing Laser Pointer Settings
              Text('Vanishing Laser Pointer', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Color: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ...[
                    {'color': const Color(0xFFFF0000), 'name': 'Ruby Red'},
                    {'color': const Color(0xFF00E676), 'name': 'Emerald Green'},
                    {'color': const Color(0xFF2979FF), 'name': 'Azure Blue'},
                  ].map((entry) {
                    final c = entry['color'] as Color;
                    final isSel = state.laserColor.toARGB32() == c.toARGB32();
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: GestureDetector(
                        onTap: () {
                          notifier.setLaserColor(c);
                          HapticFeedback.selectionClick();
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSel ? Colors.black : Colors.white,
                              width: isSel ? 3 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const Spacer(),
                  Text('Fade: ${state.laserDurationSeconds}s', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                ],
              ),
              Slider(
                value: state.laserDurationSeconds.toDouble(),
                min: 1.0,
                max: 5.0,
                divisions: 4,
                onChanged: (v) => notifier.setLaserDuration(v.toInt()),
              ),
              const SizedBox(height: 8),

              // Focus Spotlight Size
              Row(
                children: [
                  Text('Focus Spotlight Radius', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('${state.spotlightRadius.toInt()} px', style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              Slider(
                value: state.spotlightRadius,
                min: 40.0,
                max: 180.0,
                divisions: 28,
                onChanged: notifier.setSpotlightRadius,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
