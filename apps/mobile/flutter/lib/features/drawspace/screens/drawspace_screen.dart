import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/widgets/board_top_bar.dart';
import '../../../providers/whiteboard_provider.dart';
import '../widgets/drawspace_canvas.dart';
import '../widgets/reference_drawer.dart';
import '../widgets/stroke_settings_sheet.dart';
import '../widgets/teacher_notes_panel.dart';
import '../widgets/tool_palette.dart';

/// Full interactive pedagogical whiteboard studio — DrawSpace Interactive Canvas Studio
/// Dark theme interface matching the EduBoard web application.
class DrawSpaceScreen extends ConsumerStatefulWidget {
  /// Optional board id from a deep link (`/drawspace?id=...`): opens and
  /// restores the EXISTING board record instead of forking a new one.
  final String? boardId;

  const DrawSpaceScreen({super.key, this.boardId});

  @override
  ConsumerState<DrawSpaceScreen> createState() => _DrawSpaceScreenState();
}

class _DrawSpaceScreenState extends ConsumerState<DrawSpaceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyPendingBoard());
  }

  /// Consumes the deep-linked board id: persist it as the last-active board so
  /// an interrupted session resumes the SAME board on next launch.
  Future<void> _applyPendingBoard() async {
    final bid = widget.boardId?.trim();
    if (bid == null || bid.isEmpty) return;
    await StorageService.put(AppConstants.whiteboardBox, 'active_board_id', bid);
    await ref.read(whiteboardProvider.notifier).setActiveBoard(bid);
  }

  void _openStrokeSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const StrokeSettingsSheet(),
    );
  }

  void _confirmClearCanvas() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131823),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF262F40)),
        ),
        title: const Text('Clear Whiteboard Canvas?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'All active strokes and placed text elements will be cleared from this board.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () {
              ref.read(whiteboardProvider.notifier).clearCanvas();
              Navigator.pop(ctx);
              HapticFeedback.mediumImpact();
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(whiteboardProvider);
    final notifier = ref.read(whiteboardProvider.notifier);

    // Presentation Mode — full-screen canvas, exit button only.
    if (state.isPresentationMode) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0F19),
        body: Stack(
          children: [
            const Positioned.fill(child: DrawSpaceCanvas()),
            Positioned(
              top: 16,
              right: 16,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    notifier.togglePresentationMode();
                    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fullscreen_exit_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Exit Present',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header matching web BoardHeader ─────────────────────────
            BoardTopBar(
              title: 'DrawSpace Canvas',
              subtitle: 'MANUAL SAVE',
              isSaving: state.saveStatus == 'saving',
              isSaved: state.saveStatus == 'saved',
              onBack: () => context.go('/dashboard'),
              onSave: () async {
                await notifier.saveBoard();
                HapticFeedback.lightImpact();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Board saved successfully'),
                      duration: Duration(seconds: 2),
                      backgroundColor: Color(0xFF059669),
                    ),
                  );
                }
              },
              centerActions: [
                // Reference Pill
                _DarkHeaderPill(
                  icon: Icons.menu_book_rounded,
                  label: 'Reference',
                  isActive: state.isReferenceOpen,
                  onTap: () {
                    notifier.toggleReferencePanel();
                    HapticFeedback.selectionClick();
                  },
                ),
                const SizedBox(width: 8),

                // Group Step Pill
                _DarkHeaderPill(
                  icon: Icons.add_rounded,
                  label: 'Group Step (${state.stepIndex + 1})',
                  isActive: state.isStepRevealActive,
                  onTap: () {
                    notifier.toggleStepReveal();
                    HapticFeedback.selectionClick();
                  },
                ),
              ],
            ),

            // ── Main Body with Canvas & Floating Panels ────────────────────
            Expanded(
              child: Stack(
                children: [
                  // Drawing Canvas (with optional Reference Drawer)
                  Row(
                    children: [
                      if (state.isReferenceOpen)
                        const Expanded(flex: 3, child: ReferenceDrawer()),
                      Expanded(
                        flex: state.isReferenceOpen ? 7 : 10,
                        child: const DrawSpaceCanvas(),
                      ),
                    ],
                  ),

                  // ── Top-Right Floating Card: Teacher Teleprompter ────────
                  Positioned(
                    top: 12,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131823),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF262F40), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.description_outlined,
                            color: Color(0xFFF59E0B),
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Teacher Teleprompter',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Eye visibility icon
                          GestureDetector(
                            onTap: () {
                              notifier.toggleNotesPanel();
                              HapticFeedback.selectionClick();
                            },
                            child: Icon(
                              state.isNotesOpen ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                              color: const Color(0xFF94A3B8),
                              size: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Orange + Note button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                if (!state.isNotesOpen) {
                                  notifier.toggleNotesPanel();
                                }
                                HapticFeedback.lightImpact();
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add, color: Colors.black, size: 12),
                                    SizedBox(width: 2),
                                    Text(
                                      'Note',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Progressive Reveal Step Manager Banner (if active) ────
                  if (state.isStepRevealActive)
                    Positioned(
                      top: 54,
                      left: 16,
                      right: 16,
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 480),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131823),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Step ${state.stepIndex + 1}/${state.stepTitles.isEmpty ? 1 : state.stepTitles.length}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: Color(0xFF60A5FA),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  state.stepTitles.isNotEmpty
                                      ? state.stepTitles[state.stepIndex]
                                      : 'Progressive Step',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 20),
                                tooltip: 'Previous Step',
                                onPressed: state.stepIndex > 0 ? notifier.prevStep : null,
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
                                tooltip: 'Next Step',
                                onPressed: state.stepIndex < state.stepTitles.length - 1 ? notifier.nextStep : null,
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 18),
                                tooltip: 'Close Step Mode',
                                onPressed: notifier.toggleStepReveal,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // ── Floating Bottom Toolbar ──────────────────────────────
                  Positioned(
                    bottom: 16,
                    left: 12,
                    right: 12,
                    child: Center(
                      child: ToolPalette(
                        onOpenStrokeSettings: _openStrokeSettings,
                        onToggleTeacherNotes: notifier.toggleNotesPanel,
                        onClearCanvas: _confirmClearCanvas,
                        isPresenting: state.isPresentationMode,
                        onTogglePresent: () {
                          notifier.togglePresentationMode();
                          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                        },
                      ),
                    ),
                  ),

                  // ── Slide-in Teacher Notes Panel ─────────────────────────
                  if (state.isNotesOpen)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      right: 0,
                      child: TeacherNotesPanel(
                        onClose: notifier.toggleNotesPanel,
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

/// Dark header pill button matching the web UI
class _DarkHeaderPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _DarkHeaderPill({
    required this.icon,
    required this.label,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF1E3A8A) : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? const Color(0xFF3B82F6) : const Color(0xFF334155),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive ? const Color(0xFF93C5FD) : const Color(0xFF94A3B8),
                size: 13,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : const Color(0xFFCBD5E1),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
