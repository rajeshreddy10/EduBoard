import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/doc_annotation_model.dart';
import '../repositories/document_repository.dart';
import '../core/utilities/safe_json.dart';

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return FirestoreDocumentRepository();
});

class DocCanvasState {
  final List<DocumentModel> documents;
  final DocumentModel? activeDocument;
  final int currentPageIndex;
  final List<DocAnnotationModel> annotations;
  final DocAnnotationType activeAnnotationTool;
  final bool isHighlighterActive;
  final bool isMagnifierActive;
  final Offset magnifierPosition;
  final double magnifierScale;
  final int activeMode; // 0: Scroll, 1: Annotate, 2: Draw, 3: Text
  final Color activeHighlighterColor;
  final List<DocAnnotationModel> undoneAnnotations;

  const DocCanvasState({
    this.documents = const [],
    this.activeDocument,
    this.currentPageIndex = 1,
    this.annotations = const [],
    this.activeAnnotationTool = DocAnnotationType.highlight,
    this.isHighlighterActive = false,
    this.isMagnifierActive = false,
    this.magnifierPosition = const Offset(160, 240),
    this.magnifierScale = 2.0,
    this.activeMode = 0,
    this.activeHighlighterColor = const Color(0xFFFFEB3B),
    this.undoneAnnotations = const [],
  });

  DocCanvasState copyWith({
    List<DocumentModel>? documents,
    DocumentModel? activeDocument,
    int? currentPageIndex,
    List<DocAnnotationModel>? annotations,
    DocAnnotationType? activeAnnotationTool,
    bool? isHighlighterActive,
    bool? isMagnifierActive,
    Offset? magnifierPosition,
    double? magnifierScale,
    int? activeMode,
    Color? activeHighlighterColor,
    List<DocAnnotationModel>? undoneAnnotations,
  }) {
    return DocCanvasState(
      documents: documents ?? this.documents,
      activeDocument: activeDocument ?? this.activeDocument,
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      annotations: annotations ?? this.annotations,
      activeAnnotationTool: activeAnnotationTool ?? this.activeAnnotationTool,
      isHighlighterActive: isHighlighterActive ?? this.isHighlighterActive,
      isMagnifierActive: isMagnifierActive ?? this.isMagnifierActive,
      magnifierPosition: magnifierPosition ?? this.magnifierPosition,
      magnifierScale: magnifierScale ?? this.magnifierScale,
      activeMode: activeMode ?? this.activeMode,
      activeHighlighterColor:
          activeHighlighterColor ?? this.activeHighlighterColor,
      undoneAnnotations: undoneAnnotations ?? this.undoneAnnotations,
    );
  }
}

class DocCanvasNotifier extends Notifier<DocCanvasState> {
  DocumentRepository get _repo => ref.read(documentRepositoryProvider);
  StreamSubscription<Map<String, dynamic>>? _sessionSub;

  @override
  DocCanvasState build() {
    ref.onDispose(() => _sessionSub?.cancel());
    Future.microtask(() => _loadInitial());
    return const DocCanvasState();
  }

