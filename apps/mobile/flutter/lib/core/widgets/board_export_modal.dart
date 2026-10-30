import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modal dialog allowing users to choose an export format, view preview, and copy/share.
class BoardExportModal extends StatelessWidget {
  final String title;
  final Map<String, String Function()> formatExporters; // e.g. {'JSON': () => ..., 'SVG': () => ...}

  const BoardExportModal({
    super.key,
    required this.title,
    required this.formatExporters,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required Map<String, String Function()> formatExporters,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BoardExportModal(
        title: title,
        formatExporters: formatExporters,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final formats = formatExporters.keys.toList();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.file_download_outlined, color: colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Export Session',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Choose Format', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: formats.map((fmt) {
                IconData icon;
                Color color;
                switch (fmt.toUpperCase()) {
                  case 'PDF':
                    icon = Icons.picture_as_pdf_rounded;
                    color = Colors.red;
                    break;
                  case 'SVG':
                    icon = Icons.polyline_rounded;
                    color = Colors.orange;
                    break;
                  case 'PNG':
                    icon = Icons.image_rounded;
                    color = Colors.blue;
                    break;
                  case 'JSON':
                    icon = Icons.code_rounded;
                    color = Colors.green;
                    break;
                  case 'MARKDOWN':
                  case 'MD':
                    icon = Icons.text_snippet_rounded;
                    color = Colors.purple;
                    break;
                  case 'LATEX':
                    icon = Icons.functions_rounded;
                    color = Colors.teal;
                    break;
                  default:
                    icon = Icons.description_rounded;
                    color = Colors.indigo;
                }

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      final exporter = formatExporters[fmt];
                      if (exporter == null) return;
                      final content = exporter();
                      Clipboard.setData(ClipboardData(text: content));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$fmt export copied to clipboard!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 20, color: color),
                          const SizedBox(width: 8),
                          Text(
                            fmt,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

