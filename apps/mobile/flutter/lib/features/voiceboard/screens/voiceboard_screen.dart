import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/board_top_bar.dart';
import '../../../providers/voice_provider.dart';

/// Stroke model for lightweight drawing on the Voice Board canvas
class _VoiceStroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final bool isEraser;

  const _VoiceStroke({
    required this.points,
    required this.color,
    required this.width,
    this.isEraser = false,
  });

  Map<String, dynamic> toJson() {
    final hex = '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    return {
      'tool': isEraser ? 'eraser' : 'pen',
      'color': hex,
      'colorHex': hex,
      'width': width,
      'strokeWidth': width,
      'points': points.map((p) => {'x': p.dx, 'y': p.dy, 'pressure': 1.0}).toList(),
    };
  }

  factory _VoiceStroke.fromJson(Map<String, dynamic> json) {
    final ptsList = json['points'] as List<dynamic>?;
    List<Offset> pts = [];
    if (ptsList != null) {
      pts = ptsList
          .whereType<Map>()
          .map((m) => Offset((m['x'] as num?)?.toDouble() ?? 0.0, (m['y'] as num?)?.toDouble() ?? 0.0))
          .toList();
    }
    final isEraser = json['tool'] == 'eraser';
    Color color = Colors.white;
    final rawColor = json['color'] ?? json['colorHex'];
    if (rawColor is String && rawColor.contains('#')) {
      final hex = rawColor.replaceAll('#', '').trim();
      final parsed = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
      if (parsed != null) color = Color(parsed);
    }
    return _VoiceStroke(
      points: pts,
      color: isEraser ? const Color(0xFF0B0F19) : color,
      width: (json['width'] as num?)?.toDouble() ?? (json['strokeWidth'] as num?)?.toDouble() ?? (isEraser ? 24.0 : 3.5),
      isEraser: isEraser,
    );
  }
}

/// Voice Board — Speech to Whiteboard Text with freehand drawing.
/// Dark theme interface matching the EduBoard web application.
class VoiceBoardScreen extends ConsumerStatefulWidget {
  /// Optional saved-session id from a deep link (`/voiceboard?id=...`).
  final String? sessionId;

  const VoiceBoardScreen({super.key, this.sessionId});

  @override
  ConsumerState<VoiceBoardScreen> createState() => _VoiceBoardScreenState();
}

