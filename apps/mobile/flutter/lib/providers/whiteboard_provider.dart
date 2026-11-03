import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../core/services/storage_service.dart';
import '../models/doc_annotation_model.dart';
import '../models/whiteboard_stroke_model.dart';
import '../repositories/whiteboard_repository.dart';

final whiteboardRepositoryProvider = Provider<WhiteboardRepository>((ref) {
  return LiveWhiteboardRepository();
});

class WhiteboardState {
  final WhiteboardTool activeTool;
  final WhiteboardShapeType activeShape;
  final Color activeColor;
  final double activeStrokeWidth;
  final List<WhiteboardStroke> strokes;
  final List<WhiteboardStroke> undoneStrokes;
  final List<WhiteboardTextElement> textElements;
  final List<WhiteboardTextElement> undoneTextElements;
  final List<TeacherNote> teacherNotes;
  final double scale;
  final Offset panOffset;
  final double rotation;
  final Offset? laserPosition;
  final Color laserColor;
  final Offset? spotlightPosition;
  final double spotlightRadius;
  final double revealFraction;
  final bool isNotesOpen;
  final bool isReferenceOpen;
  final bool isPresentationMode;
  final String? selectedElementId;
  final String activeBoardId;
  final bool autoSaveEnabled;
  final String boardTitle;
  final String boardDescription;
  final String boardCategory;
  /// 'saving' | 'saved' | '' (idle) — mirrors the Web save-status UX.
  final String saveStatus;
  final List<Color> recentColors;
  final int laserDurationSeconds;
  final String pointerStyle;
  final Offset? pointerPosition;
  final int stepIndex;
  final List<String> stepTitles;
  final bool isStepRevealActive;
  final DocumentModel? referenceDocument;
  final bool showDocOnCanvas;

  const WhiteboardState({
    this.activeTool = WhiteboardTool.pen,
    this.activeShape = WhiteboardShapeType.rectangle,
    this.activeColor = const Color(0xFF000000),
    this.activeStrokeWidth = AppConstants.defaultStrokeWidth,
    this.strokes = const [],
    this.undoneStrokes = const [],
    this.textElements = const [],
    this.undoneTextElements = const [],
    this.teacherNotes = const [],
    this.scale = 1.0,
    this.panOffset = Offset.zero,
    this.rotation = 0.0,
    this.laserPosition,
    this.laserColor = const Color(0xFFFF0000),
    this.spotlightPosition,
    this.spotlightRadius = 90.0,
    this.revealFraction = 0.0,
    this.isNotesOpen = false,
    this.isReferenceOpen = false,
    this.isPresentationMode = false,
    this.selectedElementId,
    this.activeBoardId = 'main_board',
    this.autoSaveEnabled = true,
    this.boardTitle = 'DrawSpace Interactive Whiteboard',
    this.boardDescription = '',
    this.boardCategory = 'whiteboard',
    this.saveStatus = '',
    this.recentColors = const [
      Color(0xFF0F172A),
      Color(0xFFDC2626),
      Color(0xFFEA580C),
      Color(0xFF16A34A),
      Color(0xFF2563EB),
      Color(0xFF9333EA),
    ],
    this.laserDurationSeconds = 2,
    this.pointerStyle = 'dot',
    this.pointerPosition,
    this.stepIndex = 0,
    this.stepTitles = const [
      'Step 1: Introduction & Topic Definition',
      'Step 2: Fundamental Principles',
      'Step 3: Mathematical Formulation',
      'Step 4: Worked Solution & Analysis',
      'Step 5: Lesson Summary & Reflection',
    ],
    this.isStepRevealActive = false,
    this.referenceDocument,
    this.showDocOnCanvas = true,
  });

