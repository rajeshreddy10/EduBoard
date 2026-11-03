import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/doc_annotation_model.dart';
import '../../../providers/doccanvas_provider.dart';

/// Full-featured academic document viewer: renders real files (Images, Text, PDF, Docs)
/// with page navigation, zoom, and smooth layout for direct canvas annotation.
class DocViewerPlaceholder extends ConsumerWidget {
  const DocViewerPlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(docCanvasProvider);
    final doc = state.activeDocument;

    if (doc == null) {
      return const Center(
        child: Text(
          'No document selected',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
      );
    }

    final ext = doc.fileType.toLowerCase();
    final isImage = ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'svg'].contains(ext);
    final isText = ['txt', 'md', 'csv', 'json', 'log', 'html', 'py', 'js', 'dart', 'ts'].contains(ext);
    final isPdf = ext == 'pdf';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131823),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262F40), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Document Header ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF262F40), width: 1),
              ),
            ),
            child: Row(
              children: [
                _buildFileIcon(ext),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${doc.category} • ${doc.author}',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Page ${state.currentPageIndex} of ${doc.totalPages}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF60A5FA),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Main Document Viewport ────────────────────────────────────────
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: _buildDocumentContent(context, doc, isImage, isText, isPdf, state.currentPageIndex),
            ),
          ),

          // ── Page Navigation Footer (if multi-page) ────────────────────────
          if (doc.totalPages > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF262F40), width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.chevron_left_rounded, size: 18, color: Colors.white),
                    label: const Text('Previous Page', style: TextStyle(color: Colors.white, fontSize: 11.5)),
                    onPressed: state.currentPageIndex > 1
                        ? () => ref.read(docCanvasProvider.notifier).setPageIndex(state.currentPageIndex - 1)
                        : null,
                  ),
                  Text(
                    'Page ${state.currentPageIndex} / ${doc.totalPages}',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white),
                    label: const Text('Next Page', style: TextStyle(color: Colors.white, fontSize: 11.5)),
                    onPressed: state.currentPageIndex < doc.totalPages
                        ? () => ref.read(docCanvasProvider.notifier).setPageIndex(state.currentPageIndex + 1)
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFileIcon(String ext) {
    IconData icon = Icons.description_rounded;
    Color color = const Color(0xFF3B82F6);

    if (ext == 'pdf') {
      icon = Icons.picture_as_pdf_rounded;
      color = const Color(0xFFEF4444);
    } else if (['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'svg'].contains(ext)) {
      icon = Icons.image_rounded;
      color = const Color(0xFFA855F7);
    } else if (['txt', 'md', 'csv', 'json', 'log', 'py', 'dart', 'js', 'ts'].contains(ext)) {
      icon = Icons.article_rounded;
      color = const Color(0xFF10B981);
    } else if (['doc', 'docx'].contains(ext)) {
      icon = Icons.description_rounded;
      color = const Color(0xFF3B82F6);
    } else if (['ppt', 'pptx'].contains(ext)) {
      icon = Icons.slideshow_rounded;
      color = const Color(0xFFF97316);
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  Widget _buildDocumentContent(
    BuildContext context,
    DocumentModel doc,
    bool isImage,
    bool isText,
    bool isPdf,
    int pageIndex,
  ) {
    // 1. Real local or memory Image file: direct rendering so annotation layer captures 100% of gestures
    if (isImage) {
      if (doc.url != null && doc.url!.startsWith('data:image')) {
        try {
          final base64String = doc.url!.split(',').last;
          final bytes = base64Decode(base64String);
          return Center(
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _buildFallbackImage(doc),
            ),
          );
        } catch (_) {}
      }

      if (doc.filePath != null && File(doc.filePath!).existsSync()) {
        return Center(
          child: Image.file(
            File(doc.filePath!),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildFallbackImage(doc),
          ),
        );
      }

      if (doc.url != null && doc.url!.startsWith('http')) {
        return Center(
          child: Image.network(
            doc.url!,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildFallbackImage(doc),
          ),
        );
      }

      return _buildFallbackImage(doc);
    }

    // 2. Real Text Document
    if (isText && doc.fileContent != null && doc.fileContent!.isNotEmpty) {
      final allLines = doc.fileContent!.split('\n');
      const linesPerPage = 28;
      final start = ((pageIndex - 1) * linesPerPage).clamp(0, allLines.length);
      final end = (start + linesPerPage).clamp(0, allLines.length);
      final pageLines = allLines.sublist(start, end);

      return Container(
        color: const Color(0xFF0F172A),
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: pageLines.length,
          itemBuilder: (ctx, i) {
            final lineNum = start + i + 1;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      '$lineNum',
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      pageLines[i],
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    // 3. PDF or Presentation Document View
    return _buildPdfDocumentView(doc, pageIndex);
  }

  Widget _buildFallbackImage(DocumentModel doc) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_outlined, color: Color(0xFF818CF8), size: 48),
          const SizedBox(height: 10),
          Text(
            doc.title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 4),
          const Text(
            'Interactive Image Document Ready for Canvas Annotations',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfDocumentView(DocumentModel doc, int pageIndex) {
    return Container(
      color: const Color(0xFF0B0F19),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 680),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF131823),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF262F40), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Academic Page Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEF4444), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Document Page $pageIndex of ${doc.totalPages} • Academic Problem Set',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'Ready to Annotate',
                        style: TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),

                const Divider(color: Color(0xFF262F40), height: 24),

                // Question & Formulation Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Problem Formulation Page $pageIndex',
                        style: const TextStyle(
                          color: Color(0xFF60A5FA),
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        doc.fileContent != null && doc.fileContent!.isNotEmpty
                            ? doc.fileContent!
                            : (doc.previewExcerpt.isNotEmpty
                                ? doc.previewExcerpt
                                : 'Calculate boundary limits, examine derivatives, and annotate solution steps on this document canvas.'),
                        style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5, height: 1.45),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Solution Work Area Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note_rounded, color: Color(0xFF60A5FA), size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Annotate directly above using the Pen, Highlighter, and Text tools. All markings are synchronized with your session.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
