import 'package:flutter/material.dart';
import 'screens/history_screen.dart';
import 'screens/shift_screen.dart';
import 'theme/app_theme.dart';

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
      theme: AppTheme.darkTheme,
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
  final GlobalKey<HistoryScreenState> _historyKey = GlobalKey<HistoryScreenState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _currentIndex == 0
          ? AppBar(
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.flash_on_rounded, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'TRACKR',
                    style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.amberAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'LITE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.amberAccent,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.outline.withValues(alpha: 0.3)),
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
            onShiftCompleted: () {
              _historyKey.currentState?.refreshHistory();
              setState(() => _currentIndex = 1);
            },
          ),
          HistoryScreen(key: _historyKey),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: AppTheme.surface,
        indicatorColor: AppTheme.primary.withValues(alpha: 0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.edit_note_rounded),
            selectedIcon: Icon(Icons.edit_note_rounded, color: AppTheme.primary),
            label: 'Active Shift',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            selectedIcon: Icon(Icons.history_rounded, color: AppTheme.primary),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
