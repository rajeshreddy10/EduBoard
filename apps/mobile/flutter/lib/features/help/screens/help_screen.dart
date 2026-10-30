import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utilities/responsive_layout.dart';

/// Help & Guide Center - mirrors web /help with searchable FAQ accordions
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String _search = '';
  String? _openId;

  static const List<_Faq> _faqs = [
    _Faq('1', 'Dashboard & History', 'What is the EduBoard Dashboard?',
        'The Dashboard is your main control hub. It provides an overview of your recent whiteboards, quick board creation launchers, class stats, and direct access to your saved cloud history.'),
    _Faq('2', 'Dashboard & History', 'How do I access and resume past saved sessions?',
        'Open "Workspace History" from the dashboard to view all your saved sessions. You can resume editing, rename, duplicate, share, or delete any past session.'),
    _Faq('3', 'Smart Board', 'What tools are available in Smart Board (DrawSpace)?',
        'Smart Board includes freehand Pen, Eraser, Pan, Select, Vanishing Laser Pointer, Focus Spotlight, 6 color swatches, Text Typing, Shapes, Progressive Reveal steps, 30/70 Reference Drawer, Undo/Redo, and Presentation Mode.'),
    _Faq('4', 'Smart Board', 'How do I open and use the Reference Drawer?',
        'Tap the sidebar icon in the DrawSpace header to slide open the 30/70 split view. Load lesson notes or reference materials on the left while keeping your main teaching canvas active on the right.'),
    _Faq('5', 'DocCanvas Studio', 'What is DocCanvas Document Annotator?',
        'DocCanvas allows you to import and annotate PDF, Word, PPT, and image documents directly on canvas with pen, highlighter, text markup, focus magnifier, and vector replay player.'),
    _Faq('6', 'Voice & AI', 'How does Voice Board speech transcription work?',
        'Tap "Start Listening" and speak into your microphone. Your spoken words are automatically transcribed into canvas text blocks with real-time sentence deduplication and confidence scoring.'),
    _Faq('7', 'Collaboration', 'How do I share and collaborate on whiteboards?',
        'Open any board and share it to invite collaborators by email with Viewer or Editor permissions, or broadcast your canvas in real time via Socket.IO sync.'),
    _Faq('8', 'Settings & Mobile', 'How do I sync settings across devices?',
        'Sign in with the same Firebase account on each device. Theme presets, accents, profile, and board data sync automatically through Firestore in real time.'),
  ];

  static const List<_Category> _categories = [
    _Category(Icons.gesture_rounded, 'Smart Board', Color(0xFF9333EA)),
    _Category(Icons.description_rounded, 'DocCanvas Studio', Color(0xFF2563EB)),
    _Category(Icons.mic_rounded, 'Voice & AI', Color(0xFFEA580C)),
    _Category(Icons.cloud_sync_rounded, 'Collaboration', Color(0xFF4F46E5)),
    _Category(Icons.settings_rounded, 'Settings & Mobile', Color(0xFF059669)),
  ];

  List<_Faq> get _filtered => _search.isEmpty
      ? _faqs
      : _faqs
          .where((f) =>
              f.q.toLowerCase().contains(_search.toLowerCase()) ||
              f.a.toLowerCase().contains(_search.toLowerCase()) ||
              f.category.toLowerCase().contains(_search.toLowerCase()))
          .toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/dashboard'),
        ),
        title: Text(
          'Help & Guide Center',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: ResponsiveLayout.contentWidth(context)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              physics: const BouncingScrollPhysics(),
              children: [
                // Global Search Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.1)),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Search for a topic or tool…',
                      border: InputBorder.none,
                      icon: Icon(Icons.search_rounded, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Category Pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: _categories.map((c) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() => _search = c.label);
                              HapticFeedback.selectionClick();
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: c.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: c.color.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(c.icon, size: 16, color: c.color),
                                  const SizedBox(width: 6),
                                  Text(
                                    c.label,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.color),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      'FREQUENTLY ASKED QUESTIONS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_filtered.length} items',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colorScheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_filtered.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.search_off_rounded, size: 44, color: colorScheme.onSurface.withValues(alpha: 0.3)),
                        const SizedBox(height: 10),
                        Text('No results found for "$_search"', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6))),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => setState(() => _search = ''),
                          child: const Text('Clear search filter'),
                        ),
                      ],
                    ),
                  )
                else
                  ..._filtered.map((faq) {
                    final isOpen = _openId == faq.id;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isOpen ? colorScheme.primary.withValues(alpha: 0.4) : colorScheme.onSurface.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Theme(
                        data: theme.copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: isOpen,
                          onExpansionChanged: (expanded) {
                            setState(() => _openId = expanded ? faq.id : null);
                            HapticFeedback.selectionClick();
                          },
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                faq.category.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                faq.q,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ],
                          ),
                          children: [
                            Divider(color: colorScheme.onSurface.withValues(alpha: 0.08)),
                            const SizedBox(height: 8),
                            Text(
                              faq.a,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: colorScheme.onSurface.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 20),
                // Support Box
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary.withValues(alpha: 0.08),
                        colorScheme.tertiary.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Need additional support?', style: TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(
                              'Our team is available to assist with any questions or technical issues.',
                              style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Support request opened — our team responds within 24h.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.mail_rounded, size: 16),
                        label: const Text('Contact'),
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

class _Faq {
  final String id;
  final String category;
  final String q;
  final String a;

  const _Faq(this.id, this.category, this.q, this.a);
}

class _Category {
  final IconData icon;
  final String label;
  final Color color;

  const _Category(this.icon, this.label, this.color);
}