  void _subscribeToSession(String docId) {
    _sessionSub?.cancel();
    if (docId.trim().isEmpty) return;
    _sessionSub = _repo.watchDocSession(docId.trim()).listen((data) {
      if (data.isEmpty) return;
      List<DocAnnotationModel> remoteAnnotations = [];
      if (data['annotations'] is List && (data['annotations'] as List).isNotEmpty) {
        remoteAnnotations = (data['annotations'] as List)
            .whereType<Map>()
            .map((m) => DocAnnotationModel.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      } else if (data['strokes'] is List && (data['strokes'] as List).isNotEmpty) {
        remoteAnnotations = (data['strokes'] as List).whereType<Map>().map((s) {
          final id = s['id']?.toString() ?? 'ann_${DateTime.now().millisecondsSinceEpoch}';
          final pts = (s['points'] as List<dynamic>? ?? []).whereType<Map>().map((p) {
            return Offset(asDoubleOr(p['x'], 0), asDoubleOr(p['y'], 0));
          }).toList();
          Color color = const Color(0xFFFFD54F);
          final rawColor = s['color'];
          if (rawColor is String && rawColor.contains('#')) {
            final hex = rawColor.replaceAll('#', '').trim();
            final parsed = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
            if (parsed != null) color = Color(parsed);
          }
          final tool = s['tool']?.toString();
          DocAnnotationType type = DocAnnotationType.pen;
          if (tool == 'highlighter' || tool == 'highlight') type = DocAnnotationType.highlight;
          if (tool == 'text') type = DocAnnotationType.text;
          return DocAnnotationModel(
            id: id,
            pageIndex: 1,
            type: type,
            points: pts,
            color: color,
            strokeWidth: asDoubleOr(s['width'] ?? s['strokeWidth'], 3.0),
            createdAt: DateTime.now(),
          );
        }).toList();
      }

      if (remoteAnnotations.isNotEmpty) {
        state = state.copyWith(annotations: remoteAnnotations);
      }
    }, onError: (e) {
      debugPrint('[DocCanvas Stream Note] $e');
    });
  }

  Future<void> _loadInitial() async {
    final docs = await _repo.getDocuments();
    final active = docs.isNotEmpty ? docs.first : null;
    List<DocAnnotationModel> annotations = [];
    if (active != null) {
      annotations = await _repo.getAnnotations(active.id);
      _subscribeToSession(active.id);
    }
    state = state.copyWith(
      documents: docs,
      activeDocument: active,
      annotations: annotations,
    );
  }

  Future<void> loadDocs() async {
    final docs = await _repo.getDocuments();
    final active = docs.isNotEmpty ? docs.first : null;
    if (active != null) {
      _subscribeToSession(active.id);
    }
    state = state.copyWith(
      documents: docs,
      activeDocument: active,
    );
  }

  Future<void> selectDocument(DocumentModel doc) async {
    _subscribeToSession(doc.id);
    final annotations = await _repo.getAnnotations(doc.id);
    state = state.copyWith(
        activeDocument: doc, currentPageIndex: 1, annotations: annotations);
  }

  /// Deep-link support: open a SPECIFIC document from History/boards.
  Future<bool> selectDocumentById(String documentId) async {
    final id = documentId.trim();
    if (id.isEmpty) return false;
    final match = state.documents.where((d) => d.id == id).toList();
    DocumentModel? doc = match.isNotEmpty ? match.first : null;
    doc ??= await _repo.loadDocument(id);
    if (doc != null) {
      await selectDocument(doc);
      return true;
    }
    return false;
  }

  void setPageIndex(int page) {
    if (state.activeDocument == null) return;
    if (page >= 1 && page <= state.activeDocument!.totalPages) {
      state = state.copyWith(currentPageIndex: page);
    }
  }

  void toggleHighlighter() {
    state = state.copyWith(
      isHighlighterActive: !state.isHighlighterActive,
      activeAnnotationTool: DocAnnotationType.highlight,
    );
  }

  void setAnnotationTool(DocAnnotationType tool) {
    state = state.copyWith(activeAnnotationTool: tool);
  }

  void toggleMagnifier() {
    state = state.copyWith(isMagnifierActive: !state.isMagnifierActive);
  }

  void setMagnifierPosition(Offset pos) {
    state = state.copyWith(magnifierPosition: pos);
  }

  void setMagnifierScale(double scale) {
    state = state.copyWith(magnifierScale: scale.clamp(1.2, 4.0));
  }

  void setActiveMode(int mode) {
    state = state.copyWith(activeMode: mode);
  }

  void setHighlighterColor(Color color) {
    state = state.copyWith(activeHighlighterColor: color);
  }

  void undo() {
    if (state.annotations.isNotEmpty) {
      final last = state.annotations.last;
      state = state.copyWith(
        annotations:
            state.annotations.sublist(0, state.annotations.length - 1),
        undoneAnnotations: [...state.undoneAnnotations, last],
      );
      if (state.activeDocument != null) {
        _repo.deleteAnnotation(state.activeDocument!.id, last.id);
      }
    }
  }

  void redo() {
    if (state.undoneAnnotations.isNotEmpty) {
      final toRedo = state.undoneAnnotations.last;
      state = state.copyWith(
        undoneAnnotations: state.undoneAnnotations
            .sublist(0, state.undoneAnnotations.length - 1),
        annotations: [...state.annotations, toRedo],
      );
      if (state.activeDocument != null) {
        _repo.saveAnnotation(state.activeDocument!.id, toRedo);
      }
    }
  }

  /// Add a newly opened/imported document and make it the active document.
  void addUploadedDocument(DocumentModel newDoc) {
    final updated = [...state.documents, newDoc];
    state = state.copyWith(
      documents: updated,
      activeDocument: newDoc,
      currentPageIndex: 1,
      annotations: [],
    );
  }

  Future<void> addAnnotation(DocAnnotationModel annotation) async {
    state = state.copyWith(
        annotations: [...state.annotations, annotation]);
    if (state.activeDocument != null) {
      await _repo.saveAnnotation(state.activeDocument!.id, annotation);
    }
  }

  Future<void> clearAnnotations() async {
    final currentDocId = state.activeDocument?.id;
    if (currentDocId != null) {
      for (final a in state.annotations) {
        await _repo.deleteAnnotation(currentDocId, a.id);
      }
    }
    state = state.copyWith(annotations: []);
  }

  /// Explicitly save the current active document and all annotations.
  Future<void> saveSession() async {
    final doc = state.activeDocument;
    if (doc != null) {
      await _repo.saveDocSession(
        docId: doc.id,
        document: doc,
        annotations: state.annotations,
      );
    }
  }
}

final docCanvasProvider =
    NotifierProvider<DocCanvasNotifier, DocCanvasState>(DocCanvasNotifier.new);