  WhiteboardState copyWith({
    WhiteboardTool? activeTool,
    WhiteboardShapeType? activeShape,
    Color? activeColor,
    double? activeStrokeWidth,
    List<WhiteboardStroke>? strokes,
    List<WhiteboardStroke>? undoneStrokes,
    List<WhiteboardTextElement>? textElements,
    List<WhiteboardTextElement>? undoneTextElements,
    List<TeacherNote>? teacherNotes,
    double? scale,
    Offset? panOffset,
    double? rotation,
    Offset? laserPosition,
    Color? laserColor,
    Offset? spotlightPosition,
    double? spotlightRadius,
    double? revealFraction,
    bool? isNotesOpen,
    bool? isReferenceOpen,
    bool? isPresentationMode,
    String? selectedElementId,
    String? activeBoardId,
    bool? autoSaveEnabled,
    String? boardTitle,
    String? boardDescription,
    String? boardCategory,
    String? saveStatus,
    bool clearSaveStatus = false,
    List<Color>? recentColors,
    int? laserDurationSeconds,
    String? pointerStyle,
    Offset? pointerPosition,
    int? stepIndex,
    List<String>? stepTitles,
    bool? isStepRevealActive,
    DocumentModel? referenceDocument,
    bool clearReferenceDocument = false,
    bool? showDocOnCanvas,
  }) {
    return WhiteboardState(
      activeTool: activeTool ?? this.activeTool,
      activeShape: activeShape ?? this.activeShape,
      activeColor: activeColor ?? this.activeColor,
      activeStrokeWidth: activeStrokeWidth ?? this.activeStrokeWidth,
      strokes: strokes ?? this.strokes,
      undoneStrokes: undoneStrokes ?? this.undoneStrokes,
      textElements: textElements ?? this.textElements,
      undoneTextElements: undoneTextElements ?? this.undoneTextElements,
      teacherNotes: teacherNotes ?? this.teacherNotes,
      scale: scale ?? this.scale,
      panOffset: panOffset ?? this.panOffset,
      rotation: rotation ?? this.rotation,
      laserPosition: laserPosition ?? this.laserPosition,
      laserColor: laserColor ?? this.laserColor,
      spotlightPosition: spotlightPosition ?? this.spotlightPosition,
      spotlightRadius: spotlightRadius ?? this.spotlightRadius,
      revealFraction: revealFraction ?? this.revealFraction,
      isNotesOpen: isNotesOpen ?? this.isNotesOpen,
      isReferenceOpen: isReferenceOpen ?? this.isReferenceOpen,
      isPresentationMode: isPresentationMode ?? this.isPresentationMode,
      selectedElementId: selectedElementId ?? this.selectedElementId,
      activeBoardId: activeBoardId ?? this.activeBoardId,
      autoSaveEnabled: autoSaveEnabled ?? this.autoSaveEnabled,
      boardTitle: boardTitle ?? this.boardTitle,
      boardDescription: boardDescription ?? this.boardDescription,
      boardCategory: boardCategory ?? this.boardCategory,
      saveStatus: clearSaveStatus ? '' : (saveStatus ?? this.saveStatus),
      recentColors: recentColors ?? this.recentColors,
      laserDurationSeconds: laserDurationSeconds ?? this.laserDurationSeconds,
      pointerStyle: pointerStyle ?? this.pointerStyle,
      pointerPosition: pointerPosition ?? this.pointerPosition,
      stepIndex: stepIndex ?? this.stepIndex,
      stepTitles: stepTitles ?? this.stepTitles,
      isStepRevealActive: isStepRevealActive ?? this.isStepRevealActive,
      referenceDocument: clearReferenceDocument
          ? null
          : (referenceDocument ?? this.referenceDocument),
      showDocOnCanvas: showDocOnCanvas ?? this.showDocOnCanvas,
    );
  }
}

class WhiteboardNotifier extends Notifier<WhiteboardState> {
  WhiteboardRepository get _repo => ref.read(whiteboardRepositoryProvider);
  StreamSubscription? _strokesSub;
  Timer? _autoSaveTimer;

  /// Maps an active board id to a history category: ids minted by this app are
  /// prefixed with the studio type (`drawspace_`, `doccanvas_`, `voiceboard_`).
  static String categoryForBoardId(String boardId) {
    final id = boardId.toLowerCase();
    if (id.startsWith('voiceboard') || id.startsWith('voice_')) return 'voiceSession';
    if (id.startsWith('doccanvas') || id.startsWith('gesture') || id.startsWith('doc_')) return 'docAnnotation';
    return 'whiteboard';
  }

  /// Matches the Web board-id convention: `drawspace_${Date.now()}_${rand}`.
  static String mintBoardId({String prefix = 'drawspace'}) {
    final scent = (Random().nextInt(99999) + 10000).toString();
    return '${prefix}_${DateTime.now().millisecondsSinceEpoch}_$scent';
  }

  @override
  WhiteboardState build() {
    ref.onDispose(() {
      _strokesSub?.cancel();
      _autoSaveTimer?.cancel();
    });

    Future.microtask(() async {
      // Resume the last active board across restarts instead of hardcoding a
      // fixed id. Board ids are stored locally (Hive) and match the Firestore
      // document ids, so an interrupted session continues exactly where the
      // teacher left off.
      final stored = StorageService.get<String>(AppConstants.whiteboardBox, 'active_board_id');
      final boardId = (stored != null && stored.trim().isNotEmpty) ? stored.trim() : mintBoardId();
      if (stored?.trim() != boardId) {
        await StorageService.put(AppConstants.whiteboardBox, 'active_board_id', boardId);
      }
      await _initBoard(boardId);
    });
    return const WhiteboardState();
  }

