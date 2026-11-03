import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/widgets/board_top_bar.dart';
import '../../../models/doc_annotation_model.dart';
import '../../../providers/doccanvas_provider.dart';
import '../widgets/doc_annotation_layer.dart';
import '../widgets/doc_viewer_placeholder.dart';
import '../widgets/magnifier_overlay.dart';

/// DocCanvas Document Annotator Studio
/// Dark theme interface matching the EduBoard web application.
/// Supports PDF, DOCX, DOC, PPT, PPTX, TXT, and image file annotation.
class DocCanvasScreen extends ConsumerStatefulWidget {
  /// Optional document id from a deep link (`/doccanvas?id=...`).
  final String? documentId;

  const DocCanvasScreen({super.key, this.documentId});

  @override
  ConsumerState<DocCanvasScreen> createState() => _DocCanvasScreenState();
}

class _DocCanvasScreenState extends ConsumerState<DocCanvasScreen> {
  bool _isReferenceOpen = false;
  bool _isSaving = false;
  bool _isSaved = false;
  Color _selectedColor = const Color(0xFF3B82F6);

  static const List<Color> _swatchColors = [
    Color(0xFF3B82F6), // Blue
    Color(0xFFEF4444), // Red
    Color(0xFF10B981), // Green
    Color(0xFFF97316), // Orange
    Color(0xFF8B5CF6), // Purple
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final id = widget.documentId?.trim();
      if (id == null || id.isEmpty) return;
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      final ok = await ref.read(docCanvasProvider.notifier).selectDocumentById(id);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document opened from your library')),
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
      await ref.read(docCanvasProvider.notifier).saveSession();
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isSaved = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document annotations saved to cloud'),
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
            content: Text('Failed to save: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  /// Open the file type selection sheet to pick files from device.
  void _openFilePicker() {
    _showFileTypeSheet();
  }

  Future<void> _pickRealFile([List<String>? allowedExtensions]) async {
    try {
      final files = await FilePicker.pickFiles(
        type: allowedExtensions != null && allowedExtensions.isNotEmpty
            ? FileType.custom
            : FileType.any,
        allowedExtensions: allowedExtensions,
      );

      if (files.isEmpty) return;

      final picked = files.first;
      final path = picked.path;
      final name = picked.name;
      final ext = (picked.extension ?? name.split('.').last).toLowerCase();

      Uint8List? rawBytes;
      try {
        rawBytes = await picked.readAsBytes();
      } catch (_) {}

      if ((rawBytes == null || rawBytes.isEmpty) && path != null) {
        try {
          final file = File(path);
          if (file.existsSync()) {
            rawBytes = await file.readAsBytes();
          }
        } catch (_) {}
      }

      String? content;
      int pageCount = 1;
      String category = 'Document';
      String? dataUrl;
      String? effectivePath = path;

      if (['txt', 'md', 'csv', 'json', 'log', 'html', 'py', 'dart', 'js', 'ts'].contains(ext)) {
        category = 'Text Document';
        if (rawBytes != null && rawBytes.isNotEmpty) {
          content = utf8.decode(rawBytes, allowMalformed: true);
        } else if (path != null && File(path).existsSync()) {
          try {
            content = await File(path).readAsString();
          } catch (_) {}
        }
        pageCount = ((content?.split('\n').length ?? 1) / 30).ceil().clamp(1, 100);
      } else if (['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'].contains(ext)) {
        category = 'Image Document';
        pageCount = 1;
        if (rawBytes != null && rawBytes.isNotEmpty) {
          dataUrl = 'data:image/$ext;base64,${base64Encode(rawBytes)}';
          try {
            final tempFile = File('${Directory.systemTemp.path}/doc_${DateTime.now().millisecondsSinceEpoch}.$ext');
            await tempFile.writeAsBytes(rawBytes);
            effectivePath = tempFile.path;
          } catch (_) {}
        }
      } else if (ext == 'pdf') {
        category = 'PDF Document';
        pageCount = 5;
        if (rawBytes != null && rawBytes.isNotEmpty) {
          dataUrl = 'data:application/pdf;base64,${base64Encode(rawBytes)}';
          try {
            final tempFile = File('${Directory.systemTemp.path}/doc_${DateTime.now().millisecondsSinceEpoch}.pdf');
            await tempFile.writeAsBytes(rawBytes);
            effectivePath = tempFile.path;
          } catch (_) {}
        }
      } else if (['doc', 'docx'].contains(ext)) {
        category = 'Word Document';
        pageCount = 4;
      } else if (['ppt', 'pptx'].contains(ext)) {
        category = 'Presentation';
        pageCount = 5;
      }

      final newDoc = DocumentModel(
        id: 'doc_${DateTime.now().millisecondsSinceEpoch}',
        title: name,
        author: 'Instructor',
        totalPages: pageCount,
        category: category,
        previewExcerpt: content != null
            ? content.substring(0, content.length.clamp(0, 160))
            : '$category loaded from storage.',
        updatedAt: DateTime.now(),
        filePath: effectivePath,
        fileType: ext,
        fileContent: content,
        url: dataUrl,
      );

      ref.read(docCanvasProvider.notifier).addUploadedDocument(newDoc);

      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name opened successfully'),
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[FilePicker Note] $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131823),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF262F40)),
        ),
        title: const Text('Storage Permission Required', style: TextStyle(color: Colors.white)),
        content: const Text(
          'To open files from your device, EduBoard needs storage access.\n\n'
          'Please enable it in Settings → Apps → EduBoard → Permissions.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showFileTypeSheet() {
    final fileTypes = [
      _FileType(Icons.folder_open_rounded, 'All Files', const Color(0xFF38BDF8), 'all'),
      _FileType(Icons.picture_as_pdf_rounded, 'PDF Document', const Color(0xFFE53935), 'pdf'),
      _FileType(Icons.description_rounded, 'Word (DOC/DOCX)', const Color(0xFF1E88E5), 'docx'),
      _FileType(Icons.slideshow_rounded, 'PowerPoint (PPT)', const Color(0xFFFB8C00), 'pptx'),
      _FileType(Icons.article_rounded, 'Text (TXT)', const Color(0xFF43A047), 'txt'),
      _FileType(Icons.image_rounded, 'Images (PNG/JPG)', const Color(0xFF8E24AA), 'png'),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131823),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF262F40)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.folder_open_rounded, color: Color(0xFF38BDF8), size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Select File Type to Open',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Select format from your device storage:',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: fileTypes.map((ft) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleFileSelected(ft);
                  },
                  child: Container(
                    width: 95,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ft.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ft.color.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(ft.icon, color: ft.color, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          ft.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: ft.color,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _handleFileSelected(_FileType fileType) {
    if (fileType.ext == 'pdf') {
      _pickRealFile(['pdf']);
    } else if (fileType.ext == 'docx') {
      _pickRealFile(['doc', 'docx']);
    } else if (fileType.ext == 'pptx') {
      _pickRealFile(['ppt', 'pptx']);
    } else if (fileType.ext == 'txt') {
      _pickRealFile(['txt', 'md', 'csv', 'json', 'log']);
    } else if (fileType.ext == 'png') {
      _pickRealFile(['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp']);
    } else {
      _pickRealFile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(docCanvasProvider);
    final notifier = ref.read(docCanvasProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header matching web BoardHeader ─────────────────────────
            BoardTopBar(
              title: state.activeDocument?.title ?? 'DocCanvas Studio',
              subtitle: 'MANUAL SAVE',
              isSaving: _isSaving,
              isSaved: _isSaved,
              onBack: () => context.canPop() ? context.pop() : context.go('/dashboard'),
              onSave: _handleSave,
              centerActions: [
                // Reference Pill
                _DarkPill(
                  icon: Icons.menu_book_rounded,
                  label: 'Reference',
                  isActive: _isReferenceOpen,
                  onTap: () {
                    setState(() => _isReferenceOpen = !_isReferenceOpen);
                    HapticFeedback.selectionClick();
                  },
                ),
                const SizedBox(width: 8),

                // Replay Pill
                _DarkPill(
                  icon: Icons.history_rounded,
                  label: 'Replay',
                  isActive: false,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Session snapshot ready'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),

                // Open Document Blue Pill
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openFilePicker,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.file_upload_outlined, color: Colors.white, size: 14),
                          SizedBox(width: 5),
                          Text(
                            'Open Document',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Main Workspace Area ────────────────────────────────────────
            Expanded(
              child: Stack(
                children: [
                  Row(
                    children: [
                      // Reference Drawer (if open)
                      if (_isReferenceOpen)
                        Container(
                          width: 200,
                          decoration: const BoxDecoration(
                            color: Color(0xFF131823),
                            border: Border(
                              right: BorderSide(color: Color(0xFF262F40), width: 1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    const Icon(Icons.folder_open_rounded, color: Color(0xFF38BDF8), size: 18),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Files',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.add, color: Colors.white, size: 18),
                                      tooltip: 'Add File',
                                      onPressed: _openFilePicker,
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(color: Color(0xFF262F40), height: 1),
                              Expanded(
                                child: state.documents.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'No files opened',
                                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: state.documents.length,
                                        itemBuilder: (ctx, i) {
                                          final doc = state.documents[i];
                                          final isSelected = doc.id == state.activeDocument?.id;
                                          return ListTile(
                                            dense: true,
                                            selected: isSelected,
                                            selectedTileColor: const Color(0xFF1E3A8A).withValues(alpha: 0.3),
                                            leading: Icon(
                                              Icons.description_rounded,
                                              size: 16,
                                              color: isSelected ? const Color(0xFF60A5FA) : const Color(0xFF94A3B8),
                                            ),
                                            title: Text(
                                              doc.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                                                fontSize: 12,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                            onTap: () => notifier.selectDocument(doc),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),

                      // Document and Canvas Viewer
                      Expanded(
                        child: state.activeDocument == null
                            ? Center(
                                // Blank Canvas prompt card matching screenshot 2
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 20),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF131823),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: const Color(0xFF262F40), width: 1.2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.4),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.description_outlined,
                                        color: Color(0xFF8B5CF6),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      const Flexible(
                                        child: Text(
                                          'Blank Canvas — Draw directly or import a document',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: _openFilePicker,
                                          borderRadius: BorderRadius.circular(16),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF6366F1),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.file_upload_outlined, color: Colors.white, size: 14),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Open File',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11.5,
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
                              )
                            : const Stack(
                                children: [
                                  Positioned.fill(child: DocViewerPlaceholder()),
                                  Positioned.fill(child: DocAnnotationLayer()),
                                  MagnifierOverlay(),
                                ],
                              ),
                      ),
                    ],
                  ),

                  // ── Floating Bottom Toolbar matching screenshot 2 ─────────
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
                              // 1. Pen tool in Purple Circle
                              _CircleToolButton(
                                icon: Icons.edit_rounded,
                                tooltip: 'Pen Tool',
                                isSelected: state.activeAnnotationTool == DocAnnotationType.pen,
                                activeColor: const Color(0xFF8B5CF6),
                                onTap: () {
                                  notifier.setAnnotationTool(DocAnnotationType.pen);
                                  HapticFeedback.selectionClick();
                                },
                              ),
                              const SizedBox(width: 4),

                              // 2. T Text Tool
                              _CircleToolButton(
                                icon: Icons.title_rounded,
                                tooltip: 'Text Tool',
                                isSelected: state.activeAnnotationTool == DocAnnotationType.text,
                                onTap: () {
                                  notifier.setAnnotationTool(DocAnnotationType.text);
                                  HapticFeedback.selectionClick();
                                },
                              ),
                              const SizedBox(width: 4),

                              // 3. Eraser Tool (Interactive touch-to-erase)
                              _CircleToolButton(
                                icon: Icons.cleaning_services_rounded,
                                tooltip: 'Eraser Tool',
                                isSelected: state.activeAnnotationTool == DocAnnotationType.eraser,
                                activeColor: const Color(0xFFEF4444),
                                onTap: () {
                                  notifier.setAnnotationTool(DocAnnotationType.eraser);
                                  HapticFeedback.selectionClick();
                                },
                              ),
                              const SizedBox(width: 4),

                              // 4. Brush / Highlighter Tool
                              _CircleToolButton(
                                icon: Icons.brush_rounded,
                                tooltip: 'Highlighter Tool',
                                isSelected: state.activeAnnotationTool == DocAnnotationType.highlight,
                                activeColor: const Color(0xFFFBBF24),
                                onTap: () {
                                  notifier.setAnnotationTool(DocAnnotationType.highlight);
                                  HapticFeedback.selectionClick();
                                },
                              ),
                              const SizedBox(width: 4),

                              // 5. Laser Tool ⚡
                              _CircleToolButton(
                                icon: Icons.bolt_rounded,
                                tooltip: 'Laser Pointer',
                                isSelected: false,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                },
                              ),
                              const SizedBox(width: 4),

                              // 6. Magnifier Tool 🔍
                              _CircleToolButton(
                                icon: Icons.search_rounded,
                                tooltip: 'Magnifier',
                                isSelected: state.isMagnifierActive,
                                onTap: () {
                                  notifier.toggleMagnifier();
                                  HapticFeedback.selectionClick();
                                },
                              ),
                              const SizedBox(width: 4),

                              // 7. Pointer Tool ↖
                              _CircleToolButton(
                                icon: Icons.near_me_rounded,
                                tooltip: 'Pointer / Select',
                                isSelected: false,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                },
                              ),
                              const SizedBox(width: 8),

                              // 8. Color Swatches (Blue, Red, Green, Orange, Purple)
                              ..._swatchColors.map((color) {
                                final isSelected = _selectedColor.toARGB32() == color.toARGB32();
                                return GestureDetector(
                                  onTap: () {
                                    setState(() => _selectedColor = color);
                                    notifier.setHighlighterColor(color);
                                    if (state.activeAnnotationTool == DocAnnotationType.eraser) {
                                      notifier.setAnnotationTool(DocAnnotationType.pen);
                                    }
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

                              // Undo
                              _CircleToolButton(
                                icon: Icons.undo_rounded,
                                tooltip: 'Undo',
                                isSelected: false,
                                isEnabled: state.annotations.isNotEmpty,
                                onTap: () {
                                  notifier.undo();
                                  HapticFeedback.lightImpact();
                                },
                              ),
                              const SizedBox(width: 4),

                              // Redo
                              _CircleToolButton(
                                icon: Icons.redo_rounded,
                                tooltip: 'Redo',
                                isSelected: false,
                                isEnabled: state.undoneAnnotations.isNotEmpty,
                                onTap: () {
                                  notifier.redo();
                                  HapticFeedback.lightImpact();
                                },
                              ),
                              const SizedBox(width: 4),

                              // ↺ Reset / Clear annotations
                              _CircleToolButton(
                                icon: Icons.refresh_rounded,
                                tooltip: 'Reset Annotations',
                                isSelected: false,
                                onTap: () {
                                  notifier.clearAnnotations();
                                  HapticFeedback.lightImpact();
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

class _DarkPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _DarkPill({
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

class _CircleToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final bool isEnabled;
  final Color? activeColor;
  final VoidCallback onTap;

  const _CircleToolButton({
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    this.isEnabled = true,
    this.activeColor,
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
              color: isSelected ? (activeColor ?? const Color(0xFF8B5CF6)) : Colors.transparent,
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

class _FileType {
  final IconData icon;
  final String label;
  final Color color;
  final String ext;

  const _FileType(this.icon, this.label, this.color, this.ext);
}
