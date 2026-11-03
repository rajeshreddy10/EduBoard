import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/doc_annotation_model.dart';
import '../../../providers/whiteboard_provider.dart';

/// Modern 2026 Material 3 Reference Dock (30/70 Split Screen)
/// Supports real device file picking (PDF, Images, Docs, Code) and instant canvas synchronization.
class ReferenceDrawer extends ConsumerStatefulWidget {
  const ReferenceDrawer({super.key});

  @override
  ConsumerState<ReferenceDrawer> createState() => _ReferenceDrawerState();
}

class _ReferenceDrawerState extends ConsumerState<ReferenceDrawer> {
  int _selectedCategoryIndex = 0;
  int _currentPage = 1;

  final List<String> _categories = ['All', 'Physics', 'Circuits', 'Calculus', 'Chemistry'];

  Future<void> _pickAndOpenFile() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);
      if (files.isEmpty) return;

      final picked = files.first;
      final name = picked.name;
      final path = picked.path;
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

      if (['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'svg'].contains(ext)) {
        category = 'Image Diagram';
        pageCount = 1;
        if (rawBytes != null && rawBytes.isNotEmpty) {
          dataUrl = 'data:image/$ext;base64,${base64Encode(rawBytes)}';
          try {
            final tempFile = File('${Directory.systemTemp.path}/ref_${DateTime.now().millisecondsSinceEpoch}.$ext');
            await tempFile.writeAsBytes(rawBytes);
            effectivePath = tempFile.path;
          } catch (_) {}
        }
      } else if (['txt', 'md', 'csv', 'json', 'log', 'py', 'dart', 'js', 'html'].contains(ext)) {
        category = 'Text Document';
        if (rawBytes != null && rawBytes.isNotEmpty) {
          content = utf8.decode(rawBytes, allowMalformed: true);
        } else if (path != null && File(path).existsSync()) {
          content = await File(path).readAsString();
        }
        pageCount = ((content?.split('\n').length ?? 1) / 28).ceil().clamp(1, 100);
      } else if (ext == 'pdf') {
        category = 'PDF Document';
        pageCount = 5;
        if (rawBytes != null && rawBytes.isNotEmpty) {
          dataUrl = 'data:application/pdf;base64,${base64Encode(rawBytes)}';
        }
      } else if (['doc', 'docx'].contains(ext)) {
        category = 'Word Document';
        pageCount = 4;
      } else if (['ppt', 'pptx'].contains(ext)) {
        category = 'Presentation';
        pageCount = 6;
      }

      final newDoc = DocumentModel(
        id: 'ref_${DateTime.now().millisecondsSinceEpoch}',
        title: name,
        author: 'Instructor',
        totalPages: pageCount,
        category: category,
        previewExcerpt: content != null
            ? content.substring(0, content.length.clamp(0, 180))
            : '$category loaded into Reference Dock and rendered on Whiteboard.',
        updatedAt: DateTime.now(),
        filePath: effectivePath,
        fileType: ext,
        fileContent: content,
        url: dataUrl,
      );

      setState(() => _currentPage = 1);
      ref.read(whiteboardProvider.notifier).setReferenceDocument(newDoc);

      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name is now active in Reference Dock and on Canvas'),
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
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

  void _loadSampleDocument(String title, String ext, String category, int pages, String preview, [String? content]) {
    final doc = DocumentModel(
      id: 'sample_${title.toLowerCase().replaceAll(' ', '_')}',
      title: title,
      author: 'EduBoard Academic Library',
      totalPages: pages,
      category: category,
      previewExcerpt: preview,
      updatedAt: DateTime.now(),
      fileType: ext,
      fileContent: content ?? preview,
    );
    setState(() => _currentPage = 1);
    ref.read(whiteboardProvider.notifier).setReferenceDocument(doc);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(whiteboardProvider);
    final doc = state.referenceDocument;
    final showOnCanvas = state.showDocOnCanvas;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0E17),
        border: Border(
          right: BorderSide(color: Color(0xFF1E293B), width: 1.5),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Modern Sleek Header ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF111827),
                border: Border(bottom: BorderSide(color: Color(0xFF1F2937), width: 1)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reference Dock',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          '30/70 Split View • Live on Canvas',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                    tooltip: 'Close Reference Dock',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      ref.read(whiteboardProvider.notifier).toggleReferencePanel();
                    },
                  ),
                ],
              ),
            ),

            // ── Primary Action Controls ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1)),
              ),
              child: Row(
                children: [
                  // Open File Button with gradient
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _pickAndOpenFile,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.file_upload_outlined, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Import File',
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
                  ),
                  const SizedBox(width: 8),

                  // Toggle Canvas Overlay Pill
                  if (doc != null)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          ref.read(whiteboardProvider.notifier).toggleShowDocOnCanvas();
                          HapticFeedback.selectionClick();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: showOnCanvas
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : const Color(0xFF334155).withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: showOnCanvas ? const Color(0xFF10B981) : const Color(0xFF475569),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                showOnCanvas ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                color: showOnCanvas ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                                size: 15,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                showOnCanvas ? 'On Canvas' : 'Dock Only',
                                style: TextStyle(
                                  color: showOnCanvas ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
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

            // ── Main Body: Active Document View or Interactive Library ───────
            Expanded(
              child: doc != null ? _buildActiveDocView(doc) : _buildModernLibraryView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveDocView(DocumentModel doc) {
    final ext = doc.fileType.toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'svg'].contains(ext);
    final isText = ['txt', 'md', 'csv', 'json', 'log', 'py', 'dart', 'js', 'html'].contains(ext);

    return Column(
      children: [
        // Active Document Info Card
        Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF131823),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF262F40), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildExtBadge(ext),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${doc.category} • ${doc.totalPages} Pages',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                    tooltip: 'Remove from Dock',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      ref.read(whiteboardProvider.notifier).clearReferenceDocument();
                      HapticFeedback.lightImpact();
                    },
                  ),
                ],
              ),
              if (doc.totalPages > 1) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.chevron_left_rounded, size: 16, color: _currentPage > 1 ? Colors.white : Colors.white24),
                            const Text('Prev', style: TextStyle(color: Colors.white, fontSize: 10.5)),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      'Page $_currentPage / ${doc.totalPages}',
                      style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    InkWell(
                      onTap: _currentPage < doc.totalPages ? () => setState(() => _currentPage++) : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Text('Next', style: TextStyle(color: Colors.white, fontSize: 10.5)),
                            Icon(Icons.chevron_right_rounded, size: 16, color: _currentPage < doc.totalPages ? Colors.white : Colors.white24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Live Viewer Area
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            clipBehavior: Clip.antiAlias,
            child: isImage
                ? _buildImageDockViewer(doc)
                : isText
                    ? _buildTextDockViewer(doc)
                    : _buildAcademicDockViewer(doc),
          ),
        ),
      ],
    );
  }

  Widget _buildExtBadge(String ext) {
    Color bg = const Color(0xFF2563EB);
    IconData icon = Icons.description_rounded;

    if (ext == 'pdf') {
      bg = const Color(0xFFEF4444);
      icon = Icons.picture_as_pdf_rounded;
    } else if (['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)) {
      bg = const Color(0xFFA855F7);
      icon = Icons.image_rounded;
    } else if (['txt', 'md', 'py', 'js', 'dart'].contains(ext)) {
      bg = const Color(0xFF10B981);
      icon = Icons.code_rounded;
    } else if (['doc', 'docx'].contains(ext)) {
      bg = const Color(0xFF3B82F6);
      icon = Icons.description_rounded;
    } else if (['ppt', 'pptx'].contains(ext)) {
      bg = const Color(0xFFF97316);
      icon = Icons.slideshow_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: bg, size: 18),
    );
  }

  Widget _buildImageDockViewer(DocumentModel doc) {
    if (doc.url != null && doc.url!.startsWith('data:image')) {
      try {
        final base64String = doc.url!.split(',').last;
        final bytes = base64Decode(base64String);
        return InteractiveViewer(
          maxScale: 6.0,
          child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
        );
      } catch (_) {}
    }

    if (doc.filePath != null && File(doc.filePath!).existsSync()) {
      return InteractiveViewer(
        maxScale: 6.0,
        child: Center(child: Image.file(File(doc.filePath!), fit: BoxFit.contain)),
      );
    }

    return const Center(
      child: Text('Image Active in Dock', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
    );
  }

  Widget _buildTextDockViewer(DocumentModel doc) {
    final text = doc.fileContent ?? doc.previewExcerpt;
    final lines = text.split('\n');
    const linesPerPage = 28;
    final start = ((_currentPage - 1) * linesPerPage).clamp(0, lines.length);
    final end = (start + linesPerPage).clamp(0, lines.length);
    final pageLines = lines.sublist(start, end);

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: pageLines.length,
      itemBuilder: (ctx, i) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '${start + i + 1}',
                  style: const TextStyle(color: Color(0xFF475569), fontSize: 9.5, fontFamily: 'monospace'),
                ),
              ),
              Expanded(
                child: Text(
                  pageLines[i],
                  style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11, height: 1.35),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAcademicDockViewer(DocumentModel doc) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF131823),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF262F40)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Page $_currentPage Concept & Equations',
                  style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  doc.fileContent ?? doc.previewExcerpt,
                  style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: const Row(
              children: [
                Icon(Icons.draw_rounded, color: Color(0xFFF59E0B), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rendered on canvas: Annotate, solve, and write directly on top of this sheet.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernLibraryView() {
    final sampleResources = [
      _DockResource(
        title: 'Physics Mechanics Notes.pdf',
        category: 'Physics',
        ext: 'pdf',
        color: const Color(0xFFEF4444),
        icon: Icons.picture_as_pdf_rounded,
        pages: 5,
        preview: 'Classical Mechanics Problem Set:\n\n1. Calculate projectile range with launch angle theta and air drag.\n2. Angular momentum conservation: L = r x p = I * omega.\n3. Friction force on 30 deg incline: f_k = mu_k * N = mu_k * m * g * cos(theta).\n\nGraph free-body diagrams and solve equations on the whiteboard.',
      ),
      _DockResource(
        title: 'Circuit Analysis Diagram.png',
        category: 'Circuits',
        ext: 'png',
        color: const Color(0xFF38BDF8),
        icon: Icons.image_rounded,
        pages: 1,
        preview: 'RLC Circuit Schematic Diagram:\n\nAnalyze nodes A, B, and C under sinusoidal excitation. Verify Kirchhoff Current Law summation at junction.',
      ),
      _DockResource(
        title: 'Calculus Formulas.docx',
        category: 'Calculus',
        ext: 'docx',
        color: const Color(0xFF818CF8),
        icon: Icons.description_rounded,
        pages: 4,
        preview: 'Calculus Theorems & Derivatives:\n\n- d/dx [sin(x)] = cos(x)\n- d/dx [ln(x)] = 1/x\n- Fundamental Theorem of Calculus: d/dx Integral [f(t) dt from a to x] = f(x)\n- Integration by parts: Integral [u dv] = u*v - Integral [v du].',
      ),
      _DockResource(
        title: 'Organic Chemistry Lab.txt',
        category: 'Chemistry',
        ext: 'txt',
        color: const Color(0xFF10B981),
        icon: Icons.article_rounded,
        pages: 3,
        preview: 'Chemistry Titration Guide:\n1. Prepare 0.1M standard acid.\n2. Record burrette volume reading at equivalence.\n3. Calculate molarity: M1*V1 = M2*V2.',
      ),
    ];

    final filtered = _selectedCategoryIndex == 0
        ? sampleResources
        : sampleResources.where((r) => r.category == _categories[_selectedCategoryIndex]).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Pills
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            itemCount: _categories.length,
            itemBuilder: (ctx, i) {
              final isSel = _selectedCategoryIndex == i;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedCategoryIndex = i);
                  HapticFeedback.selectionClick();
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSel ? const Color(0xFF60A5FA) : const Color(0xFF334155),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _categories[i],
                      style: TextStyle(
                        color: isSel ? Colors.white : const Color(0xFF94A3B8),
                        fontSize: 10.5,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const Padding(
          padding: EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Text(
            'QUICK LESSON MATERIALS',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
        ),

        // Material Cards
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              final res = filtered[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _loadSampleDocument(
                        res.title,
                        res.ext,
                        res.category,
                        res.pages,
                        res.preview,
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131823),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF262F40)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: res.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(res.icon, color: res.color, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  res.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${res.category} • Tap to solve on Canvas',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF64748B), size: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DockResource {
  final String title;
  final String category;
  final String ext;
  final Color color;
  final IconData icon;
  final int pages;
  final String preview;

  _DockResource({
    required this.title,
    required this.category,
    required this.ext,
    required this.color,
    required this.icon,
    required this.pages,
    required this.preview,
  });
}
