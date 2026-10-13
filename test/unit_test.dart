import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackr_lite/models/block_entry.dart';
import 'package:trackr_lite/models/movement_entry.dart';
import 'package:trackr_lite/models/shift_log.dart';
import 'package:trackr_lite/services/movement_service.dart';
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

    test('Includes shift remarks after machine stabled section', () {
      const log = ShiftLog(
        date: '2026-09-12',
        machineName: 'UTV005H',
        division: 'TVC',
        section: 'KTYM',
        stabledStation: 'KTYM',
        stabledTime: '17:30',
        remarks: 'Heavy rain delayed work. Machine in working condition.',
        blocks: [],
      );

      final report = ReportService.formatReport(log);
      expect(report, contains('Remarks: Heavy rain delayed work. Machine in working condition.'));
      expect(report, contains('Machine stabled at KTYM – 17:30 hrs.'));
      final remarksPos = report.indexOf('Remarks:');
      final stabledPos = report.indexOf('Machine stabled');
      expect(stabledPos, lessThan(remarksPos));

      // Test JSON roundtrip
      final json = log.toJson();
      expect(json['remarks'], 'Heavy rain delayed work. Machine in working condition.');
      final restored = ShiftLog.fromJson(json);
      expect(restored.remarks, log.remarks);
    });

    test('Formats night shift date as dual dates (e.g. 12/13.10.2026)', () {
      const dayLog = ShiftLog(
        date: '2026-10-12',
        machineName: 'UTV005H',
        division: 'TVC',
        section: 'KTYM',
        isNightShift: false,
        blocks: [],
      );
      expect(dayLog.formattedDate, '12.10.2026');

      const nightLog = ShiftLog(
        date: '2026-10-12',
        machineName: 'UTV005H',
        division: 'TVC',
        section: 'KTYM',
        isNightShift: true,
        blocks: [],
      );
      expect(nightLog.formattedDate, '12/13.10.2026');

      final report = ReportService.formatReport(nightLog);
      expect(report, contains('Progress of UTV005H on 12/13.10.2026'));

      // Month crossing check (e.g. Oct 31 to Nov 01)
      const monthEndLog = ShiftLog(
        date: '2026-10-31',
        machineName: 'UTV005H',
        division: 'TVC',
        section: 'KTYM',
        isNightShift: true,
        blocks: [],
      );
      expect(monthEndLog.formattedDate, '31.10/01.11.2026');
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

    test('Saves, loads, edits, and fully deletes remark templates', () async {
      final initial = await StorageService.getRemarkTemplates();
      expect(initial, contains('Kindly arrange one barrel diesel'));
      expect(initial, isNot(contains('Diesel filled: ___ Ltrs at ___')));

      // Test adding
      await StorageService.addRemarkTemplate('Custom Track Template #1');
      var updated = await StorageService.getRemarkTemplates();
      expect(updated, contains('Custom Track Template #1'));

      // Test editing
      final idx = updated.indexOf('Custom Track Template #1');
      await StorageService.updateRemarkTemplate(idx, 'Modified Track Template #1');
      updated = await StorageService.getRemarkTemplates();
      expect(updated, contains('Modified Track Template #1'));
      expect(updated, isNot(contains('Custom Track Template #1')));

      // Test deleting all templates fully to empty list
      while (updated.isNotEmpty) {
        await StorageService.deleteRemarkTemplate(0);
        updated = await StorageService.getRemarkTemplates();
      }
      expect(updated, isEmpty);

      // Verify that after deletion, getRemarkTemplates still returns [] and does NOT restore defaults
      final afterEmpty = await StorageService.getRemarkTemplates();
      expect(afterEmpty, isEmpty);
    });

    test('Preserves user active shift across date changes and app updates if work is logged', () async {
      final pastDateShift = ShiftLog(
        date: '2026-10-10', // Past date
        machineName: 'UTV005H',
        division: 'TVC',
        section: 'KTYM',
        remarks: 'Night work in progress',
        isNightShift: true,
        blocks: [
          const BlockEntry(
            id: 'p1',
            startTime: '22:00',
            endTime: '02:00',
            stationFrom: 'KTYM',
            stationTo: 'CGY',
            items: [
              WorkItem(activity: 'Sleepers unloaded', output: 120, outputUnit: 'Nos'),
            ],
          ),
        ],
      );

      await StorageService.saveActiveShift(pastDateShift);

      // Fetching active shift on a different day must preserve user's data and auto-save it to history
      final retrieved = await StorageService.getActiveShift();
      expect(retrieved.blocks.length, 1);
      expect(retrieved.remarks, 'Night work in progress');
      expect(retrieved.blocks.first.items.first.output, 120);
      expect(retrieved.isNightShift, isTrue);

      // Verify it was auto-saved to history datewise
      final savedHistory = await StorageService.getHistory();
      expect(savedHistory.any((h) => h.date == '2026-10-10'), isTrue);
    });

    test('Sorts history datewise and looks up by date and night shift', () async {
      await StorageService.resetAllData();

      const shiftOct10 = ShiftLog(
        date: '2026-10-10',
        machineName: 'UTV005H',
        division: 'TVC',
        section: 'KTYM',
        blocks: [],
      );
      const shiftOct12 = ShiftLog(
        date: '2026-10-12',
        machineName: 'UTV005H',
        division: 'TVC',
        section: 'KTYM',
        blocks: [],
      );
      const shiftOct11 = ShiftLog(
        date: '2026-10-11',
        machineName: 'UTV005H',
        division: 'TVC',
        section: 'KTYM',
        blocks: [],
      );
      const shiftOct12Night = ShiftLog(
        date: '2026-10-12',
        machineName: 'UTV005H',
        division: 'TVC',
        section: 'KTYM',
        isNightShift: true,
        blocks: [],
      );

      await StorageService.saveOrUpdateHistoryShift(shiftOct10);
      await StorageService.saveOrUpdateHistoryShift(shiftOct12);
      await StorageService.saveOrUpdateHistoryShift(shiftOct11);
      await StorageService.saveOrUpdateHistoryShift(shiftOct12Night);

      final history = await StorageService.getHistory();
      expect(history.length, 4);
      // Datewise order: 2026-10-12 (night), 2026-10-12 (day), 2026-10-11, 2026-10-10
      expect(history[0].date, '2026-10-12');
      expect(history[0].isNightShift, isTrue);
      expect(history[1].date, '2026-10-12');
      expect(history[1].isNightShift, isFalse);
      expect(history[2].date, '2026-10-11');
      expect(history[3].date, '2026-10-10');

      // Test getHistoryShiftForDate
      final foundOct11 = await StorageService.getHistoryShiftForDate('2026-10-11');
      expect(foundOct11, isNotNull);
      expect(foundOct11!.date, '2026-10-11');

      final foundNight = await StorageService.getHistoryShiftForDate('2026-10-12', isNightShift: true);
      expect(foundNight, isNotNull);
      expect(foundNight!.isNightShift, isTrue);
    });

    test('Movement overrides can be saved, retrieved, and deleted', () async {
      const override = MovementDayItem(
        date: '2026-10-05',
        type: MovementItemType.stay,
        stayStation: 'AWY',
        isManualOverride: true,
      );

      await StorageService.saveMovementOverride(override);
      var overrides = await StorageService.getMovementOverrides();
      expect(overrides.containsKey('2026-10-05'), isTrue);
      expect(overrides['2026-10-05']!.stayStation, 'AWY');
      expect(overrides['2026-10-05']!.isManualOverride, isTrue);

      await StorageService.deleteMovementOverride('2026-10-05');
      overrides = await StorageService.getMovementOverrides();
      expect(overrides.containsKey('2026-10-05'), isFalse);
    });
  });

  group('MovementService', () {
    test('formatTimeDot formats military and dotted time notation correctly', () {
      expect(MovementService.formatTimeDot('09:16'), '09.16');
      expect(MovementService.formatTimeDot('9:16'), '09.16');
      expect(MovementService.formatTimeDot('16:36'), '16.36');
      expect(MovementService.formatTimeDot('09.16'), '09.16');
      expect(MovementService.formatTimeDot(''), '_____');
      expect(MovementService.formatTimeDot('_____'), '_____');
    });

    test('formatDateDot formats DateTime correctly', () {
      expect(MovementService.formatDateDot(DateTime(2026, 10, 1)), '01.10.26');
      expect(MovementService.formatDateDot(DateTime(2026, 10, 15)), '15.10.26');
    });

    test('formatDualDateDot formats cross-day and cross-month night dates', () {
      expect(MovementService.formatDualDateDot(DateTime(2026, 10, 6), DateTime(2026, 10, 7)), '06/07.10.26');
      expect(MovementService.formatDualDateDot(DateTime(2026, 10, 31), DateTime(2026, 11, 1)), '31.10/01.11.26');
    });

    test('Generates Register and Dual Date movement report strings according to reference sheet', () {
      final days = [
        const MovementDayItem(
          date: '2026-10-01',
          type: MovementItemType.transit,
          runs: [
            MovementRun(
              fromStation: 'KTYM',
              toStation: 'CGY',
              departureTime: '09:16',
              arrivalTime: '16:36',
            ),
          ],
        ),
        const MovementDayItem(
          date: '2026-10-02',
          type: MovementItemType.stay,
          stayStation: 'CGY',
        ),
        const MovementDayItem(
          date: '2026-10-06',
          type: MovementItemType.transit,
          runs: [
            MovementRun(
              fromStation: 'AFK',
              toStation: 'AWY',
              departureTime: '21:57',
              arrivalTime: '04:20',
              isOvernight: true,
              isDepartureLeg: true,
            ),
          ],
        ),
        const MovementDayItem(
          date: '2026-10-07',
          type: MovementItemType.transit,
          runs: [
            MovementRun(
              fromStation: 'AFK',
              toStation: 'AWY',
              departureTime: '21:57',
              arrivalTime: '04:20',
              isOvernight: true,
              isArrivalLeg: true,
            ),
            MovementRun(
              fromStation: 'AWY',
              toStation: 'TCR',
              departureTime: '15:53',
              arrivalTime: '',
              isOvernight: false,
            ),
          ],
        ),
      ];

      // 1. Register style
      final registerReport = MovementService.formatMovementReport(
        monthDays: days,
        selectedMonth: DateTime(2026, 10, 1),
        machineName: 'UTV005H',
        division: 'TVC',
        style: MovementFormatStyle.register,
      );

      expect(registerReport, contains('* MACHINE MOVEMENT – OCTOBER 2026 *'));
      expect(registerReport, contains('01.10.26 :- KTYM – CGY (09.16 – 16.36 hrs)'));
      expect(registerReport, contains('02.10.26 :- Stay at CGY'));
      expect(registerReport, contains('06.10.26 :- AFK – _____ (21.57 – _____ hrs)'));
      expect(registerReport, contains('07.10.26 :- { _____ – AWY (_____ – 04.20 hrs)'));
      expect(registerReport, contains('            { AWY – TCR (15.53 – _____ hrs)'));

      // 2. Dual date style
      final dualDateReport = MovementService.formatMovementReport(
        monthDays: days,
        selectedMonth: DateTime(2026, 10, 1),
        machineName: 'UTV005H',
        division: 'TVC',
        style: MovementFormatStyle.dualDate,
      );

      expect(dualDateReport, contains('01.10.26 :- KTYM – CGY (09.16 – 16.36 hrs)'));
      expect(dualDateReport, contains('02.10.26 :- Stay at CGY'));
      expect(dualDateReport, contains('06/07.10.26 :- AFK – AWY (21.57 – 04.20 hrs)'));
    });
  });
}
