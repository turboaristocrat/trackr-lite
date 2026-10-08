import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackr_lite/models/block_entry.dart';
import 'package:trackr_lite/models/shift_log.dart';
import 'package:trackr_lite/services/report_service.dart';
import 'package:trackr_lite/services/station_service.dart';
import 'package:trackr_lite/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StationService', () {
    test('Station search finds matches by code and name', () {
      final results = StationService.search('HAD');
      expect(results.any((s) => s.code == 'HAD'), isTrue);
      expect(results.first.name, contains('Harippad'));
    });
  });

  group('ReportService', () {
    test('Matches official Southern Railway UTV format exactly', () {
      const log = ShiftLog(
        date: '2026-09-12',
        machineName: 'UTV005H',
        division: 'TVC',
        section: 'KTYM',
        readyStation: 'CGY',
        readyTime: '09:25',
        stabledStation: 'KTYM',
        blocks: [
          BlockEntry(
            id: 'b1',
            startTime: '10:35',
            endTime: '11:20',
            stationFrom: 'CGY',
            stationTo: 'CGV',
            line: 'UP',
            items: [
              WorkItem(activity: 'Sleepers unloaded', output: 16, outputUnit: 'Nos'),
            ],
          ),
          BlockEntry(
            id: 'b2',
            startTime: '12:05',
            endTime: '13:30',
            stationFrom: 'CGY',
            stationTo: 'TRVL',
            line: 'DN',
            items: [
              WorkItem(activity: 'Sleepers loaded', output: 64, outputUnit: 'Nos'),
            ],
          ),
          BlockEntry(
            id: 'b3',
            startTime: '14:55',
            endTime: '15:50',
            stationFrom: 'CGY',
            stationTo: 'CGV',
            line: 'UP',
            items: [
              WorkItem(activity: 'Sleepers unloaded', output: 24, outputUnit: 'Nos'),
            ],
          ),
          BlockEntry(
            id: 'b4',
            startTime: '16:38',
            endTime: '16:53',
            stationFrom: 'CGV',
            stationTo: 'KTYM',
            isTransit: true,
          ),
        ],
      );

      final report = ReportService.formatReport(log);

      expect(report, contains('Progress of UTV005H on 12.09.2026'));
      expect(report, contains('Division: TVC'));
      expect(report, contains('Section: KTYM'));
      expect(report, contains('Machine ready at CGY – 09:25 hrs.'));
      expect(report, contains('Block – 1'));
      expect(report, contains('BT: 10:35 – 11:20 hrs'));
      expect(report, contains('CGY – CGV (UP)'));
      expect(report, contains('Sleepers unloaded: 16 Nos'));
      expect(report, contains('CGY – TRVL (DN)'));
      expect(report, contains('Sleepers loaded: 64 Nos'));
      expect(report, contains('CGV – KTYM : 16:38 – 16:53 hrs'));
      expect(report, contains('Total:'));
      expect(report, contains('Sleepers loaded: 64 Nos'));
      expect(report, contains('Sleepers unloaded: 40 Nos'));
      expect(report, contains('= 104 nos'));
      expect(report, contains('Machine stabled at KTYM.'));
    });

    test('Formats multiple work items within a single block', () {
      const log = ShiftLog(
        date: '2026-09-12',
        machineName: 'UTV005H',
        division: 'TVC',
        section: 'KTYM',
        blocks: [
          BlockEntry(
            id: 'm1',
            startTime: '10:00',
            endTime: '11:00',
            stationFrom: 'CGY',
            stationTo: 'CGV',
            line: 'Both',
            items: [
              WorkItem(activity: 'Sleepers unloaded', output: 20, outputUnit: 'Nos'),
              WorkItem(activity: 'Rails loaded', output: 5, outputUnit: 'Nos'),
            ],
          ),
        ],
      );

      final report = ReportService.formatReport(log);
      expect(report, contains('CGY – CGV (Both)'));
      expect(report, contains('Sleepers unloaded: 20 Nos'));
      expect(report, contains('Rails loaded: 5 Nos'));
      expect(report, contains('Total:'));
      expect(report, contains('Sleepers unloaded: 20 Nos'));
      expect(report, contains('Rails loaded: 5 Nos'));
      expect(report, contains('= 25 nos'));
    });
  });

  group('StorageService', () {
    test('Saves and retrieves active shift and history', () async {
      final initial = await StorageService.getActiveShift();
      expect(initial.machineName, 'UTV005H');

      final updated = initial.copyWith(
        machineName: 'DUOMAT 814',
        blocks: [
          const BlockEntry(
            id: 't1',
            startTime: '02:00',
            endTime: '04:00',
            stationFrom: 'TCR',
            stationTo: 'OLR',
            items: [
              WorkItem(activity: 'Tamping done', output: 1500, outputUnit: 'Meters'),
            ],
          ),
        ],
      );

      await StorageService.saveActiveShift(updated);
      final fetched = await StorageService.getActiveShift();
      expect(fetched.machineName, 'DUOMAT 814');
      expect(fetched.blocks.length, 1);

      // Test saveOrUpdateHistoryShift
      // 1. Initial save
      final res1 = await StorageService.saveOrUpdateHistoryShift(updated);
      expect(res1, SaveHistoryResult.savedNew);
      var history = await StorageService.getHistory();
      expect(history.length, 1);
      expect(history.first.machineName, 'DUOMAT 814');

      // 2. Press again without change
      final res2 = await StorageService.saveOrUpdateHistoryShift(updated);
      expect(res2, SaveHistoryResult.noChanges);
      history = await StorageService.getHistory();
      expect(history.length, 1);

      // 3. Press again with change
      final modified = updated.copyWith(section: 'ALLP');
      final res3 = await StorageService.saveOrUpdateHistoryShift(modified);
      expect(res3, SaveHistoryResult.updated);
      history = await StorageService.getHistory();
      expect(history.length, 1);
      expect(history.first.section, 'ALLP');
    });

    test('Export and import backup JSON', () async {
      final exportJson = await StorageService.exportBackupJson();
      expect(exportJson, contains('TRACKR_Lite'));

      final success = await StorageService.importBackupJson(exportJson);
      expect(success, isTrue);
    });

    test('resetAllData resets active shift, history, and notes to 0', () async {
      await StorageService.resetAllData();
      final fresh = await StorageService.getActiveShift();
      final history = await StorageService.getHistory();
      final notes = await StorageService.getNotes();

      expect(fresh.blocks, isEmpty);
      expect(fresh.blockCount, 0);
      expect(fresh.totalBlockOutput, 0.0);
      expect(history, isEmpty);
      expect(notes, isEmpty);
    });
  });
}
