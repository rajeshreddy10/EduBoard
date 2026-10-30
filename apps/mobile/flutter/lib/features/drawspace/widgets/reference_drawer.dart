import 'package:flutter/material.dart';

/// 30/70 Reference Drawer for PDFs, Images, and Lesson Resources
class ReferenceDrawer extends StatelessWidget {
  const ReferenceDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final resources = [
      _ResourceItem(Icons.picture_as_pdf_rounded, 'Lesson Plan.pdf', 'PDF', Colors.red),
      _ResourceItem(Icons.image_rounded, 'Diagram.png', 'Image', Colors.blue),
      _ResourceItem(Icons.description_rounded, 'Notes.docx', 'Document', Colors.indigo),
      _ResourceItem(Icons.slideshow_rounded, 'Slides.pptx', 'Presentation', Colors.orange),
      _ResourceItem(Icons.photo_library_rounded, 'Screenshots', 'Gallery', Colors.green),
    ];

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          right: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.12)),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.folder_open_rounded, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Reference Materials',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: resources.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final res = resources[idx];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: res.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(res.icon, color: res.color, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    res.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                  Text(
                                    res.type,
                                    style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.visibility_rounded, size: 18, color: colorScheme.onSurface.withValues(alpha: 0.4)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Upload Resource'),
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceItem {
  final IconData icon;
  final String name;
  final String type;
  final Color color;

  _ResourceItem(this.icon, this.name, this.type, this.color);
}
