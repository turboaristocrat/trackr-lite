import 'package:flutter/material.dart';
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
  final TextEditingController _inputCtrl = TextEditingController();

  final List<String> _quickReminders = [
    '⛽ Diesel Refueling',
    '🔧 Check Hydraulic Oil',
    '⚠️ Caution Order Noted',
    '📋 Track Tools & Clamp Check',
    '📝 Shift Handover Notes',
    '⚡ OHE Power Block Clearance',
  ];

  @override
  void initState() {
    super.initState();
    refreshNotes();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
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

  Future<void> _addNote(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final item = ReminderItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: trimmed,
    );
    final updated = List<ReminderItem>.from(_notes)..insert(0, item);
    await _saveAll(updated);
    _inputCtrl.clear();
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
                      // Filter Segmented Buttons
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

                // Quick Tag Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: _quickReminders.map((rem) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(rem, style: const TextStyle(fontSize: 11.5)),
                          backgroundColor: AppTheme.surfaceContainerLow,
                          side: const BorderSide(color: AppTheme.borderColor, width: 0.8),
                          onPressed: () => _addNote(rem),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Add Note Input Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Type a reminder or machine note...',
                            prefixIcon: Icon(Icons.add_task_rounded, size: 19),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          onSubmitted: (val) => _addNote(val),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _addNote(_inputCtrl.text),
                        child: const Row(
                          children: [
                            Icon(Icons.add_rounded, size: 18),
                            SizedBox(width: 4),
                            Text('Add'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Notes List
                Expanded(
                  child: filteredNotes.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
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
              'Add maintenance checklists, caution orders, or shift handover notes anytime above.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard(ReminderItem note) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: note.isDone ? AppTheme.surfaceContainerLow : AppTheme.cardBg,
      child: InkWell(
        onTap: () => _toggleNote(note.id),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  note.isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: note.isDone ? AppTheme.railSafetyGreen : AppTheme.textMuted,
                  size: 22,
                ),
                onPressed: () => _toggleNote(note.id),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  note.text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: note.isDone ? FontWeight.normal : FontWeight.w600,
                    color: note.isDone ? AppTheme.textMuted : AppTheme.textPrimary,
                    decoration: note.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.textMuted),
                visualDensity: VisualDensity.compact,
                tooltip: 'Delete',
                onPressed: () => _deleteNote(note.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
