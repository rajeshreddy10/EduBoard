import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/doc_annotation_model.dart';
import '../../../providers/whiteboard_provider.dart';

/// 30/70 Reference Drawer for PDFs, Images, and Lesson Resources.
/// Mirrors the EduBoard web application Reference Drawer.
class ReferenceDrawer extends ConsumerStatefulWidget {
  const ReferenceDrawer({super.key});

  @override
  ConsumerState<ReferenceDrawer> createState() => _ReferenceDrawerState();
}

class _ReferenceDrawerState extends ConsumerState<ReferenceDrawer> {
  int _currentPage = 1;

  Future<void> _pickAndOpenFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.any,
      );

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

      if (['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'].contains(ext)) {
        category = 'Image Document';
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
            : '$category ready for pedagogical reference on canvas.',
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
            content: Text('$name loaded into Reference Drawer'),
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

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(
          right: BorderSide(color: Color(0xFF1E293B), width: 1.5),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Drawer Header ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF131823),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF262F40), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: Color(0xFF60A5FA), size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reference Materials',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          doc != null ? doc.title : 'Split Screen 30/70',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (doc != null)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 18),
                      tooltip: 'Close Reference',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        ref.read(whiteboardProvider.notifier).clearReferenceDocument();
                      },
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.add_rounded, color: Color(0xFF38BDF8), size: 20),
                      tooltip: 'Open File',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _pickAndOpenFile,
                    ),
                ],
              ),
            ),

            // ── Drawer Body: Either Loaded Document OR Sample Resource List ─
            Expanded(
              child: doc != null ? _buildLoadedDocumentView(doc) : _buildResourcePickerView(),
            ),

            // ── Drawer Bottom Action ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFF131823),
                border: Border(top: BorderSide(color: Color(0xFF262F40), width: 1)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.file_upload_outlined, size: 16),
                  label: Text(
                    doc != null ? 'Open Different File' : 'Open Device Document',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _pickAndOpenFile,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadedDocumentView(DocumentModel doc) {
    final ext = doc.fileType.toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'].contains(ext);
    final isText = ['txt', 'md', 'csv', 'json', 'log', 'py', 'dart', 'js', 'html'].contains(ext);

    return Column(
      children: [
        // Page Navigation header if multi-page
        if (doc.totalPages > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: const Color(0xFF1E293B),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: _currentPage > 1 ? Colors.white : Colors.white24,
                      size: 20,
                    ),
                  ),
                ),
                Text(
                  'Page $_currentPage of ${doc.totalPages}',
                  style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 11, fontWeight: FontWeight.bold),
                ),
                InkWell(
                  onTap: _currentPage < doc.totalPages ? () => setState(() => _currentPage++) : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: _currentPage < doc.totalPages ? Colors.white : Colors.white24,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Main Viewer
        Expanded(
          child: Container(
            color: const Color(0xFF0B0F19),
            child: isImage
                ? _buildImageViewer(doc)
                : isText
                    ? _buildTextViewer(doc)
                    : _buildAcademicDocViewer(doc),
          ),
        ),
      ],
    );
  }

  Widget _buildImageViewer(DocumentModel doc) {
    if (doc.url != null && doc.url!.startsWith('data:image')) {
      try {
        final base64String = doc.url!.split(',').last;
        final bytes = base64Decode(base64String);
        return InteractiveViewer(
          maxScale: 5.0,
          child: Center(
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _buildImageError(),
            ),
          ),
        );
      } catch (_) {}
    }

    if (doc.filePath != null && File(doc.filePath!).existsSync()) {
      return InteractiveViewer(
        maxScale: 5.0,
        child: Center(
          child: Image.file(
            File(doc.filePath!),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildImageError(),
          ),
        ),
      );
    }

    return _buildImageError();
  }

  Widget _buildImageError() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8), size: 36),
          SizedBox(height: 8),
          Text('Image rendered from storage', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildTextViewer(DocumentModel doc) {
    final text = doc.fileContent ?? doc.previewExcerpt;
    final lines = text.split('\n');
    const linesPerPage = 28;
    final start = ((_currentPage - 1) * linesPerPage).clamp(0, lines.length);
    final end = (start + linesPerPage).clamp(0, lines.length);
    final pageLines = lines.sublist(start, end);

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: pageLines.length,
      itemBuilder: (ctx, i) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  '${start + i + 1}',
                  style: const TextStyle(color: Color(0xFF475569), fontSize: 10, fontFamily: 'monospace'),
                ),
              ),
              Expanded(
                child: Text(
                  pageLines[i],
                  style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11.5, height: 1.35),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAcademicDocViewer(DocumentModel doc) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                Icon(
                  doc.fileType == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
                  color: doc.fileType == 'pdf' ? const Color(0xFFEF4444) : const Color(0xFF38BDF8),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    doc.title,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF131823),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF262F40)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Section $_currentPage: Key Principles & Questions',
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
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: const Row(
              children: [
                Icon(Icons.edit_note_rounded, color: Color(0xFF3B82F6), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Solve and annotate directly on the whiteboard on the right (70% canvas).',
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

  Widget _buildResourcePickerView() {
    final sampleResources = [
      _SampleResource(
        icon: Icons.picture_as_pdf_rounded,
        title: 'Physics Mechanics Notes.pdf',
        type: 'PDF Document',
        color: const Color(0xFFEF4444),
        pages: 5,
        preview: 'Classical Mechanics Problem Set:\n\n1. Calculate the projectile trajectory with air resistance.\n2. Apply conservation of angular momentum to orbiting masses.\n3. Derive kinetic friction coefficient on an inclined plane.\n\nUse the pen tool on the right whiteboard canvas to graph coordinates.',
      ),
      _SampleResource(
        icon: Icons.image_rounded,
        title: 'Circuit Analysis Diagram.png',
        type: 'Image Diagram',
        color: const Color(0xFF38BDF8),
        pages: 1,
        preview: 'RLC Circuit Schematic Diagram:\n\nAnalyze nodes A, B, and C under 60Hz alternating sinusoidal drive. Verify Kirchhoff Current Law (KCL) summation at junction.',
      ),
      _SampleResource(
        icon: Icons.description_rounded,
        title: 'Calculus Formulas.docx',
        type: 'Word Document',
        color: const Color(0xFF818CF8),
        pages: 4,
        preview: 'Essential Derivatives & Integrals:\n\n- d/dx [sin(x)] = cos(x)\n- d/dx [ln(x)] = 1/x\n- Integral [e^(kx) dx] = (1/k) * e^(kx) + C\n- Integration by parts: Integral [u dv] = u*v - Integral [v du].',
      ),
      _SampleResource(
        icon: Icons.slideshow_rounded,
        title: 'Thermodynamics Lecture.pptx',
        type: 'Presentation',
        color: const Color(0xFFF97316),
        pages: 6,
        preview: 'Slide 1: First and Second Laws of Thermodynamics.\nDelta U = Q - W.\nEntropy of an isolated system always increases.\nCarnot engine ideal efficiency eta = 1 - (Tc/Th).',
      ),
      _SampleResource(
        icon: Icons.article_rounded,
        title: 'Lab Experiments.txt',
        type: 'Text Notes',
        color: const Color(0xFF10B981),
        pages: 3,
        preview: 'Chemistry Laboratory Procedure:\n1. Calibrate analytical balance to +/- 0.001g.\n2. Titrate standard HCl against NaOH solution.\n3. Record phenolphthalein color change endpoint.',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            'SELECT REFERENCE MATERIAL',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 6),
        ...sampleResources.map((res) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _loadSampleDocument(
                    res.title,
                    res.title.split('.').last,
                    res.type,
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
                              '${res.type} • ${res.pages} Pages',
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
        }),
      ],
    );
  }
}

class _SampleResource {
  final IconData icon;
  final String title;
  final String type;
  final Color color;
  final int pages;
  final String preview;

  _SampleResource({
    required this.icon,
    required this.title,
    required this.type,
    required this.color,
    required this.pages,
    required this.preview,
  });
}