  Future<void> _initBoard(String boardId) async {
    _strokesSub?.cancel();

    // 1. Load initial strokes, text elements and teacher notes from the live
    // backend / Firestore. Repository calls are internally guarded (they
    // swallow timeouts/offline errors and return best-effort data), but we
    // guard the aggregate load so one bad response can never blank out the
    // drawing surface.
    List<WhiteboardStroke> strokes = const [];
    List<TeacherNote> notes = const [];
    List<WhiteboardTextElement> texts = const [];
    Map<String, dynamic> meta = const {};
    try {
      strokes = await _repo.loadActiveBoardStrokes(boardId);
      notes = await _repo.loadTeacherNotes(boardId);
      texts = await _repo.loadTextElements(boardId);
      meta = await _repo.loadBoardMeta(boardId);
    } catch (e) {
      debugPrint('[Whiteboard Init Warning] $e');
    }

    // Re-opening a saved board must restore its ORIGINAL title and summary
    // (History convention) — never rename or re-stamp the record.
    final metaTitle = meta['title']?.toString().trim() ?? '';
    final metaDescription = meta['description']?.toString().trim() ?? '';

    DocumentModel? loadedDoc;
    if (meta['activeDocument'] is Map) {
      loadedDoc = DocumentModel.fromJson(Map<String, dynamic>.from(meta['activeDocument'] as Map), boardId);
    } else if (meta['bgFile'] is Map) {
      final bg = meta['bgFile'] as Map;
      loadedDoc = DocumentModel(
        id: 'bg_$boardId',
        title: metaTitle.isNotEmpty ? metaTitle : 'Board Document',
        author: 'Instructor',
        totalPages: 1,
        category: 'Document',
        previewExcerpt: 'Document background for whiteboard',
        updatedAt: DateTime.now(),
        fileType: bg['type']?.toString() ?? 'image',
        url: bg['url']?.toString(),
      );
    }

    state = state.copyWith(
      activeBoardId: boardId,
      strokes: strokes,
      teacherNotes: notes,
      textElements: texts,
      undoneStrokes: [],
      undoneTextElements: [],
      boardTitle: metaTitle.isNotEmpty ? metaTitle : boardTitleForNewBoard(boardId),
      boardDescription: metaDescription,
      referenceDocument: loadedDoc,
      isReferenceOpen: loadedDoc != null ? true : state.isReferenceOpen,
      saveStatus: '',
      clearSaveStatus: true,
    );

    // 2. Subscribe to real-time changes from Firestore (strokes, text elements, title) and Socket.IO
    _strokesSub = _repo.watchActiveBoard(boardId).listen((snapshot) {
      if (snapshot.isEmpty) return;
      final bool hasPendingWrites = snapshot['hasPendingWrites'] == true;
      if (hasPendingWrites) return; // Ignore local in-flight echo

      final liveStrokes = snapshot['strokes'] as List<WhiteboardStroke>?;
      final liveElements = snapshot['elements'] as List<WhiteboardTextElement>?;
      final liveTitle = snapshot['title']?.toString();
      final liveDescription = snapshot['description']?.toString();

      state = state.copyWith(
        strokes: (liveStrokes != null && liveStrokes.isNotEmpty) ? liveStrokes : state.strokes,
        textElements: (liveElements != null && liveElements.isNotEmpty) ? liveElements : state.textElements,
        boardTitle: (liveTitle != null && liveTitle.isNotEmpty) ? liveTitle : state.boardTitle,
        boardDescription: (liveDescription != null && liveDescription.isNotEmpty) ? liveDescription : state.boardDescription,
      );
    }, onError: (e) {
      debugPrint('[Whiteboard Stream Warning] $e');
    });
  }

  String boardTitleForNewBoard(String boardId) {
    final cat = categoryForBoardId(boardId);
    if (cat == 'voiceSession') return 'Voice Board Session';
    if (cat == 'docAnnotation') return 'DocCanvas Session';
    return 'DrawSpace Interactive Whiteboard';
  }

