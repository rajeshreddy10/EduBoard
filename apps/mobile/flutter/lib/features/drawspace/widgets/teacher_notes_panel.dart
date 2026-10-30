import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/whiteboard_provider.dart';

/// Private drawer for instructor lesson cues, derivations, and pedagogy steps.
/// Features search filter, real-time autosave, and creation of structured notes.
class TeacherNotesPanel extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const TeacherNotesPanel({super.key, required this.onClose});

  @override
  ConsumerState<TeacherNotesPanel> createState() => _TeacherNotesPanelState();
}

class _TeacherNotesPanelState extends ConsumerState<TeacherNotesPanel> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _searchController = TextEditingController();
  bool _isAdding = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _saveNote() {
    if (_titleController.text.trim().isNotEmpty) {
      ref.read(whiteboardProvider.notifier).addTeacherNote(
            _titleController.text.trim(),
            _contentController.text.trim(),
          );
      _titleController.clear();
      _contentController.clear();
      setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(whiteboardProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timeFormat = DateFormat.jm();

    final filteredNotes = state.teacherNotes.where((note) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return note.title.toLowerCase().contains(q) || note.content.toLowerCase().contains(q);
    }).toList();

    return Container(
      width: 320,
      color: colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 18, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Teacher Notes (Private)',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Search notes & cues...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            if (_isAdding)
              Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Cue Title',
                        hintText: 'e.g. Stokes Derivation Step 2',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _contentController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Pedagogical Cue',
                        hintText: 'Ask class for right hand rule orientation...',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _isAdding = false),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _saveNote,
                          child: const Text('Save Cue'),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Private Cue'),
                    onPressed: () => setState(() => _isAdding = true),
                  ),
                ),
              ),

            Expanded(
              child: filteredNotes.isEmpty
                  ? Center(
                      child: Text(
                        _searchQuery.isEmpty ? 'No cues added yet.' : 'No notes match "$_searchQuery"',
                        style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: filteredNotes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final note = filteredNotes[idx];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.08)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      note.title,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    timeFormat.format(note.createdAt),
                                    style: TextStyle(fontSize: 10, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                note.content,
                                style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.8)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
