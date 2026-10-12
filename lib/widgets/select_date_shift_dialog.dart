import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/shift_log.dart';
import '../theme/app_theme.dart';

class SelectDateShiftDialog extends StatefulWidget {
  final String initialDate;
  final bool initialIsNightShift;
  final String? initialTime;

  const SelectDateShiftDialog({
    super.key,
    required this.initialDate,
    required this.initialIsNightShift,
    this.initialTime,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required String initialDate,
    required bool initialIsNightShift,
    String? initialTime,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => SelectDateShiftDialog(
        initialDate: initialDate,
        initialIsNightShift: initialIsNightShift,
        initialTime: initialTime,
      ),
    );
  }

  @override
  State<SelectDateShiftDialog> createState() => _SelectDateShiftDialogState();
}

class _SelectDateShiftDialogState extends State<SelectDateShiftDialog> {
  late DateTime _selectedDate;
  late bool _isNightShift;
  String _time = '';

  @override
  void initState() {
    super.initState();
    try {
      _selectedDate = DateTime.parse(widget.initialDate);
    } catch (_) {
      _selectedDate = DateTime.now();
    }
    _isNightShift = widget.initialIsNightShift;
    _time = widget.initialTime ?? '';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
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
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final initial = _time.isNotEmpty && _time.contains(':')
        ? TimeOfDay(
            hour: int.tryParse(_time.split(':')[0]) ?? now.hour,
            minute: int.tryParse(_time.split(':')[1]) ?? now.minute,
          )
        : now;

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
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
      setState(() {
        _time = '$h:$m';
        // Auto-detect night shift based on hour (18:00 - 06:00 is night shift)
        if (picked.hour >= 18 || picked.hour < 6) {
          _isNightShift = true;
        } else {
          _isNightShift = false;
        }
      });
    }
  }

  String _formatPreview() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final dummy = ShiftLog(
      date: dateStr,
      isNightShift: _isNightShift,
      machineName: '',
      division: '',
      section: '',
      blocks: const [],
    );
    return dummy.formattedDate;
  }

  void _save() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    Navigator.pop(context, {
      'date': dateStr,
      'isNightShift': _isNightShift,
      'time': _time,
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayDateStr = DateFormat('EEE, dd MMMM yyyy').format(_selectedDate);
    final formattedPreview = _formatPreview();

    return AlertDialog(
      backgroundColor: AppTheme.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Row(
        children: [
          Icon(Icons.calendar_month_rounded, color: AppTheme.primary, size: 22),
          SizedBox(width: 8),
          Text(
            'Select Date & Shift',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose the shift work date. For night shifts, TRACKR Lite automatically formats both dates (e.g. 12/13/10/2026).',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 16),

              // Date Picker Card
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_calendar_rounded, size: 20, color: AppTheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Shift Date', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                            const SizedBox(height: 1),
                            Text(displayDateStr, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Shift Type Segmented Control (Day vs Night)
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isNightShift = false),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_isNightShift
                              ? AppTheme.primary.withValues(alpha: 0.12)
                              : AppTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: !_isNightShift ? AppTheme.primary : AppTheme.borderColor,
                            width: !_isNightShift ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.wb_sunny_rounded,
                              size: 16,
                              color: !_isNightShift ? AppTheme.primary : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Day Shift',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: !_isNightShift ? AppTheme.primary : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isNightShift = true),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _isNightShift
                              ? const Color(0xFF6750A4).withValues(alpha: 0.12)
                              : AppTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isNightShift ? const Color(0xFF6750A4) : AppTheme.borderColor,
                            width: _isNightShift ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.nightlight_round,
                              size: 16,
                              color: _isNightShift ? const Color(0xFF6750A4) : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Night Shift',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _isNightShift ? const Color(0xFF6750A4) : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Optional Time Picker (for auto-detecting shift)
              InkWell(
                onTap: _pickTime,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 18, color: AppTheme.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Shift Time (Optional - Auto-detects shift)', style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
                            const SizedBox(height: 1),
                            Text(
                              _time.isNotEmpty ? '$_time hrs' : 'Tap to set time (e.g. 22:30)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _time.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                                color: _time.isNotEmpty ? AppTheme.textPrimary : AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_time.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() => _time = ''),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Formatted Preview Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _isNightShift
                      ? const Color(0xFF6750A4).withValues(alpha: 0.08)
                      : AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isNightShift
                        ? const Color(0xFF6750A4).withValues(alpha: 0.3)
                        : AppTheme.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isNightShift ? Icons.nights_stay_rounded : Icons.today_rounded,
                      size: 18,
                      color: _isNightShift ? const Color(0xFF6750A4) : AppTheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isNightShift ? 'Report Date (Night Shift):' : 'Report Date (Day Shift):',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            formattedPreview,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _isNightShift ? const Color(0xFF6750A4) : AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Apply Date & Shift'),
        ),
      ],
    );
  }
}