  /// Switch to an existing board (deep link from History / dashboard).
  /// Saves the outgoing board first so no stroke is lost in the switch.
  Future<void> setActiveBoard(String boardId) async {
    if (boardId.isEmpty || boardId == state.activeBoardId) return;
    _autoSaveTimer?.cancel();
    await _flushAutoSave();
    await StorageService.put(AppConstants.whiteboardBox, 'active_board_id', boardId);
    await _initBoard(boardId);
  }

  /// Start a brand-new board (Quick Actions "New Whiteboard").
  Future<String> startNewBoard({String title = 'DrawSpace Interactive Whiteboard'}) async {
    _autoSaveTimer?.cancel();
    await _flushAutoSave();
    final newId = mintBoardId();
    await StorageService.put(AppConstants.whiteboardBox, 'active_board_id', newId);
    await _initBoard(newId);
    state = state.copyWith(boardTitle: title);
    _scheduleAutoSave();
    return newId;
  }

  /// Rename the active board (History rename / save confirmation dialog).
  void setBoardTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty || trimmed == state.boardTitle) return;
    state = state.copyWith(boardTitle: trimmed);
    _scheduleAutoSave();
  }

  void setAutoSaveEnabled(bool enabled) => state = state.copyWith(autoSaveEnabled: enabled);

  void setTool(WhiteboardTool tool) => state = state.copyWith(activeTool: tool);
  void setShape(WhiteboardShapeType shape) => state = state.copyWith(activeShape: shape);
  void setColor(Color color) {
    state = state.copyWith(activeColor: color);
    recordRecentColor(color);
  }

  void recordRecentColor(Color color) {
    final existing = List<Color>.from(state.recentColors);
    existing.removeWhere((c) => c.toARGB32() == color.toARGB32());
    existing.insert(0, color);
    if (existing.length > 8) {
      existing.removeLast();
    }
    state = state.copyWith(recentColors: existing);
  }

  void setLaserDuration(int seconds) {
    state = state.copyWith(laserDurationSeconds: seconds.clamp(1, 10));
  }

  void setPointerStyle(String style) {
    state = state.copyWith(pointerStyle: style);
  }

  void setPointerPosition(Offset? pos) {
    state = state.copyWith(pointerPosition: pos);
  }

  void toggleStepReveal() {
    state = state.copyWith(isStepRevealActive: !state.isStepRevealActive);
  }

  void setStepIndex(int index) {
    final clamped = index.clamp(0, state.stepTitles.length - 1);
    final fraction = state.stepTitles.isEmpty ? 0.0 : (clamped + 1) / state.stepTitles.length;
    state = state.copyWith(stepIndex: clamped, revealFraction: fraction);
    _scheduleAutoSave();
  }

  void nextStep() {
    if (state.stepIndex < state.stepTitles.length - 1) {
      setStepIndex(state.stepIndex + 1);
    }
  }

  void prevStep() {
    if (state.stepIndex > 0) {
      setStepIndex(state.stepIndex - 1);
    }
  }

  void selectTextElement(String? id) {
    final updated = state.textElements.map((e) {
      return e.copyWith(isSelected: e.id == id);
    }).toList();
    state = state.copyWith(selectedElementId: id, textElements: updated);
  }

  void toggleTextBold(String id) {
    final updated = state.textElements.map((e) {
      if (e.id == id) return e.copyWith(isBold: !e.isBold);
      return e;
    }).toList();
    state = state.copyWith(textElements: updated);
    _repo.saveTextElements(state.activeBoardId, updated);
    _scheduleAutoSave();
  }

  void toggleTextItalic(String id) {
    final updated = state.textElements.map((e) {
      if (e.id == id) return e.copyWith(isItalic: !e.isItalic);
      return e;
    }).toList();
    state = state.copyWith(textElements: updated);
    _repo.saveTextElements(state.activeBoardId, updated);
    _scheduleAutoSave();
  }

  void toggleTextUnderline(String id) {
    final updated = state.textElements.map((e) {
      if (e.id == id) return e.copyWith(isUnderline: !e.isUnderline);
      return e;
    }).toList();
    state = state.copyWith(textElements: updated);
    _repo.saveTextElements(state.activeBoardId, updated);
    _scheduleAutoSave();
  }

  void setTextAlignment(String id, TextAlign align) {
    final updated = state.textElements.map((e) {
      if (e.id == id) return e.copyWith(textAlign: align);
      return e;
    }).toList();
    state = state.copyWith(textElements: updated);
    _repo.saveTextElements(state.activeBoardId, updated);
    _scheduleAutoSave();
  }

  void rotateTextElement(String id, double deltaAngle) {
    final updated = state.textElements.map((e) {
      if (e.id == id) return e.copyWith(rotation: e.rotation + deltaAngle);
      return e;
    }).toList();
    state = state.copyWith(textElements: updated);
    _repo.saveTextElements(state.activeBoardId, updated);
    _scheduleAutoSave();
  }

  void scaleTextElement(String id, double scaleFactor) {
    final updated = state.textElements.map((e) {
      if (e.id == id) return e.copyWith(scale: (e.scale * scaleFactor).clamp(0.5, 4.0));
      return e;
    }).toList();
    state = state.copyWith(textElements: updated);
    _repo.saveTextElements(state.activeBoardId, updated);
    _scheduleAutoSave();
  }
  void setStrokeWidth(double width) => state = state.copyWith(activeStrokeWidth: width);
  void setLaserColor(Color color) => state = state.copyWith(laserColor: color);
  void setSpotlightRadius(double radius) => state = state.copyWith(spotlightRadius: radius);

  void addStroke(WhiteboardStroke stroke) {
    final updated = List<WhiteboardStroke>.from(state.strokes)..add(stroke);
    state = state.copyWith(strokes: updated, undoneStrokes: []);
    _repo.saveStroke(state.activeBoardId, stroke);
    _scheduleAutoSave();
  }

  void updateCurrentStroke(WhiteboardStroke stroke) {
    if (state.strokes.isEmpty) return;
    final updated = List<WhiteboardStroke>.from(state.strokes);
    updated[updated.length - 1] = stroke;
    state = state.copyWith(strokes: updated);
  }

  void undo() {
    if (state.strokes.isNotEmpty) {
      final last = state.strokes.last;
      state = state.copyWith(
        strokes: state.strokes.sublist(0, state.strokes.length - 1),
        undoneStrokes: [...state.undoneStrokes, last],
      );
      _repo.deleteStroke(state.activeBoardId, last.id);
      _scheduleAutoSave();
      return;
    }
    if (state.textElements.isNotEmpty) {
      final lastText = state.textElements.last;
      state = state.copyWith(
        textElements: state.textElements.sublist(0, state.textElements.length - 1),
        undoneTextElements: [...state.undoneTextElements, lastText],
      );
      _repo.saveTextElements(state.activeBoardId, state.textElements);
      _scheduleAutoSave();
    }
  }

  void redo() {
    if (state.undoneStrokes.isNotEmpty) {
      final toRedo = state.undoneStrokes.last;
      state = state.copyWith(
        undoneStrokes: state.undoneStrokes.sublist(0, state.undoneStrokes.length - 1),
        strokes: [...state.strokes, toRedo],
      );
      _repo.saveStroke(state.activeBoardId, toRedo);
      _scheduleAutoSave();
      return;
    }
    if (state.undoneTextElements.isNotEmpty) {
      final toRedoText = state.undoneTextElements.last;
      state = state.copyWith(
        undoneTextElements: state.undoneTextElements.sublist(0, state.undoneTextElements.length - 1),
        textElements: [...state.textElements, toRedoText],
      );
      _repo.saveTextElements(state.activeBoardId, state.textElements);
      _scheduleAutoSave();
    }
  }

  void clearCanvas() {
    state = state.copyWith(
      strokes: [],
      undoneStrokes: [],
      textElements: [],
      undoneTextElements: [],
      scale: 1.0,
      panOffset: Offset.zero,
      rotation: 0.0,
    );
    _repo.clearBoard(state.activeBoardId);
    _repo.saveTextElements(state.activeBoardId, const []);
    _scheduleAutoSave();
  }

  void updateTransform({double? scale, Offset? panOffset, double? rotation}) {
    state = state.copyWith(
      scale: scale ?? state.scale,
      panOffset: panOffset ?? state.panOffset,
      rotation: rotation ?? state.rotation,
    );
    _scheduleAutoSave();
  }

  void resetTransform() {
    state = state.copyWith(scale: 1.0, panOffset: Offset.zero, rotation: 0.0);
    _scheduleAutoSave();
  }

  // Guard against redundant setState churn: identical positions (e.g. a
  // finger holding still at 120 Hz sampling) trigger zero rebuilds.
  void setLaserPosition(Offset? pos) {
    if (state.laserPosition == pos) return;
    state = state.copyWith(laserPosition: pos);
  }

  void setSpotlightPosition(Offset? pos) {
    if (state.spotlightPosition == pos) return;
    state = state.copyWith(spotlightPosition: pos);
  }

  void setRevealFraction(double fraction) {
    final clamped = fraction.clamp(0.0, 1.0);
    if (state.revealFraction == clamped) return;
    state = state.copyWith(revealFraction: clamped);
  }
  void toggleNotesPanel() => state = state.copyWith(isNotesOpen: !state.isNotesOpen);
  void toggleReferencePanel() => state = state.copyWith(isReferenceOpen: !state.isReferenceOpen);
  void setReferenceDocument(DocumentModel? doc) => state = state.copyWith(
        referenceDocument: doc,
        isReferenceOpen: doc != null ? true : state.isReferenceOpen,
      );
  void clearReferenceDocument() => state = state.copyWith(clearReferenceDocument: true);
  void toggleShowDocOnCanvas() => state = state.copyWith(showDocOnCanvas: !state.showDocOnCanvas);
  void togglePresentationMode() => state = state.copyWith(isPresentationMode: !state.isPresentationMode);

  void addTeacherNote(String title, String content) {
    final note = TeacherNote(
      id: 'tn_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      content: content,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(teacherNotes: [note, ...state.teacherNotes]);
    _repo.addTeacherNote(state.activeBoardId, note);
    _scheduleAutoSave();
  }

  void addTextElement(String text, Offset position) {
    final element = WhiteboardTextElement(
      id: 'text_${DateTime.now().millisecondsSinceEpoch}',
      position: position,
      text: text,
      color: state.activeColor,
      fontSize: 20.0,
    );
    state = state.copyWith(textElements: [...state.textElements, element], undoneTextElements: []);
    _repo.saveTextElements(state.activeBoardId, state.textElements);
    _scheduleAutoSave();
  }

  void updateTextElement(String id, {String? text, Offset? position, Color? color, double? fontSize}) {
    final updated = state.textElements.map((e) {
      if (e.id == id) {
        return e.copyWith(text: text, position: position, color: color, fontSize: fontSize);
      }
      return e;
    }).toList();
    state = state.copyWith(textElements: updated);
    _repo.saveTextElements(state.activeBoardId, updated);
    _scheduleAutoSave();
  }

  void deleteTextElement(String id) {
    final updated = state.textElements.where((e) => e.id != id).toList();
    state = state.copyWith(textElements: updated);
    _repo.saveTextElements(state.activeBoardId, updated);
    _scheduleAutoSave();
  }

  void moveTextElement(String id, Offset newPosition) {
    updateTextElement(id, position: newPosition);
  }

  /// Debounced auto-save — fires only when explicitly invoked by `saveBoard()`.
  /// Strokes and text elements are persisted immediately (per-action) so
  /// Firestore is always current; the board-snapshot (metadata + full mirror)
  /// is written only when the teacher taps Save.
  void _scheduleAutoSave() {
    // No-op: autosave is disabled. Teachers save explicitly via saveBoard().
  }

  Future<void> _flushAutoSave() async {
    // Delegate to saveBoard for all callers that still route through here
    // (e.g., setActiveBoard, startNewBoard).
    await saveBoard();
  }

  /// Explicit save — called by the teacher via the Save button in the toolbar.
  /// Persists the full board snapshot (metadata, strokes mirror, elements) to
  /// Firestore so the Web History hub and cross-device restore see the latest
  /// state of this board. Shows 'saving' → 'saved' status in the UI.
  Future<void> saveBoard() async {
    if (state.saveStatus == 'saving') return; // Already in progress
    state = state.copyWith(saveStatus: 'saving');
    try {
      final category = categoryForBoardId(state.activeBoardId);
      await _repo.saveBoardSnapshot(
        state.activeBoardId,
        title: state.boardTitle,
        description: state.boardDescription.isNotEmpty ? state.boardDescription : null,
        strokes: state.strokes,
        textElements: state.textElements,
        studio: category == 'whiteboard' ? 'drawspace' : category,
        category: category,
      );
      state = state.copyWith(saveStatus: 'saved');
      // Auto-clear 'saved' badge after 3 s so it doesn't clutter the toolbar.
      _autoSaveTimer?.cancel();
      _autoSaveTimer = Timer(const Duration(seconds: 3), () {
        state = state.copyWith(clearSaveStatus: true);
      });
    } catch (e) {
      debugPrint('[Board Save Warning] $e');
      state = state.copyWith(saveStatus: '');
    }
  }
}

final whiteboardProvider = NotifierProvider<WhiteboardNotifier, WhiteboardState>(WhiteboardNotifier.new);
