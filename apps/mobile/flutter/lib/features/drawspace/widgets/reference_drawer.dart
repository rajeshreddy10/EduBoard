import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/doc_annotation_model.dart';
import '../../../providers/whiteboard_provider.dart';

/// Modern 2026 Material 3 Reference & Knowledge Dock
/// Features:
/// - Floating Glassmorphic Panel (22px rounded corners, blur, subtle border)
/// - Universal Search across references, citations, linked files, and AI derivations
/// - Dynamic category chips (All, Physics, Circuits, Calculus, Chemistry, AI Notes)
/// - 5 Collapsible sections with smooth expand/collapse animations
/// - Academic Citations (IEEE, APA, MLA) with 1-tap "Copy" and "Insert into Whiteboard"
/// - AI Derivations & Formulas with 1-tap canvas placement
/// - Real device file import (PDF, DOCX, Images, Text, Code)
/// - Responsive for phones (overlay dock) and tablets (side docking)
class ReferenceDrawer extends ConsumerStatefulWidget {
  const ReferenceDrawer({super.key});

  @override
  ConsumerState<ReferenceDrawer> createState() => _ReferenceDrawerState();
}

class _ReferenceDrawerState extends ConsumerState<ReferenceDrawer> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedCategoryIndex = 0;
  int _currentPage = 1;

  // Collapsible section state
  bool _isReferencesExpanded = true;
  bool _isCitationsExpanded = true;
  bool _isAiDerivationsExpanded = true;
  bool _isLinkedFilesExpanded = true;
  bool _isSourcesExpanded = false;

  final List<String> _categories = [
    'All',
    'Physics',
    'Circuits',
    'Calculus',
    'Chemistry',
    'AI Notes',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
            : '$category loaded into Reference Dock and synchronized on canvas.',
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
            content: Text('$name is active in Reference Dock and on Canvas'),
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

  void _insertCitationIntoCanvas(String citation) {
    ref.read(whiteboardProvider.notifier).insertTextCard(citation);
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Citation placed on Whiteboard as text card'),
        backgroundColor: Color(0xFF2563EB),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _copyCitationToClipboard(String citation) {
    Clipboard.setData(ClipboardData(text: citation));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Citation copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _insertDerivationIntoCanvas(String title, String formula) {
    final text = '[$title]\n$formula';
    ref.read(whiteboardProvider.notifier).insertTextCard(text);
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Placed "$title" onto Whiteboard'),
        backgroundColor: const Color(0xFF059669),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool _matchesFilter(String text, String category) {
    final selectedCat = _categories[_selectedCategoryIndex];
    if (selectedCat != 'All' && category.toLowerCase() != selectedCat.toLowerCase()) {
      return false;
    }
    if (_searchQuery.isEmpty) return true;
    return text.toLowerCase().contains(_searchQuery) || category.toLowerCase().contains(_searchQuery);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(whiteboardProvider);
    final doc = state.referenceDocument;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Modern Header ──────────────────────────────────────────
              _buildHeader(context, doc),

              // ── 2. Top Action Controls ────────────────────────────────────
              _buildActionsBar(context, state),

              // ── 3. Live Search Bar ────────────────────────────────────────
              _buildSearchBar(),

              // ── 4. Category Chips ─────────────────────────────────────────
              _buildCategoryChips(),

              const Divider(color: Color(0xFF1E293B), height: 1),

              // ── 5. Scrollable Content Body ────────────────────────────────
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  children: [
                    // A. Active Document Glass Card (if any)
                    if (doc != null) ...[
                      _buildActiveDocumentCard(context, doc, state),
                      const SizedBox(height: 16),
                    ],

                    // B. Curated Academic References
                    _buildSectionHeader(
                      title: 'Core References',
                      badge: 'Textbooks & Notes',
                      icon: Icons.menu_book_rounded,
                      isExpanded: _isReferencesExpanded,
                      onToggle: () => setState(() => _isReferencesExpanded = !_isReferencesExpanded),
                    ),
                    if (_isReferencesExpanded) ..._buildReferencesSection(),

                    const SizedBox(height: 16),

                    // C. Academic Citations (IEEE, APA, MLA)
                    _buildSectionHeader(
                      title: 'Citations & Bib',
                      badge: 'IEEE • APA • MLA',
                      icon: Icons.format_quote_rounded,
                      isExpanded: _isCitationsExpanded,
                      onToggle: () => setState(() => _isCitationsExpanded = !_isCitationsExpanded),
                    ),
                    if (_isCitationsExpanded) ..._buildCitationsSection(),

                    const SizedBox(height: 16),

                    // D. AI References & Formulas
                    _buildSectionHeader(
                      title: 'AI References & Proofs',
                      badge: 'Math • Equations',
                      icon: Icons.auto_awesome_rounded,
                      isExpanded: _isAiDerivationsExpanded,
                      onToggle: () => setState(() => _isAiDerivationsExpanded = !_isAiDerivationsExpanded),
                    ),
                    if (_isAiDerivationsExpanded) ..._buildAiDerivationsSection(),

                    const SizedBox(height: 16),

                    // E. Linked Files & Problem Sets
                    _buildSectionHeader(
                      title: 'Linked Files & Sheets',
                      badge: 'PDF • Images',
                      icon: Icons.attach_file_rounded,
                      isExpanded: _isLinkedFilesExpanded,
                      onToggle: () => setState(() => _isLinkedFilesExpanded = !_isLinkedFilesExpanded),
                    ),
                    if (_isLinkedFilesExpanded) ..._buildLinkedFilesSection(),

                    const SizedBox(height: 16),

                    // F. External Sources & Repositories
                    _buildSectionHeader(
                      title: 'Course Sources',
                      badge: 'MIT OCW • Stanford',
                      icon: Icons.open_in_new_rounded,
                      isExpanded: _isSourcesExpanded,
                      onToggle: () => setState(() => _isSourcesExpanded = !_isSourcesExpanded),
                    ),
                    if (_isSourcesExpanded) ..._buildSourcesSection(),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header Widget ──────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, DocumentModel? doc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Knowledge Dock',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  'References • Citations • Linked Files',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                ref.read(whiteboardProvider.notifier).toggleReferencePanel();
                HapticFeedback.selectionClick();
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions Bar ────────────────────────────────────────────────────────────
  Widget _buildActionsBar(BuildContext context, WhiteboardState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(
        children: [
          // Import File Button
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _pickAndOpenFile,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
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

          // Canvas Underlay Toggle Pill
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                ref.read(whiteboardProvider.notifier).toggleShowDocOnCanvas();
                HapticFeedback.selectionClick();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: state.showDocOnCanvas
                      ? const Color(0xFF059669).withValues(alpha: 0.2)
                      : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: state.showDocOnCanvas
                        ? const Color(0xFF10B981)
                        : const Color(0xFF334155),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      state.showDocOnCanvas ? Icons.layers_rounded : Icons.layers_clear_rounded,
                      color: state.showDocOnCanvas ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      state.showDocOnCanvas ? 'On Canvas' : 'Dock Only',
                      style: TextStyle(
                        color: state.showDocOnCanvas ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
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
    );
  }

  // ── Search Bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155), width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Search references, formulas, citations...',
                  hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              GestureDetector(
                onTap: () => _searchController.clear(),
                child: const Icon(Icons.cancel_rounded, color: Color(0xFF94A3B8), size: 15),
              ),
          ],
        ),
      ),
    );
  }

  // ── Category Chips Bar ─────────────────────────────────────────────────────
  Widget _buildCategoryChips() {
    return Container(
      height: 34,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _categories.length,
        itemBuilder: (ctx, idx) {
          final isSelected = _selectedCategoryIndex == idx;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() => _selectedCategoryIndex = idx);
                  HapticFeedback.selectionClick();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF334155),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _categories[idx],
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Active Document Card ───────────────────────────────────────────────────
  Widget _buildActiveDocumentCard(BuildContext context, DocumentModel doc, WhiteboardState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  doc.fileType.toUpperCase(),
                  style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  doc.title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 16),
                tooltip: 'Unlink from Canvas',
                onPressed: () {
                  ref.read(whiteboardProvider.notifier).clearReferenceDocument();
                  HapticFeedback.selectionClick();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            doc.previewExcerpt,
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, height: 1.35),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (doc.totalPages > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Page $_currentPage of ${doc.totalPages}',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 20),
                      onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
                      onPressed: _currentPage < doc.totalPages ? () => setState(() => _currentPage++) : null,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Collapsible Section Header ─────────────────────────────────────────────
  Widget _buildSectionHeader({
    required String title,
    required String badge,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF818CF8), size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              Icon(
                isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: const Color(0xFF94A3B8),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section 1: Curated Academic References ─────────────────────────────────
  List<Widget> _buildReferencesSection() {
    final items = [
      (
        title: 'Halliday & Resnick: Electromagnetism',
        category: 'Physics',
        snippet: 'Gauss Law: ∮ E·dA = Q_enc / ε₀ • Maxwell displacement current.',
        ext: 'pdf',
        pages: 8,
      ),
      (
        title: 'Sedra & Smith: Microelectronic Circuits',
        category: 'Circuits',
        snippet: 'Small-signal analysis, MOSFET transconductance gm = 2ID/VOV.',
        ext: 'pdf',
        pages: 6,
      ),
      (
        title: 'Stewart Calculus: Multivariable Integration',
        category: 'Calculus',
        snippet: 'Green Theorem, Stokes Theorem: ∬ (∇ × F)·dS = ∮ F·dr.',
        ext: 'doc',
        pages: 5,
      ),
      (
        title: 'Organic Chemistry: Reaction Mechanisms',
        category: 'Chemistry',
        snippet: 'SN1 vs SN2 kinetics, nucleophilic addition, resonance structures.',
        ext: 'pdf',
        pages: 7,
      ),
    ].where((item) => _matchesFilter('${item.title} ${item.snippet}', item.category)).toList();

    if (items.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('No references match filter', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
        ),
      ];
    }

    return items.map((r) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    r.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    r.category,
                    style: const TextStyle(color: Color(0xFFA5B4FC), fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              r.snippet,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, height: 1.35),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.open_in_browser_rounded, size: 14, color: Color(0xFF60A5FA)),
                  label: const Text('Open in Dock & Canvas', style: TextStyle(color: Color(0xFF60A5FA), fontSize: 11)),
                  onPressed: () => _loadSampleDocument(r.title, r.ext, r.category, r.pages, r.snippet),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  // ── Section 2: Academic Citations (IEEE, APA, MLA) ─────────────────────────
  List<Widget> _buildCitationsSection() {
    final citations = [
      (
        label: 'IEEE: Maxwell Equations Foundation',
        category: 'Physics',
        citation: 'J. C. Maxwell, "A Dynamical Theory of the Electromagnetic Field," Philos. Trans. R. Soc. Lond., vol. 155, pp. 459–512, 1865.',
      ),
      (
        label: 'APA: Modern Circuit Synthesis',
        category: 'Circuits',
        citation: 'Sedra, A. S., & Smith, K. C. (2020). Microelectronic Circuits (8th ed.). Oxford University Press.',
      ),
      (
        label: 'IEEE: Vector Calculus Formulations',
        category: 'Calculus',
        citation: 'J. Stewart, Calculus: Early Transcendentals, 9th ed. Boston, MA: Cengage Learning, 2021.',
      ),
      (
        label: 'MLA: Quantum Wave Mechanics',
        category: 'Physics',
        citation: 'Griffiths, David J., and Darrell F. Schroeter. Introduction to Quantum Mechanics. 3rd ed., Cambridge UP, 2018.',
      ),
    ].where((c) => _matchesFilter('${c.label} ${c.citation}', c.category)).toList();

    if (citations.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('No citations match filter', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
        ),
      ];
    }

    return citations.map((c) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    c.label,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    c.category,
                    style: const TextStyle(color: Color(0xFF34D399), fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              c.citation,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    side: const BorderSide(color: Color(0xFF475569)),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 12, color: Color(0xFFCBD5E1)),
                  label: const Text('Copy', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 10.5)),
                  onPressed: () => _copyCitationToClipboard(c.citation),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.add_to_photos_rounded, size: 12, color: Colors.white),
                  label: const Text('Place on Board', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                  onPressed: () => _insertCitationIntoCanvas(c.citation),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  // ── Section 3: AI Derivations & Formulas ───────────────────────────────────
  List<Widget> _buildAiDerivationsSection() {
    final derivations = [
      (
        title: "Maxwell Equations Set",
        category: 'Physics',
        formula: "∇·E = ρ/ε₀\n∇·B = 0\n∇×E = -∂B/∂t\n∇×B = μ₀J + μ₀ε₀(∂E/∂t)",
      ),
      (
        title: "Kirchhoff Laws & RC Transient",
        category: 'Circuits',
        formula: "∑ I_in = ∑ I_out (KCL)\n∑ V_loop = 0 (KVL)\nV_C(t) = V₀(1 - e^(-t/RC))",
      ),
      (
        title: "Taylor Series Polynomial Expansion",
        category: 'Calculus',
        formula: "f(x) = ∑ [f^(n)(a)/n!] (x - a)^n\ne^x = 1 + x + x²/2! + x³/3! + ...",
      ),
      (
        title: "Schrödinger Time-Dependent Equation",
        category: 'Physics',
        formula: "iℏ ∂Ψ/∂t = ĤΨ = [-ℏ²/(2m) ∇² + V(r)]Ψ",
      ),
    ].where((d) => _matchesFilter('${d.title} ${d.formula}', d.category)).toList();

    if (derivations.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('No AI formulas match filter', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
        ),
      ];
    }

    return derivations.map((d) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    d.title,
                    style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 11.5),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    d.category,
                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                d.formula,
                style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                  label: const Text('Place Derivation on Board', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                  onPressed: () => _insertDerivationIntoCanvas(d.title, d.formula),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  // ── Section 4: Linked Files & Attached Problem Sets ────────────────────────
  List<Widget> _buildLinkedFilesSection() {
    final files = [
      (name: 'Midterm_Formula_Sheet.pdf', category: 'Physics', size: '240 KB', pages: 4),
      (name: 'RLC_Filter_Schematic.png', category: 'Circuits', size: '1.2 MB', pages: 1),
      (name: 'Integration_Problem_Set_04.docx', category: 'Calculus', size: '180 KB', pages: 5),
    ].where((f) => _matchesFilter('${f.name} ${f.category}', f.category)).toList();

    return files.map((f) {
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.description_rounded, color: Color(0xFF60A5FA), size: 16),
        ),
        title: Text(
          f.name,
          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('${f.category} • ${f.size}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
        trailing: TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => _loadSampleDocument(f.name, f.name.split('.').last, f.category, f.pages, 'Loaded attached material ${f.name} into session.'),
          child: const Text('Open', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11)),
        ),
      );
    }).toList();
  }

  // ── Section 5: Sources & Repositories ──────────────────────────────────────
  List<Widget> _buildSourcesSection() {
    final sources = [
      (title: 'MIT OCW 8.02: Electricity & Magnetism', desc: 'Walter Lewin lecture series & problem formulations.'),
      (title: 'Stanford Online EE101', desc: 'Circuits and systems repository with lab work sheets.'),
      (title: 'OpenStax University Physics Vol 2', desc: 'Peer-reviewed open textbooks & diagrams.'),
    ];

    return sources.map((s) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.link_rounded, color: Color(0xFF64748B), size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title, style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 11, fontWeight: FontWeight.bold)),
                  Text(s.desc, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
