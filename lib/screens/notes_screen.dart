import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reminder_item.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => NotesScreenState();
}

class NotesScreenState extends State<NotesScreen> {
  List<ReminderItem> _notes = [];
  bool _isLoading = true;
  String _filter = 'All'; // 'All', 'Pending', 'Done'
  String? _selectedTagFilter; // Filter by tag if selected

  @override
  void initState() {
    super.initState();
    refreshNotes();
  }

  Future<void> refreshNotes() async {
    setState(() => _isLoading = true);
    final list = await StorageService.getNotes();
    if (mounted) {
      setState(() {
        _notes = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAll(List<ReminderItem> updated) async {
    setState(() => _notes = updated);
    await StorageService.saveNotes(updated);
  }

  /// Collect all unique tags currently in use across notes
  List<String> get _allTags {
    final set = <String>{};
    for (final note in _notes) {
      for (final t in note.tags) {
        if (t.trim().isNotEmpty) set.add(t.trim());
      }
    }
    return set.toList()..sort();
  }

  Future<void> _showAddOrEditNoteDialog({ReminderItem? existing}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final detailsCtrl = TextEditingController(text: existing?.details ?? '');
    final tagInputCtrl = TextEditingController();

    String selectedCat = existing?.category ?? 'General';
    String? remDate = existing?.reminderDate;
    String? remTime = existing?.reminderTime;
    List<String> currentTags = List<String>.from(existing?.tags ?? []);

    final categories = ['General', 'Fuel', 'Maintenance', 'Caution', 'Inspection', 'Handover', 'Safety'];

    // Suggested quick tags
    final popularTags = ['Urgent', 'Engine', 'Hydraulic', 'Track', 'Siding', 'Depot', 'Material', 'Electrical'];

    final result = await showDialog<ReminderItem>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> pickDate() async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: now,
              firstDate: now.subtract(const Duration(days: 1)),
              lastDate: now.add(const Duration(days: 365)),
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppTheme.primary,
                    surface: AppTheme.cardBg,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) {
              setModalState(() {
                remDate = DateFormat('dd.MM.yyyy').format(picked);
              });
            }
          }

          Future<void> pickTime() async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppTheme.primary,
                    surface: AppTheme.cardBg,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) {
              final h = picked.hour.toString().padLeft(2, '0');
              final m = picked.minute.toString().padLeft(2, '0');
              setModalState(() {
                remTime = '$h:$m';
              });
            }
          }

          void addTag(String tag) {
            final cleaned = tag.trim().replaceAll(',', '');
            if (cleaned.isNotEmpty && !currentTags.contains(cleaned)) {
              setModalState(() {
                currentTags.add(cleaned);
                tagInputCtrl.clear();
              });
            }
          }

          void removeTag(String tag) {
            setModalState(() {
              currentTags.remove(tag);
            });
          }

          return AlertDialog(
            backgroundColor: AppTheme.cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  existing != null ? Icons.edit_note_rounded : Icons.note_add_rounded,
                  color: AppTheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  existing != null ? 'Edit Note & Reminder' : 'Add Note & Reminder',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Category Chips
                    const Text('Category:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: categories.map((cat) {
                          final isSel = selectedCat == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(cat, style: TextStyle(fontSize: 11.5, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                              selected: isSel,
                              selectedColor: AppTheme.primary,
                              labelStyle: TextStyle(color: isSel ? Colors.white : AppTheme.textPrimary),
                              backgroundColor: AppTheme.surfaceContainerLow,
                              onSelected: (_) => setModalState(() => selectedCat = cat),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Title
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Note Title / Task',
                        hintText: 'e.g. Check Hydraulic Oil',
                        prefixIcon: Icon(Icons.title_rounded, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Details
                    TextField(
                      controller: detailsCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Details / Notes (Optional)',
                        hintText: 'Add specific notes, location, or instructions...',
                        prefixIcon: Icon(Icons.notes_rounded, size: 18),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Tags Input & Management
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.label_outline_rounded, color: AppTheme.primary, size: 17),
                              SizedBox(width: 6),
                              Text(
                                'Tags',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Active tags
                          if (currentTags.isNotEmpty) ...[
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: currentTags.map((tag) {
                                return Chip(
                                  label: Text('#$tag', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                  deleteIcon: const Icon(Icons.close_rounded, size: 14),
                                  onDeleted: () => removeTag(tag),
                                  backgroundColor: AppTheme.cardBg,
                                  side: const BorderSide(color: AppTheme.borderColor),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                          ],

                          // Tag input field
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: tagInputCtrl,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    hintText: 'Type tag and press Add...',
                                    hintStyle: TextStyle(fontSize: 12),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  onSubmitted: (val) => addTag(val),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => addTag(tagInputCtrl.text),
                                child: const Text('Add Tag', style: TextStyle(fontSize: 11.5)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Suggested popular tags
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: popularTags.map((sug) {
                                final alreadyAdded = currentTags.contains(sug);
                                if (alreadyAdded) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(right: 5),
                                  child: InkWell(
                                    onTap: () => addTag(sug),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.cardBg,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppTheme.borderColor),
                                      ),
                                      child: Text('+$sug', style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Reminder Date & Time Section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.alarm_rounded, color: AppTheme.amberAccent, size: 18),
                              const SizedBox(width: 6),
                              const Text(
                                'Reminder Alarm / Due Date',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                              ),
                              const Spacer(),
                              if (remDate != null || remTime != null)
                                InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      remDate = null;
                                      remTime = null;
                                    });
                                  },
                                  child: const Text('Clear', style: TextStyle(color: AppTheme.redDanger, fontSize: 11.5)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                    side: BorderSide(
                                      color: remDate != null ? AppTheme.primary : AppTheme.borderColor,
                                    ),
                                  ),
                                  onPressed: pickDate,
                                  icon: const Icon(Icons.calendar_today_rounded, size: 15),
                                  label: Text(
                                    remDate ?? 'Set Date',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: remDate != null ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                    side: BorderSide(
                                      color: remTime != null ? AppTheme.primary : AppTheme.borderColor,
                                    ),
                                  ),
                                  onPressed: pickTime,
                                  icon: const Icon(Icons.access_time_rounded, size: 15),
                                  label: Text(
                                    remTime != null ? '$remTime hrs' : 'Set Time',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: remTime != null ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Quick date presets
                          Row(
                            children: [
                              _buildQuickDateChip(
                                label: 'Today',
                                onTap: () {
                                  setModalState(() {
                                    remDate = DateFormat('dd.MM.yyyy').format(DateTime.now());
                                  });
                                },
                              ),
                              const SizedBox(width: 6),
                              _buildQuickDateChip(
                                label: 'Tomorrow',
                                onTap: () {
                                  setModalState(() {
                                    remDate = DateFormat('dd.MM.yyyy').format(DateTime.now().add(const Duration(days: 1)));
                                  });
                                },
                              ),
                              const SizedBox(width: 6),
                              _buildQuickDateChip(
                                label: '+1 Week',
                                onTap: () {
                                  setModalState(() {
                                    remDate = DateFormat('dd.MM.yyyy').format(DateTime.now().add(const Duration(days: 7)));
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () {
                  final t = titleCtrl.text.trim();
                  if (t.isEmpty) return;
                  final item = (existing ?? ReminderItem(id: DateTime.now().millisecondsSinceEpoch.toString())).copyWith(
                    title: t,
                    details: detailsCtrl.text.trim(),
                    category: selectedCat,
                    tags: currentTags,
                    reminderDate: remDate,
                    reminderTime: remTime,
                  );
                  Navigator.pop(ctx, item);
                },
                child: Text(existing != null ? 'Update Note' : 'Save Note'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      if (existing != null) {
        final idx = _notes.indexWhere((n) => n.id == existing.id);
        if (idx != -1) {
          final list = List<ReminderItem>.from(_notes);
          list[idx] = result;
          await _saveAll(list);
        }
      } else {
        final list = List<ReminderItem>.from(_notes)..insert(0, result);
        await _saveAll(list);
      }
    }
  }

  Widget _buildQuickDateChip({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
      ),
    );
  }

  Future<void> _toggleNote(String id) async {
    final updated = _notes.map((n) {
      if (n.id == id) {
        return n.copyWith(isDone: !n.isDone);
      }
      return n;
    }).toList();
    await _saveAll(updated);
  }

  Future<void> _deleteNote(String id) async {
    final updated = List<ReminderItem>.from(_notes)..removeWhere((n) => n.id == id);
    await _saveAll(updated);
  }

  Future<void> _clearCompleted() async {
    final updated = List<ReminderItem>.from(_notes)..removeWhere((n) => n.isDone);
    await _saveAll(updated);
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _notes.where((n) => !n.isDone).length;
    final doneCount = _notes.where((n) => n.isDone).length;

    List<ReminderItem> filteredNotes;
    if (_filter == 'Pending') {
      filteredNotes = _notes.where((n) => !n.isDone).toList();
    } else if (_filter == 'Done') {
      filteredNotes = _notes.where((n) => n.isDone).toList();
    } else {
      filteredNotes = _notes;
    }

    // Apply tag filter if active
    if (_selectedTagFilter != null) {
      filteredNotes = filteredNotes.where((n) => n.tags.contains(_selectedTagFilter)).toList();
    }

    final allTagsList = _allTags;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.checklist_rounded, color: AppTheme.primary, size: 22),
            SizedBox(width: 8),
            Text('Notes & Reminders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          if (doneCount > 0)
            TextButton.icon(
              onPressed: _clearCompleted,
              icon: const Icon(Icons.clear_all_rounded, size: 17, color: AppTheme.textSecondary),
              label: const Text('Clear Done', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOrEditNoteDialog(),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('Add Note / Reminder', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Column(
              children: [
                // Top Summary & Filter Bar
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: pendingCount > 0
                              ? AppTheme.secondaryContainer.withValues(alpha: 0.25)
                              : AppTheme.railSafetyGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          pendingCount > 0 ? '$pendingCount Pending' : 'All Clear! ✓',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: pendingCount > 0 ? const Color(0xFF6B4800) : AppTheme.railSafetyGreen,
                          ),
                        ),
                      ),
                      const Spacer(),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'All', label: Text('All', style: TextStyle(fontSize: 11.5))),
                          ButtonSegment(value: 'Pending', label: Text('Pending', style: TextStyle(fontSize: 11.5))),
                          ButtonSegment(value: 'Done', label: Text('Done', style: TextStyle(fontSize: 11.5))),
                        ],
                        selected: {_filter},
                        onSelectionChanged: (set) => setState(() => _filter = set.first),
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),

                // Tags Filter Bar (if there are tags)
                if (allTagsList.isNotEmpty)
                  Container(
                    height: 38,
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: const Text('All Tags', style: TextStyle(fontSize: 11)),
                            selected: _selectedTagFilter == null,
                            onSelected: (_) => setState(() => _selectedTagFilter = null),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: AppTheme.surfaceContainerLow,
                            selectedColor: AppTheme.primary,
                            labelStyle: TextStyle(
                              color: _selectedTagFilter == null ? Colors.white : AppTheme.textPrimary,
                              fontWeight: _selectedTagFilter == null ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        ...allTagsList.map((tag) {
                          final isSel = _selectedTagFilter == tag;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text('#$tag', style: const TextStyle(fontSize: 11)),
                              selected: isSel,
                              onSelected: (_) => setState(() {
                                _selectedTagFilter = isSel ? null : tag;
                              }),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: AppTheme.surfaceContainerLow,
                              selectedColor: AppTheme.primary,
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : AppTheme.textPrimary,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                // Notes List
                Expanded(
                  child: filteredNotes.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                          itemCount: filteredNotes.length,
                          itemBuilder: (ctx, i) {
                            final note = filteredNotes[i];
                            return _buildNoteCard(note);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.task_alt_rounded, size: 40, color: AppTheme.railSafetyGreen),
            ),
            const SizedBox(height: 14),
            Text(
              _filter == 'Done' ? 'No completed reminders yet' : 'No reminders in this list',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap "+ Add Note / Reminder" to add notes, details, tags, and reminder alarms.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard(ReminderItem note) {
    Color catColor = AppTheme.primary;
    if (note.category == 'Fuel') catColor = Colors.orange.shade800;
    if (note.category == 'Maintenance') catColor = Colors.blue.shade800;
    if (note.category == 'Caution') catColor = Colors.amber.shade900;
    if (note.category == 'Safety') catColor = AppTheme.redDanger;
    if (note.category == 'Inspection') catColor = Colors.teal.shade800;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: note.isDone ? AppTheme.surfaceContainerLow : AppTheme.cardBg,
      child: InkWell(
        onTap: () => _showAddOrEditNoteDialog(existing: note),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Checkbox, Category, Title, Delete
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => _toggleNote(note.id),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2, right: 8),
                      child: Icon(
                        note.isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: note.isDone ? AppTheme.railSafetyGreen : AppTheme.textMuted,
                        size: 22,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: catColor.withValues(alpha: 0.25)),
                              ),
                              child: Text(
                                note.category,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: catColor,
                                ),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 17, color: AppTheme.textMuted),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Edit details & reminder',
                              onPressed: () => _showAddOrEditNoteDialog(existing: note),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 17, color: AppTheme.textMuted),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Delete',
                              onPressed: () => _deleteNote(note.id),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          note.title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: note.isDone ? AppTheme.textMuted : AppTheme.textPrimary,
                            decoration: note.isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Details section (if present)
              if (note.details.isNotEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: Text(
                    note.details,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: note.isDone ? AppTheme.textMuted : AppTheme.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],

              // Tags section (if present)
              if (note.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: note.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Text(
                          '#$tag',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],

              // Reminder badge (if present)
              if (note.hasReminder) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.amberAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.amberAccent.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.alarm_rounded, size: 13, color: AppTheme.secondary),
                        const SizedBox(width: 4),
                        Text(
                          'Due: ${note.reminderDisplay}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
