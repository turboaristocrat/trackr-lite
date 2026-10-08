import 'package:flutter/material.dart';
import 'screens/history_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/shift_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/trackr_logo.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TrackrLiteApp());
}

class TrackrLiteApp extends StatelessWidget {
  const TrackrLiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TRACKR Lite',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.lightTheme,
      home: const MainScaffold(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  final GlobalKey<ShiftScreenState> _shiftKey = GlobalKey<ShiftScreenState>();
  final GlobalKey<NotesScreenState> _notesKey = GlobalKey<NotesScreenState>();
  final GlobalKey<HistoryScreenState> _historyKey = GlobalKey<HistoryScreenState>();
  final GlobalKey<SettingsScreenState> _settingsKey = GlobalKey<SettingsScreenState>();

  void _onDataChanged() {
    _shiftKey.currentState?.refreshShift();
    _notesKey.currentState?.refreshNotes();
    _historyKey.currentState?.refreshHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _currentIndex == 0
          ? AppBar(
              title: const TrackrLogo(iconSize: 32, fontSize: 18),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: const Text(
                    'Southern Railway',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            )
          : null,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ShiftScreen(
            key: _shiftKey,
            onShiftCompleted: () {
              _historyKey.currentState?.refreshHistory();
              setState(() => _currentIndex = 2);
            },
          ),
          NotesScreen(key: _notesKey),
          HistoryScreen(key: _historyKey),
          SettingsScreen(
            key: _settingsKey,
            onDataChanged: _onDataChanged,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) {
          if (idx == 0) {
            _shiftKey.currentState?.refreshShift();
          } else if (idx == 1) {
            _notesKey.currentState?.refreshNotes();
          } else if (idx == 2) {
            _historyKey.currentState?.refreshHistory();
          } else if (idx == 3) {
            _settingsKey.currentState?.refreshSettings();
          }
          setState(() => _currentIndex = idx);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.edit_note_rounded),
            selectedIcon: Icon(Icons.edit_note_rounded),
            label: 'Active Shift',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_rounded),
            selectedIcon: Icon(Icons.checklist_rounded),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
