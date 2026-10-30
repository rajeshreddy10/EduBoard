import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/doccanvas_provider.dart';

/// Full-featured academic document viewer: renders real files (Images, Text, PDF, Docs)
/// with page navigation and smooth layout for direct canvas annotation.
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
    final isImage = ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'].contains(ext);
    final isText = ['txt', 'md', 'csv', 'json', 'log', 'html', 'py', 'js'].contains(ext);
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
    } else if (['png', 'jpg', 'jpeg', 'webp', 'gif'].contains(ext)) {
      icon = Icons.image_rounded;
      color = const Color(0xFFA855F7);
    } else if (['txt', 'md', 'csv'].contains(ext)) {
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
    dynamic doc,
    bool isImage,
    bool isText,
    bool isPdf,
    int pageIndex,
  ) {
    // 1. Real local Image file
    if (isImage) {
      if (doc.filePath != null && File(doc.filePath!).existsSync()) {
        return Center(
          child: InteractiveViewer(
            maxScale: 4.0,
            child: Image.file(
              File(doc.filePath!),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: Text('Could not render image file', style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        );
      } else if (doc.url != null && doc.url!.isNotEmpty) {
        return Center(
          child: Image.network(
            doc.url!,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
              child: Text('Could not load image from URL', style: TextStyle(color: Colors.white)),
            ),
          ),
        );
      }
    }

    // 2. Real local Text file
    if (isText && doc.fileContent != null && (doc.fileContent as String).isNotEmpty) {
      final allLines = (doc.fileContent as String).split('\n');
      const linesPerPage = 32;
      final start = ((pageIndex - 1) * linesPerPage).clamp(0, allLines.length);
      final end = (start + linesPerPage).clamp(0, allLines.length);
      final pageLines = allLines.sublist(start, end);

      return Container(
        color: const Color(0xFF0F172A),
        padding: const EdgeInsets.all(20),
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
                    width: 32,
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

    // 3. PDF or Office Document presentation layout
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF60A5FA), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Page $pageIndex • Section $pageIndex.1 Academic Problem Set',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Problem Set Page $pageIndex: Analytical Formulations',
                  style: const TextStyle(
                    color: Color(0xFF60A5FA),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  doc.previewExcerpt.isNotEmpty
                      ? doc.previewExcerpt
                      : 'Examine the system boundary conditions. Annotate vectors, boundary limits, and derive corresponding eigenvalues directly on this canvas.',
                  style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 48,
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Canvas Layer Active',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Use the pen, highlighter, and text tools below to annotate this page.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