class _VoiceBoardScreenState extends ConsumerState<VoiceBoardScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<_VoiceStroke> _strokes = [];
  final List<_VoiceStroke> _undoneStrokes = [];
  _VoiceStroke? _currentStroke;

  // Active tool: 'pen', 'eraser', 'pan'
  String _activeTool = 'pen';
  Color _activeColor = Colors.white;
  double _fontSize = 24.0;
  bool _isSaving = false;
  bool _isSaved = false;

  static const List<Color> _swatchColors = [
    Color(0xFFFFFFFF), // White
    Color(0xFF3B82F6), // Blue
    Color(0xFF10B981), // Green
    Color(0xFFEF4444), // Red
    Color(0xFF8B5CF6), // Purple
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreSavedSession());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _restoreSavedSession() async {
    final sid = widget.sessionId?.trim();
    if (sid == null || sid.isEmpty) return;
    final restored = await ref.read(voiceProvider.notifier).loadVoiceSession(sid);
    if (mounted) {
      final raw = ref.read(voiceProvider).rawStrokes;
      if (raw.isNotEmpty) {
        setState(() {
          _strokes.clear();
          _strokes.addAll(raw.map((m) => _VoiceStroke.fromJson(m)));
        });
      }
    }
    if (!restored && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice session not found — starting a fresh board.'),
          backgroundColor: Color(0xFF1E293B),
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
      _isSaved = false;
    });

    try {
      final strokesPayload = _strokes.map((s) => s.toJson()).toList();
      await ref.read(voiceProvider.notifier).saveSession(strokesPayload);
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isSaved = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice session saved to history'),
            backgroundColor: Color(0xFF059669),
            duration: Duration(seconds: 2),
          ),
        );
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _isSaved = false);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _confirmClearBoard() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131823),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF262F40)),
        ),
        title: const Text('Clear Voice Board?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'All transcribed text and whiteboard strokes will be removed from this board.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () {
              ref.read(voiceProvider.notifier).clearTranscript();
              setState(() {
                _strokes.clear();
                _undoneStrokes.clear();
              });
              Navigator.pop(ctx);
              HapticFeedback.mediumImpact();
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _undo() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _undoneStrokes.add(_strokes.removeLast());
      });
      HapticFeedback.lightImpact();
    }
  }

  void _redo() {
    if (_undoneStrokes.isNotEmpty) {
      setState(() {
        _strokes.add(_undoneStrokes.removeLast());
      });
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(voiceProvider);
    final notifier = ref.read(voiceProvider.notifier);

    // Auto-scroll when history changes and sync strokes from cloud
    ref.listen<VoiceState>(voiceProvider, (previous, next) {
      if (next.transcriptHistory.length != (previous?.transcriptHistory.length ?? 0)) {
        _scrollToBottom();
      }
      if (next.rawStrokes.isNotEmpty && (previous?.rawStrokes.length ?? 0) != next.rawStrokes.length && _strokes.length != next.rawStrokes.length) {
        setState(() {
          _strokes.clear();
          _strokes.addAll(next.rawStrokes.map((m) => _VoiceStroke.fromJson(m)));
        });
      }
    });

    final isVoiceActive = state.isRecording && !state.isPaused;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header Bar matching web BoardHeader ──────────────────────
            BoardTopBar(
              title: 'Voice Board',
              subtitle: 'ENGLISH SPEECH TO WHITEBOARD TEXT',
              isSaving: _isSaving,
              isSaved: _isSaved,
              onBack: () => context.canPop() ? context.pop() : context.go('/dashboard'),
              onSave: _handleSave,
              centerActions: [
                // Voice ON pill button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (!state.isRecording) {
                        notifier.startListening();
                      } else if (state.isPaused) {
                        notifier.resumeListening();
                      }
                      HapticFeedback.selectionClick();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isVoiceActive
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isVoiceActive
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF334155),
                          width: 1,
                        ),
                        boxShadow: isVoiceActive
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                                  blurRadius: 8,
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.mic_rounded,
                            color: Colors.white,
                            size: 13,
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Voice ON',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Alt+V',
                              style: TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 9,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Voice OFF pill button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (state.isRecording) {
                        notifier.stopListening();
                      }
                      HapticFeedback.selectionClick();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: !isVoiceActive
                            ? const Color(0xFF1E293B)
                            : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: !isVoiceActive
                              ? const Color(0xFF475569)
                              : const Color(0xFF1E293B),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Voice OFF',
                        style: TextStyle(
                          color: !isVoiceActive
                              ? Colors.white
                              : const Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Main Canvas & Transcript Area ──────────────────────────────
            Expanded(
              child: Stack(
                children: [
                  // 1. Spoken Transcript Text on Canvas
                  Positioned.fill(
                    child: state.transcriptHistory.isEmpty && state.liveText.isEmpty
                        ? const SizedBox.shrink()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
                            itemCount: state.transcriptHistory.length +
                                (state.isRecording && state.liveText.isNotEmpty ? 1 : 0),
                            itemBuilder: (context, index) {
                              final displayList = state.transcriptHistory.reversed.toList();
                              final isLive = state.isRecording &&
                                  state.liveText.isNotEmpty &&
                                  index == displayList.length;

                              if (isLive) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Text(
                                    state.liveText,
                                    style: TextStyle(
                                      color: const Color(0xFF60A5FA),
                                      fontSize: _fontSize,
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                );
                              }

                              final text = displayList[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Text(
                                  text,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: _fontSize,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // 2. Freehand Annotation Layer on top of Canvas
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: _activeTool == 'pan'
                          ? HitTestBehavior.deferToChild
                          : HitTestBehavior.opaque,
                      onPanStart: _activeTool == 'pan'
                          ? null
                          : (details) {
                              setState(() {
                                _currentStroke = _VoiceStroke(
                                  points: [details.localPosition],
                                  color: _activeTool == 'eraser'
                                      ? const Color(0xFF0B0F19)
                                      : _activeColor,
                                  width: _activeTool == 'eraser' ? 24.0 : 3.5,
                                  isEraser: _activeTool == 'eraser',
                                );
                              });
                            },
                      onPanUpdate: _activeTool == 'pan'
                          ? null
                          : (details) {
                              if (_currentStroke == null) return;
                              setState(() {
                                _currentStroke = _VoiceStroke(
                                  points: [..._currentStroke!.points, details.localPosition],
                                  color: _currentStroke!.color,
                                  width: _currentStroke!.width,
                                  isEraser: _currentStroke!.isEraser,
                                );
                              });
                            },
                      onPanEnd: _activeTool == 'pan'
                          ? null
                          : (_) {
                              if (_currentStroke != null) {
                                setState(() {
                                  _strokes.add(_currentStroke!);
                                  _currentStroke = null;
                                  _undoneStrokes.clear();
                                });
                              }
                            },
                      child: CustomPaint(
                        painter: _VoiceStrokePainter(
                          strokes: _strokes,
                          currentStroke: _currentStroke,
                        ),
                      ),
                    ),
                  ),

                  // 3. Floating Bottom Toolbar matching screenshot 1 ─────────
                  Positioned(
                    bottom: 16,
                    left: 12,
                    right: 12,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131823),
                          borderRadius: BorderRadius.circular(36),
                          border: Border.all(color: const Color(0xFF262F40), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 1. Pen Tool (Active in Blue Circle)
                              _ToolIcon(
                                icon: Icons.edit_rounded,
                                tooltip: 'Pen Tool',
                                isSelected: _activeTool == 'pen',
                                activeBgColor: const Color(0xFF3B82F6),
                                onTap: () {
                                  setState(() => _activeTool = 'pen');
                                  HapticFeedback.selectionClick();
                                },
                              ),
                              const SizedBox(width: 4),

                              // 2. Eraser Tool
                              _ToolIcon(
                                icon: Icons.cleaning_services_rounded,
                                tooltip: 'Eraser',
                                isSelected: _activeTool == 'eraser',
                                onTap: () {
                                  setState(() => _activeTool = 'eraser');
                                  HapticFeedback.selectionClick();
                                },
                              ),
                              const SizedBox(width: 4),

                              // 3. Pan / Move Tool (4-way arrows)
                              _ToolIcon(
                                icon: Icons.open_with_rounded,
                                tooltip: 'Pan Canvas',
                                isSelected: _activeTool == 'pan',
                                onTap: () {
                                  setState(() => _activeTool = 'pan');
                                  HapticFeedback.selectionClick();
                                },
                              ),
                              const SizedBox(width: 8),

                              // 4. Color Swatches (White, Blue, Green, Red, Purple)
                              ..._swatchColors.map((color) {
                                final isSelected = _activeColor.toARGB32() == color.toARGB32();
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _activeColor = color;
                                      _activeTool = 'pen';
                                    });
                                    HapticFeedback.selectionClick();
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: isSelected
                                          ? Border.all(color: Colors.white, width: 2.2)
                                          : Border.all(color: Colors.transparent, width: 1),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: color.withValues(alpha: 0.6),
                                                blurRadius: 6,
                                              )
                                            ]
                                          : null,
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(width: 8),

                              // Divider
                              Container(
                                width: 1,
                                height: 22,
                                color: const Color(0xFF262F40),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                              ),

                              // 5. Undo
                              _ToolIcon(
                                icon: Icons.undo_rounded,
                                tooltip: 'Undo Stroke',
                                isSelected: false,
                                isEnabled: _strokes.isNotEmpty,
                                onTap: _undo,
                              ),
                              const SizedBox(width: 4),

                              // 6. Redo
                              _ToolIcon(
                                icon: Icons.redo_rounded,
                                tooltip: 'Redo Stroke',
                                isSelected: false,
                                isEnabled: _undoneStrokes.isNotEmpty,
                                onTap: _redo,
                              ),
                              const SizedBox(width: 4),

                              // Reset / Clear Voice Board
                              _ToolIcon(
                                icon: Icons.refresh_rounded,
                                tooltip: 'Clear Board',
                                isSelected: false,
                                onTap: _confirmClearBoard,
                              ),
                              const SizedBox(width: 8),

                              // Divider
                              Container(
                                width: 1,
                                height: 22,
                                color: const Color(0xFF262F40),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                              ),

                              // 7. Minus Font Size
                              _ToolIcon(
                                icon: Icons.remove_rounded,
                                tooltip: 'Decrease Font Size',
                                isSelected: false,
                                onTap: () {
                                  setState(() {
                                    _fontSize = (_fontSize - 2).clamp(16.0, 48.0);
                                  });
                                  HapticFeedback.selectionClick();
                                },
                              ),
                              const SizedBox(width: 4),

                              // 8. Size label (e.g. 24px)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  '${_fontSize.toInt()}px',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),

                              // 9. Plus Font Size
                              _ToolIcon(
                                icon: Icons.add_rounded,
                                tooltip: 'Increase Font Size',
                                isSelected: false,
                                onTap: () {
                                  setState(() {
                                    _fontSize = (_fontSize + 2).clamp(16.0, 48.0);
                                  });
                                  HapticFeedback.selectionClick();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
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

class _ToolIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final bool isEnabled;
  final Color? activeBgColor;
  final VoidCallback onTap;

  const _ToolIcon({
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    this.isEnabled = true,
    this.activeBgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? (activeBgColor ?? const Color(0xFF3B82F6))
                  : Colors.transparent,
            ),
            child: Icon(
              icon,
              size: 18,
              color: !isEnabled
                  ? const Color(0xFF475569)
                  : (isSelected ? Colors.white : const Color(0xFF94A3B8)),
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceStrokePainter extends CustomPainter {
  final List<_VoiceStroke> strokes;
  final _VoiceStroke? currentStroke;

  _VoiceStrokePainter({
    required this.strokes,
    this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final allStrokes = [...strokes, if (currentStroke != null) currentStroke!];
    for (final s in allStrokes) {
      if (s.points.length < 2) continue;
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(s.points.first.dx, s.points.first.dy);
      for (int i = 1; i < s.points.length; i++) {
        path.lineTo(s.points[i].dx, s.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceStrokePainter oldDelegate) => true;
}
